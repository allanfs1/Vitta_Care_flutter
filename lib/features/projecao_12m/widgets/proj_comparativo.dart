import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/num_ptbr.dart';
import '../projecao_amostradores.dart';
import '../projecao_models.dart';
import 'proj_comuns.dart';

/// Os dois cenários lado a lado, com intervalo em ambos.
///
/// A v1.0 da especificação mostrava intervalo só no cenário com intervenção —
/// o que faz o baseline parecer certo e a projeção parecer arriscada. Os dois
/// são incertos, e comparar mediana com mediana esconde o quanto as faixas se
/// sobrepõem.
class ProjComparativo extends StatelessWidget {
  const ProjComparativo({super.key, required this.resultado});

  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    final linhas = <(String, Percentis, Percentis, bool)>[
      ('Agendamentos', r.baseline.agendamentos, r.agendaClinica.agendamentos,
          true),
      ('Comparecimentos', r.baseline.comparecimentos,
          r.agendaClinica.comparecimentos, true),
      ('Faltas', r.baseline.faltas, r.agendaClinica.faltas, false),
      ('Cancelamentos', r.baseline.cancelamentos,
          r.agendaClinica.cancelamentos, false),
    ];

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProjTitulo(
            titulo: 'Dois cenários em ${r.config.horizonteMeses} meses',
            sub: '${NumPtBr.inteiro(r.config.nSimulacoes)} execuções · '
                'semente ${r.config.seed} · ${r.duracao.inMilliseconds} ms · '
                'faixa P05–P95 nos dois lados',
          ),
          const SizedBox(height: AppSpacing.md),
          const _Cabecalho(),
          const SizedBox(height: 6),
          for (final l in linhas)
            _Linha(
              rotulo: l.$1,
              base: l.$2,
              agenda: l.$3,
              maiorEhMelhor: l.$4,
            ),
          const SizedBox(height: AppSpacing.sm),
          ProjAviso(
            texto: 'A largura do intervalo de comparecimentos é '
                '${NumPtBr.pct(r.larguraRelativa)} da mediana. Propagar só o '
                'ruído amostral daria uma faixa bem mais estreita — e falsa: '
                'ela cobriria cerca de metade dos futuros plausíveis.',
          ),
        ],
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(flex: 3, child: SizedBox()),
          Expanded(
            flex: 4,
            child: Text('CONTINUIDADE',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    color: AppColors.textSecondary)),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 4,
            child: Text('COM AGENDA CLÍNICA',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    color: AppColors.primary)),
          ),
        ],
      );
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.rotulo,
    required this.base,
    required this.agenda,
    required this.maiorEhMelhor,
  });

  final String rotulo;
  final Percentis base;
  final Percentis agenda;
  final bool maiorEhMelhor;

  @override
  Widget build(BuildContext context) {
    final delta = agenda.p50 - base.p50;
    final melhorou = maiorEhMelhor ? delta > 0 : delta < 0;
    final relevante = delta.abs() > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(rotulo,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          Expanded(flex: 4, child: _Faixa(p: base, cor: AppColors.textSecondary)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 4,
            child: _Faixa(
              p: agenda,
              cor: relevante
                  ? (melhorou ? AppColors.success : AppColors.danger)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Faixa extends StatelessWidget {
  const _Faixa({required this.p, required this.cor});
  final Percentis p;
  final Color cor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(NumPtBr.inteiro(p.p50),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: cor)),
          Text(
              '${NumPtBr.inteiro(p.p05)} – ${NumPtBr.inteiro(p.p95)}',
              style: const TextStyle(
                  fontSize: 10.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: AppColors.textTertiary)),
        ],
      );
}
