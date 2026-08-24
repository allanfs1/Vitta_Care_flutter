import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Exceção amigável lançada pelo [DocumentService].
/// Nunca expõe credenciais ou detalhes internos sensíveis.
class DocumentException implements Exception {
  const DocumentException(this.message);
  final String message;

  @override
  String toString() => 'DocumentException: $message';
}

/// Serviço responsável pela extração de texto de arquivos anexados ao chat de IA.
///
/// Extensões de texto puro (`.txt`, `.md`, `.csv`, `.json`) são decodificadas
/// localmente (sem tráfego de rede). Demais formatos (PDF, imagens, DOCX, XLSX)
/// são enviados para a **Cloud Function proxy** `analyzeDocument`, que por sua vez
/// chama o Azure Document Intelligence com a chave NUNCA exposta ao cliente.
class DocumentService {
  const DocumentService({String? proxyUrl})
      : _proxyUrl = proxyUrl ?? defaultProxyUrl;

  /// URL pública da Cloud Function proxy de OCR.
  static const String defaultProxyUrl =
      'https://us-central1-agendaclinica-457713.cloudfunctions.net/analyzeDocument';

  final String _proxyUrl;

  /// Extrai texto de [bytes] com nome [filename].
  ///
  /// - Extensões texto (`.txt .md .csv .json`): decodificação local, sem rede.
  /// - Demais extensões: POST para [_proxyUrl] com timeout de 90 s.
  ///
  /// Lança [DocumentException] em caso de erro com mensagem amigável.
  Future<String> extractText({
    required Uint8List bytes,
    required String filename,
  }) async {
    final ext = _extension(filename);

    // ── Texto puro: decodificação local ─────────────────────────────────────
    const textExts = {'.txt', '.md', '.csv', '.json'};
    if (textExts.contains(ext)) {
      return utf8.decode(bytes, allowMalformed: true);
    }

    // ── Binário: envio ao proxy OCR ──────────────────────────────────────────
    final mime = _mimeForExt(ext);
    final contentBase64 = base64Encode(bytes);

    final payload = jsonEncode(<String, String>{
      'filename': filename,
      'mime': mime,
      'contentBase64': contentBase64,
    });

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_proxyUrl),
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () => throw DocumentException(
              'Tempo esgotado ao aguardar resposta do OCR (>90 s). '
              'Tente novamente com um arquivo menor.',
            ),
          );
    } on DocumentException {
      rethrow;
    } catch (e) {
      throw DocumentException(
        'Falha de rede ao enviar o arquivo para extração de texto. '
        'Verifique sua conexão e tente novamente.',
      );
    }

    // Trata erros HTTP de forma amigável
    switch (response.statusCode) {
      case 200:
        break;
      case 404:
        throw const DocumentException(
          'Cloud Function analyzeDocument não publicada. '
          'Execute: firebase deploy --only functions:analyzeDocument',
        );
      case 401:
      case 403:
        throw const DocumentException(
          'Erro de autorização no serviço de OCR. '
          'Verifique se o secret AZURE_DOCINTEL_KEY está configurado.',
        );
      case 429:
        throw const DocumentException(
          'Limite de requisições do serviço de OCR atingido. '
          'Aguarde alguns segundos e tente novamente.',
        );
      case >= 500:
        throw DocumentException(
          'Erro interno no serviço de OCR (HTTP ${response.statusCode}). '
          'Tente novamente mais tarde.',
        );
      default:
        throw DocumentException(
          'Resposta inesperada do proxy OCR (HTTP ${response.statusCode}).',
        );
    }

    // Decodifica a resposta JSON { "text": "..." }
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const DocumentException(
        'Resposta do serviço de OCR em formato inválido.',
      );
    }

    final text = body['text'];
    if (text is! String) {
      throw const DocumentException(
        'Campo "text" ausente ou inválido na resposta do OCR.',
      );
    }

    return text;
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  /// Retorna a extensão em minúsculas com ponto, ex.: `.pdf`.
  String _extension(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return '';
    return '.${filename.substring(dot + 1).toLowerCase()}';
  }

  /// Infere o MIME type pela extensão do arquivo.
  String _mimeForExt(String ext) {
    return switch (ext) {
      '.pdf' => 'application/pdf',
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.webp' => 'image/webp',
      '.tiff' || '.tif' => 'image/tiff',
      '.bmp' => 'image/bmp',
      '.docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => 'application/octet-stream',
    };
  }
}
