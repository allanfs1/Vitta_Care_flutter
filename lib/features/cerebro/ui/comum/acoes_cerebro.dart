import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/aresta.dart' show removerAcentos;
import '../../data/models/nota_enums.dart';
import '../../graph/grafo_modelo.dart';
import '../../providers/cerebro_providers.dart';
import 'cerebro_ui.dart';

/// Ações de alto nível do Cérebro, em um só lugar.
///
/// Antes cada painel reimplementava "criar nota", "abrir nota" e "popular
/// demo" com feedbacks diferentes. Centralizar garante que a mesma ação dê
/// sempre a mesma resposta ao usuário — princípio de consistência de §10.15.
class AcoesCerebro {
  AcoesCerebro._();

  /// Abre uma nota no editor (abre aba + troca a vista central).
  static void abrirNota(WidgetRef ref, String notaId) {
    ref.read(abasProvider.notifier).abrir(notaId);
    ref.read(layoutProvider.notifier).irPara(VistaCentral.editor);
  }

  /// Foca o grafo local de uma nota e abre a nota ao lado.
  static void abrirGrafoLocal(WidgetRef ref, String notaId) {
    final profundidade = ref.read(configGrafoProvider).profundidadeLocal;
    ref.read(escopoGrafoProvider.notifier).state =
        GrafoEscopo.local(notaId, profundidade);
    abrirNota(ref, notaId);
  }

  /// Nota diária de hoje — cria a partir do template se ainda não existir.
  static Future<void> abrirDiario(WidgetRef ref) async {
    final hoje = DateTime.now();
    final iso = '${hoje.year.toString().padLeft(4, '0')}-'
        '${hoje.month.toString().padLeft(2, '0')}-'
        '${hoje.day.toString().padLeft(2, '0')}';
    final path = 'diario/$iso.md';
    final notifier = ref.read(vaultProvider.notifier);
    final existente = notifier.index.porPath(path);
    final id = existente?.id ??
        await notifier.criar(
          path: path,
          tipo: NotaTipo.diario,
          conteudo: '---\ntipo: diario\ndata: $iso\ntags: [diario]\n---\n\n'
              '# $iso\n\n## O que aconteceu\n\n- \n\n'
              '## Perguntas em aberto\n\n- \n',
        );
    abrirNota(ref, id);
  }

  /// Diálogo de criação de nota com título, pasta e tipo (§10.3).
  static Future<void> novaNota(
    BuildContext context,
    WidgetRef ref, {
    String? pastaSugerida,
  }) async {
    final path = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoNovaNota(ref: ref, pasta: pastaSugerida ?? ''),
    );
    if (path == null || path.trim().isEmpty) return;
    final id = await ref.read(vaultProvider.notifier).criar(path: path.trim());
    abrirNota(ref, id);
  }

  /// Popula o vault com volume sintético (§18.3) reportando o resultado.
  static Future<void> popularDemo(
      BuildContext context, WidgetRef ref, int alvo) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 45),
      behavior: SnackBarBehavior.floating,
      width: 420,
      content: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text('Gerando e indexando ~$alvo notas…',
                style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    ));

    final relogio = Stopwatch()..start();
    try {
      final total =
          await ref.read(vaultProvider.notifier).popularDemo(alvo: alvo);
      relogio.stop();
      final index = ref.read(vaultProvider.notifier).index;
      final links = index.totalArestas;
      final densidade = total == 0 ? 0.0 : links / total;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        width: 520,
        content: Text(
          '$total notas · $links links · densidade '
          '${densidade.toStringAsFixed(2)} · ${index.orfas.length} órfãs · '
          '${index.linksQuebrados.length} quebrados '
          '(${relogio.elapsedMilliseconds} ms)',
          style: const TextStyle(fontSize: 12.5),
        ),
      ));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
        content: Text('Falha ao popular o vault: $e'),
      ));
    }
  }

  /// Apaga a carga de demonstração da clínica ativa, com confirmação.
  ///
  /// Destrutivo e irreversível — por isso pede confirmação nomeando o número
  /// exato de notas e deixando claro que só o que tem id `nt_demo_*` sai.
  static Future<void> limparDemo(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(vaultProvider.notifier);
    final total = notifier.totalDemo;
    final messenger = ScaffoldMessenger.of(context);

    if (total == 0) {
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Não há notas de demonstração neste vault.'),
      ));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.delete_sweep_outlined, color: AppColors.danger),
        title: const Text('Limpar dados de demonstração',
            style: TextStyle(fontSize: 17)),
        content: SizedBox(
          width: 420,
          child: Text(
            'Apaga definitivamente $total notas sintéticas (id "nt_demo_…") '
            'desta clínica.\n\nAs notas escritas por pessoas não têm esse '
            'prefixo e não serão tocadas. A ação não pode ser desfeita.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text('Apagar $total notas'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    messenger.clearSnackBars();
    try {
      final removidas = await notifier.limparDemo();
      ref.read(abasProvider.notifier).fecharTodas();
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('$removidas notas de demonstração removidas · '
            '${notifier.index.totalNotas} restantes.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
        content: Text('Falha ao limpar: $e'),
      ));
    }
  }

  /// Converte um título livre em nome de arquivo estável.
  static String slug(String titulo) {
    final base = removerAcentos(titulo.trim().toLowerCase())
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return base.isEmpty ? 'nota-sem-titulo' : base;
  }
}

class _DialogoNovaNota extends StatefulWidget {
  const _DialogoNovaNota({required this.ref, required this.pasta});

  final WidgetRef ref;
  final String pasta;

  @override
  State<_DialogoNovaNota> createState() => _DialogoNovaNotaState();
}

class _DialogoNovaNotaState extends State<_DialogoNovaNota> {
  late final TextEditingController _titulo = TextEditingController();
  late String _pasta = widget.pasta;

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  String get _path {
    final arquivo = '${AcoesCerebro.slug(_titulo.text)}.md';
    return _pasta.isEmpty ? arquivo : '$_pasta/$arquivo';
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.ref.read(vaultProvider.notifier).index;
    final pastas = index.todasPastas.where((p) => p.isNotEmpty).take(8).toList();

    return AlertDialog(
      icon: Icon(Icons.note_add_outlined, color: AppColors.pinkAccent),
      title: const Text('Nova nota', style: TextStyle(fontSize: 17)),
      contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titulo,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Título',
                hintText: 'Protocolo de confirmação ativa',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => Navigator.pop(context, _path),
            ),
            const SizedBox(height: AppSpacing.md),
            RotuloSecao(
              texto: 'PASTA',
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            ),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                PilulaTexto(
                  texto: 'raiz',
                  icone: Icons.folder_open_outlined,
                  cor: _pasta.isEmpty ? AppColors.pinkAccent : null,
                  onTap: () => setState(() => _pasta = ''),
                ),
                for (final p in pastas)
                  PilulaTexto(
                    texto: p,
                    icone: Icons.folder_outlined,
                    cor: _pasta == p ? AppColors.pinkAccent : null,
                    onTap: () => setState(() => _pasta = p),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 6),
              decoration: BoxDecoration(
                color: CerebroTokens.trilho(context),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: 13, color: AppColors.textSecondaryOf(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _path,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _path),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Criar nota'),
        ),
      ],
    );
  }
}
