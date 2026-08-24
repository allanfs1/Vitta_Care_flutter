import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/configuracoes_provider.dart';
import '../widgets/config_widgets.dart';

/// CFG-06 — Dados e Privacidade.
class DadosPrivacidadeScreen extends ConsumerWidget {
  const DadosPrivacidadeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dados e Privacidade')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ConfigSection(
            title: 'Dados locais',
            children: [
              OptionTile(
                title: 'Limpar cache (CFG-06a)',
                subtitle: 'Remove dados temporários do dispositivo',
                icon: Icons.cleaning_services_outlined,
                value: '~2,4 MB',
                onTap: () => _snack(context, 'Cache limpo.'),
              ),
              OptionTile(
                title: 'Exportar meus dados (CFG-06b)',
                subtitle: 'Perfil e configurações em JSON (LGPD)',
                icon: Icons.download_outlined,
                value: 'JSON',
                onTap: () {
                  final json = ref.read(settingsProvider).encode();
                  _snack(context, 'Exportado (${json.length} bytes).');
                },
              ),
            ],
          ),
          ConfigSection(
            title: 'Sessões (CFG-06d)',
            children: [
              const ListTile(
                leading: Icon(Icons.computer),
                title: Text('Este dispositivo'),
                subtitle: Text('Sessão atual • ativa agora'),
                trailing: Icon(Icons.check_circle, color: AppColors.success),
              ),
              ListTile(
                leading: const Icon(Icons.phone_iphone),
                title: const Text('iPhone • São Paulo'),
                subtitle: const Text('Última atividade há 2 dias'),
                trailing: TextButton(
                  onPressed: () => _snack(context, 'Sessão encerrada.'),
                  child: const Text('Encerrar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => _confirmDelete(context, user.email ?? ''),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Excluir minha conta (CFG-06c)'),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext c, String msg) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

  /// Confirmação reforçada: digitar o e-mail + confirmação explícita.
  Future<void> _confirmDelete(BuildContext context, String email) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final matches = controller.text.trim() == email && email.isNotEmpty;
          return AlertDialog(
            title: const Text('Excluir conta'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Esta ação é irreversível. Para confirmar, digite seu e-mail:'),
                const SizedBox(height: AppSpacing.md),
                Text(email, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: controller,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Seu e-mail'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: matches ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Excluir'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed == true && context.mounted) {
      _snack(context, 'Conta marcada para exclusão (demo).');
    }
  }
}
