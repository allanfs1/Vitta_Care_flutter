import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../citacao_validator.dart';
import '../evidencias_providers.dart';
import '../nivel_evidencia.dart';
import '../pubmed_models.dart';
import 'artigo_card.dart';

/// Chat de pesquisa.
///
/// ## O que esta tela mostra além do texto
///
/// Um chat clínico que só mostrasse a resposta seria indistinguível de um
/// chatbot genérico — e a diferença inteira do módulo está no que sustenta a
/// resposta. Por isso cada mensagem carrega:
///
/// - **as buscas que o modelo fez** (ou o aviso de que não fez nenhuma);
/// - **o selo de conferência** das citações;
/// - **as fontes**, expansíveis ali mesmo.
///
/// ## O aviso de resposta sem busca é deliberado
///
/// Quando o modelo responde sem chamar ferramenta nenhuma, a mensagem ganha um
/// aviso. É o caso em que ele respondeu de memória — exatamente o que o módulo
/// existe para evitar — e é invisível sem esse sinal.
class PainelChat extends StatelessWidget {
  const PainelChat({
    super.key,
    required this.estado,
    required this.scroll,
    required this.onExpandirArtigo,
    required this.onSugestao,
  });

  final EvidenciasState estado;
  final ScrollController scroll;
  final ValueChanged<String> onExpandirArtigo;
  final ValueChanged<String> onSugestao;

  @override
  Widget build(BuildContext context) {
    if (estado.mensagens.isEmpty) {
      return _ChatVazio(onSugestao: onSugestao);
    }

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      itemCount: estado.mensagens.length,
      itemBuilder: (context, i) {
        final m = estado.mensagens[i];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: m.doUsuario
                ? _Pergunta(mensagem: m)
                : _Resposta(
                    mensagem: m,
                    secoes: estado.secoes,
                    carregando: estado.carregandoAbstract,
                    onExpandir: onExpandirArtigo,
                  ),
          ),
        );
      },
    );
  }
}

class _Pergunta extends StatelessWidget {
  const _Pergunta({required this.mensagem});
  final MensagemChat mensagem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg, top: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.person_outline,
                size: 16, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SelectableText(
              mensagem.texto,
              style: theme.textTheme.titleSmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _Resposta extends StatelessWidget {
  const _Resposta({
    required this.mensagem,
    required this.secoes,
    required this.carregando,
    required this.onExpandir,
  });

  final MensagemChat mensagem;
  final Map<String, List<SecaoResumo>> secoes;
  final Map<String, bool> carregando;
  final ValueChanged<String> onExpandir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = mensagem.validacao;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mensagem.ferramentas.isNotEmpty)
            _Ferramentas(nomes: mensagem.ferramentas),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(Icons.auto_awesome,
                    size: 15, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: mensagem.texto.isEmpty && mensagem.streaming
                    ? const _Pensando()
                    : MarkdownBody(
                        data: mensagem.texto,
                        selectable: true,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(theme).copyWith(
                          p: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
                          listBullet:
                              theme.textTheme.bodyMedium?.copyWith(height: 1.65),
                        ),
                      ),
              ),
            ],
          ),

          if (!mensagem.streaming) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _Rodape(
                validacao: v,
                semBusca: mensagem.ferramentas.isEmpty,
                fontes: mensagem.fontes,
                secoes: secoes,
                carregando: carregando,
                onExpandir: onExpandir,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// As buscas que o modelo fez, em linguagem de gente.
class _Ferramentas extends StatelessWidget {
  const _Ferramentas({required this.nomes});
  final List<String> nomes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buscas = nomes.where((n) => n == 'buscar_literatura').length;
    final leituras = nomes.where((n) => n == 'ler_resumos').length;

    final partes = <String>[
      if (buscas > 0) '$buscas busca${buscas > 1 ? "s" : ""} no PubMed',
      if (leituras > 0) 'leitura de resumos',
    ];
    if (partes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.travel_explore,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(
            partes.join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pensando extends StatelessWidget {
  const _Pensando();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text('Pesquisando na literatura…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }
}

/// Selo de conferência + fontes.
class _Rodape extends StatelessWidget {
  const _Rodape({
    required this.validacao,
    required this.semBusca,
    required this.fontes,
    required this.secoes,
    required this.carregando,
    required this.onExpandir,
  });

  final ResultadoValidacao? validacao;
  final bool semBusca;
  final List<ArtigoPubmed> fontes;
  final Map<String, List<SecaoResumo>> secoes;
  final Map<String, bool> carregando;
  final ValueChanged<String> onExpandir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = validacao;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resposta sem nenhuma busca = resposta de memória. É o modo de falha
        // que o módulo existe para evitar, e sem este aviso ele é invisível.
        if (semBusca)
          _Selo(
            icone: Icons.warning_amber_rounded,
            cor: theme.colorScheme.error,
            texto: 'Respondida sem consultar o PubMed — trate como orientação '
                'geral, não como evidência.',
          )
        else if (v != null && v.invalidos.isNotEmpty)
          _Selo(
            icone: Icons.gpp_maybe,
            cor: theme.colorScheme.error,
            texto: '${v.invalidos.length} citação(ões) não conferem e estão '
                'marcadas no texto.',
          )
        else if (v != null && v.semCitacao)
          _Selo(
            icone: Icons.info_outline,
            cor: theme.colorScheme.onSurfaceVariant,
            texto: 'Sem citação nesta resposta.',
          )
        else if (v != null)
          _Selo(
            icone: Icons.verified_outlined,
            cor: Colors.green,
            texto: '${v.validos.length} citação(ões) conferida(s) contra os '
                'artigos recuperados.',
          ),

        if (fontes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Fontes(
            fontes: fontes,
            secoes: secoes,
            carregando: carregando,
            onExpandir: onExpandir,
          ),
        ],
      ],
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo({required this.icone, required this.cor, required this.texto});
  final IconData icone;
  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 15, color: cor),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(texto,
              style: theme.textTheme.labelSmall?.copyWith(color: cor)),
        ),
      ],
    );
  }
}

class _Fontes extends StatefulWidget {
  const _Fontes({
    required this.fontes,
    required this.secoes,
    required this.carregando,
    required this.onExpandir,
  });

  final List<ArtigoPubmed> fontes;
  final Map<String, List<SecaoResumo>> secoes;
  final Map<String, bool> carregando;
  final ValueChanged<String> onExpandir;

  @override
  State<_Fontes> createState() => _FontesState();
}

class _FontesState extends State<_Fontes> {
  bool _aberto = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _aberto = !_aberto),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_aberto ? Icons.expand_less : Icons.expand_more, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${widget.fontes.length} fonte${widget.fontes.length > 1 ? "s" : ""}',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(width: AppSpacing.sm),
                // Miniatura da pirâmide: dá a força da evidência da resposta
                // inteira num relance, sem abrir a lista.
                for (final f in widget.fontes.take(8))
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Container(
                      width: 6,
                      height: 14,
                      decoration: BoxDecoration(
                        color: NivelEvidencia.de(f.desenhoEstudo).cor(theme),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_aberto)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              children: [
                for (var i = 0; i < widget.fontes.length; i++)
                  ArtigoCard(
                    artigo: widget.fontes[i],
                    indice: i + 1,
                    secoes: widget.secoes[widget.fontes[i].pmid] ??
                        widget.fontes[i].abstractSecoes,
                    carregandoAbstract:
                        widget.carregando[widget.fontes[i].pmid] == true,
                    onExpandir: () => widget.onExpandir(widget.fontes[i].pmid),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChatVazio extends StatelessWidget {
  const _ChatVazio({required this.onSugestao});
  final ValueChanged<String> onSugestao;

  static const _sugestoes = [
    'Metformina reduz eventos cardiovasculares em idosos com diabetes tipo 2?',
    'Qual a evidência para anticoagulação em FA com doença renal crônica?',
    'Estatina em prevenção primária após os 75 anos: vale a pena?',
    'Qual o melhor esquema para H. pylori hoje, considerando resistência?',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: AppSpacing.pageInsets,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Icon(Icons.forum_outlined,
                  size: 44, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.lg),
              Text('Converse sobre a literatura',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Pergunte, receba a resposta com as fontes, e continue: "e se '
                'ele tiver doença renal?", "isso vale para idosos?". O que já '
                'foi encontrado fica disponível pela conversa inteira, e cada '
                'citação é conferida contra os artigos recuperados.',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              _QuandoUsar(),
              const SizedBox(height: AppSpacing.xl),
              Text('Comece por', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final s in _sugestoes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: InkWell(
                    onTap: () => onSugestao(s),
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
                          Icon(Icons.chat_bubble_outline,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                              child: Text(s,
                                  style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diferencia os três modos.
///
/// Sem isto o usuário escolhe pelo nome e descobre a diferença tarde: manda uma
/// pergunta de revisão para o chat e recebe uma resposta rasa, ou espera 30 s
/// pelo agente para tirar uma dúvida de dez segundos.
class _QuandoUsar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Qual modo usar', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          _Linha(
            icone: Icons.forum_outlined,
            titulo: 'Chat',
            texto: 'Dúvida rápida, exploração, perguntas encadeadas.',
          ),
          _Linha(
            icone: Icons.auto_awesome,
            titulo: 'Perguntar à IA',
            texto: 'Uma revisão a fundo: decompõe em PICO, calibra a '
                'estratégia e sintetiza. Mais lento, mais completo.',
          ),
          _Linha(
            icone: Icons.search,
            titulo: 'Buscar',
            texto: 'Você já sabe o que procura e quer os filtros na mão.',
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.icone,
    required this.titulo,
    required this.texto,
  });
  final IconData icone;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                children: [
                  TextSpan(
                    text: '$titulo — ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: texto),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
