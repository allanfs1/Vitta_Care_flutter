import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/num_ptbr.dart';
import 'projecao_models.dart';
import 'projecao_providers.dart';
import 'widgets/proj_comparativo.dart';
import 'widgets/proj_comuns.dart';
import 'widgets/proj_graficos.dart';
import 'widgets/proj_governanca.dart';

/// Projeção de 12 meses — dois cenários lado a lado.
///
/// Responde a duas perguntas: o que tende a acontecer se a clínica continuar
/// como está, e o que muda com as intervenções da Agenda Clínica. A resposta
/// vem com intervalo, não com número pontual — e o intervalo propaga as três
/// fontes de incerteza (forecast, parâmetro, amostragem), porque propagar só a
/// última produz uma faixa que cobre cerca de metade dos futuros plausíveis.
class Projecao12mScreen extends ConsumerStatefulWidget {
  const Projecao12mScreen({super.key});

  @override
  ConsumerState<Projecao12mScreen> createState() => _Projecao12mScreenState();
}

class _Projecao12mScreenState extends ConsumerState<Projecao12mScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _abas = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(projResultadoProvider);
    final config = ref.watch(projConfigProvider);

    return Scaffold(
      backgroundColor: dark ? AppColors.backgroundDark : AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.sm),
                  child: _Cabecalho(),
                ),
                TabBar(
                  controller: _abas,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800),
                  tabs: const [
                    Tab(text: 'Cenários'),
                    Tab(text: 'Gráficos'),
                    Tab(text: 'Governança'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _abas,
                    children: [
                      ListView(
                        padding: AppSpacing.pageInsets,
                        children: [
                          if (!config.calibradoComDadosReais) ...[
                            const _AvisoNaoCalibrado(),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          _Intensidade(atual: config.intensidade),
                          const SizedBox(height: AppSpacing.lg),
                          async.when(
                            loading: () => const ProjCarregando(
                                texto: 'Projetando 12 meses…'),
                            error: (e, _) => ProjFaixa(
                              icone: Icons.error_outline,
                              cor: AppColors.danger,
                              titulo: 'Falha na projeção',
                              detalhe: '$e',
                            ),
                            data: (r) => _Conteudo(resultado: r),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const _Parametros(),
                        ],
                      ),
                      // ── Aba Gráficos ──
                      async.when(
                        loading: () => const ProjCarregando(
                            texto: 'Carregando gráficos…'),
                        error: (e, _) => Center(
                          child: ProjFaixa(
                            icone: Icons.error_outline,
                            cor: AppColors.danger,
                            titulo: 'Falha ao gerar gráficos',
                            detalhe: '$e',
                          ),
                        ),
                        data: (r) => ProjGraficos(resultado: r),
                      ),
                      ListView(
                        padding: AppSpacing.pageInsets,
                        children: const [ProjGovernanca()],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Projeção de 12 meses',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color:
                  dark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            )),
        const SizedBox(height: 2),
        Text(
          'Continuidade × Agenda Clínica · cadeia de Markov e simulação com '
          'incerteza propagada',
          style: TextStyle(
            fontSize: 12,
            color: dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// O campo que muda a conversa comercial.
class _AvisoNaoCalibrado extends StatelessWidget {
  const _AvisoNaoCalibrado();

  @override
  Widget build(BuildContext context) => const ProjFaixa(
        icone: Icons.science_outlined,
        cor: AppColors.warning,
        titulo: 'Projeção não calibrada com dados reais',
        detalhe: 'Os parâmetros de impacto são hipóteses, não efeitos medidos '
            'nesta clínica. Isto é uma projeção probabilística, não uma '
            'promessa de resultado — depois do piloto os números valem muito '
            'mais, e este aviso sai.',
      );
}

class _Intensidade extends ConsumerWidget {
  const _Intensidade({required this.atual});
  final IntensidadeCenario atual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Intensidade da intervenção',
            sub: 'Três pacotes de hipótese. Nenhum é previsão — são faixas '
                'para discutir',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final i in IntensidadeCenario.values)
                ChoiceChip(
                  label: Text(i.label),
                  selected: i == atual,
                  onSelected: (_) => aplicarIntensidade(ref, i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProjComparativo(resultado: r),
        const SizedBox(height: AppSpacing.lg),
        _Financeiro(resultado: r),
        if (r.temDemandaReprimida) ...[
          const SizedBox(height: AppSpacing.lg),
          _Capacidade(resultado: r),
        ],
        const SizedBox(height: AppSpacing.lg),
        _Cadeia(resultado: r),
      ],
    );
  }
}

/// Impacto financeiro com a decomposição que separa ganho de antecipação.
class _Financeiro extends StatelessWidget {
  const _Financeiro({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final i = resultado.impacto;
    final ingenua = i.receitaTotalBruta;

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Impacto financeiro em 12 meses',
            sub: 'Vaga reposta por paciente que já seria atendido depois é '
                'antecipação de demanda, não receita nova',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Cifra(
                  // Uma intervenção que piora o resultado não pode aparecer em
                  // verde com rótulo de ganho: é justamente o desfecho que o
                  // piloto existe para detectar.
                  rotulo: i.houvePerda
                      ? 'Perda com a intervenção'
                      : 'Receita defensável',
                  valor: NumPtBr.reais(i.receitaDefensavel),
                  cor: i.houvePerda ? AppColors.danger : AppColors.success,
                  detalhe: i.houvePerda
                      ? 'O pacote simulado reduz o comparecimento. Não há '
                          'ganho a decompor — rever as hipóteses antes de '
                          'levar este cenário a alguém.'
                      : 'Faltas evitadas + demanda genuinamente nova. '
                          'É o que pode ser apresentado como ganho.',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Cifra(
                  rotulo: 'Antecipação de demanda',
                  valor: NumPtBr.reais(i.receitaAntecipacao),
                  cor: AppColors.textSecondary,
                  detalhe: 'Existe, mas já existiria. Reportada à parte — '
                      'nunca somada à de cima.',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ProjLinhas(itens: [
            ('Consultas por falta evitada',
                NumPtBr.dec(i.consultasFaltaEvitada, casas: 0)),
            ('Consultas por demanda nova',
                NumPtBr.dec(i.consultasDemandaNova, casas: 0)),
            ('Consultas antecipadas',
                NumPtBr.dec(i.consultasAntecipadas, casas: 0)),
          ]),
          if (i.receitaDefensavel > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            ProjAviso(
              icone: Icons.calculate_outlined,
              texto: 'Somar tudo como receita nova daria '
                  '${NumPtBr.reais(ingenua)} — '
                  '${NumPtBr.pct(i.superestimativaIngenua, casas: 1)} a mais '
                  'do que o defensável. É essa conta que produz decepção '
                  'depois da implantação.',
            ),
          ],
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.rotulo,
    required this.valor,
    required this.cor,
    required this.detalhe,
  });

  final String rotulo;
  final String valor;
  final Color cor;
  final String detalhe;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: cor.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: cor)),
            const SizedBox(height: 3),
            Text(valor,
                style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 4),
            Text(detalhe,
                style: const TextStyle(fontSize: 11, height: 1.4)),
          ],
        ),
      );
}

/// Capacidade é restrição dura — o que não coube é resultado de negócio.
class _Capacidade extends StatelessWidget {
  const _Capacidade({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final b = resultado.agendaClinica;
    final meses = b.mesesComDemandaReprimida;
    return ProjFaixa(
      icone: Icons.event_busy_outlined,
      cor: AppColors.pinkAccent,
      titulo: meses >= 1
          ? 'Demanda reprimida em ${meses.toStringAsFixed(0)} mês(es) de 12'
          : 'Demanda reprimida na cauda '
              '(${NumPtBr.pct(b.probabilidadeEstouro, casas: 0)} das '
              'projeções batem no teto)',
      detalhe:
          'Cerca de ${NumPtBr.inteiro(b.demandaReprimida.p50)} agendamentos '
          'não couberam no teto de '
          '${NumPtBr.inteiro(resultado.config.capacidadeMensal)} por mês '
          '(faixa ${NumPtBr.inteiro(b.demandaReprimida.p05)}–'
          '${NumPtBr.inteiro(b.demandaReprimida.p95)}). Isto não é erro da '
          'simulação: é lista de espera, e justifica ampliar agenda. A '
          'intervenção não cria capacidade — o que ela faz é reocupar as '
          '${NumPtBr.inteiro(b.vagasRepostas.p50)} vagas que os '
          'cancelamentos devolveram.',
    );
  }
}

/// Absorção da cadeia antes e depois da intervenção.
class _Cadeia extends StatelessWidget {
  const _Cadeia({required this.resultado});
  final ProjecaoResultado resultado;

  @override
  Widget build(BuildContext context) {
    final base = resultado.absorcaoBaseline;
    final interv = resultado.absorcaoIntervencao;

    return ProjCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjTitulo(
            titulo: 'Destino de um agendamento',
            sub: 'Probabilidade de absorção da cadeia de Markov, partindo de '
                '"agendado"',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final e in ['compareceu', 'faltou', 'cancelado', 'reagendado'])
            if ((base[e] ?? 0) > 0.0001 || (interv[e] ?? 0) > 0.0001)
              ProjBarraDupla(
                rotulo: _rotulo(e),
                antes: base[e] ?? 0,
                depois: interv[e] ?? 0,
                cor: _cor(e),
              ),
          const SizedBox(height: AppSpacing.xs),
          const ProjAviso(
            icone: Icons.schedule,
            texto: 'A cadeia real é indexada por dias até a consulta: a chance '
                'de confirmar faltando 30 dias não é a mesma de faltando 1. '
                'Aplicar o mesmo delta em todas as faixas suporia que um '
                'lembrete de 30 dias vale tanto quanto um de 2.',
          ),
        ],
      ),
    );
  }

  String _rotulo(String k) => switch (k) {
        'compareceu' => 'Compareceu',
        'faltou' => 'Faltou',
        'cancelado' => 'Cancelado',
        _ => 'Reagendado',
      };

  Color _cor(String k) => switch (k) {
        'compareceu' => AppColors.success,
        'faltou' => AppColors.danger,
        'cancelado' => AppColors.warning,
        _ => AppColors.secondary,
      };
}

class _Parametros extends ConsumerWidget {
  const _Parametros();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(projConfigProvider);
    final observado = ref.watch(projVolumeObservadoProvider);
    void set(ProjecaoConfig novo) =>
        ref.read(projConfigProvider.notifier).state = novo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProjCartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProjTitulo(
                titulo: 'Cenário base',
                sub: 'O que a clínica é hoje, antes de qualquer intervenção',
              ),
              const SizedBox(height: AppSpacing.md),
              ProjDeslizante(
                rotulo: 'Agendamentos por mês',
                valor: c.agendamentosMensais.toDouble(),
                min: 100,
                max: 4000,
                texto: NumPtBr.inteiro(c.agendamentosMensais),
                ajuda: observado != null
                    ? 'A agenda desta clínica mostra cerca de '
                        '${NumPtBr.inteiro(observado)} por mês.'
                    : 'Saída do forecast de demanda.',
                onChanged: (v) =>
                    set(c.copyWith(agendamentosMensais: v.round())),
              ),
              ProjDeslizante(
                rotulo: 'Capacidade mensal (teto físico)',
                valor: c.capacidadeMensal.toDouble(),
                min: 100,
                max: 4000,
                texto: NumPtBr.inteiro(c.capacidadeMensal),
                ajuda: 'Restrição dura: a intervenção não cria capacidade. O '
                    'que passa disso vira lista de espera.',
                onChanged: (v) =>
                    set(c.copyWith(capacidadeMensal: v.round())),
              ),
              ProjDeslizante(
                rotulo: 'Taxa de falta histórica',
                valor: c.taxaFalta,
                min: 0.02,
                max: 0.50,
                texto: NumPtBr.pct(c.taxaFalta),
                ajuda: 'Condicional ao agendamento existir.',
                onChanged: (v) => set(c.copyWith(taxaFalta: v)),
              ),
              ProjDeslizante(
                rotulo: 'Taxa de cancelamento histórica',
                valor: c.taxaCancelamento,
                min: 0.01,
                max: 0.35,
                texto: NumPtBr.pct(c.taxaCancelamento),
                ajuda: 'Cancelar com antecedência devolve a vaga — é '
                    'comportamento cooperativo, não falta.',
                onChanged: (v) => set(c.copyWith(taxaCancelamento: v)),
              ),
              ProjDeslizante(
                rotulo: 'Valor médio da consulta',
                valor: c.valorConsulta,
                min: 30,
                max: 800,
                texto: NumPtBr.reais(c.valorConsulta),
                ajuda: 'Converte consultas em receita.',
                onChanged: (v) => set(c.copyWith(valorConsulta: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ProjCartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProjTitulo(
                titulo: 'Incerteza',
                sub: 'As três camadas. Mexer aqui muda a largura do '
                    'intervalo, não a mediana',
              ),
              const SizedBox(height: AppSpacing.md),
              ProjDeslizante(
                rotulo: 'WAPE do forecast',
                valor: c.wapeForecast,
                min: 0.01,
                max: 0.40,
                texto: NumPtBr.pct(c.wapeForecast),
                ajuda: 'Camada 1: quanto o forecast erra. Entra como '
                    'lognormal, que preserva positividade.',
                onChanged: (v) => set(c.copyWith(wapeForecast: v)),
              ),
              ProjDeslizante(
                rotulo: 'Erro de forecast que persiste no ano',
                valor: c.rhoForecast,
                min: 0.0,
                max: 0.60,
                texto: NumPtBr.pct(c.rhoForecast, casas: 0),
                ajuda: c.rhoForecast <= 0.001
                    ? 'Em zero, a banda anual assume que os doze erros mensais '
                        'são independentes — e sai 3,5× mais estreita do que o '
                        'WAPE declarado autoriza afirmar.'
                    : 'Parcela do erro que é de nível: a série inteira no '
                        'patamar errado acompanha os doze meses, em vez de se '
                        'cancelar por média.',
                onChanged: (v) => set(c.copyWith(rhoForecast: v)),
              ),
              ProjDeslizante(
                rotulo: 'Desfechos observados (força do prior)',
                valor: c.nHistorico.toDouble(),
                min: 30,
                max: 20000,
                texto: NumPtBr.inteiro(c.nHistorico),
                ajuda: 'Camada 2: uma taxa de 22% medida em 80 casos e a mesma '
                    'medida em 8.000 não valem o mesmo.',
                onChanged: (v) => set(c.copyWith(nHistorico: v.round())),
              ),
              ProjDeslizante(
                rotulo: 'Fração de demanda genuinamente nova',
                valor: c.fracaoDemandaNova,
                min: 0.0,
                max: 1.0,
                texto: NumPtBr.pct(c.fracaoDemandaNova, casas: 0),
                ajuda: 'Parcela das vagas repostas ocupada por quem NÃO seria '
                    'atendido no horizonte. Deve ser medida no piloto, não '
                    'arbitrada.',
                onChanged: (v) => set(c.copyWith(fracaoDemandaNova: v)),
              ),
              ProjDeslizante(
                rotulo: 'Execuções da simulação',
                valor: c.nSimulacoes.toDouble(),
                min: 500,
                max: 20000,
                texto: NumPtBr.inteiro(c.nSimulacoes),
                ajuda: 'Mais execuções estreitam o erro de Monte Carlo, não a '
                    'incerteza real do problema.',
                onChanged: (v) => set(c.copyWith(nSimulacoes: v.round())),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
