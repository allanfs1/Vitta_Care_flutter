import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../models/relatorio.dart';
import 'relatorios_repository.dart';

/// Estado dos relatórios gerados (REL-01), lido de `tb_relatorio_ia` — a mesma
/// coleção onde o agente de IA grava. Antes esta tela mostrava um seed em
/// memória e ignorava tudo que a IA produzia.
class RelatoriosNotifier extends StateNotifier<List<Relatorio>> {
  RelatoriosNotifier(this._repo, this._clinicaId) : super(const []) {
    if (_clinicaId.isNotEmpty) carregar();
  }

  final RelatoriosRepository _repo;
  final String _clinicaId;

  /// Relatórios de demonstração — semeiam apenas o repositório em memória.
  static List<Relatorio> get demonstracao => _seed();

  Future<void> carregar() async {
    try {
      state = await _repo.carregar(_clinicaId);
    } catch (_) {
      state = const [];
    }
  }

  static List<Relatorio> _seed() {
    final now = DateTime.now();
    return [
      Relatorio(
        id: 'r1',
        title: 'Desempenho operacional — Junho',
        type: RelatorioType.operacional,
        createdAt: now.subtract(const Duration(days: 1)),
        period: 'Últimos 30 dias',
        body:
            'A unidade manteve taxa de ocupação de 78% (acima da média da rede). '
            'O tempo médio de espera caiu para 14 minutos. Recomenda-se manter o '
            'reforço de confirmação ativa nas quartas-feiras.',
        metrics: const [
          RelatorioMetric('Taxa de ocupação', '78%'),
          RelatorioMetric('Comparecimento', '82%'),
          RelatorioMetric('Tempo médio de espera', '14 min'),
        ],
      ),
      Relatorio(
        id: 'r2',
        title: 'Análise de absenteísmo por especialidade',
        type: RelatorioType.absenteismo,
        createdAt: now.subtract(const Duration(days: 3)),
        period: 'Trimestre atual',
        body:
            'Clínica Geral concentra o maior índice de faltas (22%). Dermatologia '
            'apresenta o menor (11%). Pacientes de alto risco devem entrar na fila '
            'de contato ativo 48h antes.',
        metrics: const [
          RelatorioMetric('Absenteísmo geral', '18%'),
          RelatorioMetric('Maior risco', 'Clínica Geral'),
          RelatorioMetric('Pacientes de alto risco', '3'),
        ],
      ),
      Relatorio(
        id: 'r3',
        title: 'Resumo financeiro estimado',
        type: RelatorioType.financeiro,
        createdAt: now.subtract(const Duration(days: 7)),
        period: 'Mês anterior',
        body:
            'Receita estimada estável frente ao mês anterior. A eficiência de '
            'realocação de horários cancelados (72%) reduziu a perda de receita.',
        metrics: const [
          RelatorioMetric('Realocação de horários', '72%'),
          RelatorioMetric('Cancelamentos', '12%'),
        ],
      ),
    ];
  }

  Future<void> add(Relatorio relatorio) async {
    final anterior = state;
    state = [relatorio, ...state];
    try {
      await _repo.salvar(_clinicaId, relatorio);
    } catch (_) {
      // A tela não pode listar um relatório que o banco recusou.
      state = anterior;
      rethrow;
    }
  }
}

final relatoriosRepositoryProvider = Provider<RelatoriosRepository>((ref) {
  if (ref.watch(firebaseEnabledProvider)) {
    return FirestoreRelatoriosRepository();
  }
  return MemoriaRelatoriosRepository(RelatoriosNotifier.demonstracao);
});

final relatoriosProvider =
    StateNotifierProvider<RelatoriosNotifier, List<Relatorio>>((ref) {
  return RelatoriosNotifier(
    ref.watch(relatoriosRepositoryProvider),
    ref.watch(clinicaResolvidaProvider),
  );
});
