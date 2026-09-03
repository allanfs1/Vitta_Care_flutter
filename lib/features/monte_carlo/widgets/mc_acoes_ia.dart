import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../ia/acoes_ia.dart';
import '../ia/executor_acoes.dart';
import 'mc_comuns.dart';

/// Painel de ações de IA do simulador.
///
/// Um catálogo em vez de um chat livre. Chat aberto sobre uma tela de números
/// convida a pergunta que o modelo não pode responder — "quantos encaixes eu
/// abro?" respondido de cabeça, sem rodar a simulação. Cada ação aqui recebe o
/// resultado já calculado e só escreve a leitura.
class McAcoesIa extends ConsumerWidget {
  const McAcoesIa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(mcAcoesProvider);
    final ctrl = ref.read(mcAcoesProvider.notifier);

    // `AcaoIa.lista`, não `catalogo`: as ações de gráfico ficam só no ícone ao
    // lado de cada gráfico — listá-las aqui também duplicaria a oferta.
    final porCategoria = <CategoriaAcao, List<AcaoIa>>{};
    for (final a in AcaoIa.lista) {
      porCategoria.putIfAbsent(a.categoria, () => []).add(a);
    }

    return McCartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          McTitulo(
            titulo: 'O que a IA pode ler para você',
            sub: '${AcaoIa.lista.length} leituras sobre a simulação desta '
                'data. Cada uma recebe os números já calculados — a IA '
                'interpreta, não conta.',
            acao: estado.respostas.isEmpty
                ? null
                : TextButton.icon(
                    onPressed: ctrl.limparTudo,
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Limpar'),
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final cat in CategoriaAcao.values)
            if (porCategoria[cat] != null)
              _Grupo(
                categoria: cat,
                acoes: porCategoria[cat]!,
                estado: estado,
                onExecutar: ctrl.executar,
                indisponivel: ctrl.indisponivel,
              ),
          const SizedBox(height: AppSpacing.xs),
          const McAviso(
            icone: Icons.shield_outlined,
            texto: 'Toda cifra do texto é conferida contra a simulação. O que '
                'não veio dela aparece marcado com ⚠️ — e nenhuma ação daqui '
                'altera a agenda.',
          ),
        ],
      ),
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({
    required this.categoria,
    required this.acoes,
    required this.estado,
    required this.onExecutar,
    required this.indisponivel,
  });

  final CategoriaAcao categoria;
  final List<AcaoIa> acoes;
  final EstadoAcoes estado;
  final void Function(String) onExecutar;
  final String? Function(AcaoIa) indisponivel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(categoria.icone, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(categoria.label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary)),
            ],
          ),
        ),
        for (final a in acoes)
          _Acao(
            acao: a,
            resposta: estado.respostas[a.id],
            rodando: estado.rodando == a.id,
            bloqueado: estado.rodando != null && estado.rodando != a.id,
            motivo: indisponivel(a),
            onExecutar: () => onExecutar(a.id),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _Acao extends StatelessWidget {
  const _Acao({
    required this.acao,
    required this.resposta,
    required this.rodando,
    required this.bloqueado,
    required this.motivo,
    required this.onExecutar,
  });

  final AcaoIa acao;
  final RespostaAcao? resposta;
  final bool rodando;
  final bool bloqueado;
  final String? motivo;
  final VoidCallback onExecutar;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final indisponivel = motivo != null;
    final habilitado = !rodando && !bloqueado && !indisponivel;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: rodando
              ? AppColors.primary.withValues(alpha: 0.5)
              : (dark ? AppColors.borderDark : AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(acao.icone,
                  size: 17,
                  color: indisponivel
                      ? AppColors.textTertiary
                      : AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(acao.titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: indisponivel
                              ? AppColors.textTertiary
                              : (dark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary),
                        )),
                    const SizedBox(height: 2),
                    Text(acao.descricao,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (rodando)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton.tonal(
                  onPressed: habilitado ? onExecutar : null,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(resposta != null ? 'Refazer' : 'Ler'),
                ),
            ],
          ),
          if (indisponivel) ...[
            const SizedBox(height: AppSpacing.sm),
            McAviso(icone: Icons.block, texto: motivo!),
          ],
          if (resposta != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Resposta(resposta: resposta!),
          ],
        ],
      ),
    );
  }
}

class _Resposta extends StatelessWidget {
  const _Resposta({required this.resposta});
  final RespostaAcao resposta;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (resposta.falhou) {
      return McAviso(
        icone: Icons.error_outline,
        cor: AppColors.danger,
        texto: 'A IA não respondeu: ${resposta.erro}. Os números da simulação '
            'continuam válidos — só a leitura falhou.',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: resposta.temAviso
              ? AppColors.warning.withValues(alpha: 0.45)
              : (dark ? AppColors.borderDark : AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            resposta.texto,
            style: const TextStyle(fontSize: 12.5, height: 1.55),
          ),
          if (resposta.aviso != null) ...[
            const SizedBox(height: AppSpacing.sm),
            McAviso(
              icone: Icons.warning_amber_outlined,
              cor: AppColors.warning,
              texto: resposta.aviso!,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                'Leitura de IA · ${_hora(resposta.em)}',
                style: const TextStyle(
                    fontSize: 10.5, color: AppColors.textTertiary),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: resposta.texto));
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Texto copiado.'),
                    ));
                },
                icon: const Icon(Icons.copy_all_outlined, size: 15),
                label: const Text('Copiar'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
