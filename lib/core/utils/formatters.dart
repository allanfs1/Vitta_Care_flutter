import 'package:intl/intl.dart';

/// Formatação de datas, horas e números (pt-BR).
class Fmt {
  Fmt._();

  static final _time = DateFormat('HH:mm', 'pt_BR');
  static final _dayMonth = DateFormat("d 'de' MMM", 'pt_BR');
  static final _fullDate = DateFormat("d 'de' MMMM 'de' y", 'pt_BR');
  static final _weekdayShort = DateFormat('EEE', 'pt_BR');
  static final _weekdayFull = DateFormat('EEEE', 'pt_BR');
  static final _shortDate = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _monthYear = DateFormat("MMMM 'de' y", 'pt_BR');

  static String time(DateTime d) => _time.format(d);
  static String dayMonth(DateTime d) => _dayMonth.format(d);
  static String fullDate(DateTime d) => _fullDate.format(d);
  static String shortDate(DateTime d) => _shortDate.format(d);

  /// Mês por extenso com o ano (ex.: "Junho de 2026").
  static String monthYear(DateTime d) {
    final s = _monthYear.format(d);
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  static String weekdayShort(DateTime d) {
    final s = _weekdayShort.format(d).replaceAll('.', '');
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  static String weekdayFull(DateTime d) {
    final s = _weekdayFull.format(d);
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  static String percent(num value, {int decimals = 0}) =>
      '${value.toStringAsFixed(decimals)}%';

  static String signedPercent(num value, {int decimals = 1}) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(decimals)}%';
  }

  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  static String cpfMask(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11) return digits;
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
  }
}
