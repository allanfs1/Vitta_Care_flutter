import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tarefas_agendadas/scheduled_task.dart';
import '../../tarefas_agendadas/scheduled_tasks_service.dart';
import 'vigia_models.dart';
import 'vigia_service.dart';

/// Rotinas propostas pela IA, aguardando decisão humana.
///
/// Vem do mesmo stream das tarefas — sugestão é uma tarefa que ainda não pode
/// rodar, não uma entidade separada. Isso mantém uma única fonte de verdade e
/// evita que uma sugestão aprovada precise "migrar" de coleção.
final sugestoesRotinaProvider = Provider<List<ScheduledTask>>((ref) {
  final todas = ref.watch(scheduledTasksProvider).value ?? const [];
  final pendentes = todas.where((t) => t.isSugestao).toList()
    ..sort((a, b) {
      // Mais confiança primeiro; empate desempata pela mais recente.
      final c = (b.confianca ?? 0).compareTo(a.confianca ?? 0);
      if (c != 0) return c;
      return (b.sugeridaEm ?? DateTime(0)).compareTo(a.sugeridaEm ?? DateTime(0));
    });
  return pendentes;
});

/// Quantas sugestões aguardam decisão — alimenta o badge da navegação.
final sugestoesPendentesCountProvider =
    Provider<int>((ref) => ref.watch(sugestoesRotinaProvider).length);

/// Estado do ciclo diário, para a UI poder mostrar "analisando…" e o resultado.
class VigiaEstado {
  const VigiaEstado({this.rodando = false, this.ultimo, this.erro});

  final bool rodando;
  final ResultadoCiclo? ultimo;
  final String? erro;
}

/// Dispara o ciclo do Vigia e guarda o resultado.
///
/// **Não agenda nada sozinho.** Quem agenda é o `AppShell`, num `State` de
/// verdade, cujo `dispose` o Flutter garante. Um `Timer` criado no construtor
/// de um provider sobrevive ao fim da árvore de widgets em teste e, pior, não
/// tem um dono claro em produção.
///
/// A trava de "já rodou hoje" vive no Firestore (`tb_vigia_ciclos`), então
/// abrir o app cinco vezes não gera cinco ciclos — nem em cinco dispositivos.
class VigiaController extends StateNotifier<VigiaEstado> {
  VigiaController(this._ref) : super(const VigiaEstado());

  final Ref _ref;

  /// Atraso sugerido entre o app abrir e o ciclo começar. O boot já é o momento
  /// mais disputado do dia e a análise não tem pressa.
  static const Duration atrasoBoot = Duration(seconds: 20);

  /// `true` quando faz sentido rodar agora — usado por quem agenda.
  bool get podeRodar =>
      !state.rodando && _ref.read(tarefasClinicaIdProvider).isNotEmpty;

  /// Executa o ciclo. [forcar] ignora a trava diária (botão "analisar agora").
  Future<ResultadoCiclo> rodar({bool forcar = false}) async {
    if (state.rodando) {
      return const ResultadoCiclo(
          executou: false, motivo: 'O ciclo já está em andamento.');
    }
    state = const VigiaEstado(rodando: true);
    try {
      final r = await _ref.read(vigiaServiceProvider).rodarCiclo(forcar: forcar);
      if (mounted) state = VigiaEstado(ultimo: r);
      return r;
    } catch (e) {
      if (mounted) state = VigiaEstado(erro: e.toString());
      return ResultadoCiclo(executou: false, motivo: e.toString());
    }
  }

}

final vigiaControllerProvider =
    StateNotifierProvider<VigiaController, VigiaEstado>(VigiaController.new);
