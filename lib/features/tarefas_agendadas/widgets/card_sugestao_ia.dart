import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../scheduled_task.dart';
import '../scheduled_tasks_service.dart';

/// Cartão de uma rotina proposta pela IA, aguardando decisão humana.
///
/// O desenho parte de uma premissa: aprovar é ligar uma automação que vai agir
/// sozinha depois. Ninguém deve fazer isso sem ver o que a IA observou. Por
/// isso o cartão mostra o problema, as evidências e o que a rotina vai executar
/// **antes** dos botões — e o botão de aprovar abre uma confirmação que repete
/// a frequência, que é a parte que costuma surpreender.
class CardSugestaoIa extends ConsumerStatefulWidget {
  const CardSugestaoIa({super.key, required this.tarefa});

  final ScheduledTask tarefa;

  @override
  ConsumerState<CardSugestaoIa> createState() => _CardSugestaoIaState();
}

class _CardSugestaoIaState extends ConsumerState<CardSugestaoIa> {
  bool _ocupado = false;
  bool _detalhes = false;

  ScheduledTask get t => widget.tarefa;

  @override
  Widget build(BuildContext context) {
    final acao = t.kind == 'action';
    final cor = acao ? AppColors.warning : AppColors.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecalho(context, cor, acao),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.problemaDetectado.isNotEmpty)
                  _bloco(
                    context,
                    icone: Icons.search,
                    titulo: 'O QUE A IA OBSERVOU',
                    texto: t.problemaDetectado,
                  ),
                if (t.impactoEstimado.isNotEmpty)
                  _bloco(
                    context,
                    icone: Icons.trending_up,
                    titulo: 'GANHO ESPERADO',
                    texto: t.impactoEstimado,
                    cor: AppColors.success,
                  ),
                if (_detalhes) ...[
                  if (t.evidencias.isNotEmpty)
                    _evidencias(context),
                  _bloco(
                    context,
                    icone: Icons.play_circle_outline,
                    titulo: 'O QUE ESTA ROTINA VAI EXECUTAR',
                    texto: t.prompt,
                    monoespacado: true,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                _acoes(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalho(BuildContext context, Color cor, bool acao) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(acao ? Icons.bolt_outlined : Icons.assessment_outlined,
                size: 17, color: cor),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.titulo,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, height: 1.25),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _selo(context, Icons.schedule, t.scheduleLabel),
                    _selo(context, acao ? Icons.bolt : Icons.description_outlined,
                        acao ? 'Ação' : 'Relatório'),
                    if (t.confianca != null)
                      _selo(
                        context,
                        Icons.psychology_outlined,
                        'confiança ${(t.confianca! * 100).round()}%',
                        cor: _corConfianca(t.confianca!),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selo(BuildContext context, IconData icone, String texto,
      {Color? cor}) {
    final c = cor ?? AppColors.textSecondaryOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 11, color: c),
          const SizedBox(width: 4),
          Text(texto,
              style: TextStyle(
                  fontSize: 10.5, color: c, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  static Color _corConfianca(double c) => c >= 0.85
      ? AppColors.success
      : (c >= 0.7 ? AppColors.warning : AppColors.danger);

  Widget _bloco(
    BuildContext context, {
    required IconData icone,
    required String titulo,
    required String texto,
    Color? cor,
    bool monoespacado = false,
  }) {
    final c = cor ?? AppColors.textSecondaryOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 12, color: c),
              const SizedBox(width: 5),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: c,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            texto,
            style: TextStyle(
              fontSize: monoespacado ? 11.5 : 12.5,
              height: 1.4,
              fontFamily: monoespacado ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _evidencias(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined,
                  size: 12, color: AppColors.textSecondaryOf(context)),
              const SizedBox(width: 5),
              Text(
                'EVIDÊNCIAS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final e in t.evidencias)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 6),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondaryOf(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(e,
                        style: const TextStyle(fontSize: 12, height: 1.35)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _acoes(BuildContext context) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _detalhes = !_detalhes),
          icon: Icon(_detalhes ? Icons.expand_less : Icons.expand_more, size: 16),
          label: Text(_detalhes ? 'Menos detalhes' : 'Ver evidências'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const Spacer(),
        if (_ocupado)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          TextButton(
            onPressed: _recusar,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondaryOf(context),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Recusar'),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: _aprovar,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Aprovar e ativar'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _aprovar() async {
    // Repete a frequência na confirmação: é o detalhe que costuma escapar na
    // leitura e o que mais incomoda depois ("por que isso rodou de novo?").
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.play_circle_outline, color: AppColors.success),
        title: const Text('Ativar esta rotina?', style: TextStyle(fontSize: 17)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.titulo,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'A partir de agora ela vai executar sozinha: ${t.scheduleLabel}.\n\n'
                '${t.kind == "action" ? "É uma rotina de AÇÃO — ela age sobre a operação." : "É uma rotina de RELATÓRIO — ela produz um documento."}\n\n'
                'Você pode pausar ou excluir a qualquer momento na lista de tarefas.',
                style: const TextStyle(fontSize: 12.5, height: 1.45),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ativar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _ocupado = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(scheduledTasksServiceProvider).aprovar(
            t.id,
            por: ref.read(authProvider).email,
          );
      messenger.showSnackBar(SnackBar(
        content: Text('"${t.titulo}" está ativa — ${t.scheduleLabel}.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Não foi possível ativar: $e'),
      ));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _recusar() async {
    final controller = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Recusar sugestão', style: TextStyle(fontSize: 17)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'O motivo não é burocracia: é o que a IA lê para não propor a '
                'mesma coisa amanhã.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'Ex.: já fazemos isso manualmente na recepção',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(
                context,
                controller.text.trim().isEmpty
                    ? 'Sem motivo informado.'
                    : controller.text.trim()),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    if (motivo == null || !mounted) return;

    setState(() => _ocupado = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(scheduledTasksServiceProvider).recusar(
            t.id,
            motivo: motivo,
            por: ref.read(authProvider).email,
          );
      messenger.showSnackBar(
          const SnackBar(content: Text('Sugestão recusada.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Não foi possível recusar: $e'),
      ));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }
}
