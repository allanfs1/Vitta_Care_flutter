import 'package:cloud_firestore/cloud_firestore.dart';

import 'monte_carlo_calibracao.dart';
import 'monte_carlo_models.dart';

/// Persistência das execuções e decisões do simulador (fase F3).
///
/// Duas coleções:
/// - `tb_mc_execucoes`: o que foi previsto, com que parâmetros e em que versão
///   de rótulo. Sem isso não há como auditar uma decisão depois.
/// - `tb_mc_calibracao`: o resultado de cada calibração, para acompanhar a
///   deriva de `phi` ao longo do ano.
///
/// Todas as operações são **best-effort**: em offline/mock nada é persistido e
/// a UI segue funcionando com o estado local.
abstract class MonteCarloRepositorio {
  Future<String?> salvarExecucao(String clinicId, SimulacaoResultado r);

  Future<void> registrarDecisao(
    String clinicId, {
    required String execucaoId,
    required int encaixesAprovados,
    required String ator,
    required String justificativa,
  });

  Future<String?> salvarCalibracao(String clinicId, CalibracaoResultado c);
}

/// Implementação offline/testes — não persiste nada.
class MockMonteCarloRepositorio implements MonteCarloRepositorio {
  const MockMonteCarloRepositorio();

  @override
  Future<String?> salvarExecucao(String clinicId, SimulacaoResultado r) async =>
      null;

  @override
  Future<void> registrarDecisao(
    String clinicId, {
    required String execucaoId,
    required int encaixesAprovados,
    required String ator,
    required String justificativa,
  }) async {}

  @override
  Future<String?> salvarCalibracao(
          String clinicId, CalibracaoResultado c) async =>
      null;
}

// ─────────────────────── Mapeamento (puro, testável) ───────────────────────
//
// Monta o payload SEM depender de `Timestamp`: datas ficam como `DateTime` e a
// camada Firestore as converte na escrita.

/// Documento de uma execução do simulador.
///
/// Guarda os parâmetros junto do resultado de propósito: um P95 sem o `rho`,
/// a semente e a `labelVersion` que o produziram é um número órfão, impossível
/// de reproduzir ou comparar com outra série.
Map<String, dynamic> execucaoDoc(String clinicId, SimulacaoResultado r) => {
      'idclinica': clinicId,
      'data': DateTime(r.data.year, r.data.month, r.data.day),
      'labelVersion': r.config.labelVersion,
      'parametros': {
        'rho': r.config.rho,
        'nRuns': r.config.nRuns,
        'seed': r.config.seed,
        'baseCapacidade': r.config.baseCapacidade.name,
        'encaixeModo': r.config.encaixeModo.name,
        'pFaltaEncaixe': r.config.pFaltaEncaixe,
        'taxas': {
          'baixo': r.config.modeloRisco.pBaixo,
          'medio': r.config.modeloRisco.pMedio,
          'alto': r.config.modeloRisco.pAlto,
          'cancelBaixo': r.config.modeloRisco.pCancelBaixo,
          'cancelMedio': r.config.modeloRisco.pCancelMedio,
          'cancelAlto': r.config.modeloRisco.pCancelAlto,
        },
      },
      'agendados': r.totalAgendados,
      'exato': r.exato,
      'duracaoMs': r.duracao.inMilliseconds,
      'phiObservado': r.phiObservado,
      'faltas': {
        'esperadas': r.faltasEsperadas,
        'p05': r.faltas.p05,
        'p50': r.faltas.p50,
        'p95': r.faltas.p95,
        'media': r.faltas.media,
        'desvio': r.faltas.desvio,
      },
      'cancelamentos': {
        'esperados': r.cancelamentosEsperados,
        'p50': r.cancelamentos.p50,
      },
      'fila': {
        'chamadasSeguras': r.fila.chamadasSeguras,
        'liberadasP25': r.fila.liberadasP25,
        'liberadasP50': r.fila.liberadasP50,
      },
      'slots': [
        for (final s in r.slots)
          {
            'medicoId': s.doctorId,
            'hora': s.hour,
            'agendados': s.agendados,
            'capacidade': s.capacidade,
            'capacidadeFisica': s.capacidadeFisica,
            'capacidadeConfigurada': s.capacidadeConfigurada,
            'presentesP50': s.presentes.p50,
            'presentesP95': s.presentes.p95,
            'riscoEstouro': s.riscoEstouro(0),
          },
      ],
      'origem': 'app',
    };

/// Documento de auditoria de uma decisão tomada a partir de uma execução.
Map<String, dynamic> decisaoDoc(
  String clinicId, {
  required String execucaoId,
  required int encaixesAprovados,
  required String ator,
  required String justificativa,
}) =>
    {
      'idclinica': clinicId,
      'execucaoId': execucaoId,
      'encaixesAprovados': encaixesAprovados,
      'ator': ator,
      'justificativa': justificativa,
      'decisao': 'overbooking_mc',
      'origem': 'app',
    };

/// Documento de uma calibração.
Map<String, dynamic> calibracaoDoc(String clinicId, CalibracaoResultado c) => {
      'idclinica': clinicId,
      'labelVersion': kLabelVersion,
      'diasAnalisados': c.diasAnalisados,
      'consultasAnalisadas': c.consultasAnalisadas,
      'phi': c.phi,
      'rhoEstimado': c.rhoEstimado,
      'aprovadoParaUso': c.aprovadoParaUso,
      'taxas': {
        for (final e in c.taxas.entries)
          e.key.name: {
            'total': e.value.total,
            'faltas': e.value.faltas,
            'cancelamentos': e.value.cancelamentos,
            'taxaFalta': e.value.taxaFalta,
            'taxaCancelamento': e.value.taxaCancelamento,
            'confiavel': e.value.confiavel,
          },
      },
      'backtest': {
        'amostras': c.backtest.amostras,
        'crpsMedio': c.backtest.crpsMedio,
        'pinballP50': c.backtest.pinballP50,
        'pinballP95': c.backtest.pinballP95,
        'cobertura90': c.backtest.cobertura90,
        'ece': c.backtest.ece,
      },
      'avisos': c.avisos,
      'origem': 'app',
    };

/// Implementação Firestore.
///
/// Escreve apenas com `clinicId` resolvido — sem tenant não há gravação, e não
/// existe clínica padrão de fallback. Gravar na clínica errada é pior do que
/// não gravar.
class FirestoreMonteCarloRepositorio implements MonteCarloRepositorio {
  const FirestoreMonteCarloRepositorio(this._db);

  final FirebaseFirestore _db;

  static const colExecucoes = 'tb_mc_execucoes';
  static const colDecisoes = 'tb_mc_decisoes';
  static const colCalibracao = 'tb_mc_calibracao';

  bool _valido(String clinicId) => clinicId.trim().isNotEmpty;

  @override
  Future<String?> salvarExecucao(String clinicId, SimulacaoResultado r) async {
    if (!_valido(clinicId)) return null;
    try {
      final doc = await _db.collection(colExecucoes).add({
        ...execucaoDoc(clinicId, r),
        'criadoEm': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> registrarDecisao(
    String clinicId, {
    required String execucaoId,
    required int encaixesAprovados,
    required String ator,
    required String justificativa,
  }) async {
    if (!_valido(clinicId)) return;
    try {
      await _db.collection(colDecisoes).add({
        ...decisaoDoc(
          clinicId,
          execucaoId: execucaoId,
          encaixesAprovados: encaixesAprovados,
          ator: ator,
          justificativa: justificativa,
        ),
        'criadoEm': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // best-effort
    }
  }

  @override
  Future<String?> salvarCalibracao(
      String clinicId, CalibracaoResultado c) async {
    if (!_valido(clinicId)) return null;
    try {
      final doc = await _db.collection(colCalibracao).add({
        ...calibracaoDoc(clinicId, c),
        'criadoEm': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (_) {
      return null;
    }
  }
}
