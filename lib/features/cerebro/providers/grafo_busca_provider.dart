import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/ai_service.dart';
import '../agent/agent_search_engine.dart';
import '../index/busca_service.dart';
import '../index/vault_index.dart';
import 'cerebro_providers.dart';

// -- Modo ---------------------------------------------------------------------

enum ModoBuscaGrafo { normal, agente }

// -- Estado -------------------------------------------------------------------

class GrafoBuscaEstado {
  const GrafoBuscaEstado({
    this.query = '',
    this.modo = ModoBuscaGrafo.normal,
    this.idsEncontrados = const {},
    this.titulosEncontrados = const [],
    this.raciocinio = '',
    this.analiseAgente,
    this.carregando = false,
    this.erro,
  });

  final String query;
  final ModoBuscaGrafo modo;

  /// IDs das notas retornadas pela busca (para destacar no grafo).
  final Set<String> idsEncontrados;

  /// Títulos das notas encontradas (para o painel de resultados da IA).
  final List<String> titulosEncontrados;

  /// Raciocínio textual gerado pelo agente IA.
  ///
  /// É um resumo verificável das evidências, não uma cadeia de pensamento.
  final String raciocinio;

  /// Prévia local e evidências que ancoram a análise remota do Agente.
  final AgentSearchAnalysis? analiseAgente;

  final bool carregando;
  final String? erro;

  bool get ativa => query.trim().isNotEmpty && idsEncontrados.isNotEmpty;
  bool get semResultado =>
      query.trim().isNotEmpty && !carregando && idsEncontrados.isEmpty;

  GrafoBuscaEstado copyWith({
    String? query,
    ModoBuscaGrafo? modo,
    Set<String>? idsEncontrados,
    List<String>? titulosEncontrados,
    String? raciocinio,
    AgentSearchAnalysis? analiseAgente,
    bool? carregando,
    String? erro,
    bool limparErro = false,
    bool limparAnaliseAgente = false,
  }) =>
      GrafoBuscaEstado(
        query: query ?? this.query,
        modo: modo ?? this.modo,
        idsEncontrados: idsEncontrados ?? this.idsEncontrados,
        titulosEncontrados: titulosEncontrados ?? this.titulosEncontrados,
        raciocinio: raciocinio ?? this.raciocinio,
        analiseAgente: limparAnaliseAgente
            ? null
            : (analiseAgente ?? this.analiseAgente),
        carregando: carregando ?? this.carregando,
        erro: limparErro ? null : (erro ?? this.erro),
      );
}

// -- Notifier -----------------------------------------------------------------

class GrafoBuscaNotifier extends StateNotifier<GrafoBuscaEstado> {
  GrafoBuscaNotifier(this._ref) : super(const GrafoBuscaEstado());

  final Ref _ref;
  Timer? _debounce;
  static const _aiService = AiService();
  int _requestVersion = 0;

  // ── API pública ──────────────────────────────────────────────────────────

  void alternarModo(ModoBuscaGrafo modo) {
    if (state.modo == modo) return;
    _requestVersion++;
    _debounce?.cancel();
    state = state.copyWith(
      modo: modo,
      idsEncontrados: {},
      titulosEncontrados: [],
      raciocinio: '',
      limparErro: true,
      limparAnaliseAgente: true,
      carregando: false,
    );
    if (state.query.trim().isNotEmpty) {
      buscar(state.query);
    }
  }

  void buscar(String query) {
    final request = ++_requestVersion;
    state = state.copyWith(query: query, limparErro: true);
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = state.copyWith(
        idsEncontrados: {},
        titulosEncontrados: [],
        raciocinio: '',
        carregando: false,
        limparAnaliseAgente: true,
      );
      return;
    }
    _debounce = Timer(
      state.modo == ModoBuscaGrafo.agente
          ? const Duration(milliseconds: 180)
          : const Duration(milliseconds: 200),
      () {
        if (request != _requestVersion) return;
        if (state.modo == ModoBuscaGrafo.agente) {
          _previsualizarAgente(query, request);
        } else {
          _buscaNormal(query);
        }
      },
    );
  }

  /// Executa o segundo estágio: a IA recebe somente a prévia local
  /// ranqueada. Use no Enter ou no botão de análise para não gastar uma
  /// chamada remota a cada tecla digitada.
  void executarAgente() {
    final query = state.query.trim();
    if (query.isEmpty || state.modo != ModoBuscaGrafo.agente) return;
    _debounce?.cancel();
    final request = ++_requestVersion;
    _buscaAgente(query, request);
  }

  void limpar() {
    _requestVersion++;
    _debounce?.cancel();
    state = GrafoBuscaEstado(modo: state.modo);
  }

  // ── Execução da Busca ────────────────────────────────────────────────────

  void _buscaNormal(String query) {
    final index = _ref.read(vaultProvider.notifier).index;
    final service = BuscaService(index);
    final resultados = service.buscar(query, limite: 200);
    final ids = resultados.map((r) => r.nota.id).toSet();
    final titulos = resultados.take(15).map((r) => r.nota.titulo).toList();
    state = state.copyWith(
      idsEncontrados: ids,
      titulosEncontrados: titulos,
      raciocinio: '',
      carregando: false,
      limparAnaliseAgente: true,
    );
  }

  // ── Busca com Agente IA ──────────────────────────────────────────────────

  void _previsualizarAgente(String query, int request) {
    final index = _ref.read(vaultProvider.notifier).index;
    final analise = AgentSearchEngine(index).analyze(query);
    if (request != _requestVersion || state.modo != ModoBuscaGrafo.agente) {
      return;
    }
    _aplicarAnaliseLocal(analise);
  }

  Future<void> _buscaAgente(String query, int request) async {
    final index = _ref.read(vaultProvider.notifier).index;
    final local = AgentSearchEngine(index).analyze(query);
    state = state.copyWith(
      idsEncontrados: local.noteIds,
      titulosEncontrados: _titulos(local.noteIds, index),
      raciocinio: local.summary,
      analiseAgente: local,
      carregando: true,
      limparErro: true,
    );

    try {
      final contexto = _montarContexto(index, local);

      final prompt = '''Você é um agente de busca com recuperação aumentada em um vault de saúde e gestão clínica.

CONSULTA DO USUÁRIO: "$query"
INTENÇÃO DETECTADA LOCALMENTE: ${local.intent.label}

EVIDÊNCIAS RECUPERADAS LOCALMENTE (id • título • tipo • tags • motivos):
$contexto

INSTRUÇÕES:
1. Use somente IDs presentes nas evidências. Não invente notas, fatos ou ligações.
2. Priorize protocolos e decisões quando forem relevantes; use a topologia como apoio.
3. Produza um resumo curto, verificável e orientado à ação. Não exponha raciocínio interno.
4. Responda SOMENTE em JSON válido, sem texto antes ou depois:
{
  "ids": ["id_nota1", "id_nota2"],
  "titulos": ["Título 1", "Título 2"],
  "resumo": "Resumo de até 280 caracteres, citando apenas relações observáveis no vault."
}''';

      final resposta = await _aiService.helpReply([
        {
          'role': 'system',
          'content':
              'Você é um agente semântico preciso. Responda exclusivamente em JSON válido conforme o esquema solicitado.'
        },
        {'role': 'user', 'content': prompt},
      ]);

      // Tenta parsear a resposta do LLM
      final resultado = _parsearRespostaIA(resposta, index);

      if (request != _requestVersion ||
          state.modo != ModoBuscaGrafo.agente ||
          state.query.trim() != query.trim()) {
        return;
      }

      if (resultado.$1.isNotEmpty) {
        final evidence = _priorizarEvidencias(
          local.evidence,
          resultado.$1,
          index,
        );
        final analise = local.copyWith(
          evidence: evidence,
          summary: resultado.$3.isNotEmpty ? resultado.$3 : local.summary,
          remoteValidated: true,
        );
        state = state.copyWith(
          idsEncontrados: analise.noteIds,
          titulosEncontrados: _titulos(analise.noteIds, index),
          raciocinio: analise.summary,
          analiseAgente: analise,
          carregando: false,
        );
        return;
      }

      _aplicarAnaliseLocal(local);
    } catch (e) {
      debugPrint('Erro busca agente: $e');
      if (request == _requestVersion && state.modo == ModoBuscaGrafo.agente) {
        _aplicarAnaliseLocal(local);
      }
    }
  }

  void _aplicarAnaliseLocal(AgentSearchAnalysis analise) {
    final index = _ref.read(vaultProvider.notifier).index;
    state = state.copyWith(
      idsEncontrados: analise.noteIds,
      titulosEncontrados: _titulos(analise.noteIds, index),
      raciocinio: analise.summary,
      analiseAgente: analise,
      carregando: false,
      limparErro: true,
    );
  }

  List<String> _titulos(Set<String> ids, VaultIndex index) => ids
      .map((id) => index.porId(id)?.titulo ?? '')
      .where((title) => title.isNotEmpty)
      .take(15)
      .toList();

  List<AgentSearchEvidence> _priorizarEvidencias(
    List<AgentSearchEvidence> local,
    Set<String> idsRemotos,
    VaultIndex index,
  ) {
    final localById = {for (final item in local) item.noteId: item};
    final out = <AgentSearchEvidence>[];
    for (final id in idsRemotos) {
      final localItem = localById[id];
      if (localItem != null) {
        out.add(localItem);
      } else if (index.porId(id) != null) {
        out.add(AgentSearchEvidence(
          noteId: id,
          score: 1,
          reasons: const ['Selecionada pela análise IA dentro do vault'],
        ));
      }
    }
    for (final item in local) {
      if (!idsRemotos.contains(item.noteId) && out.length < 10) out.add(item);
    }
    return out.take(10).toList();
  }

  /// Monta um contexto curto e auditável: só as notas que a recuperação local
  /// já provou relevantes entram no prompt remoto.
  String _montarContexto(VaultIndex index, AgentSearchAnalysis analise) {
    final linhas = <String>[];
    for (final evidencia in analise.evidence.take(14)) {
      final nota = index.porId(evidencia.noteId);
      if (nota == null) continue;
      final tags = nota.tags.take(4).map((t) => '#$t').join(' ');
      final reasons = evidencia.reasons.join('; ');
      linhas.add(
        '${nota.id} • ${nota.titulo} • ${nota.tipo.label}'
        '${tags.isEmpty ? '' : ' • $tags'}'
        '${reasons.isEmpty ? '' : ' • Evidência: $reasons'}',
      );
    }
    return linhas.join('\n');
  }

  /// Parseia a resposta da IA de forma ultra-resiliente.
  (Set<String>, List<String>, String) _parsearRespostaIA(
      String resposta, VaultIndex index) {
    final texto = resposta.trim();

    // Se o texto for o fallback padrão de erro da IA, cai pro motor local
    if (texto.contains('Não consegui falar com a IA') ||
        texto.contains('limite de requisições')) {
      return (const {}, const [], '');
    }

    try {
      var jsonStr = texto;
      // Extrai JSON entre chaves { ... } se houver texto extra
      final inicio = jsonStr.indexOf('{');
      final fim = jsonStr.lastIndexOf('}');
      if (inicio >= 0 && fim > inicio) {
        jsonStr = jsonStr.substring(inicio, fim + 1);
      }

      final mapa = jsonDecode(jsonStr) as Map<String, dynamic>;
      final idsRaw = (mapa['ids'] as List?)?.cast<String>() ?? [];
      final titulosRaw = (mapa['titulos'] as List?)?.cast<String>() ?? [];
      final raciocinio = (mapa['raciocinio'] as String?) ?? '';

      final idsValidos = <String>{};
      for (final id in idsRaw) {
        if (index.porId(id) != null) idsValidos.add(id);
      }

      // Se não encontrou IDs válidos, tenta resolver pelos títulos
      if (idsValidos.isEmpty && titulosRaw.isNotEmpty) {
        for (final titulo in titulosRaw) {
          final idEncontrado = _encontrarIdPorTitulo(titulo, index);
          if (idEncontrado != null) idsValidos.add(idEncontrado);
        }
      }

      if (idsValidos.isNotEmpty) {
        final titulosFinais = idsValidos
            .map((id) => index.porId(id)?.titulo ?? '')
            .where((t) => t.isNotEmpty)
            .toList();
        return (
          idsValidos,
          titulosFinais,
          raciocinio.isNotEmpty ? raciocinio : 'Notas selecionadas pelo agente IA.'
        );
      }
    } catch (_) {
      // Tenta extração via regex de IDs conhecidos
      final idsExtraidos = <String>{};
      for (final notaId in index.notas.keys) {
        if (texto.contains(notaId)) {
          idsExtraidos.add(notaId);
        }
      }
      if (idsExtraidos.isNotEmpty) {
        final titulos = idsExtraidos
            .map((id) => index.porId(id)?.titulo ?? '')
            .where((t) => t.isNotEmpty)
            .toList();
        return (
          idsExtraidos,
          titulos,
          'Identificamos as notas relevantes citadas na resposta da IA.'
        );
      }
    }

    return (const {}, const [], '');
  }



  String? _encontrarIdPorTitulo(String titulo, VaultIndex index) {
    final tLower = titulo.trim().toLowerCase();
    for (final nota in index.notas.values) {
      if (nota.titulo.trim().toLowerCase() == tLower) return nota.id;
      if (nota.aliases.any((a) => a.trim().toLowerCase() == tLower)) return nota.id;
    }
    // Match parcial
    for (final nota in index.notas.values) {
      if (nota.titulo.toLowerCase().contains(tLower) ||
          tLower.contains(nota.titulo.toLowerCase())) {
        return nota.id;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

// -- Provider -----------------------------------------------------------------

final grafoBuscaProvider =
    StateNotifierProvider<GrafoBuscaNotifier, GrafoBuscaEstado>(
  (ref) => GrafoBuscaNotifier(ref),
);
