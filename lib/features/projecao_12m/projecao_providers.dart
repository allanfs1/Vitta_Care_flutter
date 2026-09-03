import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_providers.dart';
import 'markov_engine.dart';
import 'partida_a_frio.dart';
import 'piloto_poder.dart';
import 'projecao_engine.dart';
import 'projecao_models.dart';

/// Configuração da projeção.
final projConfigProvider =
    StateProvider<ProjecaoConfig>((ref) => const ProjecaoConfig());

/// Resultado dos dois cenários.
///
/// `FutureProvider` porque a simulação percorre `nSimulacoes × horizonte` —
/// alguns milhões de operações no padrão. Sem ceder o frame, a troca de um
/// slider travaria a interface.
final projResultadoProvider = FutureProvider<ProjecaoResultado>((ref) async {
  final config = ref.watch(projConfigProvider);
  await Future<void>.delayed(Duration.zero);
  return ProjecaoEngine.projetar(config);
});

/// Matriz de referência sob a intervenção ativa — alimenta o diagrama.
final projMatrizProvider = Provider<MatrizTransicao>((ref) {
  final c = ref.watch(projConfigProvider);
  return MarkovEngine.aplicarIntervencao(
    MarkovEngine.referencia(),
    reducaoFalta: c.intervencao.reducaoFalta,
    reducaoCancelamento: c.intervencao.reducaoCancelamento,
    deltaConfirmacao: c.intervencao.deltaConfirmacao,
  );
});

/// Volume mensal observado na agenda da clínica, quando houver.
///
/// Serve de sugestão para o campo de agendamentos mensais — a projeção usa o
/// que a pessoa confirmar, não o que o app adivinhou.
final projVolumeObservadoProvider = Provider<int?>((ref) {
  final agendamentos = ref.watch(appointmentsProvider);
  if (agendamentos.length < 10) return null;

  final meses = <String>{};
  for (final a in agendamentos) {
    meses.add('${a.start.year}-${a.start.month}');
  }
  if (meses.isEmpty) return null;
  return (agendamentos.length / meses.length).round();
});

/// Meses de agenda que a clínica tem registrados, e quantos desfechos já
/// fecharam.
///
/// Serve à partida a frio: com pouco histórico, o shrinkage precisa puxar para
/// o cohort e a faixa precisa permanecer larga. Devolve `null` quando não há
/// agenda o bastante para afirmar qualquer coisa — e nesse caso a tela mostra o
/// caso "sem histórico", que é a resposta honesta.
final projHistoricoObservadoProvider =
    Provider<({int meses, int desfechos})?>((ref) {
  final agendamentos = ref.watch(appointmentsProvider);
  if (agendamentos.isEmpty) return null;

  final meses = <String>{};
  var desfechos = 0;
  final agora = DateTime.now();
  for (final a in agendamentos) {
    meses.add('${a.start.year}-${a.start.month}');
    // Só agendamento já passado sustenta estimativa de taxa: agendamento
    // futuro não tem desfecho, e contá-lo inflaria a força do prior.
    if (a.start.isBefore(agora)) desfechos++;
  }
  return (meses: meses.length, desfechos: desfechos);
});

/// Dimensionamento do piloto para o volume configurado.
final projPilotoProvider = Provider<ViabilidadePiloto>((ref) {
  final c = ref.watch(projConfigProvider);
  return PoderPiloto.avaliar(
    agendamentosPorMes: c.agendamentosMensais,
    mesesDisponiveis: 3,
    reducaoRelativa: c.intervencao.reducaoFalta,
    taxaBase: c.taxaFalta,
  );
});

/// Ajustes que a maturidade do histórico impõe aos parâmetros.
final projPartidaAFrioProvider = Provider<AjustePartidaAFrio>((ref) {
  final obs = ref.watch(projHistoricoObservadoProvider);
  return PartidaAFrio.avaliar(
    mesesDeHistorico: obs?.meses ?? 0,
    desfechosObservados: obs?.desfechos ?? 0,
    wapeAlvo: ref.watch(projConfigProvider).wapeForecast,
  );
});

/// Aplica um pacote de intensidade pré-definido.
void aplicarIntensidade(WidgetRef ref, IntensidadeCenario i) {
  final atual = ref.read(projConfigProvider);
  ref.read(projConfigProvider.notifier).state = atual.copyWith(
    intensidade: i,
    intervencao: ParametrosIntervencao.de(i),
  );
}
