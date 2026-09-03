import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../monte_carlo_models.dart';
import '../monte_carlo_providers.dart';
import 'mc_comuns.dart';

/// Aba de parâmetros: tudo que muda a resposta, num lugar só, com o efeito de
/// cada escolha escrito ao lado.
class McParametrosTab extends ConsumerWidget {
  const McParametrosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(mcConfigProvider);
    final limite = ref.watch(mcLimiteRiscoProvider);
    final limiteEq = ref.watch(mcLimiteEquidadeProvider);
    final odds = ref.watch(mcOddsRatioProvider);
    final valorSlot = ref.watch(mcValorSlotProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    void setConfig(SimulacaoConfig c) =>
        ref.read(mcConfigProvider.notifier).state = c;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        McCartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const McTitulo(
                titulo: 'Modelo',
                sub: 'As taxas de falta são um ponto de partida, não uma '
                    'medição — calibrar antes de decidir por elas',
              ),
              const SizedBox(height: AppSpacing.md),
              McDeslizante(
                rotulo: 'Correlação entre faltas do dia (ρ)',
                valor: config.rho,
                min: 0,
                max: 0.20,
                divisoes: 20,
                texto: config.rho <= 0
                    ? '0 — modelo independente (equivale à v1.0)'
                    : McNum.dec(config.rho, casas: 3),
                ajuda:
                    'Chuva, feriado e greve de transporte empurram as faltas do '
                    'dia juntas. Em ρ = 0 o motor usa a forma fechada exata e '
                    'não simula nada.',
                onChanged: (v) => setConfig(config.copyWith(rho: v)),
              ),
              _Escolha<BaseCapacidade>(
                rotulo: 'Capacidade de referência',
                valor: config.baseCapacidade,
                opcoes: BaseCapacidade.values,
                rotuloDe: (b) => b.label,
                ajuda: config.baseCapacidade == BaseCapacidade.fisica
                    ? 'Mede o risco contra cadeira e tempo reais (slotLimit).'
                    : 'A referência já inclui o overbooking configurado do '
                        'médico — os encaixes recomendados empilham em cima dele.',
                onChanged: (v) => setConfig(config.copyWith(baseCapacidade: v)),
              ),
              _Escolha<EncaixeModo>(
                rotulo: 'Como o encaixe entra na conta',
                valor: config.encaixeModo,
                opcoes: EncaixeModo.values,
                rotuloDe: (e) => e.label,
                ajuda: config.encaixeModo == EncaixeModo.certo
                    ? 'Limite superior do risco: o encaixe comparece sempre.'
                    : 'Limite inferior: o encaixe também pode faltar, mas o '
                        'cálculo ignora o fator comum do dia para ele.',
                onChanged: (v) => setConfig(config.copyWith(encaixeModo: v)),
              ),
              if (config.encaixeModo == EncaixeModo.probabilistico)
                McDeslizante(
                  rotulo: 'Falta do paciente de encaixe',
                  valor: config.pFaltaEncaixe,
                  min: 0.0,
                  max: 0.5,
                  divisoes: 25,
                  texto: McNum.pct(config.pFaltaEncaixe, casas: 0),
                  ajuda: 'Encaixes são chamados de última hora e costumam ter '
                      'adesão diferente da média da agenda.',
                  onChanged: (v) =>
                      setConfig(config.copyWith(pFaltaEncaixe: v)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        McCartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const McTitulo(
                titulo: 'Política de decisão',
                sub: 'Os limites que aprovam ou reprovam um cenário',
              ),
              const SizedBox(height: AppSpacing.md),
              McDeslizante(
                rotulo: 'Risco de estouro tolerado por slot',
                valor: limite,
                min: 0.01,
                max: 0.25,
                divisoes: 24,
                texto: McNum.pct(limite, casas: 0),
                ajuda:
                    'O cenário é julgado pelo pior slot, não pela média do dia.',
                onChanged: (v) =>
                    ref.read(mcLimiteRiscoProvider.notifier).state = v,
              ),
              McDeslizante(
                rotulo: 'Teto de desequilíbrio entre faixas de risco',
                valor: limiteEq,
                min: 1.0,
                max: 2.5,
                divisoes: 30,
                texto: McNum.vezes(limiteEq),
                ajuda: 'Acima disso o cenário é reprovado mesmo com risco de '
                    'estouro baixo. Em 1,00 exige carga estritamente '
                    'proporcional; valores altos desligam a trava.',
                onChanged: (v) =>
                    ref.read(mcLimiteEquidadeProvider.notifier).state = v,
              ),
              McDeslizante(
                rotulo: 'Efeito da intervenção (razão de chances)',
                valor: odds,
                min: 0.2,
                max: 1.0,
                divisoes: 16,
                texto: odds >= 0.999
                    ? '1,00 — sem intervenção'
                    : McNum.dec(odds),
                ajuda:
                    'Lembrete e confirmação ativa entram como razão de chances, '
                    'que nunca leva a probabilidade para fora de (0, 1). Parte '
                    'de quem deixaria de faltar passa a cancelar com aviso.',
                onChanged: (v) =>
                    ref.read(mcOddsRatioProvider.notifier).state = v,
              ),
              McDeslizante(
                rotulo: 'Valor médio do slot',
                valor: valorSlot,
                min: 50,
                max: 600,
                divisoes: 55,
                texto: McNum.reais(valorSlot),
                ajuda: 'Converte ociosidade e comparecimento em receita '
                    'esperada na tabela de cenários.',
                onChanged: (v) =>
                    ref.read(mcValorSlotProvider.notifier).state = v,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        McCartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const McTitulo(
                titulo: 'Execução',
                sub: 'Reprodutibilidade e custo',
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _Numero(
                      rotulo: 'Execuções',
                      valor: '${config.nRuns}',
                      onSubmit: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 100 && n <= 200000) {
                          setConfig(config.copyWith(nRuns: n));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _Numero(
                      rotulo: 'Semente',
                      valor: '${config.seed}',
                      onSubmit: (v) {
                        final n = int.tryParse(v);
                        if (n != null) setConfig(config.copyWith(seed: n));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const McAviso(
                icone: Icons.speed,
                cor: AppColors.secondary,
                texto: 'Sob ρ = 0,03 o erro de Monte Carlo do P95 já estabiliza '
                    'em 20.000 execuções. Mais que isso gasta tempo para mover '
                    'um número que parou.',
              ),
              Text(
                'Rótulo de falta: ${config.labelVersion}. Métricas históricas '
                'calculadas com outro rótulo não são comparáveis com estas.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Escolha<T> extends StatelessWidget {
  const _Escolha({
    required this.rotulo,
    required this.valor,
    required this.opcoes,
    required this.rotuloDe,
    required this.ajuda,
    required this.onChanged,
  });

  final String rotulo;
  final T valor;
  final List<T> opcoes;
  final String Function(T) rotuloDe;
  final String ajuda;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final o in opcoes)
                ChoiceChip(
                  label: Text(rotuloDe(o),
                      style: const TextStyle(fontSize: 11.5)),
                  selected: o == valor,
                  onSelected: (_) => onChanged(o),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(ajuda,
              style: TextStyle(
                fontSize: 11,
                color: dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              )),
        ],
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({
    required this.rotulo,
    required this.valor,
    required this.onSubmit,
  });

  final String rotulo;
  final String valor;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: valor,
        key: ValueKey('$rotulo-$valor'),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: rotulo,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onFieldSubmitted: onSubmit,
      );
}
