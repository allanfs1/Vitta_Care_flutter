import 'package:flutter/widgets.dart';

import 'idioma.dart';
import 'textos_en.dart';
import 'textos_es.dart';
import 'textos_pt.dart';

/// Strings da interface, por idioma.
///
/// ## Por que mapas em Dart e não ARB com codegen
///
/// `gen_l10n` é o caminho padrão do Flutter e o formato que tradutores humanos
/// esperam. Ficou de fora por três motivos concretos deste projeto:
///
/// 1. **Não há etapa de codegen no build.** Introduzir uma faz `flutter test`
///    e a CI dependerem de rodar `gen-l10n` antes — um modo de falha novo, e
///    silencioso (a mensagem some, não quebra).
/// 2. **Falta de chave precisa ser visível, não fatal.** Aqui, chave ausente
///    cai no português e o app segue; com codegen, o build quebra ou a string
///    vira vazia.
/// 3. **A tradução dinâmica é o recurso principal.** O que o médico mais
///    precisa traduzido é o *conteúdo* (resumo em inglês), não o rótulo do
///    botão — e isso é IA em tempo de execução, não ARB.
///
/// Migrar para ARB depois é mecânico: as chaves já estão nomeadas e agrupadas.
///
/// ## Português é a fonte da verdade
///
/// [textosPt] é o mapa completo; os outros podem estar incompletos sem quebrar
/// nada — [Textos.t] cai no português quando falta a chave. Isso torna
/// possível traduzir por partes, em vez de exigir que os três idiomas andem
/// juntos a cada string nova. O teste `traducoes_test` mostra o que falta.
class Textos {
  const Textos(this.idioma);

  final Idioma idioma;

  static const LocalizationsDelegate<Textos> delegate = _TextosDelegate();

  /// Acesso a partir do contexto. Cai no português quando o delegate não está
  /// instalado — em teste de widget isolado, por exemplo.
  static Textos de(BuildContext context) =>
      Localizations.of<Textos>(context, Textos) ?? const Textos(Idioma.pt);

  Map<String, String> get _mapa => switch (idioma) {
        Idioma.pt => textosPt,
        Idioma.en => textosEn,
        Idioma.es => textosEs,
      };

  /// Texto da [chave]. Sem tradução, devolve o português; sem português,
  /// devolve a própria chave — assim uma chave errada aparece na tela em vez
  /// de virar um espaço em branco que ninguém nota.
  String t(String chave) => _mapa[chave] ?? textosPt[chave] ?? chave;

  /// Texto com substituição de marcadores: `t2('x', {'n': '3'})` troca `{n}`.
  String t2(String chave, Map<String, String> valores) {
    var s = t(chave);
    valores.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  /// Escolhe entre singular e plural pela contagem, e substitui `{n}`.
  ///
  /// Regra simples (n == 1 → singular) — suficiente para pt/en/es. Idiomas com
  /// plural complexo (russo, polonês, árabe) precisariam de CLDR; quando algum
  /// entrar, é aqui que muda.
  String plural(int n, String chaveUm, String chaveMuitos) =>
      t2(n == 1 ? chaveUm : chaveMuitos, {'n': '$n'});
}

class _TextosDelegate extends LocalizationsDelegate<Textos> {
  const _TextosDelegate();

  @override
  bool isSupported(Locale locale) =>
      Idioma.values.any((i) => i.locale.languageCode == locale.languageCode);

  @override
  Future<Textos> load(Locale locale) async =>
      Textos(Idioma.doLocale(locale));

  @override
  bool shouldReload(_TextosDelegate old) => false;
}

/// Atalho: `context.txt.t('evidencias.titulo')`.
extension TextosContext on BuildContext {
  Textos get txt => Textos.de(this);
}
