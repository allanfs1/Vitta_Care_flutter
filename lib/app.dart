import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/color_blind.dart';
import 'features/assistente/assistant_scope.dart';
import 'features/configuracoes/providers/configuracoes_provider.dart';
import 'navigation/app_router.dart';

/// Raiz do Vitta App: MaterialApp.router, tema reativo às preferências do
/// usuário (Módulo 9) e localização.
class VittaApp extends ConsumerWidget {
  const VittaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

    // Acessibilidade: escala mínima de 1.3× sobrepõe a tipografia (CFG-04b).
    final scale =
        settings.largerTouchTargets ? settings.fontScale.clamp(1.3, 1.6) : settings.fontScale;

    final supportedLocales = const [
      Locale('pt', 'BR'),
      Locale('en', 'US'),
      Locale('es', 'ES'),
    ];
    final locale = switch (settings.locale) {
      'en_US' => const Locale('en', 'US'),
      'es_ES' => const Locale('es', 'ES'),
      _ => const Locale('pt', 'BR'),
    };

    return MaterialApp.router(
      title: 'Vitta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromSettings(settings, Brightness.light),
      darkTheme: AppTheme.fromSettings(settings, Brightness.dark),
      themeMode: settings.themeMode,
      routerConfig: router,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Assistente de ajuda global (chat + spotlight), acessível em qualquer
        // tela. Fica acima do conteúdo do app.
        Widget app = AssistantScope(child: child ?? const SizedBox.shrink());
        // Filtro de daltonismo (CFG-04e).
        final filter = colorBlindMatrix(settings.colorBlindFilter);
        if (filter != null) {
          app = ColorFiltered(colorFilter: ColorFilter.matrix(filter), child: app);
        }
        // Escala de texto global (CFG-02b / CFG-04b).
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: scale,
          maxScaleFactor: scale,
          child: app,
        );
      },
    );
  }
}
