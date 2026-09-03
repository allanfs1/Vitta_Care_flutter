import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/projecao_12m/projecao_engine.dart';
import 'package:vitta_app/features/projecao_12m/projecao_models.dart';

void main() {
  test('reprimida identica entre cenarios?', () {
    for (final n in [2000, 8000]) {
      final r = ProjecaoEngine.projetar(ProjecaoConfig(nSimulacoes: n));
      // ignore: avoid_print
      print('n=$n base reprimida ${r.baseline.demandaReprimida.toMap()} '
          'agenda ${r.agendaClinica.demandaReprimida.toMap()}');
      // ignore: avoid_print
      print('   meses base=${r.baseline.mesesComDemandaReprimida} '
          'agenda=${r.agendaClinica.mesesComDemandaReprimida} '
          'pEstouro base=${r.baseline.probabilidadeEstouro} '
          'agenda=${r.agendaClinica.probabilidadeEstouro}');
      // ignore: avoid_print
      print('   agendamentos base=${r.baseline.agendamentos.toMap()} '
          'agenda=${r.agendaClinica.agendamentos.toMap()}');
    }
  });
}
