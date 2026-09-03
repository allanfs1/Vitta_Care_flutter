import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../monte_carlo_calibracao.dart';
import '../monte_carlo_providers.dart';
import 'mc_comuns.dart';
import 'mc_explicar_icone.dart';

/// Aba de calibração (fase F2).
///
/// A ordem das seções é deliberada: **o que invalida os números vem antes dos
/// números.** Um estimador honesto sobre uma base enviesada devolve um número
/// honesto sobre uma clínica que não existe — mostrar a taxa primeiro e a
/// ressalva no rodapé seria convidar a decidir pelo número errado.
class McCalibracaoTab extends ConsumerWidget {
  const McCalibracaoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mcCalibracaoProvider);

    return async.when(
      loading: () => const _Carregando(),
      error: (e, _) => McFaixaEstado(
        icone: Icons.error_outline,
        cor: AppColors.danger,
        titulo: 'Falha na calibração',
        detalhe: '$e',
      ),
      data: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ref.watch(mcHistoricoEhDemoProvider)) ...[
            const _BannerDemo(),
            const SizedBox(height: AppSpacing.lg),
          ],
          _Veredito(calibracao: c),
          if (c.integridade.achados.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Integridade(integridade: c.integridade),
          ],
          const SizedBox(height: AppSpacing.lg),
          _Kpis(calibracao: c),
          const SizedBox(height: AppSpacing.lg),
          _Janela(),
          const SizedBox(height: AppSpacing.lg),
          _TabelaTaxas(calibracao: c),
          if (c.porMes.length >= 3) ...[
            const SizedBox(height: AppSpacing.lg),
            _Sazonalidade(calibracao: c),
          ],
          const SizedBox(height: AppSpacing.lg),
          _Backtest(calibracao: c),
          if (c.avisos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Avisos(avisos: c.avisos),
          ],
          const SizedBox(height: AppSpacing.lg),
          _Aplicar(calibracao: c),
        ],
      ),
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 72),
    child: Column(
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'Medindo o histórico da agenda…',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _Veredito extends StatelessWidget {
  const _Veredito({required this.calibracao});
  final CalibracaoResultado calibracao;

  @override
  Widget build(BuildContext context) {
    final c = calibracao;
    final bloqueios = c.integridade.bloqueios;

    if (bloqueios.isNotEmpty) {
      return McFaixaEstado(
        icone: Icons.gpp_maybe_outlined,
        cor: AppColors.danger,
        titulo: bloqueios.length == 1
            ? 'Os dados não permitem calibrar'
            : '${bloqueios.length} problemas impedem a calibração',
        detalhe:
            'O problema não está no modelo: está na entrada. Os números '
            'abaixo foram calculados e estão corretos para os dados '
            'recebidos — o que não vale é usar esses dados para decidir.',
        rodape: _Passos(
          titulo: 'Para destravar',
          passos: [
            for (final b in bloqueios)
              if (b.acao.isNotEmpty) b.acao,
          ],
        ),
      );
    }

    if (c.aprovadoParaUso) {
      return McFaixaEstado(
        icone: Icons.verified_outlined,
        cor: AppColors.success,
        titulo: 'Calibração aprovada para uso',
        detalhe:
            '${McNum.inteiro(c.diasAnalisados)} dias de histórico e cobertura '
            'do intervalo dentro do nominal. Os parâmetros medidos podem '
            'substituir os padrões do modelo.',
      );
    }

    return McFaixaEstado(
      icone: Icons.pending_actions_outlined,
      cor: AppColors.warning,
      titulo: 'Calibração parcial — ainda não use para decidir',
      detalhe:
          'São ${McNum.inteiro(c.diasAnalisados)} dia(s) analisados; a fase F2 '
          'pede 120. '
          '${c.backtest.temAmostras ? "A cobertura do intervalo está em ${McNum.pct(c.backtest.cobertura90, casas: 0)} (esperado ~90%)." : "Não há dias suficientes para rodar o backtest."}',
    );
  }
}

/// Lista numerada de próximos passos.
class _Passos extends StatelessWidget {
  const _Passos({required this.titulo, required this.passos});
  final String titulo;
  final List<String> passos;

  @override
  Widget build(BuildContext context) {
    if (passos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < passos.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 17,
                  height: 17,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    passos[i],
                    style: const TextStyle(fontSize: 12, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Integridade extends StatelessWidget {
  const _Integridade({required this.integridade});
  final IntegridadeDados integridade;

  @override
  Widget build(BuildContext context) {
    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const McTitulo(
            titulo: 'Integridade dos dados',
            sub:
                'O que foi encontrado na entrada, antes de olhar qualquer '
                'número medido',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final a in integridade.achados) _Achado(achado: a),
        ],
      ),
    );
  }
}

class _Achado extends StatelessWidget {
  const _Achado({required this.achado});
  final AchadoIntegridade achado;

  @override
  Widget build(BuildContext context) {
    final cor = achado.bloqueia ? AppColors.danger : AppColors.warning;
    // A barra colorida da esquerda é um filho, não uma borda: o Flutter proíbe
    // `borderRadius` sobre borda de cores não uniformes.
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: cor.withValues(alpha: 0.22)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: cor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            achado.titulo,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              height: 1.3,
                              color: cor,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        McSelo(
                          texto: achado.bloqueia ? 'Bloqueia' : 'Atenção',
                          cor: cor,
                          icone: achado.bloqueia
                              ? Icons.block
                              : Icons.warning_amber_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      achado.detalhe,
                      style: const TextStyle(fontSize: 12, height: 1.45),
                    ),
                    if (achado.acao.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.arrow_forward,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              achado.acao,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.calibracao});
  final CalibracaoResultado calibracao;

  @override
  Widget build(BuildContext context) {
    final c = calibracao;
    final semDados = c.diasAnalisados == 0;
    final phiSuspeito = c.phi < 0.7 && c.diasAnalisados >= 10;

    return McGradeKpis(
      cartoes: [
        McKpi(
          rotulo: 'Dias analisados',
          valor: McNum.inteiro(c.diasAnalisados),
          sufixo: '/ 120',
          icone: Icons.calendar_month_outlined,
          cor: c.diasAnalisados >= 120 ? AppColors.success : AppColors.warning,
          indisponivel: semDados,
          dica: 'A fase F2 pede 120 dias de histórico com desfecho registrado.',
        ),
        McKpi(
          rotulo: 'Consultas com desfecho',
          valor: McNum.inteiro(c.consultasAnalisadas),
          icone: Icons.fact_check_outlined,
          cor: AppColors.secondary,
          indisponivel: semDados,
          dica:
              'Realizadas, faltas e cancelamentos. Pendentes e confirmadas '
              'no passado ficam de fora — ninguém deu baixa nelas.',
        ),
        McKpi(
          rotulo: 'Sobredispersão φ',
          valor: McNum.dec(c.phi),
          icone: Icons.blur_on,
          cor: phiSuspeito
              ? AppColors.warning
              : (c.phi > 1.3 ? AppColors.pinkAccent : AppColors.textSecondary),
          indisponivel: semDados,
          dica:
              '1,00 significa faltas independentes. Acima disso elas se movem '
              'juntas; abaixo é sinal de dado preenchido em lote.',
        ),
        McKpi(
          rotulo: 'ρ estimado',
          valor: McNum.dec(c.rhoEstimado, casas: 3),
          icone: Icons.link_outlined,
          cor: c.rhoEstimado > 0 ? AppColors.warning : AppColors.textSecondary,
          indisponivel: semDados,
          dica:
              'Correlação latente implícita em φ. Alimenta a simulação da '
              'aba Decisão.',
        ),
        McKpi(
          rotulo: 'Cobertura P05–P95',
          valor: c.backtest.temAmostras
              ? McNum.pct(c.backtest.cobertura90, casas: 0)
              : '—',
          icone: Icons.verified_outlined,
          cor: c.backtest.coberturaAceitavel
              ? AppColors.success
              : AppColors.danger,
          indisponivel: !c.backtest.temAmostras,
          dica:
              'Fração dos dias em que o observado caiu dentro do intervalo '
              'previsto. Deveria ficar perto de 90%.',
        ),
      ],
    );
  }
}

class _Janela extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final janela = ref.watch(mcJanelaCalibracaoProvider);
    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McDeslizante(
            rotulo: 'Janela de histórico',
            valor: janela.toDouble(),
            min: 30,
            max: 365,
            texto: '${McNum.inteiro(janela)} dias',
            ajuda:
                'Janela curta acompanha melhor a sazonalidade; janela longa '
                'dá amostra maior. φ muda ao longo do ano — chuva, férias e '
                'ondas respiratórias mudam o quanto as faltas se movem juntas.',
            onChanged: (v) =>
                ref.read(mcJanelaCalibracaoProvider.notifier).state = v.round(),
          ),
          const McAviso(
            icone: Icons.filter_alt_outlined,
            texto:
                'Este controle filtra o histórico que a agenda já carregou '
                '— não busca mais dado no banco. Se os dias analisados não '
                'sobem ao aumentar a janela, é porque a agenda não tem mais.',
          ),
        ],
      ),
    );
  }
}

class _TabelaTaxas extends StatelessWidget {
  const _TabelaTaxas({required this.calibracao});
  final CalibracaoResultado calibracao;

  @override
  Widget build(BuildContext context) {
    final comDado = calibracao.taxas.values.where((t) => t.total > 0).toList();

    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const McTitulo(
            titulo: 'Taxas observadas por faixa de risco',
            sub:
                'Intervalo de Wilson 95% — uma taxa medida em poucas '
                'consultas não vale o mesmo que uma medida em muitas',
          ),
          const SizedBox(height: AppSpacing.md),
          if (comDado.isEmpty)
            const _Vazio(
              icone: Icons.inbox_outlined,
              texto: 'Nenhuma consulta com desfecho na janela.',
            )
          else
            McTabela(
              child: DataTable(
                columnSpacing: 24,
                headingRowHeight: 38,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 48,
                headingTextStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
                columns: const [
                  DataColumn(label: Text('Faixa')),
                  DataColumn(label: Text('Consultas'), numeric: true),
                  DataColumn(label: Text('Faltas'), numeric: true),
                  DataColumn(label: Text('Taxa medida'), numeric: true),
                  DataColumn(label: Text('IC 95%')),
                  DataColumn(label: Text('Cancelam.'), numeric: true),
                  DataColumn(label: Text('Amostra')),
                ],
                rows: [
                  for (final f in RiskLevel.values)
                    if (calibracao.taxas[f] != null)
                      _linha(calibracao.taxas[f]!),
                ],
              ),
            ),
          if (comDado.length == 1) ...[
            const SizedBox(height: AppSpacing.sm),
            const McAviso(
              icone: Icons.layers_clear_outlined,
              cor: AppColors.danger,
              texto:
                  'Só uma faixa tem dado. O modelo atribui probabilidades '
                  'diferentes por faixa, então com uma faixa só todos os '
                  'pacientes ficam com o mesmo risco — a estratificação não '
                  'está chegando do banco.',
            ),
          ],
        ],
      ),
    );
  }

  DataRow _linha(TaxaObservada t) {
    final (lo, hi) = t.ic95Falta;
    final vazia = t.total == 0;
    final estilo = TextStyle(
      fontSize: 12.5,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: vazia ? AppColors.textTertiary : null,
    );

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: vazia ? AppColors.textTertiary : t.risco.color,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                t.risco.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: vazia ? AppColors.textTertiary : t.risco.color,
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(McNum.inteiro(t.total), style: estilo)),
        DataCell(Text(vazia ? '—' : McNum.inteiro(t.faltas), style: estilo)),
        DataCell(
          Text(
            vazia ? '—' : McNum.pct(t.taxaFalta),
            style: estilo.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        DataCell(
          Text(
            vazia
                ? '—'
                : '${McNum.pct(lo, casas: 1)} – ${McNum.pct(hi, casas: 1)}',
            style: estilo.copyWith(fontSize: 11),
          ),
        ),
        DataCell(
          Text(vazia ? '—' : McNum.pct(t.taxaCancelamento), style: estilo),
        ),
        DataCell(
          McSelo(
            texto: vazia
                ? 'Sem dado'
                : (t.confiavel ? 'Suficiente' : 'Pequena'),
            cor: vazia
                ? AppColors.textTertiary
                : (t.confiavel ? AppColors.success : AppColors.warning),
          ),
        ),
      ],
    );
  }
}

class _Backtest extends StatelessWidget {
  const _Backtest({required this.calibracao});
  final CalibracaoResultado calibracao;

  @override
  Widget build(BuildContext context) {
    final b = calibracao.backtest;

    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const McTitulo(
            titulo: 'Backtest fora da amostra',
            sub:
                'Métricas distribucionais — erro médio não serve para julgar '
                'uma previsão que é uma distribuição inteira',
          ),
          const SizedBox(height: AppSpacing.md),
          if (!b.temAmostras)
            const _Vazio(
              icone: Icons.science_outlined,
              texto:
                  'Sem dias suficientes na janela de validação. Sem '
                  'backtest não há como afirmar que o intervalo previsto é '
                  'honesto.',
            )
          else ...[
            _linha(
              'Dias avaliados',
              McNum.inteiro(b.amostras),
              'Cada dia da janela de validação, previsto com o modelo calibrado.',
            ),
            _linha(
              'Cobertura P05–P95',
              McNum.pct(b.cobertura90, casas: 0),
              'Deveria ficar perto de 90%. Muito abaixo significa intervalo '
                  'estreito demais — é assim que o modelo independente falha.',
              destaque: true,
              ok: b.coberturaAceitavel,
            ),
            _linha(
              'CRPS médio',
              McNum.dec(b.crpsMedio, casas: 3),
              'Qualidade da distribuição inteira. Menor é melhor.',
            ),
            _linha(
              'Pinball P50',
              McNum.dec(b.pinballP50, casas: 3),
              'Perda no quantil central.',
            ),
            _linha(
              'Pinball P95',
              McNum.dec(b.pinballP95, casas: 3),
              'Perda na cauda — o número que decide overbooking.',
            ),
            _linha(
              'ECE',
              McNum.dec(b.ece, casas: 3),
              'Desvio de calibração dos PIT. Zero é calibrado.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _linha(
    String rotulo,
    String valor,
    String ajuda, {
    bool destaque = false,
    bool ok = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                rotulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            if (destaque)
              McSelo(
                texto: valor,
                cor: ok ? AppColors.success : AppColors.danger,
              )
            else
              Text(
                valor,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          ajuda,
          style: const TextStyle(
            fontSize: 11,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

/// Aviso de que a calibração roda sobre histórico sintético.
class _BannerDemo extends StatelessWidget {
  const _BannerDemo();

  @override
  Widget build(BuildContext context) => McCartao(
        cor: AppColors.primary.withValues(alpha: 0.05),
        borda: AppColors.primary.withValues(alpha: 0.30),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.biotech_outlined, color: AppColors.primary, size: 19),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Histórico sintético (modo demonstração)',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: AppColors.primary)),
                  SizedBox(height: 3),
                  Text(
                    'Sem Firebase ativo a agenda não tem histórico — e sem '
                    'histórico esta aba só saberia dizer "dados insuficientes". '
                    'Os números abaixo vêm de uma base gerada com taxas, '
                    'correlação e sazonalidade conhecidas, para que o estimador '
                    'possa ser conferido. Nenhum deles descreve uma clínica real.',
                    style: TextStyle(fontSize: 12, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Sobredispersão mês a mês.
class _Sazonalidade extends StatelessWidget {
  const _Sazonalidade({required this.calibracao});
  final CalibracaoResultado calibracao;

  @override
  Widget build(BuildContext context) {
    final meses = calibracao.porMes.where((m) => m.dias >= 3).toList();
    if (meses.isEmpty) return const SizedBox.shrink();

    var maxPhi = 1.0;
    for (final m in meses) {
      if (m.phi > maxPhi) maxPhi = m.phi;
    }

    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McTitulo(
            acao: const McExplicarIcone(acaoId: 'grafico_sazonalidade'),
            titulo: 'Sobredispersão ao longo do ano',
            sub: !calibracao.sazonalidadeTestavel
                ? 'Só ${calibracao.mesesTestaveis} mês(es) com dias '
                    'suficientes — não dá para testar sazonalidade ainda '
                    '(precisa de 4). As barras abaixo são descritivas.'
                : (calibracao.sazonalidadeSignificativa
                    ? 'A variação excede o que o ruído explicaria — um ρ único '
                        'congelado erra nos dois extremos'
                    : 'Testado: a variação observada cabe dentro do ruído de '
                        'amostragem'),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final m in meses) _linha(m, maxPhi),
          const SizedBox(height: AppSpacing.xs),
          const McAviso(
            icone: Icons.straighten,
            texto: 'A marca vertical em 1,00 é a independência. Barra além dela '
                'indica faltas que se movem juntas naquele mês. Cada mês traz '
                'poucos dias, então a barra isolada é ruidosa — o que importa '
                'é o padrão.',
          ),
        ],
      ),
    );
  }

  Widget _linha(DispersaoMensal m, double maxPhi) {
    final acima = m.phi > 1.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(m.nome,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (m.phi / maxPhi).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor:
                        AppColors.textTertiary.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation(
                        acima ? AppColors.pinkAccent : AppColors.secondary),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (1.0 / maxPhi).clamp(0.0, 1.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 1.5,
                      height: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 42,
            child: Text(McNum.dec(m.phi),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
          SizedBox(
            width: 42,
            child: Text('${m.dias}d',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.icone, required this.texto});
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      vertical: AppSpacing.xl,
      horizontal: AppSpacing.lg,
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.30)),
    ),
    child: Column(
      children: [
        Icon(icone, size: 26, color: AppColors.textTertiary),
        const SizedBox(height: AppSpacing.sm),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _Avisos extends StatelessWidget {
  const _Avisos({required this.avisos});
  final List<String> avisos;

  @override
  Widget build(BuildContext context) {
    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const McTitulo(
            titulo: 'Limitações dos dados',
            sub: 'Não impedem calibrar, mas mudam como ler os números',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final a in avisos) McAviso(texto: a),
        ],
      ),
    );
  }
}

class _Aplicar extends ConsumerWidget {
  const _Aplicar({required this.calibracao});
  final CalibracaoResultado calibracao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = calibracao;
    final pode = c.podeAplicar;
    final m = c.modeloCalibrado;

    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const McTitulo(
            titulo: 'Aplicar à simulação',
            sub: 'A calibração propõe; a decisão de adotar é sua',
          ),
          const SizedBox(height: AppSpacing.md),
          _Preview(
            taxas: [
              ('Baixo', m.pBaixo, RiskLevel.low.color),
              ('Médio', m.pMedio, RiskLevel.medium.color),
              ('Alto', m.pAlto, RiskLevel.high.color),
            ],
            rho: c.rhoEstimado,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              FilledButton.icon(
                onPressed: pode
                    ? () {
                        aplicarCalibracao(ref, c);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                'Parâmetros calibrados aplicados '
                                'à aba Decisão.',
                              ),
                            ),
                          );
                      }
                    : null,
                icon: const Icon(Icons.download_done_outlined, size: 18),
                label: const Text('Aplicar parâmetros medidos'),
              ),
              const SizedBox(width: AppSpacing.md),
              if (!pode)
                Expanded(
                  child: Text(
                    c.integridade.temBloqueio
                        ? 'Desabilitado enquanto houver problema bloqueante '
                              'na integridade dos dados.'
                        : 'Desabilitado: menos de 30 dias de histórico com '
                              'desfecho registrado.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Prévia do que será aplicado — barras comparáveis, não só três números.
class _Preview extends StatelessWidget {
  const _Preview({required this.taxas, required this.rho});

  final List<(String, double, Color)> taxas;
  final double rho;

  @override
  Widget build(BuildContext context) {
    final maior = taxas.fold(0.0, (m, t) => t.$2 > m ? t.$2 : m);
    final escala = maior <= 0 ? 1.0 : maior;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in taxas)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text(
                    t.$1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (t.$2 / escala).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: t.$3.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(t.$3),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 52,
                  child: Text(
                    McNum.pct(t.$2),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Text(
              'Correlação ρ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AppSpacing.sm),
            McSelo(texto: McNum.dec(rho, casas: 3), cor: AppColors.primary),
          ],
        ),
      ],
    );
  }
}
