import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/queue_model.dart';
import '../providers/agent_provider.dart';
import '../providers/queue_provider.dart';
import 'feedback_gravacao.dart';

/// Modal de criação/edição de fila (§1.2). Passe [queue] para editar.
class QueueFormModal extends ConsumerStatefulWidget {
  const QueueFormModal({super.key, this.queue});

  final QueueModel? queue;

  @override
  ConsumerState<QueueFormModal> createState() => _QueueFormModalState();
}

class _QueueFormModalState extends ConsumerState<QueueFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _firstResponseController;
  late final TextEditingController _resolutionController;
  late DistributionStrategy _strategy;
  late Set<String> _selectedAgents;

  bool get _isEditing => widget.queue != null;

  @override
  void initState() {
    super.initState();
    final q = widget.queue;
    _nameController = TextEditingController(text: q?.name ?? '');
    _firstResponseController = TextEditingController(
        text: (q?.sla.firstResponse.inMinutes ?? 5).toString());
    _resolutionController = TextEditingController(
        text: (q?.sla.resolution.inMinutes ?? 30).toString());
    _strategy = q?.distributionStrategy ?? DistributionStrategy.leastOccupied;
    _selectedAgents = {...?q?.agentIds};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _firstResponseController.dispose();
    _resolutionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final sla = QueueSla(
      firstResponse:
          Duration(minutes: int.parse(_firstResponseController.text)),
      resolution: Duration(minutes: int.parse(_resolutionController.text)),
    );
    final notifier = ref.read(queuesProvider.notifier);

    final gravou = await comFeedback(context, () {
      if (_isEditing) {
        return notifier.updateQueue(widget.queue!.copyWith(
          name: _nameController.text.trim().toUpperCase(),
          distributionStrategy: _strategy,
          sla: sla,
          agentIds: _selectedAgents.toList(),
        ));
      }
      return notifier.addQueue(QueueModel(
        id: 'q-${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim().toUpperCase(),
        distributionStrategy: _strategy,
        sla: sla,
        agentIds: _selectedAgents.toList(),
      ));
    });
    // Fechar o modal numa gravação recusada faria a fila "sumir" sem aviso.
    if (gravou && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final agents = ref.watch(agentsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Container(
        width: screenWidth < 640 ? screenWidth * 0.9 : 560,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditing ? 'Editar Fila' : 'Nova Fila',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _label(theme, 'NOME DO SETOR'),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration(theme, 'Ex: TRIAGEM GERAL'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                _label(theme, 'ESTRATÉGIA DE DISTRIBUIÇÃO'),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<DistributionStrategy>(
                  initialValue: _strategy,
                  decoration: _inputDecoration(theme, ''),
                  items: [
                    for (final s in DistributionStrategy.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _strategy = v);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'SLA 1ª RESPOSTA (MIN)'),
                          const SizedBox(height: AppSpacing.xs),
                          TextFormField(
                            controller: _firstResponseController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(theme, '5'),
                            validator: _validateMinutes,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'SLA RESOLUÇÃO (MIN)'),
                          const SizedBox(height: AppSpacing.xs),
                          TextFormField(
                            controller: _resolutionController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(theme, '30'),
                            validator: _validateMinutes,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _label(theme, 'AGENTES VINCULADOS'),
                const SizedBox(height: AppSpacing.xs),
                if (agents.isEmpty)
                  Text('Nenhum atendente cadastrado.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant))
                else
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final agent in agents)
                        FilterChip(
                          label: Text(agent.nomeOperacional),
                          selected: _selectedAgents.contains(agent.id),
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _selectedAgents.add(agent.id);
                              } else {
                                _selectedAgents.remove(agent.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancelar',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                      ),
                      child: Text(_isEditing ? 'SALVAR' : 'CRIAR FILA',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateMinutes(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null || n <= 0) return 'Inválido';
    return null;
  }

  Widget _label(ThemeData theme, String text) => Text(text,
      style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold));

  InputDecoration _inputDecoration(ThemeData theme, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: theme.colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    );
  }
}
