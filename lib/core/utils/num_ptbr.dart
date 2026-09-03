/// Formatação numérica pt-BR sem depender de `intl` no caminho quente.
///
/// `toStringAsFixed` devolve `0.90` — separador decimal de outra língua no meio
/// de uma tela em português. Aqui é `0,90`, e milhar com ponto.
class NumPtBr {
  const NumPtBr._();

  static String dec(num v, {int casas = 2}) {
    if (v.isNaN) return '—';
    if (v.isInfinite) return v.isNegative ? '−∞' : '∞';
    return v.toStringAsFixed(casas).replaceAll('.', ',');
  }

  /// Fração 0–1 para percentual.
  static String pct(num fracao, {int casas = 1}) =>
      fracao.isNaN ? '—' : '${dec(fracao * 100, casas: casas)}%';

  /// Valor já em escala 0–100.
  static String pctDireto(num v, {int casas = 1}) =>
      v.isNaN ? '—' : '${dec(v, casas: casas)}%';

  static String inteiro(num v) {
    if (v.isNaN) return '—';
    final s = v.round().abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${v < 0 ? '−' : ''}$buf';
  }

  static String reais(num v) => 'R\$ ${inteiro(v)}';

  /// Reais com centavos — para valores unitários.
  static String reaisExato(num v) {
    final neg = v < 0;
    final abs = v.abs();
    final centavos = ((abs - abs.floor()) * 100).round();
    return '${neg ? '−' : ''}R\$ ${inteiro(abs.floor())},'
        '${centavos.toString().padLeft(2, '0')}';
  }

  static String vezes(num v, {int casas = 2}) => '${dec(v, casas: casas)}x';
}
