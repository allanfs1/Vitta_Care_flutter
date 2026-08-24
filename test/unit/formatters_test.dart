import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vitta_app/core/utils/formatters.dart';

/// Testes unitários de formatação (datas, percentuais, durações, CPF).
void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  test('time formata HH:mm', () {
    expect(Fmt.time(DateTime(2026, 6, 24, 9, 5)), '09:05');
  });

  test('percent e signedPercent', () {
    expect(Fmt.percent(18), '18%');
    expect(Fmt.percent(18.4, decimals: 1), '18.4%');
    expect(Fmt.signedPercent(2.4), '+2.4%');
    expect(Fmt.signedPercent(-0.8), '-0.8%');
  });

  test('duration converte minutos', () {
    expect(Fmt.duration(45), '45 min');
    expect(Fmt.duration(60), '1h');
    expect(Fmt.duration(90), '1h 30min');
  });

  test('cpfMask aplica máscara', () {
    expect(Fmt.cpfMask('52998224725'), '529.982.247-25');
    expect(Fmt.cpfMask('123'), '123'); // tamanho inválido retorna original
  });

  test('weekdayShort capitaliza', () {
    final s = Fmt.weekdayShort(DateTime(2026, 6, 22)); // segunda-feira
    expect(s.isNotEmpty, true);
    expect(s[0], s[0].toUpperCase());
  });
}
