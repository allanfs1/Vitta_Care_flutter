import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modules/mcp/mcp_providers.dart';
import '../../../core/services/ai_config.dart';
import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../agent/ia_session.dart';
import 'saved_plans_panel.dart';

/// Sidebar direita da /ia: status do sistema (real), config dos agentes
/// (timeout), anexos pendentes e histórico de planos/relatórios.
class AiDashboardRightSidebar extends ConsumerWidget {
  const AiDashboardRightSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolCount = ref.watch(mcpToolSpecsProvider).length;
    final firebaseOn = ref.watch(firebaseEnabledProvider);
    final timeout = ref.watch(agentTimeoutProvider);
    final batchSize = ref.watch(agentBatchSizeProvider);
    final maxRetries = ref.watch(agentMaxRetriesProvider);
    final attachments = ref.watch(pendingAttachmentsProvider);

    return Container(
      width: 320,
      color: AppColors.backgroundOf(context),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _header(context, 'STATUS DO SISTEMA'),
          const SizedBox(height: AppSpacing.sm),
          _statusCard(
            context,
            icon: AiConfig.isConfigured ? Icons.bolt : Icons.bolt_outlined,
            iconColor: AiConfig.isConfigured
                ? Colors.tealAccent
                : Colors.orangeAccent,
            title: 'DeepSeek V4 Flash',
            subtitle: AiConfig.connectivity.label,
            statusColor: AiConfig.isConfigured
                ? Colors.tealAccent
                : Colors.orangeAccent,
          ),
          if (!AiConfig.isConfigured)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'A IA responde só em modo local até o app ser iniciado com '
                '--dart-define=AI_PROXY_URL=… (ou AZURE_AI_KEY em dev). '
                'Sem isso, cada envio ao modelo volta 401.',
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context), fontSize: 11),
              ),
            ),
          _statusCard(
            context,
            icon: Icons.code,
            iconColor: Colors.tealAccent,
            title: 'MCP Server',
            subtitle: '$toolCount ferramentas',
            statusColor: Colors.tealAccent,
          ),
          _statusCard(
            context,
            icon: Icons.cloud_queue,
            iconColor: firebaseOn ? Colors.tealAccent : Colors.white54,
            title: 'Firebase',
            subtitle: firebaseOn ? 'Conectado' : 'Modo demonstração',
            statusColor: firebaseOn ? Colors.tealAccent : Colors.white54,
          ),
          const SizedBox(height: AppSpacing.xl),
          _header(context, 'CONFIG DOS AGENTES'),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Timeout por agente',
                  style: TextStyle(
                      color: AppColors.textPrimaryOf(context), fontSize: 14)),
              Text('${timeout}s',
                  style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: timeout.toDouble().clamp(30, 180),
            min: 30,
            max: 180,
            divisions: 15,
            activeColor: Colors.deepPurpleAccent,
            inactiveColor: AppColors.surfaceOf(context),
            onChanged: (v) =>
                ref.read(agentTimeoutProvider.notifier).state = v.round(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('30s',
                  style: TextStyle(
                      color: AppColors.textSecondaryOf(context), fontSize: 12)),
              Text('180s',
                  style: TextStyle(
                      color: AppColors.textSecondaryOf(context), fontSize: 12)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _intSlider(
            context,
            label: 'Tarefas em paralelo',
            value: batchSize,
            min: 1,
            max: 6,
            valueLabel: '$batchSize',
            onChanged: (v) =>
                ref.read(agentBatchSizeProvider.notifier).state = v,
          ),
          const SizedBox(height: AppSpacing.md),
          _intSlider(
            context,
            label: 'Retentativas (429/503)',
            value: maxRetries,
            min: 0,
            max: 5,
            valueLabel: '$maxRetries',
            onChanged: (v) =>
                ref.read(agentMaxRetriesProvider.notifier).state = v,
          ),
          const SizedBox(height: AppSpacing.xl),
          _header(context, 'ANEXOS'),
          const SizedBox(height: AppSpacing.sm),
          if (attachments.isEmpty)
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined,
                      color: AppColors.textSecondaryOf(context), size: 28),
                  const SizedBox(height: AppSpacing.sm),
                  Text('SEM ARQUIVOS',
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            ...attachments.keys.map((name) => Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description,
                          color: AppColors.pinkAccent, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textPrimaryOf(context), fontSize: 13)),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            size: 16, color: AppColors.textSecondaryOf(context)),
                        onPressed: () => ref
                            .read(pendingAttachmentsProvider.notifier)
                            .remove(name),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: AppSpacing.xl),
          _header(context, 'HISTÓRICO (PLANOS & RELATÓRIOS)'),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(height: 360, child: SavedPlansPanel()),
        ],
      ),
    );
  }

  /// Slider de valor inteiro (label + valor + min/max), no padrão da seção de
  /// config dos agentes. [min]/[max] inteiros; uma divisão por unidade.
  Widget _intSlider(
    BuildContext context, {
    required String label,
    required int value,
    required int min,
    required int max,
    required String valueLabel,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: AppColors.textPrimaryOf(context), fontSize: 14)),
            Text(valueLabel,
                style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: Colors.deepPurpleAccent,
          inactiveColor: AppColors.surfaceOf(context),
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$min',
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context), fontSize: 12)),
            Text('$max',
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context), fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _header(BuildContext context, String title) => Text(
        title,
        style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2),
      );

  Widget _statusCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: AppColors.textSecondaryOf(context), fontSize: 12)),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: statusColor),
          ),
        ],
      ),
    );
  }
}
