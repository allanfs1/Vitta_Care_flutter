import 'package:flutter/foundation.dart';

import '../../core/models/doctor.dart';
import 'monte_carlo_engine.dart';
import 'monte_carlo_models.dart';

/// Entrada da simulação em outro isolate. Só tipos simples atravessam a
/// fronteira — [Doctor] fica para trás, resolvido em capacidades e nomes antes
/// do envio.
@immutable
class EntradaSimulacao {
  const EntradaSimulacao({
    required this.data,
    required this.consultas,
    required this.capacidades,
    required this.nomes,
    required this.config,
  });

  final DateTime data;
  final List<ConsultaRisco> consultas;
  final Map<String, List<int>> capacidades;
  final Map<String, String> nomes;
  final SimulacaoConfig config;
}

/// Função de topo executada no isolate. Precisa ser estática/top-level para
/// `compute` conseguir referenciá-la.
SimulacaoResultado rodarSimulacao(EntradaSimulacao e) =>
    MonteCarloEngine.simular(
      data: e.data,
      consultas: e.consultas,
      capacidades: e.capacidades,
      nomes: e.nomes,
      config: e.config,
    );

/// Roda a simulação fora da thread de UI.
///
/// Usa `compute`, que no nativo abre um isolate de verdade e **na web roda no
/// mesmo isolate** — a web não tem `dart:isolate`. Por isso o caminho rápido
/// abaixo importa: quando a carga é pequena (ou exata), não vale pagar o custo
/// de serialização, e na web isso evita um `await` que não traria ganho nenhum.
class MonteCarloIsolate {
  const MonteCarloIsolate._();

  /// Acima deste número de amostras individuais a simulação sai da thread de UI.
  /// `nRuns * consultas` é o que de fato custa.
  static const int limiarTrabalho = 400000;

  static Future<SimulacaoResultado> simular({
    required DateTime data,
    required List<ConsultaRisco> consultas,
    required List<Doctor> medicos,
    SimulacaoConfig config = const SimulacaoConfig(),
  }) async {
    // O caminho exato não amostra nada: é convolução, microssegundos.
    final trabalho = config.independente
        ? 0
        : config.nRuns * consultas.length;

    if (trabalho < limiarTrabalho || kIsWeb) {
      // Sem `Future.delayed` de propósito: ele cria um `Timer`, e um timer
      // pendente sobrevive à árvore de widgets em teste. O caminho exato custa
      // microssegundos; na web, onde não há isolate, a amostragem pesada trava
      // o frame — o preço de a web não ter `dart:isolate`. Reduzir `nRuns` é a
      // saída enquanto a simulação não for fatiada entre frames.
      return MonteCarloEngine.simular(
        data: data,
        consultas: consultas,
        medicos: medicos,
        config: config,
      );
    }

    final entrada = EntradaSimulacao(
      data: data,
      consultas: consultas,
      capacidades: MonteCarloEngine.mapaCapacidades(
          data: data, consultas: consultas, medicos: medicos),
      nomes: MonteCarloEngine.mapaNomes(medicos),
      config: config,
    );

    return compute(rodarSimulacao, entrada, debugLabel: 'monte-carlo');
  }
}
