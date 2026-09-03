import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../agent/agent_models.dart';
import '../agent/agent_orchestrator.dart';
import '../agent/ai_export_service.dart';
import 'ai_rich_content.dart';
import 'ia_suggestions_panel.dart';

/// Modo Agentes (orquestrador multi-agente) — AgentAI.md §7.1.4.
/// Plano → execução paralela com ferramentas MCP → síntese em streaming.
class AiAgentsPanel extends ConsumerStatefulWidget {
  const AiAgentsPanel({super.key});

  @override
  ConsumerState<AiAgentsPanel> createState() => _AiAgentsPanelState();
}

class _AiAgentsPanelState extends ConsumerState<AiAgentsPanel> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// Prompt aplicado a partir de uma sugestão. Enquanto o campo contiver
  /// exatamente esse texto, o painel de sugestões fica oculto.
  String? _appliedSuggestion;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _focus.addListener(_onChanged);
  }

  void _onChanged() {
    if (_appliedSuggestion != null && _controller.text != _appliedSuggestion) {
      _appliedSuggestion = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _focus.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run([String? preset]) {
    final text = preset ?? _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(agentOrchestratorProvider.notifier).run(text);
  }

  void _onSuggestion(String prompt) {
    _appliedSuggestion = prompt;
    _controller
      ..text = prompt
      ..selection = TextSelection.collapsed(offset: prompt.length);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentOrchestratorProvider);
    return Column(
      children: [
        Expanded(
          child: state.phase == OrchestratorPhase.idle
              ? _Intro(onPick: _run)
              : _RunView(state: state),
        ),
        if (_focus.hasFocus && _appliedSuggestion == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: IaSuggestionsPanel(
                query: _controller.text, onSelect: _onSuggestion),
          ),
        _InputBar(
          controller: _controller,
          focusNode: _focus,
          running: state.running,
          onSend: _run,
        ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onPick});
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    const examples = [
      'Faça um diagnóstico completo do absenteísmo da clínica nesta semana',
      'Prepare um resumo operacional: agenda de hoje, riscos e overbooking',
    ];
    // Rolável: em telas baixas os cards de exemplo + a barra de input abaixo
    // estouravam o `Expanded` ("BOTTOM OVERFLOWED"). Centraliza quando há espaço.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy_outlined,
              color: Color(0xFFC084FC), size: 40),
          const SizedBox(height: AppSpacing.lg),
          Text('Modo Multi-Agente',
              style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Descreva um objetivo. A IA cria um plano com agentes independentes\nque executam em paralelo com ferramentas MCP e entregam uma síntese.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondaryOf(context), fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xxl),
          for (final ex in examples)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: InkWell(
                onTap: () => onPick(ex),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Container(
                  width: 520,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt,
                          color: Color(0xFFC084FC), size: 18),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(ex,
                            style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
        ),
        ),
      ),
    );
  }
}

class _RunView extends StatelessWidget {
  const _RunView({required this.state});
  final OrchestratorState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          children: [
            const Icon(Icons.flag_outlined,
                color: Color(0xFFC084FC), size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(state.objective,
                  style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _PhaseBanner(phase: state.phase, error: state.error),
        const SizedBox(height: AppSpacing.lg),
        if (state.error != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border:
                  Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            child: Text(state.error!,
                style: TextStyle(color: AppColors.textPrimaryOf(context))),
          ),
        for (var i = 0; i < state.tasks.length; i++)
          _TaskCard(index: i, task: state.tasks[i]),
        if (state.synthesis.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: AppColors.pinkAccent, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('Síntese executiva',
                  style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          if (state.phase == OrchestratorPhase.done) ...[
            const SizedBox(height: AppSpacing.sm),
            _ExportBar(title: state.objective, content: state.synthesis),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: AiRichContent(content: state.synthesis),
          ),
        ],
      ],
    );
  }
}

/// Barra de exportação da síntese: resposta em PDF, gráficos em PDF e dados
/// em Excel. As opções de gráfico ficam desabilitadas quando a resposta não
/// contém nenhum bloco `json-chart`.
class _ExportBar extends StatefulWidget {
  const _ExportBar({required this.title, required this.content});
  final String title;
  final String content;

  @override
  State<_ExportBar> createState() => _ExportBarState();
}

class _ExportBarState extends State<_ExportBar> {
  static const _service = AiExportService();
  bool _busy = false;

  String get _title =>
      widget.title.trim().isEmpty ? 'Relatório IA' : widget.title.trim();

  Future<void> _do(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _snack(done);
    } catch (e) {
      _snack('Falha ao exportar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final charts = AiExportService.chartsOf(widget.content);
    final hasCharts = charts.isNotEmpty;
    final subtitle =
        'Gerado em ${DateTime.now().toString().substring(0, 16)}';

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_busy)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.pinkAccent),
          ),
        _chip(
          icon: Icons.picture_as_pdf_outlined,
          label: 'Resposta (PDF)',
          onTap: () => _do(
            () => _service.exportResponsePdf(
                title: _title, content: widget.content, subtitle: subtitle),
            'PDF da resposta gerado.',
          ),
        ),
        _chip(
          icon: Icons.insert_chart_outlined,
          label: 'Gráficos (PDF)',
          enabled: hasCharts,
          onTap: () => _do(
            () => _service.exportChartsPdf(
                title: _title, charts: charts, subtitle: subtitle),
            'PDF dos gráficos gerado.',
          ),
        ),
        _chip(
          icon: Icons.table_view_outlined,
          label: 'Dados (Excel)',
          enabled: hasCharts,
          onTap: () => _do(
            () => _service.exportChartsExcel(title: _title, charts: charts),
            'Planilha Excel gerada.',
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final on = enabled && !_busy;
    final color = on
        ? AppColors.textPrimaryOf(context)
        : AppColors.textSecondaryOf(context).withValues(alpha: 0.5);
    return OutlinedButton.icon(
      onPressed: on ? onTap : null,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.borderOf(context)),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
    );
  }
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({required this.phase, this.error});
  final OrchestratorPhase phase;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      OrchestratorPhase.planning => ('Planejando tarefas…', Color(0xFFC084FC)),
      OrchestratorPhase.executing =>
        ('Executando agentes em paralelo…', Colors.tealAccent),
      OrchestratorPhase.synthesizing =>
        ('Sintetizando relatório…', AppColors.pinkAccent),
      OrchestratorPhase.done => ('Concluído', Colors.tealAccent),
      OrchestratorPhase.error => ('Falhou', AppColors.danger),
      OrchestratorPhase.idle => ('', AppColors.textSecondaryOf(context)),
    };
    return Row(
      children: [
        if (phase == OrchestratorPhase.planning ||
            phase == OrchestratorPhase.executing ||
            phase == OrchestratorPhase.synthesizing)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else
          Icon(
            phase == OrchestratorPhase.done
                ? Icons.check_circle
                : Icons.info_outline,
            size: 14,
            color: color,
          ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.index, required this.task});
  final int index;
  final AgentTaskState task;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (task.status) {
      TaskStatus.running => (null, AppColors.pinkAccent),
      TaskStatus.done => (Icons.check_circle, Colors.tealAccent),
      TaskStatus.error => (Icons.error, AppColors.danger),
      TaskStatus.idle => (Icons.schedule, AppColors.textSecondaryOf(context)),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: task.status != TaskStatus.idle,
          iconColor: AppColors.textSecondaryOf(context),
          collapsedIconColor: AppColors.textSecondaryOf(context),
          leading: icon == null
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                )
              : Icon(icon, color: color, size: 18),
          title: Text(
            '${index + 1}. ${task.task.titulo}',
            style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
          subtitle: task.task.complex
              ? const Text('Pro',
                  style: TextStyle(color: Color(0xFFC084FC), fontSize: 11))
              : null,
          childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: task.result.isEmpty
                  ? Text('Aguardando…',
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context), fontSize: 13))
                  : AiRichContent(
                      content: task.result,
                      textColor: AppColors.textSecondaryOf(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.running,
    required this.onSend,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool running;
  final void Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !running,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => onSend(),
                style: TextStyle(color: AppColors.textPrimaryOf(context)),
                decoration: InputDecoration(
                  hintText: 'Descreva um objetivo para os agentes…',
                  hintStyle: TextStyle(color: AppColors.textSecondaryOf(context)),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            running
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFC084FC)),
                    ),
                  )
                : IconButton(
                    onPressed: () => onSend(),
                    icon: const Icon(Icons.play_arrow,
                        color: Color(0xFFC084FC)),
                  ),
          ],
        ),
      ),
    );
  }
}
