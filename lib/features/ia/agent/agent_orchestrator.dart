import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modules/mcp/mcp_providers.dart';
import 'agent_controller.dart';
import 'agent_models.dart';
import 'agent_plans_service.dart';
import 'ai_agent_service.dart';
import 'ia_session.dart';

/// Fase do orquestrador multi-agente.
enum OrchestratorPhase { idle, planning, executing, synthesizing, done, error }

/// Estado de execução de uma tarefa do plano.
class AgentTaskState {
  AgentTaskState(this.task);
  final PlanTask task;
  TaskStatus status = TaskStatus.idle;
  String result = '';
}

class OrchestratorState {
  const OrchestratorState({
    this.objective = '',
    this.phase = OrchestratorPhase.idle,
    this.tasks = const [],
    this.synthesis = '',
    this.error,
  });

  final String objective;
  final OrchestratorPhase phase;
  final List<AgentTaskState> tasks;
  final String synthesis;
  final String? error;

  bool get running =>
      phase == OrchestratorPhase.planning ||
      phase == OrchestratorPhase.executing ||
      phase == OrchestratorPhase.synthesizing;

  OrchestratorState copyWith({
    String? objective,
    OrchestratorPhase? phase,
    List<AgentTaskState>? tasks,
    String? synthesis,
    String? error,
  }) =>
      OrchestratorState(
        objective: objective ?? this.objective,
        phase: phase ?? this.phase,
        tasks: tasks ?? this.tasks,
        synthesis: synthesis ?? this.synthesis,
        error: error,
      );
}

final agentOrchestratorProvider =
    StateNotifierProvider<AgentOrchestrator, OrchestratorState>((ref) {
  return AgentOrchestrator(ref);
});

/// Orquestrador multi-agente (AgentAI.md §7.1.4): planeja → executa em paralelo
/// (lotes de 4) → sintetiza um relatório executivo em streaming.
class AgentOrchestrator extends StateNotifier<OrchestratorState> {
  AgentOrchestrator(this._ref) : super(const OrchestratorState());

  final Ref _ref;

  Future<void> run(String objective) async {
    final obj = objective.trim();
    if (obj.isEmpty || state.running) return;

    final service = _ref.read(aiAgentServiceProvider);
    final server = _ref.read(mcpServerProvider);
    final specs = _ref.read(mcpToolSpecsProvider);
    final clinicaId = server.ctx.defaultClinicaId;
    final timeout = Duration(seconds: _ref.read(agentTimeoutProvider));
    // Lote de paralelismo configurável (baixo evita rajada → 429 na IA).
    final batchSize = _ref.read(agentBatchSizeProvider).clamp(1, 8);
    Future<String> callTool(String n, Map<String, dynamic> a) async =>
        (await server.callTool(n, a)).text;

    // 1) Planejamento
    state = OrchestratorState(
        objective: obj, phase: OrchestratorPhase.planning, tasks: const []);
    final List<PlanTask> plan;
    try {
      plan = await service.plan(obj);
    } catch (e) {
      state = state.copyWith(
          phase: OrchestratorPhase.error,
          error: 'Falha ao planejar: $e');
      return;
    }
    if (plan.isEmpty) {
      state = state.copyWith(
          phase: OrchestratorPhase.error,
          error: 'O planejador não retornou tarefas. Reformule o objetivo.');
      return;
    }

    final tasks = plan.map(AgentTaskState.new).toList();
    state = state.copyWith(phase: OrchestratorPhase.executing, tasks: tasks);

    // 2) Execução paralela (lotes de batchSize)
    for (var i = 0; i < tasks.length; i += batchSize) {
      final batch = tasks.skip(i).take(batchSize).toList();
      for (final t in batch) {
        t.status = TaskStatus.running;
      }
      _bump();
      await Future.wait(batch.map((t) async {
        try {
          t.result = await service
              .runToString(
                prompt: t.task.prompt,
                toolSpecs: specs,
                callTool: callTool,
                clinicaId: clinicaId,
              )
              .timeout(timeout);
          t.status = TaskStatus.done;
        } on TimeoutException {
          t.result = '⚠️ Tempo esgotado (${timeout.inSeconds}s).';
          t.status = TaskStatus.error;
        } catch (e) {
          t.result = '⚠️ $e';
          t.status = TaskStatus.error;
        }
        _bump();
      }));
    }

    // 3) Síntese (streaming, sem ferramentas)
    state = state.copyWith(phase: OrchestratorPhase.synthesizing, synthesis: '');
    final buffer = StringBuffer();
    final synthPrompt = _synthesisPrompt(obj, tasks);
    try {
      await for (final ev in service.run(
        history: [ChatMessage(role: ChatRole.user, content: synthPrompt)],
        toolSpecs: const [],
        callTool: callTool,
        clinicaId: clinicaId,
      )) {
        if (ev is AgentToken) {
          buffer.write(ev.text);
          state = state.copyWith(synthesis: buffer.toString());
        } else if (ev is AgentDone) {
          if (ev.text.isNotEmpty) {
            buffer
              ..clear()
              ..write(ev.text);
          }
          state = state.copyWith(synthesis: buffer.toString());
        } else if (ev is AgentError) {
          buffer.write('\n\n⚠️ ${ev.message}');
          state = state.copyWith(synthesis: buffer.toString());
        }
      }
    } catch (e) {
      state = state.copyWith(synthesis: '${buffer.toString()}\n\n⚠️ $e');
    }

    state = state.copyWith(phase: OrchestratorPhase.done);

    // Persistência do plano e relatório (§7.2/§7.3). Falhas não quebram a UX.
    try {
      final plansService = _ref.read(agentPlansServiceProvider);
      final taskMaps = state.tasks
          .map((t) => <String, dynamic>{
                'titulo': t.task.titulo,
                'prompt': t.task.prompt,
                'resultado': t.result,
                'status': t.status.name,
              })
          .toList();
      await plansService.savePlan(
        objective: obj,
        tasks: taskMaps,
        synthesis: state.synthesis,
        clinicaId: clinicaId,
      );
      await plansService.saveReport(
        titulo: 'Relatório multi-agente',
        conteudoMarkdown: state.synthesis,
        clinicaId: clinicaId,
      );
    } catch (_) {
      // Ignora falhas de persistência para não interromper a UX.
    }
  }

  String _synthesisPrompt(String objective, List<AgentTaskState> tasks) {
    final b = StringBuffer()
      ..writeln('Objetivo do usuário: "$objective".')
      ..writeln()
      ..writeln('Resultados dos agentes:');
    for (final t in tasks) {
      b
        ..writeln('### ${t.task.titulo}')
        ..writeln(t.result)
        ..writeln();
    }
    b
      ..writeln('---')
      ..writeln(
          'Consolide os resultados acima em um RELATÓRIO EXECUTIVO em português: '
          'principais descobertas, pontos críticos e recomendações acionáveis. '
          'Use markdown. Se fizer sentido, inclua UM bloco ```json-chart``` '
          '(type bar/line/pie) para ilustrar números-chave. Não repita os dados '
          'crus; sintetize.');
    return b.toString();
  }

  void _bump() => state = state.copyWith(tasks: [...state.tasks]);

  void reset() => state = const OrchestratorState();
}
