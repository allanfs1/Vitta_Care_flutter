import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/textos.dart';
import '../../../core/theme/app_spacing.dart';
import '../evidencias_providers.dart';
import '../nivel_evidencia.dart';
import '../sessoes/sessao_export.dart';
import '../sessoes/sessao_models.dart';

/// Painel de sessões salvas.
///
/// Aberto como folha lateral porque restaurar uma sessão é uma troca de
/// contexto, não uma ação dentro do resultado atual — e a lista precisa de
/// espaço para mostrar do que cada sessão trata.
class PainelSessoes extends ConsumerWidget {
  const PainelSessoes({super.key, required this.onRestaurar});

  final ValueChanged<SessaoPesquisa> onRestaurar;

  static Future<void> abrir(
    BuildContext context,
    ValueChanged<SessaoPesquisa> onRestaurar,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: PainelSessoes(onRestaurar: onRestaurar),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.txt;
    final sessoes = ref.watch(sessoesProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.bookmark_outline, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Text(t.t('evid.sessao.salvas'),
                  style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        if (sessoes.isEmpty)
          Expanded(child: _Vazio())
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: sessoes.length,
              separatorBuilder: (context, indice) => const Divider(height: 1),
              itemBuilder: (context, i) => _Linha(
                sessao: sessoes[i],
                onRestaurar: () {
                  Navigator.of(context).pop();
                  onRestaurar(sessoes[i]);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _Vazio extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.pageInsets,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border,
                size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(t.t('evid.sessao.nenhuma'),
                style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              t.t('evid.sessao.nenhuma.ajuda'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Linha extends ConsumerWidget {
  const _Linha({required this.sessao, required this.onRestaurar});

  final SessaoPesquisa sessao;
  final VoidCallback onRestaurar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.txt;
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      onTap: onRestaurar,
      title: Text(sessao.titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_data(sessao.salvaEm)} · ${_modo(sessao.modo)} · '
              '${t.t2("evid.sessao.artigos", {"n": "${sessao.artigos.length}"})}',
              style: theme.textTheme.bodySmall,
            ),
            if (sessao.artigos.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              // Miniatura da pirâmide: dá a força da evidência da sessão num
              // relance, sem abri-la.
              Row(
                children: [
                  for (final a in sessao.artigos.take(12))
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Container(
                        width: 5,
                        height: 12,
                        decoration: BoxDecoration(
                          color: NivelEvidencia.de(a.desenhoEstudo).cor(theme),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      trailing: _Menu(sessao: sessao),
    );
  }

  static String _modo(String m) => switch (m) {
        'agente' => 'IA',
        'chat' => 'Chat',
        _ => 'Busca',
      };

  static String _data(DateTime d) {
    final l = d.toLocal();
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(l.day)}/${dd(l.month)}/${l.year}';
  }
}

class _Menu extends ConsumerWidget {
  const _Menu({required this.sessao});
  final SessaoPesquisa sessao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.txt;
    return PopupMenuButton<String>(
      onSelected: (v) async {
        final notifier = ref.read(sessoesProvider.notifier);
        switch (v) {
          case 'renomear':
            final novo = await _pedirNome(context, sessao.titulo);
            if (novo != null) await notifier.renomear(sessao.id, novo);
          case 'excluir':
            await notifier.excluir(sessao.id);
            if (context.mounted) _aviso(context, t.t('evid.sessao.excluida'));
          default:
            final formato = FormatoExport.values.firstWhere(
              (f) => f.name == v,
              orElse: () => FormatoExport.markdown,
            );
            final conteudo = SessaoExport.gerar(sessao, formato);
            await Clipboard.setData(ClipboardData(text: conteudo));
            if (context.mounted) {
              // Copiar em vez de baixar: o download programático é bloqueado no
              // sandbox da web e no-op fora dela — copiar funciona nos dois, e
              // o médico cola onde precisa. Ver EVIDENCIAS.md §9.
              _aviso(context,
                  '${formato.rotulo} copiado (${SessaoExport.nomeArquivo(sessao, formato)}).');
            }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'renomear', child: Text(t.t('comum.renomear'))),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'markdown', child: Text(t.t('evid.sessao.exportar.md'))),
        PopupMenuItem(
            value: 'ris', child: Text(t.t('evid.sessao.exportar.ris'))),
        PopupMenuItem(
            value: 'bibtex', child: Text(t.t('evid.sessao.exportar.bib'))),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'excluir', child: Text(t.t('comum.excluir'))),
      ],
    );
  }

  static void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texto)));
  }

  static Future<String?> _pedirNome(BuildContext context, String atual) {
    final c = TextEditingController(text: atual);
    final t = context.txt;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('comum.renomear')),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: t.t('evid.sessao.nome')),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.t('comum.cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
            child: Text(t.t('comum.salvar')),
          ),
        ],
      ),
    );
  }
}

/// Diálogo de salvar a sessão atual.
Future<void> salvarSessaoDialogo(BuildContext context, WidgetRef ref) async {
  final t = context.txt;
  final ctrl = ref.read(evidenciasControllerProvider.notifier);
  final previa = ctrl.montarSessao();

  if (previa == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Faça uma pesquisa antes de salvar.')),
    );
    return;
  }

  final c = TextEditingController(text: previa.titulo);
  final nome = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.t('evid.sessao.salvar')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: c,
            autofocus: true,
            decoration: InputDecoration(labelText: t.t('evid.sessao.nome')),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            t.t2('evid.sessao.artigos', {'n': '${previa.artigos.length}'}) +
                (previa.temSintese ? ' · com síntese' : '') +
                (previa.temConversa ? ' · com conversa' : ''),
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.t('comum.cancelar')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
          child: Text(t.t('comum.salvar')),
        ),
      ],
    ),
  );

  if (nome == null) return;
  final sessao = ctrl.montarSessao(titulo: nome);
  if (sessao == null) return;
  await ref.read(sessoesProvider.notifier).salvar(sessao);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.t('evid.sessao.salva'))),
    );
  }
}
