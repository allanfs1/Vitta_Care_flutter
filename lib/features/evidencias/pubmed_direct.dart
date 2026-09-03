import 'dart:convert';

import 'package:http/http.dart' as http;

import 'efetch_xml.dart';
import 'phi_guard.dart';
import 'pubmed_models.dart';

/// Conector **direto** ao NCBI E-utilities, do próprio app.
///
/// ## Quando este caminho é usado
///
/// Só quando o `pubmedProxy` não responde. O proxy continua sendo o caminho
/// preferido — ver `.specify/EVIDENCIAS.md` §3. Este é o plano B, e existe
/// porque a alternativa era a tela inteira ficar inútil até alguém publicar a
/// Cloud Function.
///
/// ## O que se perde no plano B (e o que não se perde)
///
/// | | Proxy | Direto |
/// |---|---|---|
/// | Guarda de PHI | servidor, inescapável | [detectarPhi] no cliente |
/// | Limite de taxa | balde global, coordenado | o do navegador do usuário |
/// | Cache | compartilhado entre clínicas | memória da aba |
/// | API key do NCBI | usada (10 req/s) | não usada (~3 req/s) |
/// | Autenticação | exigida | não há |
///
/// A linha que importa é a primeira: **a guarda de PHI continua rodando**. Ela
/// é a única cujo furo teria consequência de LGPD; as demais diferenças custam
/// desempenho, não conformidade.
///
/// ## Por que isto funciona no navegador
///
/// O NCBI responde `Access-Control-Allow-Origin: *` (verificado em
/// 2026-09-01), então o build web chama sem intermediário. Nenhum segredo é
/// exposto: o caminho direto **não** usa API key — o teto menor é aceito de
/// propósito, em troca de não embarcar credencial no bundle.
class PubmedDirect {
  PubmedDirect({
    http.Client? client,
    this.tool = 'vitta_app',
    this.email = '',
  }) : _client = client ?? http.Client();

  static const String _base = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils';

  final http.Client _client;

  /// Identificação exigida pelo NCBI em toda chamada. Sem `email` o NCBI ainda
  /// responde, mas passa a tratar o tráfego como anônimo — e é a informação que
  /// ele usa para avisar antes de bloquear.
  final String tool;
  final String email;

  /// Cache de processo. Some ao recarregar a aba — é o esperado: o cache que
  /// vale é o do servidor, compartilhado. Este só evita repetir a mesma busca
  /// dentro da sessão.
  final Map<String, _Entrada> _cache = {};

  static const Duration _ttlBusca = Duration(minutes: 15);
  static const Duration _ttlArtigo = Duration(hours: 24);

  // ── Operações ────────────────────────────────────────────────────────

  Future<ResultadoBusca> buscar(
    String termo, {
    int limite = 20,
    int offset = 0,
    OrdemBusca ordem = OrdemBusca.relevancia,
  }) async {
    _exigirLiberado(termo);
    final params = {
      'db': 'pubmed',
      'term': termo,
      'retmode': 'json',
      'retmax': '${limite.clamp(1, 100)}',
      'retstart': '$offset',
      if (ordem == OrdemBusca.data) 'sort': 'pub_date',
    };
    final j = await _json('esearch.fcgi', params, _ttlBusca);
    final r = (j['esearchresult'] as Map?)?.cast<String, dynamic>() ?? {};

    if (r['ERROR'] != null) {
      throw EvidenciaErro(
        'O PubMed recusou a consulta: ${r['ERROR']}',
        codigo: 'INVALID_QUERY',
        status: 400,
      );
    }

    return ResultadoBusca(
      total: int.tryParse('${r['count'] ?? 0}') ?? 0,
      pmids: (r['idlist'] as List?)?.map((e) => '$e').toList() ?? const [],
      queryEnviada: termo,
      queryTraduzida: '${r['querytranslation'] ?? ''}',
      retstart: int.tryParse('${r['retstart'] ?? offset}') ?? offset,
      buscadoEm: DateTime.now(),
      viaProxy: false,
    );
  }

  Future<List<ArtigoPubmed>> resumos(List<String> pmids) async {
    if (pmids.isEmpty) return const [];
    final j = await _json('esummary.fcgi', {
      'db': 'pubmed',
      'id': pmids.join(','),
      'retmode': 'json',
      'version': '2.0',
    }, _ttlArtigo);

    final result = (j['result'] as Map?)?.cast<String, dynamic>() ?? {};
    final uids = (result['uids'] as List?)?.map((e) => '$e').toList() ?? pmids;

    final out = <ArtigoPubmed>[];
    for (final uid in uids) {
      final reg = (result[uid] as Map?)?.cast<String, dynamic>();
      if (reg != null) out.add(_normalizar(uid, reg));
    }
    return out;
  }

  /// Resumos em seções rotuladas, por PMID.
  ///
  /// Usa `retmode=xml`: o formato texto do EFetch é um relatório para humanos e
  /// separá-lo por heurística de linha erra (ver [lerAbstractsXml]).
  Future<Map<String, List<SecaoResumo>>> abstracts(List<String> pmids) async {
    if (pmids.isEmpty) return const {};
    final xml = await _texto('efetch.fcgi', {
      'db': 'pubmed',
      'id': pmids.join(','),
      'retmode': 'xml',
      'rettype': 'abstract',
    }, _ttlArtigo);
    return lerAbstractsXml(xml);
  }

  Future<List<String>> relacionados(String pmid, {int limite = 10}) async {
    final j = await _json('elink.fcgi', {
      'dbfrom': 'pubmed',
      'db': 'pubmed',
      'id': pmid,
      'linkname': 'pubmed_pubmed',
      'retmode': 'json',
    }, _ttlArtigo);

    final sets = (j['linksets'] as List?) ?? const [];
    final out = <String>[];
    for (final s in sets) {
      for (final db in ((s as Map?)?['linksetdbs'] as List?) ?? const []) {
        for (final l in ((db as Map?)?['links'] as List?) ?? const []) {
          final id = '$l';
          if (id != pmid && !out.contains(id)) out.add(id);
        }
      }
    }
    return out.take(limite).toList();
  }

  /// ESpell — **só responde XML**. Pedir `retmode=json` devolve HTTP 500
  /// (verificado contra o serviço real; o swagger do projeto documenta errado).
  Future<String> corrigirTermo(String termo) async {
    _exigirLiberado(termo);
    final xml = await _texto(
      'espell.fcgi',
      {'db': 'pubmed', 'term': termo},
      const Duration(days: 7),
    );
    return _tag(xml, 'CorrectedQuery');
  }

  // ── Transporte ───────────────────────────────────────────────────────

  void _exigirLiberado(String termo) {
    final phi = detectarPhi(termo);
    if (phi.isNotEmpty) {
      throw EvidenciaErro(
        'Busca bloqueada: o termo contém ${phi.join(", ")}. '
        'Use apenas os elementos clínicos da pergunta.',
        codigo: 'PHI_BLOCKED',
        status: 400,
      );
    }
  }

  Uri _uri(String caminho, Map<String, String> params) => Uri.parse(
        '$_base/$caminho',
      ).replace(queryParameters: {
        ...params,
        'tool': tool,
        if (email.isNotEmpty) 'email': email,
      });

  Future<String> _texto(
    String caminho,
    Map<String, String> params,
    Duration ttl,
  ) async {
    final chave = '$caminho?${_ordenar(params)}';
    final guardado = _cache[chave];
    if (guardado != null && !guardado.expirou) return guardado.corpo;

    final res = await _pegar(_uri(caminho, params));
    _cache[chave] = _Entrada(res, DateTime.now().add(ttl));
    return res;
  }

  Future<Map<String, dynamic>> _json(
    String caminho,
    Map<String, String> params,
    Duration ttl,
  ) async {
    final corpo = await _texto(caminho, params, ttl);
    try {
      final d = jsonDecode(corpo);
      return d is Map<String, dynamic> ? d : <String, dynamic>{};
    } catch (_) {
      throw const EvidenciaErro(
        'O PubMed devolveu uma resposta que não pôde ser lida.',
        codigo: 'UPSTREAM_ERROR',
        status: 502,
      );
    }
  }

  /// GET com repetição em erro transitório.
  ///
  /// O NCBI devolve 429/500/503 sob carga com alguma frequência; desistir na
  /// primeira faria a tela piscar erro por algo que a segunda tentativa
  /// resolve. Erros permanentes (4xx que não 429) não são repetidos.
  Future<String> _pegar(Uri uri) async {
    const esperas = [Duration(milliseconds: 400), Duration(milliseconds: 1200)];
    Object? ultimo;

    for (var tentativa = 0; tentativa <= esperas.length; tentativa++) {
      try {
        final res = await _client.get(uri).timeout(const Duration(seconds: 30));
        if (res.statusCode == 200) return res.body;

        final transitorio = res.statusCode == 429 || res.statusCode >= 500;
        if (!transitorio) {
          throw EvidenciaErro(
            'O PubMed recusou a consulta (HTTP ${res.statusCode}).',
            codigo: res.statusCode == 400 ? 'INVALID_QUERY' : 'UPSTREAM_ERROR',
            status: res.statusCode,
          );
        }
        ultimo = EvidenciaErro(
          res.statusCode == 429
              ? 'Limite de requisições do PubMed atingido. Aguarde alguns segundos.'
              : 'O PubMed está instável no momento (HTTP ${res.statusCode}).',
          codigo: res.statusCode == 429 ? 'RATE_LIMITED' : 'UPSTREAM_ERROR',
          status: res.statusCode,
        );
      } on EvidenciaErro {
        rethrow;
      } catch (e) {
        ultimo = e;
      }
      if (tentativa < esperas.length) {
        await Future<void>.delayed(esperas[tentativa]);
      }
    }

    if (ultimo is EvidenciaErro) throw ultimo;
    throw const EvidenciaErro(
      'Não foi possível falar com o PubMed. Verifique a conexão.',
      codigo: 'NETWORK',
    );
  }

  static String _ordenar(Map<String, String> p) {
    final chaves = p.keys.toList()..sort();
    return chaves.map((k) => '$k=${p[k]}').join('&');
  }

  void dispose() => _client.close();

  // ── Normalização ─────────────────────────────────────────────────────

  /// Converte o registro do ESummary no modelo do app.
  ///
  /// Espelha `normalizarArtigo` do servidor — as duas precisam concordar, senão
  /// a tela mostra coisas diferentes conforme o caminho usado.
  static ArtigoPubmed _normalizar(String pmid, Map<String, dynamic> r) {
    String? doi;
    String? pmcid;
    for (final id in (r['articleids'] as List?) ?? const []) {
      final m = (id as Map?)?.cast<String, dynamic>();
      final tipo = '${m?['idtype'] ?? ''}';
      final valor = '${m?['value'] ?? ''}'.trim();
      if (valor.isEmpty) continue;
      if (tipo == 'doi') doi = valor;
      if (tipo == 'pmc') pmcid = valor;
    }

    final autores = <String>[];
    for (final a in (r['authors'] as List?) ?? const []) {
      final m = (a as Map?)?.cast<String, dynamic>();
      // `CollectiveName` é o nome do grupo/consórcio, não uma pessoa — entrar
      // como autor confundiria a citação.
      if ('${m?['authtype'] ?? ''}' == 'CollectiveName') continue;
      final nome = '${m?['name'] ?? ''}'.trim();
      if (nome.isNotEmpty) autores.add(nome);
    }

    final pubdate = '${r['pubdate'] ?? ''}'.trim();
    final anoMatch = RegExp(r'\b(1[5-9]\d{2}|20\d{2})\b').firstMatch(pubdate);

    return ArtigoPubmed(
      pmid: pmid,
      titulo: '${r['title'] ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim(),
      autores: autores,
      periodico: '${r['fulljournalname'] ?? r['source'] ?? ''}'.trim(),
      dataPublicacao: pubdate,
      ano: anoMatch == null ? null : int.tryParse(anoMatch.group(1)!),
      doi: doi,
      pmcid: pmcid,
      tiposPublicacao: ((r['pubtype'] as List?) ?? const [])
          .map((e) => '$e')
          .where((e) => e.isNotEmpty)
          .toList(),
      volume: '${r['volume'] ?? ''}',
      paginas: '${r['pages'] ?? ''}',
      url: 'https://pubmed.ncbi.nlm.nih.gov/$pmid/',
    );
  }

  static String _tag(String xml, String tag) {
    final m =
        RegExp('<$tag>([\\s\\S]*?)</$tag>', caseSensitive: false).firstMatch(xml);
    if (m == null) return '';
    return m
        .group(1)!
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .trim();
  }
}

class _Entrada {
  _Entrada(this.corpo, this.expiraEm);
  final String corpo;
  final DateTime expiraEm;
  bool get expirou => DateTime.now().isAfter(expiraEm);
}
