import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../../core/services/auth_service.dart';
import 'efetch_xml.dart';
import 'pubmed_direct.dart';
import 'pubmed_models.dart';

/// Por onde a consulta saiu.
enum CaminhoEvidencia {
  /// Cloud Function `pubmedProxy` — autenticada, guarda de PHI no servidor,
  /// cache e limite de taxa compartilhados. É o caminho pretendido.
  proxy,

  /// Direto ao NCBI, do navegador. Plano B enquanto o proxy não está
  /// publicado — ver [PubmedDirect] para o que muda.
  direto,
}

/// Cliente do módulo de Evidências.
///
/// ## Dois caminhos, um preferido
///
/// Tenta o `pubmedProxy` primeiro. Se ele não estiver publicado — ou o
/// navegador bloquear por CORS, que na web é indistinguível — cai para o
/// [PubmedDirect] e **avisa a tela**, que mostra a diferença ao usuário.
///
/// A alternativa seria a tela ficar inútil até alguém rodar
/// `firebase deploy --only functions:pubmedProxy`. Um módulo de pesquisa que
/// só funciona depois de um deploy manual não é um módulo, é uma promessa.
///
/// ## O fallback é lembrado por sessão
///
/// Uma vez que o proxy falhou, as chamadas seguintes vão direto sem tentar de
/// novo. Sem isso, **cada** busca pagaria o timeout do proxy antes de
/// funcionar — o usuário sentiria a tela travando a cada pesquisa.
/// [reavaliarProxy] limpa a marca (a tela chama ao recarregar).
class PubmedService {
  PubmedService({
    required AuthService auth,
    http.Client? client,
    String? proxyUrl,
    PubmedDirect? direto,
    this.permitirFallback = true,
  })  : _auth = auth,
        _client = client ?? http.Client(),
        _url = proxyUrl ?? urlPadrao,
        _direto = direto ?? PubmedDirect(client: client);

  static const String urlPadrao =
      'https://us-central1-agendaclinica-457713.cloudfunctions.net/pubmedProxy';

  final AuthService _auth;
  final http.Client _client;
  final String _url;
  final PubmedDirect _direto;

  /// `false` desliga o plano B — usado em teste para provar que o proxy é
  /// mesmo o caminho tentado primeiro.
  final bool permitirFallback;

  bool _proxyCaido = false;

  /// Caminho usado na última operação. A tela mostra isso.
  CaminhoEvidencia ultimoCaminho = CaminhoEvidencia.proxy;

  /// Motivo pelo qual o proxy foi descartado, para o painel de diagnóstico.
  String? motivoFallback;

  bool get usandoFallback => _proxyCaido;

  /// Faz a próxima chamada tentar o proxy de novo.
  void reavaliarProxy() {
    _proxyCaido = false;
    motivoFallback = null;
  }

  // ── Operações ────────────────────────────────────────────────────────

  Future<ResultadoBusca> buscar(
    String termo, {
    int limite = 20,
    int offset = 0,
    OrdemBusca ordem = OrdemBusca.relevancia,
  }) {
    return _executar(
      viaProxy: () async {
        final j = await _chamar('buscar', {
          'termo': termo,
          'limite': limite,
          'offset': offset,
          'ordem': ordem == OrdemBusca.data ? 'data' : 'relevancia',
        });
        return ResultadoBusca.doJson(j);
      },
      viaDireto: () => _direto.buscar(
        termo,
        limite: limite,
        offset: offset,
        ordem: ordem,
      ),
    );
  }

  Future<List<ArtigoPubmed>> resumos(List<String> pmids) {
    if (pmids.isEmpty) return Future.value(const []);
    return _executar(
      viaProxy: () async {
        final j = await _chamar('resumos', {'pmids': pmids});
        final lista = j['artigos'];
        if (lista is! List) return const <ArtigoPubmed>[];
        return lista
            .whereType<Map>()
            .map((e) => ArtigoPubmed.doJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      viaDireto: () => _direto.resumos(pmids),
    );
  }

  /// Busca + metadados numa tacada: é o que a tela e o agente realmente querem.
  Future<ResultadoBusca> buscarComMetadados(
    String termo, {
    int limite = 20,
    int offset = 0,
    OrdemBusca ordem = OrdemBusca.relevancia,
  }) async {
    final r = await buscar(termo, limite: limite, offset: offset, ordem: ordem);
    if (r.vazio) return r;
    return r.comArtigos(await resumos(r.pmids));
  }

  /// Resumos em seções rotuladas, por PMID.
  ///
  /// Os dois caminhos devolvem o XML do EFetch e usam o mesmo leitor — assim a
  /// tela mostra a mesma coisa independentemente de por onde a consulta saiu.
  Future<Map<String, List<SecaoResumo>>> abstracts(List<String> pmids) {
    if (pmids.isEmpty) return Future.value(const {});
    return _executar(
      viaProxy: () async {
        final j = await _chamar('abstracts', {'pmids': pmids});
        return lerAbstractsXml((j['xml'] ?? j['texto'] ?? '').toString());
      },
      viaDireto: () => _direto.abstracts(pmids),
    );
  }

  Future<List<String>> relacionados(String pmid, {int limite = 10}) {
    return _executar(
      viaProxy: () async {
        final j = await _chamar('relacionados', {
          'pmid': pmid,
          'limite': limite,
        });
        final l = j['relacionados'];
        return l is List ? l.map((e) => e.toString()).toList() : <String>[];
      },
      viaDireto: () => _direto.relacionados(pmid, limite: limite),
    );
  }

  Future<String> corrigirTermo(String termo) {
    return _executar(
      viaProxy: () async {
        final j = await _chamar('corrigir', {'termo': termo});
        return (j['corrigido'] ?? '').toString();
      },
      viaDireto: () => _direto.corrigirTermo(termo),
    );
  }

  // ── Orquestração ─────────────────────────────────────────────────────

  /// Roda [viaProxy]; se o proxy estiver indisponível, cai para [viaDireto].
  ///
  /// **Só o proxy indisponível dispara o plano B.** Um `PHI_BLOCKED` ou um
  /// `INVALID_QUERY` são respostas legítimas do servidor: repeti-las pelo
  /// caminho direto não mudaria nada e, no caso do PHI, contornaria a guarda —
  /// exatamente o que não pode acontecer.
  Future<T> _executar<T>({
    required Future<T> Function() viaProxy,
    required Future<T> Function() viaDireto,
  }) async {
    if (!_proxyCaido) {
      try {
        final r = await viaProxy();
        ultimoCaminho = CaminhoEvidencia.proxy;
        return r;
      } on EvidenciaErro catch (e) {
        if (!permitirFallback || !e.proxyIndisponivel) rethrow;
        _proxyCaido = true;
        // Mensagem para DESENVOLVEDOR (log e painel de diagnóstico). A tela
        // mostra outra, sem jargão — ver `_AvisoCaminhoDireto`.
        motivoFallback = switch (e.codigo) {
          'NOT_DEPLOYED' => 'pubmedProxy não está publicada (HTTP 404).',
          'NOT_CONFIGURED' =>
            'pubmedProxy publicada sem NCBI_TOOL/NCBI_EMAIL (HTTP 503).',
          _ => 'pubmedProxy não respondeu (rede ou CORS bloqueado).',
        };
        debugPrint('[Evidencias] proxy indisponível (${e.codigo}) — indo direto ao NCBI.');
      }
    }

    ultimoCaminho = CaminhoEvidencia.direto;
    return viaDireto();
  }

  // ── Transporte do proxy ──────────────────────────────────────────────

  Future<Map<String, dynamic>> _chamar(
    String acao,
    Map<String, dynamic> corpo,
  ) async {
    final token = await _auth.idToken();
    if (token == null || token.isEmpty) {
      throw const EvidenciaErro(
        'Entre na sua conta para pesquisar evidências.',
        codigo: 'UNAUTHENTICATED',
        status: 401,
      );
    }

    http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(_url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'acao': acao, ...corpo}),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      // Na web, o 404 de uma Cloud Function inexistente chega aqui: a resposta
      // não traz `Access-Control-Allow-Origin`, então o navegador a bloqueia
      // antes de o código ler o status. Falha de rede e função não publicada
      // são indistinguíveis daqui — por isso o mesmo código, que o
      // `proxyIndisponivel` trata como "tente o plano B".
      throw const EvidenciaErro(
        'Não foi possível falar com o serviço de evidências.',
        codigo: 'NETWORK',
      );
    }

    Map<String, dynamic> j;
    try {
      final d = jsonDecode(res.body);
      j = d is Map<String, dynamic> ? d : <String, dynamic>{};
    } catch (_) {
      j = <String, dynamic>{};
    }

    if (res.statusCode == 404) {
      throw const EvidenciaErro(
        'A função pubmedProxy não está publicada.',
        codigo: 'NOT_DEPLOYED',
        status: 404,
      );
    }

    if (res.statusCode >= 400) {
      throw EvidenciaErro(
        (j['error'] ?? 'Falha ao consultar o PubMed.').toString(),
        codigo: (j['codigo'] ?? 'UPSTREAM_ERROR').toString(),
        status: res.statusCode,
      );
    }
    return j;
  }

  void dispose() {
    _client.close();
    _direto.dispose();
  }
}
