import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../providers/cerebro_providers.dart';
import 'cerebro_ui.dart';

/// Barra de status inferior (`obsidian.md` §10.10).
///
/// Contagens do vault à esquerda, contexto da nota ativa à direita. Cada item
/// clicável tem hover e tooltip; o bloco da esquerda rola horizontalmente em
/// vez de estourar o layout em telas estreitas.
class CerebroStatusBar extends ConsumerWidget {
  const CerebroStatusBar({super.key, this.compacta = false});

  /// Em telas estreitas o bloco da nota ativa sai — a informação já está
  /// visível na barra de contexto do editor.
  final bool compacta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(estatisticasProvider);
    final vault = ref.watch(vaultProvider);
    final nota = ref.watch(notaAtivaProvider);
    final comFirebase = ref.watch(firebaseEnabledProvider);

    final densidade = stats.notas == 0 ? 0.0 : stats.links / stats.notas;
    final corDensidade = densidade >= 3.5
        ? AppColors.success
        : (densidade < 1.5 ? AppColors.warning : AppColors.textSecondaryOf(context));

    return Container(
      height: CerebroTokens.barraStatus,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        border: Border(top: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Sincronia(
                    salvando: vault.salvando,
                    comFirebase: comFirebase,
                    erro: vault.erro,
                  ),
                  _sep(context),
                  _Item(
                    icone: Icons.description_outlined,
                    texto: '${stats.notas} notas',
                    tooltip: 'Abrir o modo analítico',
                    onTap: () => ref
                        .read(layoutProvider.notifier)
                        .irPara(VistaCentral.analitico),
                  ),
                  _Item(
                    icone: Icons.share_outlined,
                    texto: '${stats.links} links',
                    tooltip: 'Abrir o grafo global',
                    onTap: () => ref
                        .read(layoutProvider.notifier)
                        .irPara(VistaCentral.grafo),
                  ),
                  _Densidade(valor: densidade, cor: corDensidade),
                  if (stats.orfas > 0)
                    _Item(
                      icone: Icons.link_off_outlined,
                      texto: '${stats.orfas} órfãs',
                      cor: AppColors.warning,
                      tooltip: 'Notas sem nenhuma conexão — clique para filtrar',
                      onTap: () {
                        ref.read(termoBuscaProvider.notifier).state = 'orfa:true';
                        ref
                            .read(layoutProvider.notifier)
                            .abrirPainel(PainelEsquerdo.busca);
                      },
                    ),
                  if (stats.quebrados > 0)
                    _Item(
                      icone: Icons.report_gmailerrorred_outlined,
                      texto: '${stats.quebrados} quebrados',
                      cor: AppColors.danger,
                      tooltip: 'Links apontando para notas que não existem — '
                          'clique para revisar',
                      onTap: () => ref
                          .read(layoutProvider.notifier)
                          .abrirPainel(PainelEsquerdo.sugestoes),
                    ),
                ],
              ),
            ),
          ),
          if (!compacta && nota != null) ...[
            _sep(context),
            _Item(texto: '${nota.wordCount} palavras'),
            _Item(texto: '${nota.charCount} caracteres'),
            _Item(
              icone: Icons.schedule,
              texto: '${(nota.tempoLeituraSeg / 60).ceil()} min',
              tooltip: 'Tempo estimado de leitura',
            ),
          ],
        ],
      ),
    );
  }

  Widget _sep(BuildContext context) => Container(
        width: 1,
        height: 12,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        color: AppColors.borderOf(context),
      );
}

/// Estado de persistência do vault — o item mais importante da barra, por isso
/// é o único com fundo próprio.
class _Sincronia extends StatelessWidget {
  const _Sincronia({
    required this.salvando,
    required this.comFirebase,
    required this.erro,
  });

  final bool salvando;
  final bool comFirebase;
  final String? erro;

  @override
  Widget build(BuildContext context) {
    final (icone, texto, cor, dica) = switch ((erro != null, salvando)) {
      (true, _) => (
          Icons.error_outline,
          'erro ao salvar',
          AppColors.danger,
          erro ?? 'Falha ao persistir o vault'
        ),
      (false, true) => (
          Icons.sync,
          'salvando…',
          AppColors.warning,
          'Gravando alterações da nota'
        ),
      _ => comFirebase
          ? (
              Icons.cloud_done_outlined,
              'sincronizado',
              AppColors.success,
              'Vault sincronizado com o Firestore'
            )
          : (
              Icons.memory,
              'local',
              AppColors.textSecondaryOf(context),
              'Modo local — sem Firebase configurado nesta sessão'
            ),
    };

    return Tooltip(
      message: dica,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 11, color: cor),
            const SizedBox(width: 4),
            Text(texto,
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w600, color: cor)),
          ],
        ),
      ),
    );
  }
}

/// North star do módulo: arestas por nota. Ganhou um medidor para deixar de
/// ser um número solto e virar um objetivo visível (meta ≥ 3,5).
class _Densidade extends StatelessWidget {
  const _Densidade({required this.valor, required this.cor});

  final double valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final progresso = (valor / 3.5).clamp(0.0, 1.0);
    return Tooltip(
      message: 'Densidade do grafo: ${valor.toStringAsFixed(2)} aresta(s) por '
          'nota.\nMeta do módulo: ≥ 3,5.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('densidade ${valor.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, color: cor)),
            const SizedBox(width: 5),
            Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: CerebroTokens.trilho(context),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progresso,
                child: Container(
                  decoration: BoxDecoration(
                    color: cor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatefulWidget {
  const _Item({
    required this.texto,
    this.icone,
    this.cor,
    this.onTap,
    this.tooltip,
  });

  final String texto;
  final IconData? icone;
  final Color? cor;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cor = widget.cor ?? AppColors.textSecondaryOf(context);
    final clicavel = widget.onTap != null;

    Widget conteudo = AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: clicavel && _hover
            ? CerebroTokens.hover(context)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icone != null) ...[
            Icon(widget.icone, size: 11, color: cor),
            const SizedBox(width: 4),
          ],
          Text(
            widget.texto,
            style: TextStyle(
              fontSize: 11,
              color: cor,
              decoration: clicavel && _hover
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationColor: cor,
            ),
          ),
        ],
      ),
    );

    if (clicavel) {
      conteudo = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: conteudo,
        ),
      );
    }

    return widget.tooltip == null
        ? conteudo
        : Tooltip(message: widget.tooltip!, child: conteudo);
  }
}
