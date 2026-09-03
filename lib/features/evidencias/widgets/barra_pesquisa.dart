import 'package:flutter/material.dart';

import '../../../core/i18n/textos.dart';
import '../../../core/theme/app_spacing.dart';
import '../evidencias_providers.dart';
import '../pubmed_models.dart';

/// Barra de pesquisa com seletor de modo.
///
/// O seletor vem **antes** do campo, e não escondido num menu, porque a
/// escolha muda o que o usuário deve digitar: em Busca ele escreve termos em
/// inglês com sintaxe Entrez; em Pergunta escreve português corrente. Um campo
/// só, sem indicação clara do modo, faria o médico digitar português numa busca
/// literal e concluir que "não tem nada publicado".
class BarraPesquisa extends StatelessWidget {
  const BarraPesquisa({
    super.key,
    required this.controller,
    required this.estado,
    required this.filtrosAbertos,
    required this.onEnviar,
    required this.onModo,
    required this.onOrdem,
    required this.onAlternarFiltros,
  });

  final TextEditingController controller;
  final EvidenciasState estado;
  final bool filtrosAbertos;
  final void Function([String?]) onEnviar;
  final ValueChanged<ModoPesquisa> onModo;
  final ValueChanged<OrdemBusca> onOrdem;
  final VoidCallback onAlternarFiltros;

  bool get _agente => estado.modo == ModoPesquisa.agente;
  bool get _chat => estado.modo == ModoPesquisa.chat;
  bool get _linguagemNatural => _agente || _chat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estreito = MediaQuery.sizeOf(context).width < 620;

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                _SeletorModo(modo: estado.modo, onMudar: onModo),
                const SizedBox(height: AppSpacing.md),
                _Campo(
                  modo: estado.modo,
                  controller: controller,
                  carregando: estado.carregando,
                  onEnviar: onEnviar,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!_linguagemNatural)
                  _LinhaControles(
                    estado: estado,
                    estreito: estreito,
                    filtrosAbertos: filtrosAbertos,
                    onOrdem: onOrdem,
                    onAlternarFiltros: onAlternarFiltros,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeletorModo extends StatelessWidget {
  const _SeletorModo({required this.modo, required this.onMudar});
  final ModoPesquisa modo;
  final ValueChanged<ModoPesquisa> onMudar;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ModoPesquisa>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: ModoPesquisa.busca,
          icon: const Icon(Icons.search, size: 18),
          label: Text(context.txt.t('evid.modo.buscar')),
          tooltip: context.txt.t('evid.modo.buscar.dica'),
        ),
        ButtonSegment(
          value: ModoPesquisa.agente,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(context.txt.t('evid.modo.perguntar')),
          tooltip: context.txt.t('evid.modo.perguntar.dica'),
        ),
        ButtonSegment(
          value: ModoPesquisa.chat,
          icon: const Icon(Icons.forum_outlined, size: 18),
          label: Text(context.txt.t('evid.modo.chat')),
          tooltip: context.txt.t('evid.modo.chat.dica'),
        ),
      ],
      selected: {modo},
      onSelectionChanged: (s) => onMudar(s.first),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.modo,
    required this.controller,
    required this.carregando,
    required this.onEnviar,
  });

  final ModoPesquisa modo;
  final TextEditingController controller;
  final bool carregando;
  final void Function([String?]) onEnviar;

  /// O que o campo pede em cada modo. A dica muda porque a expectativa muda —
  /// e digitar português numa busca literal é o erro mais caro do módulo.
  (String, String, IconData, String) textos(Textos t) => switch (modo) {
        ModoPesquisa.busca => (
            t.t('evid.campo.buscar.hint'),
            t.t('evid.campo.buscar.ajuda'),
            Icons.search,
            t.t('evid.modo.buscar'),
          ),
        ModoPesquisa.agente => (
            t.t('evid.campo.perguntar.hint'),
            t.t('evid.campo.perguntar.ajuda'),
            Icons.auto_awesome,
            t.t('evid.campo.perguntar'),
          ),
        ModoPesquisa.chat => (
            t.t('evid.campo.chat.hint'),
            t.t('evid.campo.chat.ajuda'),
            Icons.forum_outlined,
            t.t('evid.campo.enviar'),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (dica, ajuda, icone, acao) = textos(context.txt);
    final natural = modo != ModoPesquisa.busca;

    return TextField(
      controller: controller,
      enabled: !carregando,
      autofocus: true,
      // Pergunta clínica costuma passar de uma linha; busca Entrez raramente
      // passa. A caixa cresce só onde faz falta.
      minLines: 1,
      maxLines: natural ? 4 : 1,
      // No chat, Enter envia: é a convenção que todo mundo espera de um chat, e
      // quebrar linha ali é raro o bastante para caber no Shift+Enter.
      textInputAction:
          modo == ModoPesquisa.agente ? TextInputAction.newline : TextInputAction.send,
      onSubmitted: (_) => onEnviar(),
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: dica,
        helperText: ajuda,
        helperMaxLines: 2,
        prefixIcon: Icon(icone),
        suffixIcon: carregando
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: acao,
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => onEnviar(),
              ),
      ),
    );
  }
}

class _LinhaControles extends StatelessWidget {
  const _LinhaControles({
    required this.estado,
    required this.estreito,
    required this.filtrosAbertos,
    required this.onOrdem,
    required this.onAlternarFiltros,
  });

  final EvidenciasState estado;
  final bool estreito;
  final bool filtrosAbertos;
  final ValueChanged<OrdemBusca> onOrdem;
  final VoidCallback onAlternarFiltros;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ativos = estado.filtros.quantidadeAtiva;

    // Wrap, não Row: em tela estreita o botão de filtros mais o seletor de
    // ordenação passam da largura, e um Row corta o segundo controle — foi o
    // que acontecia com "Mais recentes" ficando ilegível.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        // O contador no botão evita o pior estado da tela: filtro ligado,
        // resultado estranho e ninguém lembrando por quê.
        OutlinedButton.icon(
          onPressed: onAlternarFiltros,
          icon: Icon(
            filtrosAbertos ? Icons.filter_list_off : Icons.filter_list,
            size: 18,
          ),
          label: Text(ativos == 0
              ? context.txt.t('evid.filtros')
              : context.txt.t2('evid.filtros.ativos', {'n': '$ativos'})),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                ativos > 0 ? theme.colorScheme.primary : null,
            side: ativos > 0
                ? BorderSide(color: theme.colorScheme.primary)
                : null,
          ),
        ),
        SegmentedButton<OrdemBusca>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(
              value: OrdemBusca.relevancia,
              icon: const Icon(Icons.star_outline, size: 16),
              label: Text(context.txt.t('evid.ordenar.relevancia')),
            ),
            ButtonSegment(
              value: OrdemBusca.data,
              icon: const Icon(Icons.schedule, size: 16),
              label: Text(context.txt
                  .t(estreito ? 'evid.ordenar.data.curto' : 'evid.ordenar.data')),
            ),
          ],
          selected: {estado.ordem},
          onSelectionChanged: (s) => onOrdem(s.first),
        ),
      ],
    );
  }
}
