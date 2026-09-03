import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../../ia/agent/ai_agent_service.dart';
import '../monte_carlo_engine.dart';
import '../monte_carlo_providers.dart';
import 'agente_simulacao.dart';
import 'plano_semanal.dart';

/// Estado do planejador automático.
///
/// A varredura roda **sob demanda**, nunca ao abrir a tela: são N simulações
/// de Monte Carlo seguidas, e disparar isso sozinho faria a aba engasgar sem
/// que ninguém tivesse pedido nada.
enum FasePlano { ocioso, simulando, interpretando, pronto, erro }

class EstadoPlano {
  const EstadoPlano({
    this.fase = FasePlano.ocioso,
    this.plano,
    this.sugestao,
    this.erro,
    this.diaAtual = 0,
    this.diasTotal = 0,
    this.janelaDias = 7,
  });

  final FasePlano fase;

  /// Os números. Existem mesmo quando a IA falha.
  final PlanoSemanal? plano;

  /// A leitura da IA sobre os números. Pode faltar.
  final SugestaoPlano? sugestao;

  final String? erro;

  /// Progresso da varredura — a espera é longa o bastante para precisar dele.
  final int diaAtual;
  final int diasTotal;

  final int janelaDias;

  bool get rodando =>
      fase == FasePlano.simulando || fase == FasePlano.interpretando;
  bool get temPlano => plano != null && !plano!.vazio;

  double get progresso =>
      diasTotal == 0 ? 0 : (diaAtual / diasTotal).clamp(0.0, 1.0);

  EstadoPlano copyWith({
    FasePlano? fase,
    PlanoSemanal? plano,
    SugestaoPlano? sugestao,
    String? erro,
    bool limparErro = false,
    int? diaAtual,
    int? diasTotal,
    int? janelaDias,
  }) =>
      EstadoPlano(
        fase: fase ?? this.fase,
        plano: plano ?? this.plano,
        sugestao: sugestao ?? this.sugestao,
        erro: limparErro ? null : (erro ?? this.erro),
        diaAtual: diaAtual ?? this.diaAtual,
        diasTotal: diasTotal ?? this.diasTotal,
        janelaDias: janelaDias ?? this.janelaDias,
      );
}

final agenteSimulacaoProvider = Provider<AgenteSimulacao>(
  (ref) => AgenteSimulacao(ia: AiAgentService()),
);

final planoSemanalProvider =
    StateNotifierProvider<PlanoNotifier, EstadoPlano>((ref) {
  return PlanoNotifier(ref);
});

class PlanoNotifier extends StateNotifier<EstadoPlano> {
  PlanoNotifier(this._ref) : super(const EstadoPlano());

  final Ref _ref;

  void janela(int dias) => state = state.copyWith(janelaDias: dias);

  /// Roda a varredura e depois pede a leitura da IA.
  ///
  /// As duas fases são separadas na tela de propósito: os números aparecem
  /// assim que saem, e a análise chega depois. Esperar a IA para mostrar a
  /// simulação faria o gestor olhar um spinner por causa de um texto que é
  /// complemento, não o produto.
  Future<void> gerar({DateTime? inicio}) async {
    if (state.rodando) return;

    final dias = state.janelaDias;
    final base = inicio ?? DateTime.now();
    final comeco = DateTime(base.year, base.month, base.day);

    state = state.copyWith(
      fase: FasePlano.simulando,
      limparErro: true,
      diaAtual: 0,
      diasTotal: dias,
    );

    final executor = ExecutorPlano(
      limiteRisco: _ref.read(mcLimiteRiscoProvider),
      limiteEquidade: _ref.read(mcLimiteEquidadeProvider),
      valorSlot: _ref.read(mcValorSlotProvider),
    );

    final config = _ref.read(mcConfigProvider);
    final odds = _ref.read(mcOddsRatioProvider);
    final agendamentos = _ref.read(appointmentsProvider);
    final medicos =
        _ref.read(clinicDoctorsProvider).where((d) => d.active).toList();

    PlanoSemanal plano;
    try {
      var feitos = 0;
      plano = executor.montar(
        inicio: comeco,
        dias: dias,
        consultasDe: (d) => MonteCarloEngine.montarConsultas(
          data: d,
          agendamentos: agendamentos,
          modelo: config.modeloRisco,
          oddsRatioIntervencao: odds,
        ),
        simular: (d, consultas) {
          final r = MonteCarloEngine.simular(
            data: d,
            consultas: consultas,
            medicos: medicos,
            config: config,
          );
          feitos++;
          if (mounted) state = state.copyWith(diaAtual: feitos);
          return r;
        },
      );
    } catch (e) {
      state = state.copyWith(fase: FasePlano.erro, erro: '$e');
      return;
    }

    if (!mounted) return;
    state = state.copyWith(
      fase: FasePlano.interpretando,
      plano: plano,
      diaAtual: dias,
    );

    final sugestao = await _ref.read(agenteSimulacaoProvider).interpretar(plano);
    if (!mounted) return;
    state = state.copyWith(fase: FasePlano.pronto, sugestao: sugestao);
  }

  void limpar() => state = EstadoPlano(janelaDias: state.janelaDias);
}
