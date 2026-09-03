import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../assistente/assistant_anchors.dart';
import '../../assistente/assistant_tours.dart';
import '../monte_carlo_models.dart';
import '../monte_carlo_providers.dart';
import 'distribuicao_chart.dart';
import 'mc_comuns.dart';
import 'mc_explicar_icone.dart';

/// Aba de decisão: o que fazer com a agenda de amanhã.
///
/// A ordem das seções é a ordem da política: primeiro a fila (preencher vaga
/// que de fato abriu), só depois o overbooking (criar espera especulativa).
class McDecisaoTab extends ConsumerWidget {
  const McDecisaoTab({super.key, required this.resultado});

  final SimulacaoResultado resultado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = resultado;
    final cenarios = ref.watch(mcCenariosProvider);
    final recomendado = ref.watch(mcEncaixesRecomendadosProvider);
    final limite = ref.watch(mcLimiteRiscoProvider);

    if (r.totalAgendados == 0) {
      return McCartao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nenhuma consulta pendente ou confirmada nesta data.',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'O simulador considera apenas agendamentos ainda em aberto — '
              'realizados, faltas e cancelados são história, não previsão.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AssistantTarget(
          anchorId: HelpAnchors.simKpis,
          child: McGradeKpis(cartoes: [
            McKpi(
              rotulo: 'Agendados',
              valor: McNum.inteiro(r.totalAgendados),
              icone: Icons.event_note_outlined,
              cor: AppColors.primary,
              dica: 'Consultas pendentes ou confirmadas nesta data.',
            ),
            McKpi(
              rotulo: 'Faltas esperadas',
              valor: McNum.dec(r.faltasEsperadas, casas: 1),
              icone: Icons.person_off_outlined,
              cor: AppColors.danger,
              dica: 'Soma das probabilidades individuais. Não libera vaga a '
                  'tempo de reocupar.',
            ),
            McKpi(
              rotulo: 'Cancelam com aviso',
              valor: McNum.dec(r.cancelamentosEsperados, casas: 1),
              icone: Icons.event_busy_outlined,
              cor: AppColors.warning,
              dica: 'Estas liberam a vaga com tempo útil — é o que alimenta a '
                  'lista de espera.',
            ),
            McKpi(
              rotulo: 'Faltas P95',
              valor: McNum.inteiro(r.faltas.p95),
              sufixo: 'de ${McNum.inteiro(r.totalAgendados)}',
              icone: Icons.warning_amber_outlined,
              cor: AppColors.danger,
              dica: 'Cauda ruim: em 5% dos dias as faltas passam disso.',
            ),
            McKpi(
              rotulo: 'Sobredispersão φ',
              valor: r.exato ? '1,00' : McNum.dec(r.phiObservado),
              icone: Icons.blur_on,
              cor: AppColors.pinkAccent,
              dica: 'Quanto as faltas do dia se movem juntas. 1,00 = '
                  'independentes.',
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AssistantTarget(
          anchorId: HelpAnchors.simFila,
          child: _Fila(resultado: r),
        ),
        const SizedBox(height: AppSpacing.lg),
        AssistantTarget(
          anchorId: HelpAnchors.simRecomendacao,
          child: _Recomendacao(
              encaixes: recomendado, limite: limite, resultado: r),
        ),
        const SizedBox(height: AppSpacing.lg),
        AssistantTarget(
          anchorId: HelpAnchors.simGrafico,
          child: McCartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                McTitulo(
                  acao: const McExplicarIcone(
                      acaoId: 'grafico_distribuicao'),
                  titulo: 'Distribuição de faltas do dia',
                  sub: r.exato
                      ? 'Forma fechada (Poisson-binomial) — sem erro de amostragem'
                      : '${r.config.nRuns} execuções · semente ${r.config.seed} · '
                          '${r.duracao.inMilliseconds} ms',
                ),
                const SizedBox(height: AppSpacing.md),
                DistribuicaoChart(distribuicao: r.faltas),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AssistantTarget(
          anchorId: HelpAnchors.simCenarios,
          child: _TabelaCenarios(cenarios: cenarios, recomendado: recomendado),
        ),
        const SizedBox(height: AppSpacing.lg),
        AssistantTarget(
          anchorId: HelpAnchors.simSlots,
          child: _TabelaSlots(resultado: r, limite: limite),
        ),
      ],
    );
  }
}

/// A alavanca que vem antes do overbooking.
class _Fila extends StatelessWidget {
  const _Fila({required this.resultado});
  final SimulacaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final f = resultado.fila;
    final tem = f.chamadasSeguras > 0;
    return McCartao(
      cor: AppColors.secondary.withValues(alpha: 0.06),
      borda: AppColors.secondary.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.groups_outlined, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tem
                      ? 'Chame ${f.chamadasSeguras} paciente(s) da lista de espera'
                      : 'Nada a chamar da lista de espera',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.secondary),
                ),
                const SizedBox(height: 2),
                Text(
                  tem
                      ? 'Dimensionado pelo quartil inferior das vagas liberadas '
                          '(P25 = ${f.liberadasP25}, mediana ${f.liberadasP50}). '
                          'Preencher vaga que de fato abriu não cria espera '
                          'para ninguém — faça isto antes de pensar em encaixe.'
                      : 'Poucos cancelamentos previstos com antecedência nesta '
                          'data. Faltas sem aviso não liberam vaga a tempo.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Recomendacao extends StatelessWidget {
  const _Recomendacao({
    required this.encaixes,
    required this.limite,
    required this.resultado,
  });

  final int encaixes;
  final double limite;
  final SimulacaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final emRisco = resultado.slotsEmRisco(limite);
    final jaEstoura = encaixes == 0 && emRisco.isNotEmpty;

    final cor = jaEstoura
        ? AppColors.danger
        : (encaixes == 0 ? AppColors.warning : AppColors.success);
    final titulo = jaEstoura
        ? 'Não abra encaixes — a agenda já excede o limite'
        : (encaixes == 0
            ? 'Nenhum encaixe recomendado'
            : 'Até $encaixes encaixe${encaixes > 1 ? 's' : ''} dentro do limite');

    final detalhe = jaEstoura
        ? '${emRisco.length} slot(s) já passam de '
            '${McNum.pct(limite, casas: 0)} de risco de estouro sem '
            'nenhum encaixe. O pior é ${emRisco.first.doctorName} às '
            '${emRisco.first.hour}h, com '
            '${McNum.pct(emRisco.first.riscoEstouro(0))}.'
        : (encaixes == 0
            ? 'Qualquer encaixe levaria algum slot acima de '
                '${McNum.pct(limite, casas: 0)} de risco de estouro, ou '
                'concentraria a carga numa faixa de risco.'
            : 'Alocados nos slots de menor risco, mantendo todos abaixo de '
                '${McNum.pct(limite, casas: 0)} e com carga equilibrada '
                'entre as faixas de risco.');

    return McCartao(
      cor: cor.withValues(alpha: 0.06),
      borda: cor.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(jaEstoura ? Icons.block : Icons.event_available, color: cor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15, color: cor)),
                const SizedBox(height: 2),
                Text(detalhe, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabelaCenarios extends StatelessWidget {
  const _TabelaCenarios({required this.cenarios, required this.recomendado});

  final List<CenarioOverbooking> cenarios;
  final int recomendado;

  @override
  Widget build(BuildContext context) {
    if (cenarios.isEmpty) return const SizedBox.shrink();
    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const McTitulo(
            titulo: 'Cenários de overbooking',
            sub: 'Todos lidos da mesma simulação — a comparação entre eles não '
                'carrega ruído de amostragem',
          ),
          const SizedBox(height: AppSpacing.sm),
          McTabela(
            child: DataTable(
              columnSpacing: 20,
              headingRowHeight: 36,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 46,
              columns: const [
                DataColumn(label: Text('Encaixes')),
                DataColumn(label: Text('Risco do pior slot')),
                DataColumn(label: Text('Slots acima')),
                DataColumn(label: Text('Equidade')),
                DataColumn(label: Text('Receita esperada')),
                DataColumn(label: Text('Ociosidade')),
                DataColumn(label: Text('Decisão')),
              ],
              rows: [
                for (final c in cenarios)
                  DataRow(
                    color: c.encaixes == recomendado && recomendado > 0
                        ? WidgetStatePropertyAll(
                            AppColors.success.withValues(alpha: 0.10))
                        : null,
                    cells: [
                      DataCell(Text('+${c.encaixes}',
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text(
                        McNum.pct(c.riscoMaximoSlot),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.riscoMaximoSlot > 0.05
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      )),
                      DataCell(Text('${c.slotsAcimaDoLimite}')),
                      DataCell(McSelo(
                        texto: McNum.vezes(c.equidade.razaoMaxima),
                        cor: c.equidade.dentroDoLimite
                            ? AppColors.success
                            : AppColors.danger,
                      )),
                      DataCell(
                          Text(McNum.reais(c.receitaEsperada))),
                      DataCell(Text(McNum.dec(c.ociosidadeEsperada, casas: 1))),
                      DataCell(McSelo(
                        texto: c.aprovado ? 'Dentro' : 'Fora',
                        cor: c.aprovado ? AppColors.success : AppColors.danger,
                      )),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const McAviso(
            texto: 'Equidade é a razão entre a carga de overbooking que uma '
                'faixa de risco absorve e a sua presença na agenda. Acima do '
                'teto, o cenário é reprovado mesmo com risco de estouro baixo: '
                'encaixar sempre nos mesmos pacientes transfere o custo da '
                'eficiência para quem já tem mais barreira de acesso.',
          ),
        ],
      ),
    );
  }
}

class _TabelaSlots extends StatelessWidget {
  const _TabelaSlots({required this.resultado, required this.limite});

  final SimulacaoResultado resultado;
  final double limite;

  @override
  Widget build(BuildContext context) {
    final slots = [...resultado.slots]
      ..sort((a, b) => b.riscoEstouro(0).compareTo(a.riscoEstouro(0)));
    final top = slots.take(12).toList();
    final base = resultado.config.baseCapacidade;

    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McTitulo(
            acao: const McExplicarIcone(acaoId: 'grafico_slots'),
            titulo: 'Risco por slot (médico × hora)',
            sub: 'A unidade real da decisão: ${resultado.slots.length} slots '
                'nesta data · capacidade de referência: ${base.label}',
          ),
          const SizedBox(height: AppSpacing.sm),
          McTabela(
            child: DataTable(
              columnSpacing: 20,
              headingRowHeight: 36,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 46,
              columns: const [
                DataColumn(label: Text('Médico')),
                DataColumn(label: Text('Hora')),
                DataColumn(label: Text('Agendados')),
                DataColumn(label: Text('Cap. usada')),
                DataColumn(label: Text('Física')),
                DataColumn(label: Text('C/ overbook')),
                DataColumn(label: Text('Presentes P95')),
                DataColumn(label: Text('Libera c/ aviso')),
                DataColumn(label: Text('Alto risco')),
                DataColumn(label: Text('Risco de estouro')),
              ],
              rows: [
                for (final s in top)
                  DataRow(cells: [
                    DataCell(Text(s.doctorName,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text('${s.hour}h')),
                    DataCell(Text('${s.agendados}')),
                    DataCell(Text('${s.capacidade}',
                        style:
                            const TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text('${s.capacidadeFisica}')),
                    DataCell(Text('${s.capacidadeConfigurada}')),
                    DataCell(Text('${s.presentes.p95}')),
                    DataCell(Text('${s.liberadasComAviso.p50}')),
                    DataCell(Text(
                        McNum.pct(s.fracaoAltoRisco, casas: 0))),
                    DataCell(McSelo(
                      texto:
                          McNum.pct(s.riscoEstouro(0)),
                      cor: s.riscoEstouro(0) > limite
                          ? AppColors.danger
                          : AppColors.success,
                    )),
                  ]),
              ],
            ),
          ),
          if (base == BaseCapacidade.configurada) ...[
            const SizedBox(height: AppSpacing.sm),
            const McAviso(
              icone: Icons.warning_amber_outlined,
              texto: 'A capacidade de referência já inclui o overbooking '
                  'configurado para o médico. Os encaixes recomendados aqui '
                  'empilham em cima dele — troque para capacidade física se a '
                  'intenção era medir contra cadeira e tempo reais.',
            ),
          ],
        ],
      ),
    );
  }
}

/// Composição da agenda por faixa de risco — contexto para ler a equidade.
class McComposicaoRisco extends StatelessWidget {
  const McComposicaoRisco({super.key, required this.resultado});

  final SimulacaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final comp = resultado.composicaoRisco;
    final total = resultado.totalAgendados;
    if (total == 0) return const SizedBox.shrink();

    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const McTitulo(
            acao: McExplicarIcone(acaoId: 'grafico_composicao'),
            titulo: 'Composição da agenda',
            sub: 'Quem está exposto às decisões desta tela',
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final f in RiskLevel.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                      width: 70,
                      child: Text(f.label,
                          style: const TextStyle(fontSize: 12))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (comp[f] ?? 0) / total,
                        minHeight: 8,
                        backgroundColor: f.background,
                        valueColor: AlwaysStoppedAnimation(f.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('${comp[f] ?? 0}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
