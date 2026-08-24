import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assistente/assistant_anchors.dart';
import '../assistente/assistant_tours.dart';
import '../../core/models/enums.dart';
import '../../core/services/app_providers.dart';
import '../../core/services/whatsapp_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';
import 'widgets/whatsapp_conversations_table.dart';

/// Agente 7 — Integração WhatsApp via Z-API (`features/whatsapp`).
/// Cobre WA-01..WA-04.
class WhatsappScreen extends ConsumerStatefulWidget {
  const WhatsappScreen({super.key});

  @override
  ConsumerState<WhatsappScreen> createState() => _WhatsappScreenState();
}

class _WhatsappScreenState extends ConsumerState<WhatsappScreen> {
  WhatsappStatus _status = WhatsappStatus.disconnected;
  bool _connecting = false;
  final _templates = WhatsappTemplates();

  Future<void> _connect() async {
    setState(() => _connecting = true);
    await for (final s in ref.read(whatsappServiceProvider).connect()) {
      if (!mounted) return;
      setState(() => _status = s);
    }
    if (mounted) setState(() => _connecting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = ref.read(whatsappServiceProvider).recentMessages();
    final connected = _status == WhatsappStatus.connected;

    return Scaffold(
      appBar: AppBar(title: const Text('Integração WhatsApp')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // WA-02 — status da conexão
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: _status.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${_status.label}',
                          style: theme.textTheme.titleMedium),
                      Text('Z-API • instância da clínica',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (_connecting)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // WA-01 — conexão por QR Code
          const SectionHeader(title: 'Conexão por QR Code'),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: connected
                      ? const Center(
                          child: Icon(Icons.check_circle,
                              size: 64, color: AppColors.success))
                      : const Center(
                          child: Icon(Icons.qr_code_2,
                              size: 140, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  connected
                      ? 'WhatsApp conectado com sucesso.'
                      : 'Abra o WhatsApp da clínica e escaneie o QR Code para parear.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: AssistantTarget(
                    anchorId: HelpAnchors.whatsappConnect,
                    child: ElevatedButton.icon(
                      onPressed: _connecting || connected ? null : _connect,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(connected ? 'Conectado' : 'Gerar QR Code'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // WA-04 — configurações do assistente
          const SectionHeader(title: 'Mensagens automáticas'),
          const SizedBox(height: AppSpacing.md),
          _TemplateField(
            label: 'Confirmação',
            value: _templates.confirmation,
            onChanged: (v) => _templates.confirmation = v,
          ),
          _TemplateField(
            label: 'Lembrete',
            value: _templates.reminder,
            onChanged: (v) => _templates.reminder = v,
          ),
          _TemplateField(
            label: 'Cancelamento',
            value: _templates.cancellation,
            onChanged: (v) => _templates.cancellation = v,
          ),
          const SizedBox(height: AppSpacing.lg),

          // WA-03 — logs de mensagens / Tabela de Conversas
          const SectionHeader(title: 'Todas as conversas'),
          const SizedBox(height: AppSpacing.md),
          WhatsappConversationsTable(messages: messages),
        ],
      ),
    );
  }
}

class _TemplateField extends StatelessWidget {
  const _TemplateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        initialValue: value,
        maxLines: 2,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          helperText: 'Variáveis: {nome} {data} {hora} {medico}',
        ),
      ),
    );
  }
}

