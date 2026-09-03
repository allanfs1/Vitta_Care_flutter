/// Modelos do módulo de Evidências (PubMed/NCBI).
///
/// Espelham o formato normalizado devolvido por `functions/lib/pubmed.js`.
/// Ver `.specify/EVIDENCIAS.md` §5.
library;

/// Um artigo do PubMed, já normalizado pelo servidor.
///
/// `pmid` é a **chave natural** — sempre presente. `doi` e `pmcid` são
/// identificadores complementares e podem faltar: nem todo registro os tem, e
/// tratá-los como obrigatórios descartaria artigos válidos.
class ArtigoPubmed {
  const ArtigoPubmed({
    required this.pmid,
    required this.titulo,
    this.autores = const [],
    this.periodico = '',
    this.dataPublicacao = '',
    this.ano,
    this.doi,
    this.pmcid,
    this.tiposPublicacao = const [],
    this.volume = '',
    this.paginas = '',
    this.url = '',
    this.abstractTexto,
    this.abstractSecoes,
  });

  final String pmid;
  final String titulo;
  final List<String> autores;
  final String periodico;

  /// Data como o NCBI devolve ("2024 May 3", "2024"). A precisão original é
  /// preservada: converter para `DateTime` inventaria dia e mês que o registro
  /// não afirma.
  final String dataPublicacao;
  final int? ano;
  final String? doi;
  final String? pmcid;
  final List<String> tiposPublicacao;
  final String volume;
  final String paginas;
  final String url;

  /// Preenchido sob demanda (EFetch). `null` = ainda não buscado;
  /// string vazia = buscado e o artigo não tem abstract.
  final String? abstractTexto;

  /// Resumo em seções rotuladas, quando o artigo tem resumo estruturado.
  /// `null` = não buscado; lista vazia = buscado e sem resumo.
  final List<SecaoResumo>? abstractSecoes;

  bool get temAbstract =>
      (abstractTexto ?? '').trim().isNotEmpty ||
      (abstractSecoes?.isNotEmpty ?? false);

  /// Texto livre para acesso pelo PMC quando houver.
  String? get urlPmc =>
      pmcid == null ? null : 'https://www.ncbi.nlm.nih.gov/pmc/articles/$pmcid/';

  String? get urlDoi => doi == null ? null : 'https://doi.org/$doi';

  /// Autoria abreviada no padrão bibliográfico ("Silva A, et al.").
  String get autoresCurto {
    if (autores.isEmpty) return 'Autoria não informada';
    if (autores.length == 1) return autores.first;
    if (autores.length == 2) return '${autores[0]}, ${autores[1]}';
    return '${autores.first}, et al.';
  }

  /// Citação de uma linha, pronta para exibir ou exportar.
  String get citacao {
    final partes = <String>[
      autoresCurto,
      if (titulo.isNotEmpty) titulo,
      if (periodico.isNotEmpty) periodico,
      if (dataPublicacao.isNotEmpty) dataPublicacao,
      'PMID: $pmid',
      if (doi != null) 'DOI: $doi',
    ];
    return partes.join('. ');
  }

  /// Desenho do estudo, quando o NCBI o declara. Usado para ordenar/filtrar
  /// por força de evidência — uma metanálise pesa diferente de um relato de caso.
  String? get desenhoEstudo {
    const ordem = [
      'Meta-Analysis',
      'Systematic Review',
      'Randomized Controlled Trial',
      'Clinical Trial',
      'Observational Study',
      'Review',
      'Case Reports',
    ];
    for (final t in ordem) {
      if (tiposPublicacao.contains(t)) return t;
    }
    return tiposPublicacao.isEmpty ? null : tiposPublicacao.first;
  }

  factory ArtigoPubmed.doJson(Map<String, dynamic> j) {
    List<String> lista(Object? v) => v is List
        ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const [];
    String? nulo(Object? v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    return ArtigoPubmed(
      pmid: (j['pmid'] ?? '').toString(),
      titulo: (j['titulo'] ?? '').toString(),
      autores: lista(j['autores']),
      periodico: (j['periodico'] ?? '').toString(),
      dataPublicacao: (j['dataPublicacao'] ?? '').toString(),
      ano: j['ano'] is num ? (j['ano'] as num).toInt() : null,
      doi: nulo(j['doi']),
      pmcid: nulo(j['pmcid']),
      tiposPublicacao: lista(j['tiposPublicacao']),
      volume: (j['volume'] ?? '').toString(),
      paginas: (j['paginas'] ?? '').toString(),
      url: (j['url'] ?? '').toString(),
      abstractTexto: nulo(j['abstract']),
      abstractSecoes: j['abstractSecoes'] is List
          ? (j['abstractSecoes'] as List)
              .whereType<Map>()
              .map((m) => SecaoResumo.doJson(Map<String, dynamic>.from(m)))
              .toList()
          : null,
    );
  }

  ArtigoPubmed comAbstract(String? texto) => ArtigoPubmed(
        pmid: pmid,
        titulo: titulo,
        autores: autores,
        periodico: periodico,
        dataPublicacao: dataPublicacao,
        ano: ano,
        doi: doi,
        pmcid: pmcid,
        tiposPublicacao: tiposPublicacao,
        volume: volume,
        paginas: paginas,
        url: url,
        abstractTexto: texto,
        abstractSecoes: abstractSecoes,
      );

  ArtigoPubmed comSecoes(List<SecaoResumo>? secoes) => ArtigoPubmed(
        pmid: pmid,
        titulo: titulo,
        autores: autores,
        periodico: periodico,
        dataPublicacao: dataPublicacao,
        ano: ano,
        doi: doi,
        pmcid: pmcid,
        tiposPublicacao: tiposPublicacao,
        volume: volume,
        paginas: paginas,
        url: url,
        abstractTexto: secoes == null
            ? abstractTexto
            : secoes.map((s) => s.texto).join('\n\n'),
        abstractSecoes: secoes,
      );

  Map<String, dynamic> paraJson() => {
        'pmid': pmid,
        'titulo': titulo,
        'autores': autores,
        'periodico': periodico,
        'dataPublicacao': dataPublicacao,
        'ano': ano,
        'doi': doi,
        'pmcid': pmcid,
        'tiposPublicacao': tiposPublicacao,
        'url': url,
        if (abstractTexto != null) 'abstract': abstractTexto,
        // As seções entram no JSON porque uma sessão salva sem elas perde o
        // resumo — e resumo é o que sustenta a síntese que a sessão guarda.
        if (abstractSecoes != null)
          'abstractSecoes': abstractSecoes!.map((s) => s.paraJson()).toList(),
      };
}

/// Ordenação da busca.
///
/// Vive aqui — e não no serviço — porque os dois caminhos de rede (proxy e
/// direto) precisam do tipo, e pô-lo no serviço criaria ciclo de importação.
enum OrdemBusca {
  /// Best Match do PubMed — o padrão, e quase sempre o melhor.
  relevancia,

  /// Data de publicação decrescente. Use quando recência importa mais que
  /// adequação (ex.: "o que saiu de novo sobre X").
  data,
}

/// Um trecho rotulado do resumo ("BACKGROUND", "CONCLUSIONS"...).
///
/// O rótulo vem do PubMed quando o resumo é estruturado, e é vazio quando o
/// artigo tem resumo corrido. Preservar a estrutura importa para leitura
/// clínica: uma frase em CONCLUSIONS pesa diferente da mesma frase em METHODS.
class SecaoResumo {
  const SecaoResumo({required this.rotulo, required this.texto});

  /// Vazio quando o resumo não é estruturado.
  final String rotulo;
  final String texto;

  bool get temRotulo => rotulo.trim().isNotEmpty;

  Map<String, dynamic> paraJson() => {'rotulo': rotulo, 'texto': texto};

  factory SecaoResumo.doJson(Map<String, dynamic> j) => SecaoResumo(
        rotulo: (j['rotulo'] ?? '').toString(),
        texto: (j['texto'] ?? '').toString(),
      );

  /// Rótulo em português, quando é um dos padrões do PubMed. Rótulos fora da
  /// lista saem como vieram — inventar tradução para um rótulo desconhecido
  /// seria pior que mostrar o original.
  String get rotuloPt => switch (rotulo.toUpperCase()) {
        'BACKGROUND' || 'INTRODUCTION' => 'Contexto',
        'OBJECTIVE' || 'OBJECTIVES' || 'AIM' || 'AIMS' || 'PURPOSE' => 'Objetivo',
        'METHODS' || 'METHOD' || 'MATERIALS AND METHODS' => 'Métodos',
        'RESULTS' || 'FINDINGS' => 'Resultados',
        'CONCLUSION' || 'CONCLUSIONS' => 'Conclusões',
        'IMPORTANCE' => 'Relevância',
        'DESIGN' || 'DESIGN, SETTING, AND PARTICIPANTS' => 'Desenho',
        'INTERVENTION' || 'INTERVENTIONS' => 'Intervenção',
        'MAIN OUTCOMES AND MEASURES' || 'OUTCOMES' => 'Desfechos',
        'LIMITATIONS' => 'Limitações',
        _ => rotulo,
      };
}

/// Resultado de uma busca — inclui **como** a busca foi feita, não só o que
/// voltou.
///
/// `queryTraduzida` é o `querytranslation` do NCBI: o que o PubMed realmente
/// pesquisou depois de expandir sinônimos e MeSH. Sem ele não há como explicar
/// ao médico a diferença entre o que ele perguntou e o que foi buscado — que é
/// exatamente onde uma busca decepciona sem que ninguém entenda por quê.
class ResultadoBusca {
  const ResultadoBusca({
    required this.total,
    required this.pmids,
    required this.queryEnviada,
    required this.queryTraduzida,
    this.artigos = const [],
    this.retstart = 0,
    this.doCache = false,
    this.buscadoEm,
    this.viaProxy = true,
  });

  /// Total de registros que a consulta encontrou no PubMed (não o que veio).
  final int total;
  final List<String> pmids;
  final String queryEnviada;
  final String queryTraduzida;
  final List<ArtigoPubmed> artigos;
  final int retstart;
  final bool doCache;
  final DateTime? buscadoEm;

  /// `false` quando o resultado veio do caminho direto ao NCBI, sem passar pelo
  /// `pubmedProxy`. A tela mostra isso: as garantias não são as mesmas
  /// (ver `pubmed_direct.dart`), e esconder a diferença seria enganoso.
  final bool viaProxy;

  bool get vazio => pmids.isEmpty;

  /// `true` quando o PubMed encontrou mais do que esta página trouxe.
  bool get temMais => retstart + pmids.length < total;

  ResultadoBusca comArtigos(List<ArtigoPubmed> lista) => ResultadoBusca(
        total: total,
        pmids: pmids,
        queryEnviada: queryEnviada,
        queryTraduzida: queryTraduzida,
        artigos: lista,
        retstart: retstart,
        doCache: doCache,
        buscadoEm: buscadoEm,
        viaProxy: viaProxy,
      );

  factory ResultadoBusca.doJson(Map<String, dynamic> j) => ResultadoBusca(
        total: j['total'] is num ? (j['total'] as num).toInt() : 0,
        pmids: j['pmids'] is List
            ? (j['pmids'] as List).map((e) => e.toString()).toList()
            : const [],
        queryEnviada: (j['queryEnviada'] ?? '').toString(),
        queryTraduzida: (j['queryTraduzida'] ?? '').toString(),
        retstart: j['retstart'] is num ? (j['retstart'] as num).toInt() : 0,
        doCache: j['doCache'] == true,
        buscadoEm: DateTime.tryParse((j['buscadoEm'] ?? '').toString()),
      );
}

/// Erro do módulo, com o código que o servidor devolveu.
///
/// O código importa para a UI: `PHI_BLOCKED` não é falha — é a guarda de dado
/// pessoal funcionando, e merece uma mensagem que ensina em vez de assustar.
class EvidenciaErro implements Exception {
  const EvidenciaErro(this.mensagem, {this.codigo = 'ERRO', this.status});

  final String mensagem;
  final String codigo;
  final int? status;

  bool get bloqueadoPorDadoPessoal => codigo == 'PHI_BLOCKED';
  bool get precisaLogin => codigo == 'UNAUTHENTICATED';
  bool get naoConfigurado => codigo == 'NOT_CONFIGURED';
  bool get limiteAtingido => codigo == 'RATE_LIMITED';

  /// O proxy existe no papel mas não serve: não publicado (404), bloqueado
  /// pelo navegador, ou publicado **sem configuração** (503).
  ///
  /// Os três levam ao mesmo lugar — a busca precisa sair pelo caminho direto —
  /// e para quem usa são o mesmo problema.
  ///
  /// **`NOT_CONFIGURED` entrou aqui depois.** Sem ele, publicar a função sem
  /// `NCBI_TOOL`/`NCBI_EMAIL` deixava a tela PIOR do que antes do deploy: em
  /// vez de cair para o NCBI direto, ela morria num 503. Um proxy mal
  /// configurado tem que degradar como um proxy ausente.
  ///
  /// Na web o 404 e a falha de rede são **indistinguíveis**: o 404 da Cloud
  /// Function vem sem `Access-Control-Allow-Origin`, então o navegador bloqueia
  /// antes de o código ler o status.
  bool get proxyIndisponivel =>
      codigo == 'NOT_DEPLOYED' ||
      codigo == 'NETWORK' ||
      codigo == 'NOT_CONFIGURED';

  bool get consultaInvalida => codigo == 'INVALID_QUERY';

  @override
  String toString() => mensagem;
}
