import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../navigation/app_router.dart';
import '../monte_carlo_providers.dart';
import 'mc_comuns.dart';

/// Ponte do Simulador para o painel de Overbooking.
///
/// O painel de Overbooking mostra o que **já** aconteceu com a agenda —
/// ocupação, estouro, excedente. Isso é determinístico e olha para trás. Este
/// cartão traz o outro lado: o que a distribuição diz sobre o que ainda vai
/// acontecer, e quanto ainda cabe.
///
/// Fica em silêncio quando o simulador ainda não tem resposta, para não
/// competir com os KPIs do painel enquanto carrega.
class McPonteOverbooking extends ConsumerWidget {
  const McPonteOverbooking({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Só lê o resultado depois que o simulador foi aberto nesta sessão. Ler
    // antes disso dispararia a simulação como efeito colateral de abrir o
    // painel de Overbooking — caro, e ninguém pediu.
    if (!ref.watch(mcSessaoAtivaProvider)) return const _Convite();

    final async = ref.watch(mcResultadoProvider);
    final r = async.valueOrNull;
    if (r == null || r.totalAgendados == 0) return const _Convite();

    final encaixes = ref.watch(mcEncaixesRecomendadosProvider);
    final limite = ref.watch(mcLimiteRiscoProvider);
    final emRisco = r.slotsEmRisco(limite);
    final jaEstoura = encaixes == 0 && emRisco.isNotEmpty;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final cor = jaEstoura
        ? AppColors.danger
        : (encaixes == 0 ? AppColors.warning : AppColors.success);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.casino_outlined, color: cor, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jaEstoura
                      ? 'Simulador: não abra encaixes hoje'
                      : (encaixes == 0
                          ? 'Simulador: nenhum encaixe dentro do limite'
                          : 'Simulador: cabem até $encaixes encaixe'
                              '${encaixes > 1 ? 's' : ''}'),
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: cor),
                ),
                const SizedBox(height: 2),
                Text(
                  _detalhe(r.faltas.p50, r.faltas.p95, r.fila.chamadasSeguras,
                      emRisco.length, limite),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: () => context.go(AppRoutes.monteCarlo),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }

  String _detalhe(
      int p50, int p95, int fila, int slotsRisco, double limite) {
    final partes = <String>[
      'faltas típicas $p50, cauda ruim $p95',
      if (fila > 0) 'fila pode chamar $fila',
      if (slotsRisco > 0)
        '$slotsRisco slot(s) já acima de ${McNum.pct(limite, casas: 0)}',
    ];
    return partes.join(' · ');
  }
}

/// Cartão mostrado antes de o simulador ter rodado nesta sessão.
///
/// Não calcula nada: apenas indica que a leitura probabilística existe e onde
/// encontrá-la. O painel de Overbooking continua sendo o que sempre foi.
class _Convite extends StatelessWidget {
  const _Convite();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: dark ? AppColors.borderDark : AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.casino_outlined,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Este painel mostra a ocupação que já aconteceu. O Simulador '
              'estima quantos pacientes ainda cabem, com a distribuição de '
              'faltas do dia.',
              style: TextStyle(fontSize: 11.5),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: () => context.go(AppRoutes.monteCarlo),
            child: const Text('Simulador'),
          ),
        ],
      ),
    );
  }
}
