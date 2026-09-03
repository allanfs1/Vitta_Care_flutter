import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../ia/acoes_ia.dart';
import '../ia/executor_acoes.dart';
import 'mc_comuns.dart';

/// Ícone de IA ao lado de um gráfico: pede a leitura daquele gráfico.
///
/// Fica **junto do gráfico**, não numa lista distante, porque a dúvida nasce
/// olhando a figura. A resposta abre numa folha inferior em vez de empurrar o
/// conteúdo da página — quem está lendo o gráfico não perde o lugar.
class McExplicarIcone extends ConsumerWidget {
  const McExplicarIcone({
    super.key,
    required this.acaoId,
    this.dica = 'Pedir para a IA explicar este gráfico',
  });

  /// Id de uma ação de [CategoriaAcao.grafico].
  final String acaoId;

  final String dica;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(mcAcoesProvider);
    final ctrl = ref.read(mcAcoesProvider.notifier);
    final acao = AcaoIa.porId(acaoId);
    if (acao == null) return const SizedBox.shrink();

    final rodando = estado.rodando == acaoId;
    final ocupado = estado.rodando != null && !rodando;
    final motivo = ctrl.indisponivel(acao);
    final resposta = estado.respostas[acaoId];

    Future<void> abrir() async {
      if (resposta == null) await ctrl.executar(acaoId);
      if (!context.mounted) return;
      _mostrar(context, ref, acaoId);
    }

    return Tooltip(
      message: motivo ?? dica,
      waitDuration: const Duration(milliseconds: 350),
      child: Semantics(
        button: true,
        label: 'Explicar este gráfico com IA',
        child: InkWell(
          onTap: (rodando || ocupado || motivo != null) ? null : abrir,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: motivo != null
                  ? AppColors.textTertiary.withValues(alpha: 0.08)
                  : AppColors.primary.withValues(alpha: resposta != null ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(
                color: motivo != null
                    ? AppColors.textTertiary.withValues(alpha: 0.25)
                    : AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rodando)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  )
                else
                  Icon(
                    resposta != null
                        ? Icons.auto_awesome
                        : Icons.auto_awesome_outlined,
                    size: 13,
                    color: motivo != null
                        ? AppColors.textTertiary
                        : AppColors.primary,
                  ),
                const SizedBox(width: 5),
                Text(
                  rodando
                      ? 'Lendo…'
                      : (resposta != null ? 'Leitura' : 'Explicar'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: motivo != null
                        ? AppColors.textTertiary
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _mostrar(BuildContext context, WidgetRef ref, String acaoId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _Folha(acaoId: acaoId),
    );
  }
}

class _Folha extends ConsumerWidget {
  const _Folha({required this.acaoId});
  final String acaoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(mcAcoesProvider);
    final ctrl = ref.read(mcAcoesProvider.notifier);
    final acao = AcaoIa.porId(acaoId);
    final resposta = estado.respostas[acaoId];
    final rodando = estado.rodando == acaoId;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      acao?.titulo ?? 'Leitura da IA',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: -0.2,
                        color: dark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!rodando)
                    IconButton(
                      onPressed: () => ctrl.executar(acaoId),
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: 'Pedir outra leitura',
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: SingleChildScrollView(
                  child: rodando
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2),
                                ),
                                SizedBox(height: AppSpacing.md),
                                Text('Lendo os números do gráfico…',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        )
                      : _Corpo(resposta: resposta),
                ),
              ),
              if (resposta != null && !resposta.falhou) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'A IA recebeu os números já calculados — ela '
                        'interpreta, não conta.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.4,
                          color: dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: resposta.texto));
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Texto copiado.'),
                          ));
                      },
                      icon: const Icon(Icons.copy_all_outlined, size: 15),
                      label: const Text('Copiar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Corpo extends StatelessWidget {
  const _Corpo({required this.resposta});
  final RespostaAcao? resposta;

  @override
  Widget build(BuildContext context) {
    final r = resposta;
    if (r == null) {
      return const McAviso(
        texto: 'Nenhuma leitura ainda. Toque em atualizar para pedir uma.',
      );
    }
    if (r.falhou) {
      return McAviso(
        icone: Icons.error_outline,
        cor: AppColors.danger,
        texto: 'A IA não respondeu: ${r.erro}. Os números do gráfico '
            'continuam válidos — só a leitura falhou.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          r.texto,
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        if (r.aviso != null) ...[
          const SizedBox(height: AppSpacing.md),
          McAviso(
            icone: Icons.warning_amber_outlined,
            cor: AppColors.warning,
            texto: r.aviso!,
          ),
        ],
      ],
    );
  }
}
