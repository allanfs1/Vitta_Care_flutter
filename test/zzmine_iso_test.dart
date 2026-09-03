import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/projecao_12m/risco_calibracao.dart';

void main() {
  test('exporta isotonica para comparar com sklearn', () {
    final dados = jsonDecode(File('build/iso_in.json').readAsStringSync())
        as Map<String, dynamic>;
    final saida = <String, List<double>>{};
    for (final caso in dados.keys) {
      final c = dados[caso] as Map<String, dynamic>;
      final x = (c['x'] as List).map((e) => (e as num).toDouble()).toList();
      final y = (c['y'] as List).map((e) => e as num).toList();
      final grade = (c['grade'] as List).map((e) => (e as num).toDouble()).toList();
      final cal = CalibradorIsotonico.ajustar(x, y);
      saida[caso] = cal.aplicarTodos(grade);
    }
    File('build/iso_out.json').writeAsStringSync(jsonEncode(saida));
  });
}
