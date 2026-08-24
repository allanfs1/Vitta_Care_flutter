import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../agent/document_service.dart';

/// Botão de anexo para o chat de IA.
///
/// Abre o seletor de arquivos nativo, extrai o texto via [DocumentService]
/// (localmente para texto puro, ou via Cloud Function OCR para PDF/imagem/DOCX/XLSX)
/// e entrega o resultado para o caller via [onExtracted].
///
/// Comportamento de estado:
/// - Ícone `attach_file` cinza ([AppColors.textSecondaryOf(context)]) quando pronto.
/// - Spinner + ícone rosa ([AppColors.pinkAccent]) durante o processamento.
/// - Desabilitado quando [enabled] é `false` ou o processamento está em andamento.
class AttachmentButton extends StatefulWidget {
  const AttachmentButton({
    super.key,
    required this.onExtracted,
    this.enabled = true,
  });

  /// Chamado com o nome do arquivo e o texto extraído ao concluir com sucesso.
  final void Function(String filename, String extractedText) onExtracted;

  /// Controla se o botão responde a interações. Passe `false` enquanto o chat
  /// está enviando uma mensagem, por exemplo.
  final bool enabled;

  @override
  State<AttachmentButton> createState() => _AttachmentButtonState();
}

class _AttachmentButtonState extends State<AttachmentButton> {
  bool _loading = false;

  // Extensões aceitas no seletor de arquivos.
  static const _allowedExtensions = [
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'txt',
    'md',
    'csv',
    'json',
    'docx',
    'xlsx',
  ];

  Future<void> _pickAndExtract() async {
    if (_loading || !widget.enabled) return;

    // ── 1. Abre o seletor de arquivos ────────────────────────────────────────
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
    } catch (_) {
      // Seletor fechado abruptamente ou permissão negada — silencioso.
      return;
    }

    // Usuário cancelou sem escolher arquivo.
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    // Bytes nulos não devem ocorrer com withData:true, mas vamos proteger.
    if (file.bytes == null || file.bytes!.isEmpty) {
      _showError('Não foi possível ler os bytes do arquivo "${file.name}".');
      return;
    }

    // ── 2. Processa com spinner ───────────────────────────────────────────────
    setState(() => _loading = true);

    try {
      final text = await DocumentService().extractText(
        bytes: file.bytes!,
        filename: file.name,
      );
      // Resultado vazio é tecnicamente válido (documento em branco), mas
      // informamos ao usuário.
      if (text.trim().isEmpty) {
        _showError(
          'Nenhum texto encontrado em "${file.name}". '
          'O arquivo pode estar em branco ou ser uma imagem sem texto.',
        );
        return;
      }
      widget.onExtracted(file.name, text);
    } on DocumentException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Erro inesperado ao processar o arquivo. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.enabled && !_loading;

    return IconButton(
      onPressed: isActive ? _pickAndExtract : null,
      tooltip: 'Anexar arquivo (PDF, imagem, DOCX, XLSX, texto)',
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.pinkAccent,
              ),
            )
          : Icon(
              Icons.attach_file,
              color: isActive
                  ? AppColors.pinkAccent
                  : AppColors.textSecondaryOf(context),
            ),
    );
  }
}
