import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modules/mcp/mcp_providers.dart';
import '../../cerebro/data/models/nota_enums.dart';
import '../../cerebro/index/vault_index.dart';
import '../../cerebro/providers/cerebro_providers.dart';
import '../../notificacoes_centro/notificacoes_provider.dart';
import '../../relatorios/models/relatorio.dart';
import '../../relatorios/providers/relatorios_provider.dart';
import '../../tarefas_agendadas/scheduled_task.dart';
import '../../tarefas_agendadas/scheduled_tasks_service.dart';
import '../agent/agent_controller.dart';
import 'vigia_models.dart';
import 'vigia_prompt.dart';

/// O **Vigia**: uma vez por dia, lê a clínica e produz duas coisas — um
/// relatório para os gestores e um conjunto de rotinas propostas.
///
/// A propriedade que sustenta o desenho: **o Vigia nunca executa nada**. Ele
/// escreve um relatório (que é leitura) e cria tarefas com `status: 'suggested'`
/// (que não rodam). Ligar uma rotina exige uma pessoa apertando "Aprovar".
///
/// Três travas independentes garantem isso:
///  1. `ScheduledTasksService.criarSugestao` grava sem `nextRunAt`.
///  2. `getDue` (Dart) filtra `status == 'active'`.
///  3. O cron (`functions/scheduledTasksCron.js`) filtra o mesmo status.
class VigiaService {
  VigiaService(this._ref);

  final Ref _ref;

  /// Coleção de auditoria dos ciclos — também serve de trava de "já rodou hoje".
  static const String colecaoCiclos = 'tb_vigia_ciclos';

  /// Teto de rotinas propostas por ciclo. Rotina demais vira ruído e o gestor
  /// aprende a ignorar a seção inteira.
  static const int tetoRotinas = 3;

  /// Confiança mínima para uma proposta chegar ao gestor.
  static const double confiancaMinima = 0.6;

  /// Executa o ciclo do dia, se ainda não rodou.
  ///
  /// [forcar] pula a trava diária — é o caminho do botão "rodar agora".
  Future<ResultadoCiclo> rodarCiclo({bool forcar = false}) async {
    final relogio = Stopwatch()..start();
    // A MESMA clinica que a tela de tarefas le (`tarefasClinicaIdProvider`).
    // Gravar numa e ler de outra faria a sugestao simplesmente nao aparecer.
    final clinicaId = _ref.read(tarefasClinicaIdProvider);
    if (clinicaId.isEmpty) {
      return const ResultadoCiclo(
        executou: false,
        motivo: 'Clínica ativa ainda não resolvida.',
      );
    }

    final hoje = _diaIso(DateTime.now());
    final docCiclo =
        FirebaseFirestore.instance.collection(colecaoCiclos).doc('${clinicaId}_$hoje');

    if (!forcar) {
      final ja = await docCiclo.get();
      if (ja.exists && (ja.data()?['executou'] == true)) {
        return const ResultadoCiclo(
          executou: false,
          motivo: 'O ciclo de hoje já rodou.',
        );
      }
    }

    try {
      final resultado = await _executar(clinicaId, hoje, relogio);
      await docCiclo.set(resultado.toMap(), SetOptions(merge: true));
      return resultado;
    } catch (e) {
      relogio.stop();
      final falha = ResultadoCiclo(
        executou: false,
        motivo: 'Falha no ciclo: $e',
        duracao: relogio.elapsed,
      );
      // Registra a falha mas NÃO marca como executado: o próximo boot tenta de
      // novo, em vez de o dia ficar sem análise por causa de uma rede ruim.
      await docCiclo.set(falha.toMap(), SetOptions(merge: true));
      return falha;
    }
  }

  Future<ResultadoCiclo> _executar(
      String clinicaId, String hoje, Stopwatch relogio) async {
    final servidor = _ref.read(mcpServerProvider);
    final specs = _ref.read(mcpToolSpecsProvider);
    final agente = _ref.read(aiAgentServiceProvider);
    final tarefas = _ref.read(scheduledTasksServiceProvider);

    final vigentes = await tarefas.paraDeduplicar(clinicaId);

    final bruto = await agente
        .runToString(
          prompt: '${vigiaSystem(tetoRotinas: tetoRotinas)}\n\n'
              '${vigiaContexto(
            dataIso: hoje,
            cerebro: _resumoCerebro(),
            rotinasVigentes: _resumoVigentes(vigentes),
            recusadas: _resumoRecusadas(vigentes),
          )}',
          toolSpecs: specs,
          callTool: (nome, args) async {
            final r = await servidor.callTool(nome, args);
            return (text: r.text, isError: r.isError);
          },
          clinicaId: clinicaId,
        )
        .timeout(const Duration(minutes: 5));

    final json = _extrairJson(bruto);
    if (json == null) {
      throw StateError('O modelo não devolveu JSON utilizável.');
    }

    // ── Relatório ──────────────────────────────────────────────────────────
    String? relatorioId;
    final relJson = json['relatorio'];
    if (relJson is Map) {
      final proposto =
          RelatorioProposto.doJson(Map<String, dynamic>.from(relJson));
      if (proposto != null) {
        relatorioId = await _gravarRelatorio(proposto, hoje, clinicaId);
      }
    }

    // ── Nota no Cérebro ────────────────────────────────────────────────────
    // Escrita antes das rotinas para que as sugestões possam apontar para ela.
    String? notaId;
    final notaJson = json['notaCerebro'];
    if (notaJson is Map) {
      notaId = await _gravarNota(Map<String, dynamic>.from(notaJson), hoje);
    }

    // ── Rotinas propostas ──────────────────────────────────────────────────
    var criadas = 0;
    var descartadas = 0;
    final jaPropostas = <String>{
      for (final t in vigentes)
        if (!t.isRecusada) t.chaveDedupe,
    };
    final recusadas = <String>{
      for (final t in vigentes)
        if (t.isRecusada) t.chaveDedupe,
    };

    for (final item in (json['rotinas'] as List? ?? const [])) {
      if (criadas >= tetoRotinas) {
        descartadas++;
        continue;
      }
      if (item is! Map) {
        descartadas++;
        continue;
      }
      final proposta = RotinaProposta.doJson(Map<String, dynamic>.from(item));
      if (proposta == null) {
        descartadas++;
        continue;
      }
      // Filtros locais. O modelo pode estar confiante e errado; estes filtros
      // não julgam o mérito, só impedem ruído óbvio de chegar ao gestor.
      if (proposta.confianca < confiancaMinima ||
          jaPropostas.contains(proposta.chaveDedupe) ||
          recusadas.contains(proposta.chaveDedupe)) {
        descartadas++;
        continue;
      }

      await tarefas.criarSugestao(
        titulo: proposta.titulo,
        descricao: proposta.descricao,
        prompt: proposta.prompt,
        kind: proposta.kind,
        schedule: proposta.schedule,
        clinicaId: clinicaId,
        problemaDetectado: proposta.problemaDetectado,
        impactoEstimado: proposta.impactoEstimado,
        evidencias: proposta.evidencias,
        confianca: proposta.confianca,
        notaCerebroId: notaId,
        relatorioId: relatorioId,
      );
      jaPropostas.add(proposta.chaveDedupe);
      criadas++;
    }

    await _notificar(criadas: criadas, temRelatorio: relatorioId != null);

    relogio.stop();
    return ResultadoCiclo(
      executou: true,
      motivo: 'Ciclo concluído.',
      relatorioId: relatorioId,
      sugestoesCriadas: criadas,
      sugestoesDescartadas: descartadas,
      notaCerebroId: notaId,
      duracao: relogio.elapsed,
    );
  }

  // ── Contexto local ────────────────────────────────────────────────────────

  /// Retrato do Cérebro para o prompt. Vai pronto no contexto em vez de exigir
  /// que o modelo gaste chamadas de ferramenta para descobrir o óbvio.
  String _resumoCerebro() {
    final estado = _ref.read(vaultProvider);
    if (estado.carregando || estado.aguardandoClinica) {
      return 'O vault ainda estava carregando quando o ciclo começou.';
    }
    final index = _ref.read(vaultProvider.notifier).index;
    if (index.totalNotas == 0) return 'Cérebro vazio — nenhuma nota registrada.';

    final densidade = index.totalArestas / index.totalNotas;
    final hubs = _hubs(index, 8);
    final recentes = _recentes(index, 8);

    return [
      '${index.totalNotas} notas · ${index.totalArestas} links · '
          'densidade ${densidade.toStringAsFixed(2)}',
      '${index.orfas.length} notas órfãs · '
          '${index.linksQuebrados.length} links quebrados · '
          '${index.tags.length} tags',
      if (hubs.isNotEmpty) 'Notas mais referenciadas: ${hubs.join(" · ")}',
      if (recentes.isNotEmpty) 'Escritas recentemente: ${recentes.join(" · ")}',
    ].join('\n');
  }

  List<String> _hubs(VaultIndex index, int quantos) {
    final vivas = index.notas.values.where((n) => !n.excluida).toList()
      ..sort((a, b) => b.metrics.inDegree.compareTo(a.metrics.inDegree));
    return [
      for (final n in vivas.take(quantos))
        if (n.metrics.inDegree > 0) '${n.path} (${n.metrics.inDegree} links)',
    ];
  }

  List<String> _recentes(VaultIndex index, int quantos) {
    final vivas = index.notas.values.where((n) => !n.excluida).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [for (final n in vivas.take(quantos)) n.path];
  }

  String _resumoVigentes(List<ScheduledTask> todas) {
    final ativas = todas.where((t) => !t.isRecusada).toList();
    if (ativas.isEmpty) return 'Nenhuma rotina cadastrada ainda.';
    return [
      for (final t in ativas)
        '- [${t.status}] ${t.titulo} — ${t.scheduleLabel}'
            '${t.daIa ? " (proposta pela IA)" : ""}',
    ].join('\n');
  }

  String _resumoRecusadas(List<ScheduledTask> todas) {
    final recusadas = todas.where((t) => t.isRecusada).toList();
    if (recusadas.isEmpty) return 'Nenhuma proposta foi recusada até agora.';
    return [
      for (final t in recusadas)
        '- ${t.titulo} — recusada: '
            '${(t.motivoRecusa ?? "sem motivo registrado").trim()}',
    ].join('\n');
  }

  // ── Gravações ─────────────────────────────────────────────────────────────

  /// Grava o relatório na **mesma** clínica das sugestões.
  ///
  /// Passa pelo repositório em vez do notifier de propósito: o notifier é
  /// escopado por `clinicaResolvidaProvider`, que pode divergir do
  /// `tarefasClinicaIdProvider` usado aqui (este último cai na primeira clínica
  /// do perfil quando a seleção não pertence ao usuário). Relatório numa
  /// clínica e sugestões em outra deixaria os dois invisíveis um para o outro.
  Future<String> _gravarRelatorio(
      RelatorioProposto p, String hoje, String clinicaId) async {
    final id = 'rel_vigia_${hoje.replaceAll('-', '')}_'
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final relatorio = Relatorio(
      id: id,
      title: p.titulo,
      type: RelatorioType.ia,
      createdAt: DateTime.now(),
      period: p.periodo,
      body: p.corpo,
      metrics: [for (final (l, v) in p.metricas) RelatorioMetric(l, v)],
    );
    await _ref.read(relatoriosRepositoryProvider).salvar(clinicaId, relatorio);
    return id;
  }

  /// Registra o ciclo no Cérebro. É o que faz o Vigia melhorar com o tempo: o
  /// ciclo de amanhã lê o que o de hoje concluiu.
  Future<String?> _gravarNota(Map<String, dynamic> j, String hoje) async {
    final conteudo = (j['conteudo'] ?? '').toString().trim();
    if (conteudo.isEmpty) return null;
    final titulo = (j['titulo'] ?? 'Ciclo do Vigia — $hoje').toString().trim();

    try {
      return await _ref.read(vaultProvider.notifier).criar(
            path: 'agente/vigia/$hoje.md',
            tipo: NotaTipo.analise,
            origem: NotaOrigem.agente,
            conteudo: '---\ntipo: analise\norigem: agente\n'
                'tags: [vigia, agente]\ndata: $hoje\n---\n\n'
                '# $titulo\n\n$conteudo\n',
          );
    } catch (_) {
      // Um Cérebro indisponível não pode derrubar o ciclo: o relatório e as
      // sugestões valem por si.
      return null;
    }
  }

  Future<void> _notificar({
    required int criadas,
    required bool temRelatorio,
  }) async {
    if (criadas == 0 && !temRelatorio) return;
    final partes = <String>[
      if (temRelatorio) 'novo relatório',
      if (criadas > 0)
        '$criadas ${criadas == 1 ? "rotina sugerida" : "rotinas sugeridas"}',
    ];
    try {
      await _ref.read(notificacoesProvider.notifier).push(
            type: NotificationType.relatorio,
            title: 'O Vigia analisou a clínica',
            message: '${partes.join(" e ")}. '
                '${criadas > 0 ? "As rotinas aguardam sua aprovação." : ""}',
          );
    } catch (_) {
      // Notificação é acessório — nunca derruba o ciclo.
    }
  }

  // ── Utilitários ───────────────────────────────────────────────────────────

  static String _diaIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Extrai o objeto JSON da resposta, tolerando cercas de código e texto ao
  /// redor — modelos escorregam nisso mesmo com instrução explícita.
  static Map<String, dynamic>? _extrairJson(String bruto) {
    var t = bruto.trim();
    final cerca = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final m = cerca.firstMatch(t);
    if (m != null) t = m.group(1)!.trim();

    final inicio = t.indexOf('{');
    final fim = t.lastIndexOf('}');
    if (inicio < 0 || fim <= inicio) return null;

    try {
      final decodificado = jsonDecode(t.substring(inicio, fim + 1));
      return decodificado is Map<String, dynamic> ? decodificado : null;
    } catch (_) {
      return null;
    }
  }
}

final vigiaServiceProvider = Provider<VigiaService>(VigiaService.new);
