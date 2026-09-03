import 'package:flutter/widgets.dart';

/// Idiomas que o app oferece.
///
/// A lista é curta de propósito: cada idioma novo é um compromisso de manter
/// **todas** as chaves traduzidas para sempre. Três idiomas cobrem o público
/// real do produto (Brasil, mercado hispânico, literatura internacional).
enum Idioma {
  pt('pt_BR', Locale('pt', 'BR'), 'Português (Brasil)', '🇧🇷'),
  en('en_US', Locale('en', 'US'), 'English (US)', '🇺🇸'),
  es('es_ES', Locale('es', 'ES'), 'Español', '🇪🇸');

  const Idioma(this.chave, this.locale, this.rotulo, this.bandeira);

  /// Valor guardado em `AppSettings.locale`.
  final String chave;
  final Locale locale;
  final String rotulo;
  final String bandeira;

  /// Código ISO de duas letras — é o que o modelo entende ao traduzir.
  String get iso => locale.languageCode;

  /// Nome do idioma **em inglês**, para instruir o modelo de tradução.
  /// Pedir "traduza para Português (Brasil)" em português funciona pior que
  /// pedir em inglês, que é como o modelo foi majoritariamente treinado.
  String get nomeIngles => switch (this) {
        pt => 'Brazilian Portuguese',
        en => 'English',
        es => 'Spanish',
      };

  static Idioma daChave(String? chave) => Idioma.values.firstWhere(
        (i) => i.chave == chave,
        orElse: () => Idioma.pt,
      );

  /// Resolve a partir de um `Locale` do sistema, caindo em [pt] quando o
  /// idioma não é oferecido.
  static Idioma doLocale(Locale? l) {
    if (l == null) return Idioma.pt;
    return Idioma.values.firstWhere(
      (i) => i.locale.languageCode == l.languageCode,
      orElse: () => Idioma.pt,
    );
  }
}
