import 'dart:convert';

import '../filtros_busca.dart';
import '../pubmed_models.dart';

/// Uma sessão de pesquisa salva.
///
/// ## O que uma sessão guarda, e por quê
///
/// Não é um favorito de artigo — é o **estado da investigação**: a pergunta, a
/// estratégia que o PubMed executou, os artigos, a síntese e a conversa.
///
/// Guardar só a consulta seria mais barato e errado: rodar a mesma busca duas
/// semanas depois devolve outro conjunto (o PubMed indexa todo dia), e a
/// síntese citaria artigos que sumiram da lista. Uma revisão precisa ser
/// **reprodutível**: o que se leu naquele dia é o que sustenta a conduta que
/// se tomou naquele dia.
///
/// Por isso `queryTraduzida` e `salvaEm` são obrigatórios — sem os dois não há
/// como auditar depois o que foi de fato pesquisado, nem quando.
class SessaoPesquisa {
  const SessaoPesquisa({
    required this.id,
    required this.titulo,
    required this.pergunta,
    required this.consultaEnviada,
    required this.queryTraduzida,
    required this.artigos,
    required this.salvaEm,
    this.modo = 'busca',
    this.sintese,
    this.conversa = const [],
    this.filtros,
    this.totalNoPubmed = 0,
    this.viaProxy = true,
    this.pmidsCitados = const [],
    this.atualizadaEm,
  });

  final String id;

  /// Nome dado pelo médico, ou derivado da pergunta.
  final String titulo;

  /// O que foi perguntado/digitado, na forma original.
  final String pergunta;

  /// A consulta Entrez efetivamente enviada (com filtros aplicados).
  final String consultaEnviada;

  /// Como o PubMed expandiu a consulta. É o registro auditável da busca.
  final String queryTraduzida;

  final List<ArtigoPubmed> artigos;
  final DateTime salvaEm;
  final DateTime? atualizadaEm;

  /// `busca` · `agente` · `chat`.
  final String modo;

  /// Síntese da IA, quando houve.
  final String? sintese;

  /// Conversa do modo chat: pares `{papel, texto}`.
  final List<Map<String, String>> conversa;

  final FiltrosBusca? filtros;
  final int totalNoPubmed;
  final bool viaProxy;

  /// PMIDs que a síntese citou — permite destacar as fontes ao restaurar.
  final List<String> pmidsCitados;

  bool get temSintese => (sintese ?? '').trim().isNotEmpty;
  bool get temConversa => conversa.isNotEmpty;

  SessaoPesquisa copyWith({
    String? titulo,
    String? sintese,
    List<Map<String, String>>? conversa,
    List<ArtigoPubmed>? artigos,
    DateTime? atualizadaEm,
  }) =>
      SessaoPesquisa(
        id: id,
        titulo: titulo ?? this.titulo,
        pergunta: pergunta,
        consultaEnviada: consultaEnviada,
        queryTraduzida: queryTraduzida,
        artigos: artigos ?? this.artigos,
        salvaEm: salvaEm,
        atualizadaEm: atualizadaEm ?? DateTime.now(),
        modo: modo,
        sintese: sintese ?? this.sintese,
        conversa: conversa ?? this.conversa,
        filtros: filtros,
        totalNoPubmed: totalNoPubmed,
        viaProxy: viaProxy,
        pmidsCitados: pmidsCitados,
      );

  Map<String, dynamic> paraJson() => {
        'id': id,
        'titulo': titulo,
        'pergunta': pergunta,
        'consultaEnviada': consultaEnviada,
        'queryTraduzida': queryTraduzida,
        'modo': modo,
        'salvaEm': salvaEm.toIso8601String(),
        if (atualizadaEm != null)
          'atualizadaEm': atualizadaEm!.toIso8601String(),
        'totalNoPubmed': totalNoPubmed,
        'viaProxy': viaProxy,
        'artigos': artigos.map((a) => a.paraJson()).toList(),
        if (sintese != null) 'sintese': sintese,
        if (conversa.isNotEmpty) 'conversa': conversa,
        if (pmidsCitados.isNotEmpty) 'pmidsCitados': pmidsCitados,
      };

  factory SessaoPesquisa.doJson(Map<String, dynamic> j) {
    List<Map<String, String>> conversa() {
      final v = j['conversa'];
      if (v is! List) return const [];
      return v
          .whereType<Map>()
          .map((m) => {
                'papel': '${m['papel'] ?? 'user'}',
                'texto': '${m['texto'] ?? ''}',
              })
          .toList();
    }

    return SessaoPesquisa(
      id: '${j['id'] ?? ''}',
      titulo: '${j['titulo'] ?? 'Sessão sem nome'}',
      pergunta: '${j['pergunta'] ?? ''}',
      consultaEnviada: '${j['consultaEnviada'] ?? ''}',
      queryTraduzida: '${j['queryTraduzida'] ?? ''}',
      modo: '${j['modo'] ?? 'busca'}',
      // Data ilegível vira "agora" em vez de explodir: uma sessão com data
      // estranha ainda é útil; uma sessão que não abre, não.
      salvaEm: DateTime.tryParse('${j['salvaEm'] ?? ''}') ?? DateTime.now(),
      atualizadaEm: DateTime.tryParse('${j['atualizadaEm'] ?? ''}'),
      totalNoPubmed:
          j['totalNoPubmed'] is num ? (j['totalNoPubmed'] as num).toInt() : 0,
      viaProxy: j['viaProxy'] != false,
      artigos: (j['artigos'] as List?)
              ?.whereType<Map>()
              .map((m) => ArtigoPubmed.doJson(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      sintese: j['sintese']?.toString(),
      conversa: conversa(),
      pmidsCitados:
          (j['pmidsCitados'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }

  String paraJsonTexto() => const JsonEncoder.withIndent('  ').convert(paraJson());

  /// Título derivado da pergunta, quando o médico não nomeia.
  static String tituloDe(String pergunta) {
    final limpo = pergunta.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (limpo.isEmpty) return 'Sessão sem nome';
    return limpo.length <= 60 ? limpo : '${limpo.substring(0, 57)}…';
  }
}
