import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/i18n/textos.dart';
import '../filtros_busca.dart';

/// Painel de filtros clínicos.
///
/// Agrupado pelo que o médico decide, não pelo que a API oferece: primeiro o
/// **desenho do estudo** (o recorte que mais muda a resposta), depois tempo,
/// depois população, e por último acesso. Um painel espelhando a sintaxe do
/// Entrez seria fiel à API e inútil na mesa de consulta.
class PainelFiltros extends StatelessWidget {
  const PainelFiltros({
    super.key,
    required this.filtros,
    required this.onMudar,
    required this.onLimpar,
  });

  final FiltrosBusca filtros;
  final ValueChanged<FiltrosBusca> onMudar;
  final VoidCallback onLimpar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Altura limitada e rolagem própria: o painel vive dentro de uma Column
    // com o corpo da tela, e em tela baixa (celular deitado, janela pequena)
    // a lista inteira de filtros não cabe. Sem o teto, o overflow come o
    // resultado da busca — que é o que a pessoa veio ver.
    final alturaMax = MediaQuery.sizeOf(context).height * 0.45;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 900, maxHeight: alturaMax),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Grupo(
                    titulo: 'Desenho do estudo',
                    dica: 'Vários somam — marcar dois traz os dois tipos.',
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final d in DesenhoFiltro.values)
                          FilterChip(
                            label: Text(d.rotulo),
                            selected: filtros.desenhos.contains(d),
                            avatar: d.forte
                                ? Icon(
                                    Icons.trending_up,
                                    size: 15,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            onSelected: (sim) {
                              final s = {...filtros.desenhos};
                              sim ? s.add(d) : s.remove(d);
                              onMudar(filtros.copyWith(desenhos: s));
                            },
                          ),
                      ],
                    ),
                  ),
                  _Grupo(
                    titulo: 'Publicado nos últimos',
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final anos in const [1, 2, 5, 10])
                          ChoiceChip(
                            label: Text('$anos ano${anos > 1 ? "s" : ""}'),
                            selected: filtros.anosRecentes == anos,
                            onSelected: (sim) => onMudar(
                              sim
                                  ? filtros.copyWith(anosRecentes: anos)
                                  : filtros.copyWith(limparAnos: true),
                            ),
                          ),
                        ChoiceChip(
                          label: const Text('Qualquer data'),
                          selected: filtros.anosRecentes == null,
                          onSelected: (_) =>
                              onMudar(filtros.copyWith(limparAnos: true)),
                        ),
                      ],
                    ),
                  ),
                  _Grupo(
                    titulo: 'População',
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        FilterChip(
                          label: const Text('Só humanos'),
                          selected: filtros.somenteHumanos,
                          onSelected: (v) =>
                              onMudar(filtros.copyWith(somenteHumanos: v)),
                        ),
                        for (final f in FaixaEtaria.values)
                          if (f != FaixaEtaria.nenhuma)
                            ChoiceChip(
                              label: Text(f.rotulo),
                              selected: filtros.faixaEtaria == f,
                              onSelected: (sim) => onMudar(
                                filtros.copyWith(
                                  faixaEtaria: sim ? f : FaixaEtaria.nenhuma,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  _Grupo(
                    titulo: 'Acesso e idioma',
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        FilterChip(
                          label: const Text('Texto completo grátis'),
                          selected: filtros.somenteTextoLivre,
                          onSelected: (v) =>
                              onMudar(filtros.copyWith(somenteTextoLivre: v)),
                        ),
                        FilterChip(
                          label: const Text('Com resumo'),
                          selected: filtros.somenteComResumo,
                          onSelected: (v) =>
                              onMudar(filtros.copyWith(somenteComResumo: v)),
                        ),
                        FilterChip(
                          label: const Text('Em inglês'),
                          selected: filtros.idiomaIngles,
                          onSelected: (v) =>
                              onMudar(filtros.copyWith(idiomaIngles: v)),
                        ),
                      ],
                    ),
                  ),
                  if (!filtros.vazio)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onLimpar,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: Text(context.txt.t('evid.filtros.limpar')),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.child, this.dica});
  final String titulo;
  final Widget child;
  final String? dica;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(titulo, style: theme.textTheme.labelLarge),
              if (dica != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    dica!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
