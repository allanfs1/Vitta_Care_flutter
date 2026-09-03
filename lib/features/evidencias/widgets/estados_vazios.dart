import 'package:flutter/material.dart';

import '../../../core/i18n/textos.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_states.dart';
import '../evidencias_providers.dart';
import '../filtros_busca.dart';
import '../pubmed_models.dart';
import '../sessoes/sessao_store.dart';

/// Estados sem resultado — a maior parte do tempo que alguém passa numa tela de
/// busca é justamente aqui, então eles ensinam em vez de só informar.

/// Tela inicial: explica o modo ativo e oferece exemplos que funcionam.
class IntroEvidencias extends StatelessWidget {
  const IntroEvidencias({
    super.key,
    required this.modo,
    required this.onExemplo,
    this.historico = const [],
  });

  final ModoPesquisa modo;
  final void Function([String?]) onExemplo;
  final List<ItemHistorico> historico;

  static const _exemplosBusca = [
    'SGLT2 inhibitor[tiab] AND heart failure[tiab]',
    'metformin[tiab] AND elderly[tiab]',
    'hypertension[mesh] AND treatment adherence',
  ];

  static const _exemplosAgente = [
    'Em idosos com diabetes tipo 2, metformina reduz eventos cardiovasculares?',
    'Qual a evidência para uso de estatina em prevenção primária após os 75 anos?',
    'Anticoagulação em fibrilação atrial com doença renal crônica: o que há?',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.txt;
    final agente = modo == ModoPesquisa.agente;
    final exemplos = agente ? _exemplosAgente : _exemplosBusca;

    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Icon(
                agente ? Icons.auto_awesome : Icons.menu_book_outlined,
                size: 44,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                t.t(agente
                    ? 'evid.intro.perguntar.titulo'
                    : 'evid.intro.buscar.titulo'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                t.t(agente
                    ? 'evid.intro.perguntar.texto'
                    : 'evid.intro.buscar.texto'),
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (historico.isNotEmpty) ...[
                Text(t.t('evid.intro.continuar'),
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final h in historico.take(4))
                      ActionChip(
                        avatar: const Icon(Icons.history, size: 15),
                        label: Text(
                          h.termo.length > 48
                              ? '${h.termo.substring(0, 48)}…'
                              : h.termo,
                        ),
                        onPressed: () => onExemplo(h.termo),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              Text(
                  t.t(agente
                      ? 'evid.intro.exemplos.pergunta'
                      : 'evid.intro.exemplos.busca'),
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final e in exemplos)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: InkWell(
                    onTap: () => onExemplo(e),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Icon(agente ? Icons.help_outline : Icons.search,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(e,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontFamily: agente ? null : 'monospace',
                                )),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              const AvisoDadoPessoal(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso de LGPD. Fixo na tela inicial porque é onde alguém tentaria colar
/// dados do paciente — depois de bloqueado já é tarde para ensinar.
class AvisoDadoPessoal extends StatelessWidget {
  const AvisoDadoPessoal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              context.txt.t('evid.lgpd'),
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Esqueleto de carregamento.
///
/// Preferido a um spinner: mostra a forma do que vem, o que faz a espera
/// parecer menor e evita o salto de layout quando os cards chegam.
class EsqueletoResultados extends StatelessWidget {
  const EsqueletoResultados({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.pageInsets,
      children: [
        for (var i = 0; i < 5; i++)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 120, height: 16),
                      SizedBox(height: AppSpacing.md),
                      SkeletonBox(width: double.infinity, height: 18),
                      SizedBox(height: AppSpacing.sm),
                      SkeletonBox(width: 260, height: 14),
                      SizedBox(height: AppSpacing.xs),
                      SkeletonBox(width: 180, height: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cabeçalho do resultado, com o painel "Como pesquisamos".
class ResumoBusca extends StatelessWidget {
  const ResumoBusca({super.key, required this.resultado, required this.filtros});
  final ResultadoBusca resultado;
  final FiltrosBusca filtros;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${context.txt.plural(resultado.total, 'evid.res.um', 'evid.res.muitos')}'
                ' · ${context.txt.t2('evid.res.exibindo', {'n': '${resultado.artigos.length}'})}',
                style: theme.textTheme.titleSmall,
              ),
              if (filtros.quantidadeAtiva > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final r in filtros.resumo)
                      Chip(
                        label: Text(r),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
              if (resultado.queryTraduzida.isNotEmpty)
                ComoPesquisamos(resultado: resultado),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Como pesquisamos" — a consulta que o PubMed realmente executou.
///
/// Não é enfeite: `querytranslation` é o que o PubMed pesquisou depois de
/// expandir sinônimos e MeSH. Sem isso o médico não tem como entender por que
/// um artigo esperado não apareceu, e a busca vira caixa-preta.
class ComoPesquisamos extends StatelessWidget {
  const ComoPesquisamos({super.key, required this.resultado});
  final ResultadoBusca resultado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        dense: true,
        leading: const Icon(Icons.travel_explore, size: 20),
        title: Text(context.txt.t('evid.como.titulo'),
            style: theme.textTheme.bodyMedium),
        children: [
          _Linha(
              rotulo: context.txt.t('evid.como.enviada'),
              valor: resultado.queryEnviada),
          _Linha(
              rotulo: context.txt.t('evid.como.interpretada'),
              valor: resultado.queryTraduzida),
          if (resultado.buscadoEm != null)
            _Linha(
              rotulo: context.txt.t('evid.como.executada'),
              valor: _data(resultado.buscadoEm!),
            ),
          _Linha(
            rotulo: context.txt.t('evid.como.origem'),
            valor: context.txt.t(resultado.viaProxy
                ? 'evid.como.origem.proxy'
                : 'evid.como.origem.direto'),
          ),
          if (resultado.doCache)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                context.txt.t('evid.como.cache'),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  static String _data(DateTime d) {
    final l = d.toLocal();
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(l.day)}/${dd(l.month)}/${l.year} ${dd(l.hour)}:${dd(l.minute)}';
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.rotulo, required this.valor});
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text('$rotulo:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(
            child: SelectableText(
              valor,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RodapeResultados extends StatelessWidget {
  const RodapeResultados(
      {super.key, required this.resultado, required this.carregando});
  final ResultadoBusca resultado;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!resultado.temMais) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Text(
            context.txt.t('evid.res.fim'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.xxl);
  }
}

/// Busca sem resultado — o estado que mais precisa ensinar.
class SemResultado extends StatelessWidget {
  const SemResultado({
    super.key,
    required this.termo,
    required this.sugestao,
    required this.queryTraduzida,
    required this.filtrosAtivos,
    required this.onUsarSugestao,
    required this.onLimparFiltros,
  });

  final String termo;
  final String? sugestao;
  final String queryTraduzida;
  final int filtrosAtivos;
  final void Function([String?]) onUsarSugestao;
  final VoidCallback onLimparFiltros;

  static const _dicas = [
    'Escreva em inglês — é o idioma da indexação do PubMed.',
    'Remova filtros de data ou amplie a janela.',
    'Use termos mais gerais (ex.: "diabetes" em vez de um fármaco específico).',
    'Troque [Title] por [tiab] para buscar também no resumo.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(context.txt.t('evid.res.vazio.titulo'),
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(context.txt.t2('evid.res.vazio.para', {'termo': termo}),
                  style: theme.textTheme.bodyMedium),

              // Filtro ativo é a causa mais comum e a mais fácil de esquecer —
              // por isso vem antes de qualquer dica de vocabulário.
              if (filtrosAtivos > 0) ...[
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 20),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          context.txt.t2('evid.res.vazio.filtros',
                              {'n': '$filtrosAtivos'}),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: onLimparFiltros,
                        child: Text(context.txt.t('comum.limpar')),
                      ),
                    ],
                  ),
                ),
              ],

              if (sugestao != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.txt.t('evid.res.vazio.sugestao'),
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      ActionChip(
                        avatar: const Icon(Icons.auto_fix_high, size: 16),
                        label: Text(sugestao!),
                        onPressed: () => onUsarSugestao(sugestao),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              Text(context.txt.t('evid.res.vazio.tentar'),
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final d in _dicas)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(
                          child: Text(d, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              if (queryTraduzida.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(context.txt.t('evid.res.interpretou'),
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  queryTraduzida,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Erro — com tratamento especial para o bloqueio de dado pessoal.
class ErroEvidencias extends StatelessWidget {
  const ErroEvidencias({super.key, required this.erro, this.onTentarNovamente});
  final EvidenciaErro erro;
  final VoidCallback? onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dado pessoal bloqueado não é falha do sistema — é a guarda funcionando.
    // Merece um texto que ensina o que fazer, não um ícone de erro vermelho.
    if (erro.bloqueadoPorDadoPessoal) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          // Rolável: o texto que ensina é longo de propósito, e em tela baixa
          // ele não cabe centralizado. Cortar a explicação seria pior que
          // rolar.
          child: SingleChildScrollView(
            padding: AppSpacing.pageInsets,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.lg),
                Text(context.txt.t('evid.phi.titulo'),
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                Text(
                  erro.mensagem,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                const AvisoDadoPessoal(),
              ],
            ),
          ),
        ),
      );
    }

    return ErrorView(message: erro.mensagem, onRetry: onTentarNovamente);
  }
}

/// Ajuda de sintaxe.
void mostrarAjudaBusca(BuildContext context) {
  const campos = {
    '[tiab]': 'Busca no título e no resumo. Bom equilíbrio entre precisão e alcance.',
    '[title]': 'Só no título. Mais preciso, traz menos.',
    '[mesh]': 'Descritor MeSH — o vocabulário controlado do PubMed.',
    '[ptyp]': 'Tipo de publicação. Ex.: "Meta-Analysis"[ptyp].',
    '[pdat]': 'Data de publicação. Ex.: 2022:2026[pdat].',
    '[au]': 'Autor. Ex.: McMurray JJV[au].',
    'AND / OR': 'Combina conceitos. NOT exclui.',
    'Aspas': 'Busca a expressão exata: "heart failure".',
  };

  showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: const Text('Como escrever a busca'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A busca aceita a sintaxe do PubMed. Escreva em inglês — é o '
                'idioma da indexação.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Se preferir escrever em português, use o modo "Perguntar à IA": '
                'ele traduz e monta a estratégia por você.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: AppSpacing.xl),
              for (final e in campos.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: SelectableText(
                          e.key,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                      Expanded(
                        child:
                            Text(e.value, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.txt.t('comum.entendi')),
          ),
        ],
      );
    },
  );
}
