import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/idioma.dart';
import 'core/i18n/textos.dart';
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

    // A lista e o mapeamento vivem em `Idioma`: acrescentar um idioma passa a
    // ser um item de enum mais um mapa de textos, e não uma edição em três
    // lugares que é fácil deixar pela metade.
    final idioma = Idioma.daChave(settings.locale);

    return MaterialApp.router(
      title: 'Vitta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromSettings(settings, Brightness.light),
      darkTheme: AppTheme.fromSettings(settings, Brightness.dark),
      themeMode: settings.themeMode,
      routerConfig: router,
      locale: idioma.locale,
      supportedLocales: Idioma.values.map((i) => i.locale),
      localizationsDelegates: const [
        // Sem este primeiro delegate, trocar o idioma só mudava os rótulos dos
        // widgets do Material (datas, "OK"/"Cancelar" dos diálogos) — o texto
        // do próprio app continuava em português. É ele que faz a preferência
        // de idioma valer para o produto.
        Textos.delegate,
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
