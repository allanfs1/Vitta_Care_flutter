import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../ia/mc_ia_providers.dart';
import '../ia/plano_semanal.dart';
import 'mc_comuns.dart';

/// Planejador automático — a interface gráfica da IA do Simulador.
///
/// ## O processo que esta aba automatiza
///
/// Sem ela, o gestor abre o Simulador, escolhe uma data, lê a aba Decisão,
/// anota o número, avança um dia e repete — cinco a sete vezes por semana. A
/// aba faz a varredura inteira de uma vez e entrega o que sobrava de trabalho
/// humano: **onde olhar primeiro e por quê**.
///
/// ## Como a tela deixa claro o que é cálculo e o que é opinião
///
/// A separação é visual, não só conceitual:
///
/// - **A faixa de dias e os KPIs** vêm da simulação. São determinísticos,
///   reprodutíveis, e aparecem assim que saem — antes de a IA responder.
/// - **O cartão de análise** é da IA, marcado como tal, e chega depois.
///
/// Se a IA falhar, some só o cartão. O plano continua na tela e continua
/// utilizável — porque o produto aqui são os números, não o texto.
///
/// ## Nada é aplicado sozinho
///
/// A aba sugere; encaixar é ação do gestor, em outro lugar. É a mesma regra do
/// Vigia (`.specify/VIGIA.md`): rotina de IA nasce como proposta.
class McPlanejadorTab extends ConsumerWidget {
  const McPlanejadorTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(planoSemanalProvider);
    final ctrl = ref.read(planoSemanalProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Controles(estado: estado, ctrl: ctrl),
        if (estado.rodando) ...[
          const SizedBox(height: AppSpacing.lg),
          _Progresso(estado: estado),
        ],
        if (estado.fase == FasePlano.erro) ...[
          const SizedBox(height: AppSpacing.lg),
          McAviso(
            texto: 'Não foi possível montar o plano: ${estado.erro}',
            cor: AppColors.danger,
            icone: Icons.error_outline,
          ),
        ],
        if (estado.temPlano) ...[
          const SizedBox(height: AppSpacing.lg),
          _Resumo(plano: estado.plano!),
          const SizedBox(height: AppSpacing.lg),
          _FaixaDias(plano: estado.plano!),
          const SizedBox(height: AppSpacing.lg),
          _Analise(estado: estado),
        ] else if (!estado.rodando && estado.fase != FasePlano.erro)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.lg),
            child: _Introducao(),
          ),
      ],
    );
  }
}

class _Introducao extends StatelessWidget {
  const _Introducao();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Planejar a semana de uma vez', style: t.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Roda a simulação para cada dia da janela e monta o plano de '
            'encaixes. Os números saem da mesma simulação da aba Decisão — a '
            'diferença é que aqui ela roda para a semana inteira, e a IA '
            'aponta onde olhar primeiro.',
            style: t.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          const McAviso(
            texto: 'O plano é uma sugestão. Nenhum encaixe é criado por aqui — '
                'quem aplica na agenda é você.',
            cor: AppColors.primary,
            icone: Icons.info_outline,
          ),
        ],
      ),
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({required this.estado, required this.ctrl});
  final EstadoPlano estado;
  final PlanoNotifier ctrl;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return McCartao(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          Text('Próximos', style: t.bodyMedium),
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 3, label: Text('3 dias')),
              ButtonSegment(value: 7, label: Text('7 dias')),
              ButtonSegment(value: 14, label: Text('14 dias')),
            ],
            selected: {estado.janelaDias},
            onSelectionChanged:
                estado.rodando ? null : (s) => ctrl.janela(s.first),
          ),
          FilledButton.icon(
            onPressed: estado.rodando ? null : () => ctrl.gerar(),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(estado.temPlano ? 'Refazer plano' : 'Montar plano'),
          ),
          if (estado.temPlano && !estado.rodando)
            TextButton(
              onPressed: ctrl.limpar,
              child: const Text('Limpar'),
            ),
        ],
      ),
    );
  }
}

/// Progresso da varredura.
///
/// Mostra o dia em que está, não uma barra indeterminada: a espera é de vários
/// segundos, e "3 de 7" diz quanto falta — uma barra girando não diz nada e
/// faz a tela parecer travada.
class _Progresso extends StatelessWidget {
  const _Progresso({required this.estado});
  final EstadoPlano estado;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final simulando = estado.fase == FasePlano.simulando;
    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  simulando
                      ? 'Simulando dia ${estado.diaAtual} de ${estado.diasTotal}…'
                      : 'Analisando o plano…',
                  style: t.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: LinearProgressIndicator(
              value: simulando ? estado.progresso : null,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.plano});
  final PlanoSemanal plano;

  @override
  Widget build(BuildContext context) {
    final atencao = plano.dias.where((d) => d.atencao.pedeAtencao).length;
    return McGradeKpis(
      cartoes: [
        McKpi(
          rotulo: 'Encaixes na janela',
          valor: '${plano.totalEncaixes}',
          icone: Icons.event_available,
          cor: AppColors.primary,
          dica: 'Soma do que cada dia comporta dentro do limite de risco.',
        ),
        McKpi(
          rotulo: 'Receita adicional',
          valor: McNum.reais(plano.receitaAdicional),
          icone: Icons.trending_up,
          cor: AppColors.success,
          dica: 'Encaixes × valor do slot. Estimativa, não garantia.',
        ),
        McKpi(
          rotulo: 'Dias com agenda',
          valor: '${plano.comAgenda.length}',
          icone: Icons.calendar_month,
          cor: AppColors.info,
        ),
        McKpi(
          rotulo: 'Pedem atenção',
          valor: '$atencao',
          icone: Icons.priority_high,
          cor: atencao > 0 ? AppColors.warning : AppColors.success,
          dica: 'Dias cheios ou com slot acima do limite de risco.',
        ),
      ],
    );
  }
}

/// A faixa de dias — o coração visual da aba.
///
/// Cada dia é um cartão com a cor do seu nível de atenção, o número de
/// encaixes em destaque e o motivo embaixo. Dá para varrer a semana inteira
/// sem ler: a cor responde "onde eu olho primeiro?".
class _FaixaDias extends StatelessWidget {
  const _FaixaDias({required this.plano});
  final PlanoSemanal plano;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const McTitulo(
          titulo: 'Plano por dia',
          sub: 'Cada dia foi simulado separadamente. A cor indica quanto ele '
              'pede atenção — não o risco em si.',
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, c) {
            // Em tela estreita a faixa rola na horizontal; em tela larga os
            // dias se distribuem. Um grid fixo espremeria "quinta-feira" a
            // ponto de virar "qui…" no celular.
            final largo = c.maxWidth >= 720;
            final cartoes = [
              for (final d in plano.dias) _CartaoDia(dia: d, largo: largo),
            ];
            if (largo) {
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: cartoes,
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in cartoes)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: c,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CartaoDia extends StatelessWidget {
  const _CartaoDia({required this.dia, required this.largo});
  final DiaPlanejado dia;
  final bool largo;

  static const _semana = [
    'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM',
  ];

  Color get _cor => switch (dia.atencao) {
        AtencaoDia.ok => AppColors.success,
        AtencaoDia.folga => AppColors.info,
        AtencaoDia.cheio => AppColors.warning,
        AtencaoDia.critico => AppColors.danger,
        AtencaoDia.semAgenda => AppColors.textSecondary,
        AtencaoDia.falha => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final vazio = !dia.temAgenda || !dia.ok;

    return SizedBox(
      width: largo ? 168 : 150,
      child: McCartao(
        borda: _cor.withValues(alpha: 0.5),
        cor: _cor.withValues(alpha: vazio ? 0.03 : 0.07),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _semana[dia.data.weekday - 1],
                  style: t.labelSmall?.copyWith(
                    color: _cor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '${dia.data.day.toString().padLeft(2, '0')}/'
                  '${dia.data.month.toString().padLeft(2, '0')}',
                  style: t.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (vazio)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  dia.atencao.rotulo,
                  style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('+${dia.encaixesRecomendados}',
                      style: t.headlineSmall?.copyWith(
                        color: _cor,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(width: AppSpacing.xs),
                  // Flexible + ellipsis: com escala de texto grande (o app
                  // permite até 1,6×) "encaixes" não cabe ao lado do número no
                  // cartão de 150px, e o Row estoura.
                  Flexible(
                    child: Text(
                      'encaixe${dia.encaixesRecomendados == 1 ? "" : "s"}',
                      style: t.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('${dia.totalAgendados} agendados', style: t.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              McSelo(
                texto: dia.atencao.curto,
                cor: _cor,
                icone: dia.atencao.pedeAtencao
                    ? Icons.priority_high
                    : Icons.check_circle_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// O cartão da IA.
///
/// Fica **abaixo** dos números, e marcado como leitura da IA. A ordem importa:
/// quem chega na aba vê primeiro o que a simulação calculou, e só depois a
/// interpretação. Inverter treinaria o gestor a ler a opinião como se fosse o
/// dado.
class _Analise extends StatelessWidget {
  const _Analise({required this.estado});
  final EstadoPlano estado;

  @override
  Widget build(BuildContext context) {
    final s = estado.sugestao;
    if (s == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    if (s.falhouIa) {
      return const McAviso(
        texto: 'A leitura por IA não está disponível agora. O plano acima '
            'continua válido — ele não depende da IA.',
        cor: AppColors.textSecondary,
        icone: Icons.cloud_off_outlined,
      );
    }
    if (!s.temAnalise) return const SizedBox.shrink();

    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap, não Row: o selo "Há número não conferido" é longo, e em
          // tela estreita ele e o título não cabem na mesma linha.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              const Icon(Icons.auto_awesome,
                  size: 20, color: AppColors.primary),
              Text('Leitura da IA', style: theme.textTheme.titleMedium),
              McSelo(
                texto: s.numerosConferem ? 'Conferido' : 'Não conferido',
                cor: s.numerosConferem ? AppColors.success : AppColors.danger,
                icone: s.numerosConferem
                    ? Icons.verified_outlined
                    : Icons.gpp_maybe,
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          MarkdownBody(
            data: s.analise,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              listBullet: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
          if (!s.numerosConferem) ...[
            const SizedBox(height: AppSpacing.md),
            McAviso(
              texto: const ValidadorAvisoTexto().paraSugestao(s),
              cor: AppColors.danger,
              icone: Icons.gpp_maybe,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const McAviso(
            texto: 'Texto gerado por IA a partir dos números acima. Cada cifra '
                'foi conferida contra a simulação. O plano é sugestão: nenhum '
                'encaixe foi criado.',
            cor: AppColors.textSecondary,
            icone: Icons.info_outline,
          ),
        ],
      ),
    );
  }
}

/// Formata o aviso de validação para a tela.
class ValidadorAvisoTexto {
  const ValidadorAvisoTexto();

  String paraSugestao(dynamic s) {
    final v = s.validacao;
    if (v == null) return '';
    final n = v.naoConferem.length;
    return n == 1
        ? 'O número ${v.naoConferem.first} não veio da simulação e está '
            'marcado com ⚠️ no texto. Confira antes de agir.'
        : '$n números não vieram da simulação e estão marcados com ⚠️ no '
            'texto. Confira antes de agir.';
  }
}
