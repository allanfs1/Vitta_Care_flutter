import 'package:flutter/material.dart';

import '../../../core/i18n/textos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../configuracoes/providers/configuracoes_provider.dart';

/// Layout responsivo das telas de autenticação (login/cadastro/plano).
/// Mobile: formulário em tela cheia. Desktop/Web: painel de marca + formulário.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.maxWidth = 460,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (Responsive.isMobile(context)) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: _Logo(height: 120),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xl),
              child,
            ],
          ),
        ),
      ),
    );

    if (Responsive.isMobile(context)) {
      return Scaffold(body: SafeArea(child: form));
    }

    return Scaffold(
      body: Row(
        children: [
          Expanded(child: _BrandPanel()),
          Expanded(child: form),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      // O painel tem altura natural fixa (logo + título + bullets) e transborda
      // em janelas baixas — eram os 4 px de overflow em telas de 600 px. Rolar
      // quando não cabe resolve para qualquer altura, e o `minHeight` mantém a
      // composição centralizada quando cabe, que é o caso comum.
      child: LayoutBuilder(
        builder: (context, restricoes) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: restricoes.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Logo(height: 180, light: true),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Cuidado, inovação e eficiência para a sua clínica.',
                  style:
                      theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.lg),
                ..._bullets(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _bullets(ThemeData theme) {
    const items = [
      'Dashboards e KPIs em tempo real',
      'IA contra o absenteísmo',
      'Confirmações via WhatsApp',
    ];
    return [
      for (final i in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(i,
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
    ];
  }
}

/// Logotipo do app: usa o logo personalizado das configurações se houver,
/// senão o asset; com fallback (ícone) caso a imagem não carregue.
class _Logo extends ConsumerWidget {
  const _Logo({this.height = 160, this.light = false});

  final double height;
  final bool light;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = light ? Colors.white : AppColors.primary;
    final custom = ref.watch(settingsProvider).logoBytes;
    if (custom != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height, maxWidth: height * 5),
        child: Image.memory(custom, height: height, fit: BoxFit.contain),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height, maxWidth: height * 5),
      child: Image.asset(
        'assets/images/logo.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, color: color, size: height * 0.7),
            const SizedBox(width: 8),
            Text(context.txt.t('auth.vitta'),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
