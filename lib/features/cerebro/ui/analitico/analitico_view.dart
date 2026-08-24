import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/nota.dart';
import '../../data/models/nota_enums.dart';
import '../../graph/grafo_modelo.dart';
import '../../providers/cerebro_providers.dart';
import '../comum/badge_origem.dart';
import '../comum/acoes_cerebro.dart';
import '../comum/cerebro_ui.dart';
import '../grafo/painel_grafo.dart';

/// Modo Analítico (`obsidian.md` §10.6) — facetas · rede/lista · inspector.
///
/// Derivado da referência `img/5.jpg`: painel de facetas com contagens e
/// barras proporcionais à esquerda, visualização ao centro e inspector do
/// item selecionado à direita.
class AnaliticoView extends ConsumerStatefulWidget {
  const AnaliticoView({super.key, this.compacto = false});

  /// Em larguras menores facetas e inspector começam recolhidos — a
  /// visualização central é o que não pode encolher.
  final bool compacto;

  @override
  ConsumerState<AnaliticoView> createState() => _AnaliticoViewState();
}

class _AnaliticoViewState extends ConsumerState<AnaliticoView> {
  _Aba _aba = _Aba.rede;
  late bool _facetas = !widget.compacto;
  late bool _inspector = !widget.compacto;

  @override
  Widget build(BuildContext context) {
    final resultado = ref.watch(grafoProvider(const GrafoEscopo.global()));

    return Container(
      color: AppColors.backgroundOf(context),
      child: Column(
        children: [
          _BarraSuperior(
            aba: _aba,
            facetas: _facetas,
            inspector: _inspector,
            aoTrocar: (a) => setState(() => _aba = a),
            aoAlternarFacetas: () => setState(() => _facetas = !_facetas),
            aoAlternarInspector: () => setState(() => _inspector = !_inspector),
          ),
          Expanded(
            child: Row(
              children: [
                if (_facetas) const _PainelFacetas(),
                Expanded(
                  child: switch (_aba) {
                    _Aba.rede =>
                      const PainelGrafo(escopo: GrafoEscopo.global()),
                    _Aba.lista => const _AbaLista(),
                  },
                ),
                if (_inspector) const _Inspector(),
              ],
            ),
          ),
          _BarraInferior(
            nos: resultado.grafo.n,
            arestas: resultado.grafo.arestas.length,
            componentes: resultado.metricas.nComponentes,
            clusters: resultado.metricas.nClusters,
            densidade: resultado.metricas.densidade,
          ),
        ],
      ),
    );
  }
}

enum _Aba { rede, lista }

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({
    required this.aba,
    required this.facetas,
    required this.inspector,
    required this.aoTrocar,
    required this.aoAlternarFacetas,
    required this.aoAlternarInspector,
  });

  final _Aba aba;
  final bool facetas;
  final bool inspector;
  final ValueChanged<_Aba> aoTrocar;
  final VoidCallback aoAlternarFacetas;
  final VoidCallback aoAlternarInspector;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: CerebroTokens.barra,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        children: [
          BotaoIcone(
            icone: Icons.tune,
            tooltip: facetas ? 'Ocultar facetas' : 'Mostrar facetas',
            ativo: facetas,
            onTap: aoAlternarFacetas,
          ),
          const SizedBox(width: 4),
          Icon(Icons.analytics_outlined, size: 15, color: AppColors.pinkAccent),
          const SizedBox(width: 6),
          Text(
            'Analítico',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: CerebroTokens.trilho(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in _Aba.values)
                  InkWell(
                    onTap: () => aoTrocar(a),
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: a == aba
                            ? AppColors.surfaceOf(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            a == _Aba.rede
                                ? Icons.hub_outlined
                                : Icons.table_rows_outlined,
                            size: 13,
                            color: a == aba
                                ? AppColors.pinkAccent
                                : AppColors.textSecondaryOf(context),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            a == _Aba.rede ? 'Rede' : 'Lista',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: a == aba
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: a == aba
                                  ? AppColors.textPrimaryOf(context)
                                  : AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          BotaoIcone(
            icone: Icons.info_outline,
            tooltip: inspector ? 'Ocultar inspector' : 'Mostrar inspector',
            ativo: inspector,
            onTap: aoAlternarInspector,
          ),
        ],
      ),
    );
  }
}

// ── Facetas ─────────────────────────────────────────────────────────────────

class _PainelFacetas extends ConsumerWidget {
  const _PainelFacetas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(vaultProvider);
    final index = ref.read(vaultProvider.notifier).index;
    final notas = index.notas.values.where((n) => !n.excluida).toList();

    final porTipo = <NotaTipo, int>{};
    final porOrigem = <NotaOrigem, int>{};
    for (final n in notas) {
      porTipo.update(n.tipo, (v) => v + 1, ifAbsent: () => 1);
      porOrigem.update(n.origem, (v) => v + 1, ifAbsent: () => 1);
    }

    final tags = index.contagemTags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: 244,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(right: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          _GrupoFaceta(
            titulo: 'NOTAS',
            total: notas.length,
            itens: [
              for (final e in (porTipo.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value))))
                _ItemFaceta(e.key.label, e.value, e.key.cor,
                    filtro: 'tipo:${e.key.id}'),
            ],
            maximo: porTipo.values.isEmpty
                ? 1
                : porTipo.values.reduce((a, b) => a > b ? a : b),
          ),
          _GrupoFaceta(
            titulo: 'ORIGEM',
            total: notas.length,
            itens: [
              for (final e in porOrigem.entries)
                _ItemFaceta(
                  e.key.label,
                  e.value,
                  e.key == NotaOrigem.agente
                      ? const Color(0xFF7C3AED)
                      : AppColors.primary,
                  filtro: 'origem:${e.key.id}',
                ),
            ],
            maximo: porOrigem.values.isEmpty
                ? 1
                : porOrigem.values.reduce((a, b) => a > b ? a : b),
          ),
          _GrupoFaceta(
            titulo: 'TAGS',
            total: tags.length,
            itens: [
              for (final e in tags.take(10))
                _ItemFaceta(
                    '#${e.key}', e.value, AppColors.warning, filtro: 'tag:#${e.key}'),
            ],
            maximo: tags.isEmpty ? 1 : tags.first.value,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextButton.icon(
              onPressed: () => ref
                  .read(configGrafoProvider.notifier)
                  .atualizar((c) => c.copyWith(filtro: '')),
              icon: const Icon(Icons.clear, size: 14),
              label: const Text('Limpar filtros', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemFaceta {
  const _ItemFaceta(this.rotulo, this.valor, this.cor, {required this.filtro});

  final String rotulo;
  final int valor;
  final Color cor;
  final String filtro;
}

class _GrupoFaceta extends ConsumerWidget {
  const _GrupoFaceta({
    required this.titulo,
    required this.total,
    required this.itens,
    required this.maximo,
  });

  final String titulo;
  final int total;
  final List<_ItemFaceta> itens;
  final int maximo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtroAtual = ref.watch(configGrafoProvider).filtro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RotuloSecao(
          texto: titulo,
          contador: total,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 4),
        ),
        for (final item in itens)
          InkWell(
            onTap: () => ref.read(configGrafoProvider.notifier).atualizar(
                  (c) => c.copyWith(
                      filtro: filtroAtual == item.filtro ? '' : item.filtro),
                ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 3),
              color: filtroAtual == item.filtro
                  ? AppColors.pinkAccent.withValues(alpha: 0.10)
                  : Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.rotulo,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimaryOf(context)),
                        ),
                      ),
                      Text('${item.valor}',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Barra proporcional — as barras azuis de `img/5.jpg`.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: maximo == 0 ? 0 : item.valor / maximo,
                      minHeight: 3,
                      backgroundColor: AppColors.surfaceAltOf(context),
                      valueColor: AlwaysStoppedAnimation(item.cor),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Aba Lista ───────────────────────────────────────────────────────────────

class _AbaLista extends ConsumerWidget {
  const _AbaLista();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultado = ref.watch(grafoProvider(const GrafoEscopo.global()));
    final index = ref.read(vaultProvider.notifier).index;

    final linhas = <Nota>[];
    for (final no in resultado.grafo.nos) {
      final n = index.porId(no.id);
      if (n != null) linhas.add(n);
    }
    linhas.sort((a, b) => b.metrics.pagerank.compareTo(a.metrics.pagerank));

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 34,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 38,
          columns: const [
            DataColumn(label: Text('Nota', style: TextStyle(fontSize: 11))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontSize: 11))),
            DataColumn(
                label: Text('PageRank', style: TextStyle(fontSize: 11)),
                numeric: true),
            DataColumn(
                label: Text('Entra', style: TextStyle(fontSize: 11)),
                numeric: true),
            DataColumn(
                label: Text('Sai', style: TextStyle(fontSize: 11)),
                numeric: true),
            DataColumn(
                label: Text('Cluster', style: TextStyle(fontSize: 11)),
                numeric: true),
            DataColumn(label: Text('Origem', style: TextStyle(fontSize: 11))),
          ],
          rows: [
            for (final n in linhas.take(200))
              DataRow(
                onSelectChanged: (_) => AcoesCerebro.abrirNota(ref, n.id),
                cells: [
                  DataCell(Row(
                    children: [
                      NotaIcone(tipo: n.tipo, tamanho: 12),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(n.titulo,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5)),
                      ),
                    ],
                  )),
                  DataCell(Text(n.tipo.label,
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text(n.metrics.pagerank.toStringAsFixed(4),
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${n.metrics.inDegree}',
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${n.metrics.outDegree}',
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text('#${n.metrics.cluster}',
                      style: const TextStyle(fontSize: 11))),
                  DataCell(BadgeOrigem(nota: n, compacto: true)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Inspector ───────────────────────────────────────────────────────────────

class _Inspector extends ConsumerWidget {
  const _Inspector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(noSelecionadoProvider);
    ref.watch(vaultProvider);
    final index = ref.read(vaultProvider.notifier).index;
    final nota = id == null ? null : index.porId(id);

    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(left: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: nota == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  id == null
                      ? 'Selecione um nó no grafo para inspecionar.'
                      : 'Nó "$id" não é uma nota — é entidade, tag ou link não resolvido.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppColors.textSecondaryOf(context)),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text('NÓ SELECIONADO',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: AppColors.textSecondaryOf(context),
                    )),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  nota.titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(nota.path,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondaryOf(context))),
                const SizedBox(height: AppSpacing.sm),
                BadgeOrigem(nota: nota),
                const Divider(height: AppSpacing.xl),
                _linha(context, 'PageRank',
                    nota.metrics.pagerank.toStringAsFixed(4)),
                _linha(context, 'Entradas', '${nota.metrics.inDegree}'),
                _linha(context, 'Saídas', '${nota.metrics.outDegree}'),
                _linha(context, 'Cluster', '#${nota.metrics.cluster}'),
                _linha(context, 'Palavras', '${nota.wordCount}'),
                if (nota.tags.isNotEmpty) ...[
                  const Divider(height: AppSpacing.xl),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final t in nota.tags)
                        Chip(
                          label: Text('#$t', style: const TextStyle(fontSize: 9.5)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
                const Divider(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => AcoesCerebro.abrirNota(ref, nota.id),
                        child:
                            const Text('Abrir', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            AcoesCerebro.abrirGrafoLocal(ref, nota.id),
                        child: const Text('Grafo local',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _linha(BuildContext context, String rotulo, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(rotulo,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryOf(context))),
            ),
            Text(valor,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context))),
          ],
        ),
      );
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({
    required this.nos,
    required this.arestas,
    required this.componentes,
    required this.clusters,
    required this.densidade,
  });

  final int nos;
  final int arestas;
  final int componentes;
  final int clusters;
  final double densidade;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        border: Border(top: BorderSide(color: AppColors.borderOf(context))),
      ),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (rotulo, valor) in [
              ('nós', '$nos'),
              ('arestas', '$arestas'),
              (componentes == 1 ? 'componente' : 'componentes', '$componentes'),
              ('clusters', '$clusters'),
              ('densidade', densidade.toStringAsFixed(4)),
            ])
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Row(
                  children: [
                    Text(valor,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context),
                        )),
                    const SizedBox(width: 4),
                    Text(rotulo,
                        style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textSecondaryOf(context))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
