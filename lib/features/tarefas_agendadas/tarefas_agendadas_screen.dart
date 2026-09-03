import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_states.dart';
import '../ia/vigia/vigia_providers.dart';
import 'scheduled_task.dart';
import 'scheduled_tasks_runner.dart';
import 'scheduled_tasks_service.dart';
import 'widgets/card_sugestao_ia.dart';
import 'widgets/task_modal.dart';

/// Página Tarefas Agendadas (`.specify/TAREFAS_AGENDADAS.md` §9).
class TarefasAgendadasScreen extends ConsumerStatefulWidget {
  const TarefasAgendadasScreen({super.key});

  @override
  ConsumerState<TarefasAgendadasScreen> createState() =>
      _TarefasAgendadasScreenState();
}

class _TarefasAgendadasScreenState
    extends ConsumerState<TarefasAgendadasScreen> {
  final _runningNow = <String>{};
  final _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    // Catch-up: dispara as tarefas vencidas da clínica ao abrir (uma vez).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // A tela pode já ter sido descartada (navegação rápida) antes do frame;
      // e sem Firebase (demo/testes) o runner não tem o que fazer e só erraria.
      if (!mounted || !ref.read(firebaseEnabledProvider)) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      try {
        final n = await ref.read(scheduledTasksRunnerProvider).runDue();
        // `context.mounted`: elemento ainda ATIVO (não só não-descartado) — sem
        // isso, um `.of(context)` num elemento desativado lança
        // "Looking up a deactivated widget's ancestor is unsafe".
        if (n > 0 && context.mounted) {
          messenger?.showSnackBar(
            SnackBar(content: Text('$n tarefa(s) vencida(s) executada(s).')),
          );
        }
      } catch (_) {
        // Catch-up é best-effort: uma falha aqui não pode derrubar a tela.
      }
    });
  }

  Future<void> _openModal([ScheduledTask? task]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => TaskModal(task: task),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(task == null ? 'Tarefa criada.' : 'Tarefa atualizada.')),
      );
    }
  }

  Future<void> _runNow(ScheduledTask task) async {
    setState(() => _runningNow.add(task.id));
    final record = await ref.read(scheduledTasksRunnerProvider).runNow(task);
    if (!mounted) return;
    setState(() => _runningNow.remove(task.id));
    final msg = record == null
        ? 'Tarefa já está em execução.'
        : (record.ok ? 'Executada com sucesso.' : 'Execução falhou — veja o histórico.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _delete(ScheduledTask task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir tarefa'),
        content: Text('Excluir "${task.titulo}" permanentemente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(scheduledTasksServiceProvider).delete(task.id);
    }
  }

  Future<void> _analisarAgora() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      duration: Duration(seconds: 30),
      content: Row(children: [
        SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: AppSpacing.md),
        Expanded(child: Text('A IA está analisando a clínica…')),
      ]),
    ));
    final r = await ref.read(vigiaControllerProvider.notifier).rodar(forcar: true);
    messenger.hideCurrentSnackBar();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(r.executou
          ? '${r.sugestoesCriadas} rotina(s) sugerida(s)'
              '${r.relatorioId != null ? " e 1 relatório gerado" : ""}.'
          : r.motivo),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(scheduledTasksProvider);
    final activeCount =
        tasksAsync.value?.where((t) => t.isActive).length ?? 0;
    final sugestoes = ref.watch(sugestoesRotinaProvider);
    final vigia = ref.watch(vigiaControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas Agendadas'),
        actions: [
          if (activeCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Text('$activeCount ativa(s)',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          IconButton(
            tooltip: 'Pedir uma análise agora',
            onPressed: vigia.rodando ? null : _analisarAgora,
            icon: vigia.rodando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openModal(),
        icon: const Icon(Icons.add),
        label: const Text('Nova tarefa'),
      ),
      body: tasksAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'Erro ao carregar tarefas: $e'),
        data: (todas) {
          // Sugestao nao e tarefa vigente: ela ainda nao roda. Misturar as duas
          // na mesma lista faria o gestor achar que a IA ja ligou algo.
          final tasks = todas
              .where((t) => !t.isSugestao && !t.isRecusada)
              .toList();

          if (tasks.isEmpty && sugestoes.isEmpty) {
            return EmptyView(
              icon: Icons.schedule,
              message:
                  'Nenhuma tarefa agendada.\nCrie uma ou use "/schedule …" no chat de IA.',
              actionLabel: 'Nova tarefa',
              onAction: () => _openModal(),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (sugestoes.isNotEmpty) ...[
                _CabecalhoSugestoes(quantidade: sugestoes.length),
                const SizedBox(height: AppSpacing.md),
                for (final s in sugestoes) CardSugestaoIa(tarefa: s),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (tasks.isNotEmpty) ...[
                if (sugestoes.isNotEmpty) ...[
                  Text(
                    'ROTINAS EM VIGOR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                for (var i = 0; i < tasks.length; i++) ...[
                  _TaskCard(
                    task: tasks[i],
                    running: _runningNow.contains(tasks[i].id),
                    expanded: _expanded.contains(tasks[i].id),
                    onToggleExpand: () => setState(() {
                      final id = tasks[i].id;
                      _expanded.contains(id)
                          ? _expanded.remove(id)
                          : _expanded.add(id);
                    }),
                    onRun: () => _runNow(tasks[i]),
                    onEdit: () => _openModal(tasks[i]),
                    onDelete: () => _delete(tasks[i]),
                    onToggleStatus: () => ref
                        .read(scheduledTasksServiceProvider)
                        .setStatus(
                            tasks[i].id, tasks[i].isPaused ? 'active' : 'paused'),
                  ),
                  if (i < tasks.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.running,
    required this.expanded,
    required this.onToggleExpand,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  final ScheduledTask task;
  final bool running;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  (Color, IconData, String) get _statusVisual {
    switch (task.status) {
      case 'active':
        return (AppColors.success, Icons.play_circle_outline, 'Ativa');
      case 'paused':
        return (AppColors.warning, Icons.pause_circle_outline, 'Pausada');
      case 'completed':
        return (AppColors.textTertiary, Icons.check_circle_outline, 'Concluída');
      case 'running':
        return (AppColors.info, Icons.autorenew, 'Executando');
      case 'error':
        return (AppColors.danger, Icons.error_outline, 'Erro');
      default:
        return (AppColors.textTertiary, Icons.help_outline, task.status);
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _statusVisual;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.titulo,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(task.scheduleLabel,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _chip(label, color),
                if (task.isReport) ...[
                  const SizedBox(width: 4),
                  _chip('Relatório', AppColors.primary),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: 4,
              children: [
                _meta(Icons.event_available, 'Próxima', _fmt(task.nextRunAt)),
                _meta(Icons.history, 'Última', _fmt(task.lastRunAt)),
                _meta(Icons.repeat, 'Execuções',
                    '${task.runCount}${task.errorCount > 0 ? ' (${task.errorCount} erro)' : ''}'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                running
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : TextButton.icon(
                        onPressed: onRun,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Executar')),
                if (!task.isCompleted)
                  TextButton.icon(
                    onPressed: onToggleStatus,
                    icon: Icon(task.isPaused ? Icons.play_circle : Icons.pause, size: 18),
                    label: Text(task.isPaused ? 'Retomar' : 'Pausar'),
                  ),
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: 'Editar'),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline), tooltip: 'Excluir'),
                const Spacer(),
                IconButton(
                  onPressed: onToggleExpand,
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  tooltip: 'Detalhes',
                ),
              ],
            ),
            if (expanded) ...[
              const Divider(),
              Text('Instrução', style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(task.prompt, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Text('Histórico', style: theme.textTheme.labelLarge),
              if (task.history.isEmpty)
                Text('Sem execuções ainda.', style: theme.textTheme.bodySmall)
              else
                ...task.history.take(10).map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(r.ok ? Icons.check_circle : Icons.error,
                              size: 14,
                              color: r.ok ? AppColors.success : AppColors.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_fmt(r.runAt)} · ${(r.durationMs / 1000).toStringAsFixed(1)}s · ${r.toolsUsed} ferramenta(s)',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textSecondary),
                                ),
                                Text(r.summary,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 4, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _meta(IconData icon, String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text('$label: ',
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
}

/// Cabeçalho da seção de propostas da IA.
///
/// Diz explicitamente que nada ali está rodando. É a informação mais importante
/// da tela: sem ela, uma lista de rotinas "da IA" dá a impressão de que o
/// sistema já começou a agir sozinho.
class _CabecalhoSugestoes extends StatelessWidget {
  const _CabecalhoSugestoes({required this.quantidade});

  final int quantidade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quantidade == 1
                      ? '1 rotina sugerida pela IA'
                      : '$quantidade rotinas sugeridas pela IA',
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nenhuma delas está em execução. Elas só passam a rodar '
                  'depois que você aprovar.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
