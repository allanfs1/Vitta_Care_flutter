import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/textos.dart';
import '../evidencias_providers.dart';
import '../ia/tradutor.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../evidencias_screen.dart' show abrirUrl, copiar;
import '../nivel_evidencia.dart';
import '../pubmed_models.dart';
import 'formatos_citacao.dart';

/// Card de um artigo do PubMed.
///
/// A hierarquia visual segue o que o médico usa para triar em segundos:
/// **desenho do estudo** e **ano** primeiro (uma metanálise de 2025 pesa
/// diferente de um relato de caso de 2003), depois título, depois autoria e
/// periódico. O resumo só carrega quando expandido — o EFetch de 20 artigos
/// traz centenas de KB que quase ninguém lê inteiros, e cada chamada consome
/// cota do NCBI.
class ArtigoCard extends ConsumerStatefulWidget {
  const ArtigoCard({
    super.key,
    required this.artigo,
    required this.onExpandir,
    this.secoes,
    this.carregandoAbstract = false,
    this.destaque = false,
    this.indice,
  });

  final ArtigoPubmed artigo;
  final VoidCallback onExpandir;
  final List<SecaoResumo>? secoes;
  final bool carregandoAbstract;

  /// Marca o artigo como citado pela síntese do agente — assim o médico liga a
  /// afirmação que leu à fonte, sem procurar o PMID na lista.
  final bool destaque;
  final int? indice;

  @override
  ConsumerState<ArtigoCard> createState() => _ArtigoCardState();
}

class _ArtigoCardState extends ConsumerState<ArtigoCard> {
  /// `true` = mostrando o original mesmo havendo tradução.
  bool _verOriginal = false;
  bool _aberto = false;

  void _alternar() {
    setState(() => _aberto = !_aberto);
    if (_aberto && widget.secoes == null) widget.onExpandir();
  }

  /// Tradução em uso, ou `null` quando não há / o usuário pediu o original.
  ArtigoTraduzido? get _traducao {
    if (_verOriginal) return null;
    final t = ref.watch(traducoesProvider)[widget.artigo.pmid];
    return (t != null && t.traduzido) ? t : null;
  }

  String _tituloExibido(ArtigoPubmed a) {
    final t = _traducao;
    if (t != null) return t.titulo;
    return a.titulo.isEmpty ? context.txt.t('evid.art.semTitulo') : a.titulo;
  }

  /// O resumo mostrado. A tradução só substitui o texto **na tela** — a
  /// citação, o export e a validação de PMID seguem usando o original.
  List<SecaoResumo>? _secoesExibidas(ArtigoPubmed a) {
    final t = _traducao;
    if (t != null && t.secoes.isNotEmpty) return t.secoes;
    return widget.secoes;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.artigo;

    final nivel = NivelEvidencia.de(a.desenhoEstudo);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          // Barra lateral colorida pelo nível de evidência. É o que permite
          // varrer 20 resultados sem ler nenhum: a cor responde "vale parar
          // aqui?" antes do título.
          border: Border(left: BorderSide(color: nivel.cor(theme), width: 3.5)),
        ),
        child: DecoratedBox(
          decoration: widget.destaque
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                )
              : const BoxDecoration(),
          child: AppCard(
            onTap: _alternar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Cabecalho(
                  artigo: a,
                  aberto: _aberto,
                  destaque: widget.destaque,
                  indice: widget.indice,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _tituloExibido(a),
                  style: theme.textTheme.titleSmall?.copyWith(height: 1.35),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  a.autoresCurto,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (a.periodico.isNotEmpty)
                  Text(
                    a.dataPublicacao.isEmpty
                        ? a.periodico
                        : '${a.periodico} · ${a.dataPublicacao}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (_aberto) ...[
                  const Divider(height: AppSpacing.xl),
                  _BarraTraducao(
                    artigo: a,
                    verOriginal: _verOriginal,
                    onAlternar: () =>
                        setState(() => _verOriginal = !_verOriginal),
                  ),
                  _Resumo(
                    secoes: _secoesExibidas(a),
                    carregando: widget.carregandoAbstract,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Identificadores(artigo: a),
                  const SizedBox(height: AppSpacing.xs),
                  _Acoes(artigo: a),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.artigo,
    required this.aberto,
    required this.destaque,
    this.indice,
  });

  final ArtigoPubmed artigo;
  final bool aberto;
  final bool destaque;
  final int? indice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (indice != null) ...[
          Text(
            '$indice.',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (artigo.desenhoEstudo != null)
          Flexible(
            child: SeloDesenho(
              desenho: artigo.desenhoEstudo!,
              forte: desenhoForte(artigo.desenhoEstudo!),
            ),
          ),
        if (artigo.ano != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text('${artigo.ano}', style: theme.textTheme.labelLarge),
        ],
        const Spacer(),
        if (destaque)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Tooltip(
              message: context.txt.t('evid.art.citadoNaSintese'),
              child: Icon(
                Icons.format_quote,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        Icon(
          aberto ? Icons.expand_less : Icons.expand_more,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// Desenhos que a medicina baseada em evidência trata como topo da pirâmide.
bool desenhoForte(String t) => const {
  'Meta-Analysis',
  'Systematic Review',
  'Randomized Controlled Trial',
}.contains(t);

String rotuloDesenho(String t) => switch (t) {
  'Meta-Analysis' => 'Metanálise',
  'Systematic Review' => 'Revisão sistemática',
  'Randomized Controlled Trial' => 'Ensaio randomizado',
  'Clinical Trial' => 'Ensaio clínico',
  'Clinical Trial, Phase III' => 'Ensaio clínico fase III',
  'Observational Study' => 'Estudo observacional',
  'Multicenter Study' => 'Estudo multicêntrico',
  'Guideline' || 'Practice Guideline' => 'Diretriz',
  'Review' => 'Revisão',
  'Case Reports' => 'Relato de caso',
  'Comparative Study' => 'Estudo comparativo',
  'Journal Article' => 'Artigo',
  _ => t,
};

class SeloDesenho extends StatelessWidget {
  const SeloDesenho({super.key, required this.desenho, this.forte = false});
  final String desenho;
  final bool forte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = forte
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        rotuloDesenho(desenho),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: cor,
          fontWeight: forte ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

/// Resumo, preservando as seções rotuladas quando o artigo é estruturado.
class _Resumo extends StatelessWidget {
  const _Resumo({required this.secoes, required this.carregando});
  final List<SecaoResumo>? secoes;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (carregando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (secoes == null) {
      return Text(context.txt.t('evid.art.carregandoResumo'),
          style: theme.textTheme.bodySmall);
    }

    if (secoes!.isEmpty) {
      // Distinguir "não tem resumo" de "não carregou" importa: o médico precisa
      // saber que a ausência é do registro, não da rede.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.txt.t('evid.art.semResumo'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in secoes!) ...[
          if (s.temRotulo)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                s.rotuloPt.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: SelectableText(
              s.texto,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _Identificadores extends StatelessWidget {
  const _Identificadores({required this.artigo});
  final ArtigoPubmed artigo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estilo = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        SelectableText('PMID: ${artigo.pmid}', style: estilo),
        if (artigo.doi != null)
          SelectableText('DOI: ${artigo.doi}', style: estilo),
        if (artigo.pmcid != null)
          SelectableText('PMC: ${artigo.pmcid}', style: estilo),
      ],
    );
  }
}

class _Acoes extends StatelessWidget {
  const _Acoes({required this.artigo});
  final ArtigoPubmed artigo;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('PubMed'),
          onPressed: () => abrirUrl(context, artigo.url),
        ),
        if (artigo.urlPmc != null)
          TextButton.icon(
            icon: const Icon(Icons.article_outlined, size: 16),
            label: Text(context.txt.t('evid.art.textoCompleto')),
            onPressed: () => abrirUrl(context, artigo.urlPmc!),
          ),
        // A citação tem menu porque o formato depende de para onde vai: revista
        // pede Vancouver, trabalho acadêmico brasileiro pede ABNT, gerenciador
        // de referências pede BibTeX ou RIS.
        PopupMenuButton<FormatoCitacao>(
          tooltip: context.txt.t('evid.art.copiarCitacao'),
          onSelected: (f) => copiar(
            context,
            formatarCitacao(artigo, f),
            'Citação (${f.rotulo})',
          ),
          itemBuilder: (_) => [
            for (final f in FormatoCitacao.values)
              PopupMenuItem(value: f, child: Text(f.rotulo)),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.format_quote, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(context.txt.t('evid.art.citar')),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra de tradução do resumo.
///
/// ## O original nunca some
///
/// A tradução é uma **camada** sobre o artigo, não uma substituição. Termo
/// clínico traduzido automaticamente erra de formas que importam — "outcome",
/// "positive predictive value", e sobretudo o hedging ("may reduce" ≠
/// "reduces"). Quem decide uma conduta precisa poder ver a frase original sem
/// sair da tela, e por isso o botão de alternar fica ao lado do texto, não
/// escondido num menu.
///
/// A citação, o export e a validação de PMID continuam usando o original —
/// a tradução não toca em nada disso.
class _BarraTraducao extends ConsumerWidget {
  const _BarraTraducao({
    required this.artigo,
    required this.verOriginal,
    required this.onAlternar,
  });

  final ArtigoPubmed artigo;
  final bool verOriginal;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.txt;
    final theme = Theme.of(context);
    final notifier = ref.read(traducoesProvider.notifier);
    final traducoes = ref.watch(traducoesProvider);

    // Em inglês não há o que traduzir: o conteúdo do PubMed já é inglês.
    if (!notifier.disponivel) return const SizedBox.shrink();

    final traduzindo = notifier.traduzindo(artigo.pmid);
    final atual = traducoes[artigo.pmid];

    Widget linha(Widget filho) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: filho,
        );

    if (traduzindo) {
      return linha(Row(
        children: [
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(t.t('evid.trad.traduzindo'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ));
    }

    // Falhou: o artigo continua utilizável, e a tela diz o que houve.
    if (atual != null && atual.falha) {
      return linha(Row(
        children: [
          Icon(Icons.translate,
              size: 14, color: theme.colorScheme.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(t.t('evid.trad.falhou'),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ),
        ],
      ));
    }

    if (atual != null && atual.traduzido) {
      return linha(Row(
        children: [
          Icon(Icons.translate, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              verOriginal ? '' : t.t('evid.trad.porIA'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: onAlternar,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(verOriginal
                ? t.t('evid.trad.traduzir')
                : t.t('evid.trad.verOriginal')),
          ),
        ],
      ));
    }

    return linha(Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => notifier.traduzir(artigo),
        icon: const Icon(Icons.translate, size: 16),
        label: Text(t.t('evid.trad.traduzir')),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
    ));
  }
}
