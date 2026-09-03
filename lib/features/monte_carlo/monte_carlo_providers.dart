import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/appointment.dart';

import '../../core/services/app_providers.dart';
import 'monte_carlo_calibracao.dart';
import 'monte_carlo_engine.dart';
import 'monte_carlo_historico_demo.dart';
import 'monte_carlo_isolate.dart';
import 'monte_carlo_models.dart';
import 'monte_carlo_persistencia.dart';

/// Marca que o simulador foi aberto nesta sessão.
///
/// A ponte no painel de Overbooking só mostra números depois disso. Sem essa
/// guarda, abrir o Overbooking dispararia uma simulação inteira como efeito
/// colateral — trabalho caro que ninguém pediu, e que na web trava o frame.
final mcSessaoAtivaProvider = StateProvider<bool>((ref) => false);

/// Data avaliada pelo simulador (◀ Hoje ▶).
final mcDataProvider = StateProvider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

/// Configuração da simulação. `rho = 0` reproduz o modelo independente.
final mcConfigProvider =
    StateProvider<SimulacaoConfig>((ref) => const SimulacaoConfig());

/// Valor médio do slot, usado para converter ociosidade em receita.
final mcValorSlotProvider = StateProvider<double>((ref) => 180.0);

/// Risco de estouro tolerado por slot. A decisão é limitada pelo pior slot.
final mcLimiteRiscoProvider = StateProvider<double>((ref) => 0.05);

/// Teto da razão de exposição entre faixas de risco. Acima disso o cenário é
/// reprovado mesmo que o risco de estouro esteja dentro do limite.
final mcLimiteEquidadeProvider = StateProvider<double>((ref) => 1.25);

/// Efeito da intervenção (lembrete/confirmação) como razão de chances.
/// `1,0` = sem intervenção; abaixo disso reduz a chance de falta.
final mcOddsRatioProvider = StateProvider<double>((ref) => 1.0);

/// Consultas do dia com probabilidades atribuídas.
///
/// Puramente derivado dos providers de agenda: não toca em Firestore e por isso
/// funciona igual no modo demonstração.
final mcConsultasProvider = Provider<List<ConsultaRisco>>((ref) {
  final data = ref.watch(mcDataProvider);
  final config = ref.watch(mcConfigProvider);
  final odds = ref.watch(mcOddsRatioProvider);
  final agendamentos = ref.watch(appointmentsProvider);

  return MonteCarloEngine.montarConsultas(
    data: data,
    agendamentos: agendamentos,
    modelo: config.modeloRisco,
    oddsRatioIntervencao: odds,
  );
});

/// Resultado da simulação, fora da thread de UI quando a carga justifica.
final mcResultadoProvider = FutureProvider<SimulacaoResultado>((ref) async {
  final data = ref.watch(mcDataProvider);
  final config = ref.watch(mcConfigProvider);
  final consultas = ref.watch(mcConsultasProvider);
  final medicos =
      ref.watch(clinicDoctorsProvider).where((d) => d.active).toList();

  return MonteCarloIsolate.simular(
    data: data,
    consultas: consultas,
    medicos: medicos,
    config: config,
  );
});

/// Varredura de cenários de overbooking (0..6 encaixes).
///
/// Todos os cenários são lidos da MESMA simulação — números aleatórios comuns
/// de graça: a comparação entre eles não carrega ruído de amostragem.
final mcCenariosProvider = Provider<List<CenarioOverbooking>>((ref) {
  final r = ref.watch(mcResultadoProvider).valueOrNull;
  if (r == null) return const [];
  return MonteCarloEngine.varrerCenarios(
    r,
    limiteRisco: ref.watch(mcLimiteRiscoProvider),
    valorSlot: ref.watch(mcValorSlotProvider),
    limiteEquidade: ref.watch(mcLimiteEquidadeProvider),
  );
});

/// Encaixes recomendados: o maior k que mantém todos os slots dentro do limite
/// de risco **e** dentro do limite de equidade.
final mcEncaixesRecomendadosProvider = Provider<int>((ref) {
  final r = ref.watch(mcResultadoProvider).valueOrNull;
  if (r == null) return 0;
  return MonteCarloEngine.encaixesRecomendados(
    r,
    limiteRisco: ref.watch(mcLimiteRiscoProvider),
    limiteEquidade: ref.watch(mcLimiteEquidadeProvider),
  );
});

// ── Calibração (F2) ───────────────────────────────────────────

/// Janela de histórico usada na calibração, em dias.
final mcJanelaCalibracaoProvider = StateProvider<int>((ref) => 180);

/// Histórico de agendamentos para calibração (fase F2).
///
/// **Com Firebase ativo**: chama `carregarHistoricoCalibracao` — uma query
/// dedicada e paginada que cobre os últimos [mcJanelaCalibracaoProvider] dias
/// de `tb_agendamentos`, enriquecida com risco de `tb_faltas_data` /
/// `dashboard_risco`. Resolve os 3 bloqueios da tela de Calibração:
///   1. Histórico curto (< 30 dias): agenda ao vivo não tem retroativo.
///   2. Risco em faixa única: `tb_agendamentos` não guarda risco; a busca
///      cruza com `tb_faltas_data` que é onde o risco de fato vive.
///   3. Base só de fracasso: infere `completed` para confirmados passados.
///
/// **Modo offline/demo**: composta com `HistoricoDemo`, mantendo
/// a aba exercitável e os ids prefixados `hist_demo_`.
final mcHistoricoProvider = FutureProvider<List<Appointment>>((ref) async {
  final janela = ref.watch(mcJanelaCalibracaoProvider);
  final firebaseAtivo = ref.watch(firebaseEnabledProvider);

  if (firebaseAtivo) {
    final clinicId = ref.watch(clinicaResolvidaProvider);
    if (clinicId.isNotEmpty) {
      final service = ref.watch(appointmentServiceProvider);
      try {
        final historico = await service.carregarHistoricoCalibracao(
          clinicId,
          dias: janela,
        );
        // Se o Firestore retornou dados, usa-os sozinhos.
        if (historico.isNotEmpty) return historico;
      } catch (_) {
        // Falha de rede/permissão: cai para a agenda operacional ao vivo.
      }
    }
    // Fallback: agenda ao vivo (comportamento anterior).
    return ref.watch(appointmentsProvider);
  }

  // Offline/demo: agenda mock + histórico sintético.
  final agenda = ref.watch(appointmentsProvider);
  final clinicId = agenda.isEmpty ? 'c1' : agenda.first.clinicId;
  return [...agenda, ...HistoricoDemo.gerar(clinicId: clinicId)];
});

/// `true` quando a calibração está rodando sobre histórico sintético.
final mcHistoricoEhDemoProvider = Provider<bool>(
    (ref) => !ref.watch(firebaseEnabledProvider));

final mcCalibracaoProvider = FutureProvider<CalibracaoResultado>((ref) async {
  // Aguarda o histórico (pode ser uma query ao Firestore quando Firebase ativo).
  final historico = await ref.watch(mcHistoricoProvider.future);
  final janela = ref.watch(mcJanelaCalibracaoProvider);

  await Future<void>.delayed(Duration.zero);

  return MonteCarloCalibracao.estimar(
    historico: historico,
    janelaDias: janela,
  );
});

/// Aplica o resultado da calibração à configuração ativa.
///
/// Deliberadamente **manual**: trocar as taxas e o rho embaixo de quem está
/// olhando a tela mudaria a recomendação sem aviso. A calibração propõe; a
/// pessoa aceita.
void aplicarCalibracao(WidgetRef ref, CalibracaoResultado c) {
  final atual = ref.read(mcConfigProvider);
  ref.read(mcConfigProvider.notifier).state = atual.copyWith(
    modeloRisco: c.modeloCalibrado,
    rho: c.rhoEstimado,
  );
}

// ── Persistência (F3) ─────────────────────────────────────────────────

/// Repositório do simulador. Padrão: mock (offline).
///
/// Em `main` é sobrescrito por [FirestoreMonteCarloRepositorio] com Firebase
/// ativo — mesmo padrão de `realocacaoServiceProvider`. A implementação recusa
/// `clinicId` vazio: sem tenant resolvido nada é gravado, porque gravar na
/// clínica errada é pior do que não gravar.
final mcRepositorioProvider =
    Provider<MonteCarloRepositorio>((ref) => const MockMonteCarloRepositorio());
