import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../evidencias_providers.dart';
import '../ia/agente_evidencias.dart';
import '../ia/pico.dart';
import '../pubmed_models.dart';
import 'artigo_card.dart';

/// Painel do modo agente.
///
/// ## O agente mostra o trabalho, não só o resultado
///
/// Cada passo aparece enquanto acontece: a interpretação PICO, cada estratégia
/// tentada com quantos resultados deu, quantos resumos foram lidos, e a
/// conferência das citações. Um painel que só mostrasse a resposta final seria
/// mais limpo e muito pior: o médico não teria como saber se a IA entendeu a
/// pergunta, e a síntese seria tão verificável quanto um chute.
///
/// O bloco PICO é **editável**. É o ponto de correção mais barato do fluxo —
/// consertar "population: elderly" antes da busca custa um clique; descobrir o
/// erro depois de ler a síntese custa a consulta inteira.
class PainelAgente extends StatelessWidget {
  const PainelAgente({
    super.key,
    required this.estado,
    required this.scroll,
    required this.onRefazerPico,
    required this.onExpandirArtigo,
  });

  final EvidenciasState estado;
  final ScrollController scroll;
  final ValueChanged<Pico> onRefazerPico;
  final ValueChanged<String> onExpandirArtigo;

  @override
  Widget build(BuildContext context) {
    final resposta = estado.respostaAgente;

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final passo in estado.passos)
                  if (passo.tipo != TipoPasso.resposta)
                    _CartaoPasso(
                      passo: passo,
                      onRefazerPico: onRefazerPico,
                    ),
                if (resposta != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _Sintese(passo: resposta),
                  const SizedBox(height: AppSpacing.xl),
                  _FontesUsadas(
                    passo: resposta,
                    secoes: estado.secoes,
                    carregando: estado.carregandoAbstract,
                    onExpandir: onExpandirArtigo,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CartaoPasso extends StatelessWidget {
  const _CartaoPasso({required this.passo, required this.onRefazerPico});
  final PassoAgente passo;
  final ValueChanged<Pico> onRefazerPico;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        color: passo.eErro
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Icone(passo: passo),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(passo.titulo,
                      style: theme.textTheme.titleSmall),
                ),
                if (passo.dados['total'] != null)
                  _Contador(
                    total: passo.dados['total'] as int,
                    avaliacao: '${passo.dados['avaliacao'] ?? ''}',
                  ),
              ],
            ),
            if (passo.tipo == TipoPasso.pico && passo.dados.isNotEmpty)
              _BlocoPico(
                pico: Pico.doJson(passo.dados),
                onRefazer: onRefazerPico,
              ),
            if (passo.tipo == TipoPasso.busca && passo.detalhe != null)
              _Consulta(
                consulta: passo.detalhe!,
                traduzida: '${passo.dados['queryTraduzida'] ?? ''}',
              ),
            if (passo.tipo != TipoPasso.pico &&
                passo.tipo != TipoPasso.busca &&
                passo.detalhe != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  passo.detalhe!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: passo.eErro
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (passo.tipo == TipoPasso.validacao) _Validacao(passo: passo),
          ],
        ),
      ),
    );
  }
}

class _Icone extends StatelessWidget {
  const _Icone({required this.passo});
  final PassoAgente passo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (passo.emAndamento) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final (icone, cor) = switch (passo.tipo) {
      TipoPasso.pico => (Icons.psychology_outlined, theme.colorScheme.primary),
      TipoPasso.busca => (Icons.travel_explore, theme.colorScheme.primary),
      TipoPasso.leitura => (Icons.menu_book_outlined, theme.colorScheme.primary),
      TipoPasso.sintese => (Icons.edit_note, theme.colorScheme.primary),
      TipoPasso.validacao => (
          passo.dados['invalidos'] is List &&
                  (passo.dados['invalidos'] as List).isNotEmpty
              ? Icons.gpp_maybe
              : Icons.verified_outlined,
          passo.dados['invalidos'] is List &&
                  (passo.dados['invalidos'] as List).isNotEmpty
              ? theme.colorScheme.error
              : Colors.green,
        ),
      TipoPasso.resposta => (Icons.check_circle_outline, Colors.green),
      TipoPasso.erro => (Icons.error_outline, theme.colorScheme.error),
    };
    return Icon(icone, size: 20, color: cor);
  }
}

/// Quantos resultados a estratégia deu, com o julgamento do agente.
///
/// O número sozinho não diz nada a quem não pesquisa no PubMed todo dia: 4.000
/// resultados parece ótimo e é péssimo. O rótulo traduz.
class _Contador extends StatelessWidget {
  const _Contador({required this.total, required this.avaliacao});
  final int total;
  final String avaliacao;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = switch (avaliacao) {
      'faixa boa' => Colors.green,
      'poucos resultados' => Colors.orange,
      'resultados demais' => Colors.orange,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$total', style: theme.textTheme.titleSmall?.copyWith(color: cor)),
        if (avaliacao.isNotEmpty)
          Text(avaliacao,
              style: theme.textTheme.labelSmall?.copyWith(color: cor)),
      ],
    );
  }
}

class _Consulta extends StatelessWidget {
  const _Consulta({required this.consulta, required this.traduzida});
  final String consulta;
  final String traduzida;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: SelectableText(
              consulta,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace', height: 1.4),
            ),
          ),
          if (traduzida.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'O PubMed expandiu para: $traduzida',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// PICO editável — o ponto de correção mais barato do fluxo.
class _BlocoPico extends StatefulWidget {
  const _BlocoPico({required this.pico, required this.onRefazer});
  final Pico pico;
  final ValueChanged<Pico> onRefazer;

  @override
  State<_BlocoPico> createState() => _BlocoPicoState();
}

class _BlocoPicoState extends State<_BlocoPico> {
  bool _editando = false;
  late final Map<String, TextEditingController> _campos = {
    'P': TextEditingController(text: widget.pico.populacao),
    'I': TextEditingController(text: widget.pico.intervencao),
    'C': TextEditingController(text: widget.pico.comparador),
    'O': TextEditingController(text: widget.pico.desfecho),
  };

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  static const _titulos = {
    'P': 'População',
    'I': 'Intervenção',
    'C': 'Comparador',
    'O': 'Desfecho',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in _campos.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _editando
                  ? TextField(
                      controller: e.value,
                      decoration: InputDecoration(
                        labelText: _titulos[e.key],
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      style: theme.textTheme.bodySmall,
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text('${_titulos[e.key]}:',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                        ),
                        Expanded(
                          child: Text(
                            e.value.text.isEmpty ? '—' : e.value.text,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
            ),
          if (widget.pico.desenhosPreferidos.isNotEmpty && !_editando)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final d in widget.pico.desenhosPreferidos)
                    SeloDesenho(desenho: d, forte: desenhoForte(d)),
                ],
              ),
            ),
          Row(
            children: [
              if (!_editando)
                TextButton.icon(
                  onPressed: () => setState(() => _editando = true),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Corrigir interpretação'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _editando = false);
                    widget.onRefazer(widget.pico.copyWith(
                      populacao: _campos['P']!.text,
                      intervencao: _campos['I']!.text,
                      comparador: _campos['C']!.text,
                      desfecho: _campos['O']!.text,
                    ));
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Pesquisar de novo'),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () => setState(() => _editando = false),
                  child: const Text('Cancelar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Validacao extends StatelessWidget {
  const _Validacao({required this.passo});
  final PassoAgente passo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validos = (passo.dados['validos'] as List?) ?? const [];
    final invalidos = (passo.dados['invalidos'] as List?) ?? const [];

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          _Contagem(
            icone: Icons.check_circle_outline,
            cor: Colors.green,
            texto: '${validos.length} citação(ões) conferida(s)',
          ),
          if (invalidos.isNotEmpty)
            _Contagem(
              icone: Icons.gpp_maybe,
              cor: theme.colorScheme.error,
              texto: '${invalidos.length} não verificada(s)',
            ),
        ],
      ),
    );
  }
}

class _Contagem extends StatelessWidget {
  const _Contagem(
      {required this.icone, required this.cor, required this.texto});
  final IconData icone;
  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 15, color: cor),
        const SizedBox(width: AppSpacing.xs),
        Text(texto,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: cor)),
      ],
    );
  }
}

class _Sintese extends StatelessWidget {
  const _Sintese({required this.passo});
  final PassoAgente passo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validacao =
        (passo.dados['validacao'] as Map?)?.cast<String, dynamic>() ?? {};
    final ok = validacao['ok'] == true;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Síntese', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (!ok)
                Tooltip(
                  message: 'Há citações que não correspondem aos artigos '
                      'recuperados. Elas estão marcadas no texto.',
                  child: Icon(Icons.gpp_maybe,
                      size: 20, color: theme.colorScheme.error),
                ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          MarkdownBody(
            data: passo.detalhe ?? '',
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Aviso permanente, não só quando algo dá errado: mesmo com todas as
          // citações conferindo, a síntese é interpretação de um modelo.
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Texto gerado por IA a partir dos resumos abaixo. As '
                    'citações foram conferidas contra os artigos recuperados, '
                    'mas a interpretação não substitui a leitura dos estudos '
                    'nem o julgamento clínico.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// As fontes que sustentam a síntese, com as citadas em destaque.
class _FontesUsadas extends StatelessWidget {
  const _FontesUsadas({
    required this.passo,
    required this.secoes,
    required this.carregando,
    required this.onExpandir,
  });

  final PassoAgente passo;
  final Map<String, List<SecaoResumo>> secoes;
  final Map<String, bool> carregando;
  final ValueChanged<String> onExpandir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bruto = (passo.dados['artigos'] as List?) ?? const [];
    if (bruto.isEmpty) return const SizedBox.shrink();

    final artigos = bruto
        .whereType<Map>()
        .map((e) => ArtigoPubmed.doJson(Map<String, dynamic>.from(e)))
        .toList();
    final validacao =
        (passo.dados['validacao'] as Map?)?.cast<String, dynamic>() ?? {};
    final naoCitados =
        ((validacao['naoCitados'] as List?) ?? const []).map((e) => '$e').toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fontes (${artigos.length})',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Artigos recuperados e lidos. Os marcados com aspas foram citados na '
          'síntese; os demais entraram na leitura mas não sustentaram nenhuma '
          'afirmação.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < artigos.length; i++)
          ArtigoCard(
            artigo: artigos[i],
            indice: i + 1,
            destaque: !naoCitados.contains(artigos[i].pmid),
            secoes: secoes[artigos[i].pmid] ?? artigos[i].abstractSecoes,
            carregandoAbstract: carregando[artigos[i].pmid] == true,
            onExpandir: () => onExpandir(artigos[i].pmid),
          ),
      ],
    );
  }
}
