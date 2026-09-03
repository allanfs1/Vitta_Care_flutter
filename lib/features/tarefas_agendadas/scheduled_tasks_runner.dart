import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/modules/mcp/mcp_providers.dart';
import '../ia/agent/agent_controller.dart';
import '../ia/agent/ai_agent_service.dart';
import 'scheduled_task.dart';
import 'scheduled_tasks_service.dart';

/// Executa as tarefas agendadas usando o agente de IA (MCP), aplicando o lock
/// para nunca disparar a mesma ocorrência duas vezes (`TAREFAS_AGENDADAS.md` §6/§7).
class ScheduledTasksRunner {
  ScheduledTasksRunner(this._ref);
  final Ref _ref;

  static const _actionSystem =
      'Você é um executor autônomo de tarefas clínicas. Execute a instrução de '
      'ponta a ponta usando as ferramentas disponíveis, NUNCA peça confirmação, '
      'e ao final RESUMA os números/resultados obtidos em poucas linhas. '
      'Use sempre nomes legíveis (nunca IDs internos).';

  static const _reportSystem =
      'Você é um gerador de relatórios clínicos. Produza um relatório em Markdown '
      '(Resumo Executivo, tabelas e Recomendações) com 1 a 4 gráficos no formato '
      '```json-chart``` (type bar/line/pie). Use as ferramentas para obter dados '
      'reais e nomes legíveis (nunca IDs).';

  bool _catchUpRan = false;

  /// Catch-up: recupera órfãs e executa as vencidas da clínica (uma vez por sessão
  /// de tela). Retorna quantas foram executadas.
  Future<int> runDue({bool force = false}) async {
    if (_catchUpRan && !force) return 0;
    _catchUpRan = true;
    final clinicaId = _ref.read(tarefasClinicaIdProvider);
    if (clinicaId.isEmpty) return 0;
    final svc = _ref.read(scheduledTasksServiceProvider);
    var executed = 0;
    try {
      await svc.recoverStale(clinicaId);
      final due = await svc.getDue(clinicaId, limit: 10);
      for (final candidate in due) {
        final claimed = await svc.claimDue(candidate.id);
        if (claimed == null) continue; // outro disparador ganhou o lock
        final record = await _execute(claimed, clinicaId);
        await svc.finishRun(claimed.id, record);
        executed++;
      }
    } catch (_) {
      // Falhas de catch-up não devem quebrar a UI.
    }
    return executed;
  }

  /// "Executar agora" — não altera o agendamento.
  Future<RunRecord?> runNow(ScheduledTask task) async {
    final clinicaId = _ref.read(tarefasClinicaIdProvider);
    final svc = _ref.read(scheduledTasksServiceProvider);
    final locked = await svc.lockForManualRun(task.id);
    if (!locked) return null; // já em execução
    final record = await _execute(task, clinicaId);
    await svc.recordManualRun(task.id, record);
    return record;
  }

  Future<RunRecord> _execute(ScheduledTask task, String clinicaId) async {
    final started = DateTime.now();
    final server = _ref.read(mcpServerProvider);
    final specs = _ref.read(mcpToolSpecsProvider);
    final service = _ref.read(aiAgentServiceProvider);
    var toolsUsed = 0;

    Future<ToolOutcome> callTool(
        String name, Map<String, dynamic> args) async {
      toolsUsed++;
      final r = await server.callTool(name, args);
      return (text: r.text, isError: r.isError);
    }

    final system = task.isReport ? _reportSystem : _actionSystem;
    final effectivePrompt = '$system\n\nTAREFA:\n${task.prompt}';

    try {
      final content = await service
          .runToString(
            prompt: effectivePrompt,
            toolSpecs: specs,
            callTool: callTool,
            clinicaId: clinicaId,
          )
          .timeout(const Duration(minutes: 4));

      String? reportId;
      if (task.isReport) {
        reportId = await _saveReport(task, content, clinicaId);
      } else if (task.notifyEmail != null && task.notifyEmail!.contains('@')) {
        await _enqueueEmail(task, content, clinicaId);
      }

      final summary = content.length > 600 ? '${content.substring(0, 600)}…' : content;
      return RunRecord(
        runAt: started.toUtc(),
        ok: !content.startsWith('⚠️'),
        summary: summary.isEmpty ? 'Sem retorno do agente.' : summary,
        toolsUsed: toolsUsed,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        reportId: reportId,
      );
    } catch (e) {
      return RunRecord(
        runAt: started.toUtc(),
        ok: false,
        summary: '⚠️ Falha na execução: $e',
        toolsUsed: toolsUsed,
        durationMs: DateTime.now().difference(started).inMilliseconds,
      );
    }
  }

  Future<String> _saveReport(
      ScheduledTask task, String markdown, String clinicaId) async {
    final db = FirebaseFirestore.instance;
    final dados = {
      'titulo': task.titulo,
      'markdown': markdown,
      'conteudo': markdown,
      'tipoRelatorio': 'ia',
      'periodo': task.scheduleLabel,
      'taskId': task.id,
      'idclinica': clinicaId,
      'origem': 'scheduled',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Grava em `tb_relatorio_ia` — a coleção que a tela /relatorios lê.
    // Antes o resultado ia só para `tb_scheduled_reports`, então um relatório
    // produzido por uma rotina aprovada simplesmente não aparecia para quem
    // aprovou a rotina. O ciclo não fechava.
    final ref = await db.collection('tb_relatorio_ia').add(dados);

    // Mantém a trilha em `tb_scheduled_reports`, que é por tarefa e alimenta o
    // histórico de execuções.
    await db.collection('tb_scheduled_reports').doc(ref.id).set({
      ...dados,
      'tipoRelatorio': 'agendado',
      'relatorioId': ref.id,
    });
    return ref.id;
  }

  Future<void> _enqueueEmail(
      ScheduledTask task, String body, String clinicaId) async {
    await FirebaseFirestore.instance.collection('email_queue').add({
      'tipo': 'tarefa',
      'para': task.notifyEmail,
      'assunto': 'Tarefa agendada: ${task.titulo}',
      'corpo': body,
      'status': 'queued',
      'idclinica': clinicaId,
      'origem': 'scheduled',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

final scheduledTasksRunnerProvider =
    Provider<ScheduledTasksRunner>((ref) => ScheduledTasksRunner(ref));
