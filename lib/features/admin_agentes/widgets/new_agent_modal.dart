import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

import '../../../core/theme/app_spacing.dart';
import '../models/agent_model.dart';
import '../providers/queue_provider.dart';
import '../services/agent_registration_service.dart';

class NewAgentModal extends ConsumerStatefulWidget {
  const NewAgentModal({super.key});

  @override
  ConsumerState<NewAgentModal> createState() => _NewAgentModalState();
}

class _NewAgentModalState extends ConsumerState<NewAgentModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  late String _generatedPin;
  AgentAvailability _availability = AgentAvailability.offline;
  final Set<String> _selectedQueues = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _generatedPin = _generatePin();
  }

  /// Gera um `accessPin` de 6 dígitos (100000–999999).
  String _generatePin() => (Random().nextInt(900000) + 100000).toString();

  void _regeneratePin() => setState(() => _generatedPin = _generatePin());

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final result =
        await ref.read(agentRegistrationServiceProvider).registerAgent(
              nomeOperacional: _nameController.text,
              email: _emailController.text,
              pin: _generatedPin,
              disponibilidade: _availability,
              setores: _selectedQueues.toList(),
            );

    if (!mounted) return;

    if (result.ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.agent!.nomeOperacional} cadastrado(a).')),
      );
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Falha no cadastro.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Container(
        width: screenWidth < 640 ? screenWidth * 0.9 : 600,
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
                    'Novo Membro da Equipe',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NOME OPERACIONAL',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppSpacing.xs),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Ex: Allan Souza',
                            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Informe o nome' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('E-MAIL DE LOGIN',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppSpacing.xs),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            hintText: 'nome@clinica.com',
                            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                          ),
                          validator: (v) =>
                              v == null || !v.contains('@') ? 'E-mail inválido' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.key, color: Color(0xFFFF3B30), size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text('PIN DE SEGURANÇA (SENHA)',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                      color: const Color(0xFFFF3B30),
                                      fontWeight: FontWeight.bold)),
                            ),
                            InkWell(
                              onTap: _saving ? null : _regeneratePin,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.refresh,
                                        color: Color(0xFFFF3B30), size: 16),
                                    const SizedBox(width: 4),
                                    Text('GERAR NOVO',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                            color: const Color(0xFFFF3B30),
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md, horizontal: AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: Center(
                            child: Text(
                              _generatedPin.split('').join('  '),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: const Color(0xFFFF3B30),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('ESTE SERÁ O CÓDIGO PARA O PRIMEIRO ACESSO.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DISPONIBILIDADE',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppSpacing.xs),
                        DropdownButtonFormField<AgentAvailability>(
                          initialValue: _availability,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                          ),
                          items: [
                            for (final status in AgentAvailability.values)
                              DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _availability = v;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildQueueSelector(theme),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('FINALIZAR CADASTRO',
                            style: TextStyle(fontWeight: FontWeight.bold)),
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

  /// Seleção das filas/setores aos quais o agente será vinculado (`assignedQueues`).
  Widget _buildQueueSelector(ThemeData theme) {
    final queues = ref.watch(queuesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FILAS / SETORES',
            style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.xs),
        if (queues.isEmpty)
          Text('Nenhuma fila cadastrada ainda.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant))
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final queue in queues)
                FilterChip(
                  label: Text(queue.name),
                  selected: _selectedQueues.contains(queue.name),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _selectedQueues.add(queue.name);
                      } else {
                        _selectedQueues.remove(queue.name);
                      }
                    });
                  },
                ),
            ],
          ),
      ],
    );
  }
}
