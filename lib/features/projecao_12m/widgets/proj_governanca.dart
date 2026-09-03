import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/num_ptbr.dart';
import '../equidade.dart';
import '../piloto_poder.dart';
import '../projecao_providers.dart';
import '../risco_calibracao.dart';
import 'proj_comuns.dart';

/// Governança da projeção — o que separa uma demonstração convincente de um
/// produto que sobrevive à primeira auditoria do cliente.
///
/// Reúne as quatro coisas que não aparecem no gráfico e decidem se o número
/// pode ser apresentado: o piso de intervenção, o poder do piloto, a maturidade
/// do histórico e os critérios que liberam o escore para o financeiro.
class ProjGovernanca extends ConsumerWidget {
  const ProjGovernanca({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        _PartidaAFrio(),
        SizedBox(height: AppSpacing.lg),
        _Piloto(),
        SizedBox(height: AppSpacing.lg),
        _PisoIntervencao(),
        SizedBox(height: AppSpacing.lg),
        _UsosProibidos(),
        SizedBox(height: AppSpacing.lg),
        _Calibracao(),
        SizedBox(height: AppSpacing.lg),
        _Monitoramento(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Partida a frio
// ─────────────────────────────────────────────────────────────────────────

class _PartidaAFrio extends ConsumerWidget {
  const _PartidaAFrio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(projPartidaAFrioProvider);
    final obs = ref.watch(projHistoricoObservadoProvider);

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Maturidade do histórico',
            sub: 'Sem histórico nenhum dos três modelos pode ser treinado — e '
                'a alternativa que sobra é inventar números',
          ),
          const SizedBox(height: AppSpacing.md),
          ProjFaixa(
            icone: a.maturidade.apenasIlustrativa
                ? Icons.warning_amber_rounded
                : Icons.history_toggle_off,
            cor: a.maturidade.apenasIlustrativa
                ? AppColors.warning
                : AppColors.secondary,
            titulo: obs == null
                ? 'Sem agenda registrada — ${a.maturidade.label}'
                : '${a.maturidade.label} · '
                    '${NumPtBr.inteiro(a.desfechosObservados)} desfechos',
            detalhe: a.maturidade.possivel,
          ),
          if (a.maturidade.naoPrometer.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ProjAviso(
              icone: Icons.block_outlined,
              cor: AppColors.danger,
              texto: 'Não prometer: ${a.maturidade.naoPrometer}',
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ProjLinhas(itens: [
            ('Força do shrinkage para o cohort (k)',
                NumPtBr.dec(a.kShrinkage, casas: 0)),
            ('Peso da própria clínica com o histórico atual',
                NumPtBr.pct(a.pesoDoSegmento(a.desfechosObservados))),
            ('WAPE mínimo defensável', NumPtBr.pct(a.wapeSugerido)),
            ('Força máxima do prior Beta',
                NumPtBr.inteiro(a.nHistoricoEfetivo)),
          ]),
          const SizedBox(height: AppSpacing.xs),
          const ProjAviso(
            icone: Icons.trending_flat,
            texto: 'O shrinkage não é detalhe de robustez: é o mecanismo que '
                'permite atender clínica nova sem inventar parâmetro. Com n '
                'pequeno o peso fica no cohort e migra para a clínica conforme '
                'ela acumula desfechos — sem descontinuidade, e com o '
                'intervalo estreitando na medida em que a evidência cresce.',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Poder do piloto
// ─────────────────────────────────────────────────────────────────────────

class _Piloto extends ConsumerWidget {
  const _Piloto();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(projPilotoProvider);
    final c = ref.watch(projConfigProvider);
    final tabela = PoderPiloto.tabela(taxaBase: c.taxaFalta);

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Poder do piloto',
            sub: 'Um piloto subdimensionado não distingue "não funciona" de '
                '"não medimos o bastante"',
          ),
          const SizedBox(height: AppSpacing.md),
          ProjFaixa(
            icone: v.viavel ? Icons.check_circle_outline : Icons.timelapse,
            cor: v.viavel ? AppColors.success : AppColors.warning,
            titulo: v.viavel
                ? 'Detectável em ${v.mesesNecessarios.toStringAsFixed(1)} meses'
                : 'Não detectável em 3 meses neste volume',
            detalhe: v.recomendacao,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Amostra por braço — teste bilateral, α = 5%, poder 80%, '
            'partindo de ${NumPtBr.pct(c.taxaFalta)} de falta',
            style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProjLinhas(itens: [
            for (final d in tabela)
              (
                'Redução de ${(d.reducaoRelativa * 100).round()}% '
                    '(para ${NumPtBr.pct(d.taxaEsperada)})',
                '${NumPtBr.inteiro(d.nPorBraco)} × 2 · '
                    '${d.mesesPara(c.agendamentosMensais).toStringAsFixed(1)} '
                    'meses',
              ),
          ]),
          const SizedBox(height: AppSpacing.xs),
          const ProjAviso(
            icone: Icons.balance,
            texto: 'Uma clínica de 400 agendamentos por mês não prova sozinha '
                'uma redução de 20% em menos de seis meses. Prometer evidência '
                'em 90 dias nesse porte é prometer o que a estatística não '
                'entrega — agrupe clínicas num piloto multicêntrico, ou declare '
                'desde o início que o piloto é de viabilidade operacional.',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Equidade
// ─────────────────────────────────────────────────────────────────────────

class _PisoIntervencao extends StatelessWidget {
  const _PisoIntervencao();

  @override
  Widget build(BuildContext context) {
    const exemplos = [0.10, 0.40, 0.70];

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Piso de intervenção',
            sub: 'O escore pode adicionar esforço de contato; nunca pode '
                'subtrair serviço',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final s in exemplos) _LinhaPlano(escore: s),
          const SizedBox(height: AppSpacing.xs),
          const ProjAviso(
            icone: Icons.lock_outline,
            cor: AppColors.secondary,
            texto: 'Isto é invariante executável, não diretriz de treinamento: '
                'um plano que reduza lembretes, remova canal do piso ou retire '
                'a reserva de vaga lança exceção — inclusive em produção, '
                'porque a verificação não é um assert.',
          ),
          const ProjAviso(
            icone: Icons.groups_outlined,
            texto: 'A probabilidade de faltar correlaciona com transporte, '
                'renda, vínculo informal e distância até a unidade. Um modelo '
                'bem ajustado aprende esses padrões mesmo sem receber renda ou '
                'raça: bairro, canal e histórico funcionam como proxies. Usar '
                'o escore para reduzir esforço transferiria acesso dos mais '
                'vulneráveis para os menos, com aparência de neutralidade.',
          ),
        ],
      ),
    );
  }
}

class _LinhaPlano extends StatelessWidget {
  const _LinhaPlano({required this.escore});
  final double escore;

  @override
  Widget build(BuildContext context) {
    final p = PisoIntervencao.plano(escore);
    final cor = escore >= PisoIntervencao.limiarAlto
        ? AppColors.danger
        : (escore >= PisoIntervencao.limiarModerado
            ? AppColors.warning
            : AppColors.success);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              NumPtBr.pct(escore, casas: 0),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: cor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '${p.lembretes} lembrete(s) · '
              '${p.canais.map((c) => c.label).join(', ')}'
              '${p.contatoHumano48h ? ' · contato humano em 48h' : ''}'
              '${p.reservaVaga ? ' · vaga reservada' : ''}',
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsosProibidos extends StatelessWidget {
  const _UsosProibidos();

  @override
  Widget build(BuildContext context) => ProjCartao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProjTitulo(
              titulo: 'Usos proibidos do escore',
              sub: 'Bloqueados em código: pedir o escore para um destes fins '
                  'lança exceção',
            ),
            const SizedBox(height: AppSpacing.md),
            for (final u in UsoEscore.proibidos)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.block,
                          size: 15, color: AppColors.danger),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.label,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                          Text(u.porQueProibido,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  height: 1.4,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────
// Calibração e monitoramento
// ─────────────────────────────────────────────────────────────────────────

class _Calibracao extends StatelessWidget {
  const _Calibracao();

  @override
  Widget build(BuildContext context) => ProjCartao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProjTitulo(
              titulo: 'O que libera o escore para o financeiro',
              sub: 'Ordenar bem serve para priorizar a fila; projetar '
                  'faturamento exige probabilidade calibrada',
            ),
            const SizedBox(height: AppSpacing.md),
            ProjLinhas(itens: [
              ('ECE após calibração isotônica',
                  '≤ ${NumPtBr.dec(DiagnosticoCalibracao.vazio.limiteEce, casas: 2)}'),
              ('Brier', 'melhor que a taxa-base constante'),
              ('Métrica primária de treino', 'PR-AUC, não AUC ponderada'),
              ('Validação', 'temporal explícita, nunca CV aleatória'),
              ('ECE por subgrupo (n ≥ 300)', '≤ 0,05'),
              ('Razão entre maior e menor recall', '≤ 1,25'),
              ('Desfecho por subgrupo', 'nenhum pior que o baseline'),
            ]),
            const SizedBox(height: AppSpacing.xs),
            const ProjAviso(
              icone: Icons.straighten,
              texto: 'AUC mede só ordenação. Um modelo pode ordenar '
                  'perfeitamente e dizer "40%" onde a taxa real é 22% — e como '
                  'o motor multiplica esse escore por valor de consulta, o erro '
                  'de nível contamina toda a projeção financeira.',
            ),
            const ProjAviso(
              icone: Icons.public,
              texto: 'A última linha é a mais importante das sete. Um piloto '
                  'pode reduzir a falta agregada em 20% concentrando todo o '
                  'ganho em quem já comparecia mais: tecnicamente é sucesso, em '
                  'saúde pública é o contrário do objetivo.',
            ),
          ],
        ),
      );
}

class _Monitoramento extends StatelessWidget {
  const _Monitoramento();

  @override
  Widget build(BuildContext context) => ProjCartao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProjTitulo(
              titulo: 'Gatilhos de re-treino',
              sub: '"Erro acima do limite" sem número significa que ninguém '
                  're-treina até alguém reclamar',
            ),
            const SizedBox(height: AppSpacing.md),
            ProjLinhas(itens: const [
              ('Forecast · WAPE por 2 períodos', '> 1,3× o de validação'),
              ('Forecast · cobertura do intervalo de 80%', 'fora de 70–90%'),
              ('Risco · PR-AUC', 'queda > 10% relativos'),
              ('Risco · ECE', '> 0,05 → recalibrar antes de re-treinar'),
              ('Markov · divergência de Jensen-Shannon', '> 0,05'),
              ('Simulador · realizado fora do P05–P95', '2 meses seguidos'),
            ]),
            const SizedBox(height: AppSpacing.xs),
            const ProjAviso(
              icone: Icons.fact_check_outlined,
              texto: 'A métrica que valida o produto inteiro é a cobertura: se '
                  'o motor promete uma faixa de 90% e o realizado cai dentro '
                  'dela em metade dos meses, o produto está errado mesmo com '
                  'todas as outras métricas boas. Ela só pode ser medida depois '
                  'de meses fechados — e é a única que teria detectado o defeito '
                  'que esta revisão corrige.',
            ),
            const ProjAviso(
              icone: Icons.schedule,
              texto: 'O desfecho de um agendamento só se conhece na data da '
                  'consulta. Com 30 dias de antecedência média, a performance '
                  'do modelo de risco só pode ser medida com cerca de um mês de '
                  'atraso — dimensione a janela de alerta com essa defasagem, '
                  'ou o painel mostrará "sem dados" e alguém lerá "sem '
                  'problema".',
            ),
          ],
        ),
      );
}
