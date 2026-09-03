import 'dart:math' as math;

import '../../core/models/appointment.dart';
import '../../core/models/enums.dart';
import 'monte_carlo_engine.dart';
import 'monte_carlo_models.dart';

/// Histórico sintético para exercitar a calibração fora de produção.
///
/// Existe porque a agenda operacional carrega apenas a janela próxima: sem
/// histórico, a aba Calibração só sabe dizer "dados insuficientes", e o
/// estimador — que é a parte mais delicada do módulo — nunca é exercido por
/// ninguém antes de encontrar a base real.
///
/// **Nunca substitui dado real.** Só entra quando o Firebase está desligado, e
/// todo agendamento gerado leva o prefixo `hist_demo_` no id, para que jamais
/// se confunda com histórico de clínica.
///
/// O gerador injeta parâmetros **conhecidos** — taxas por faixa, correlação
/// diária e sazonalidade — o que o transforma no oráculo natural dos testes de
/// recuperação: se o estimador não devolve o que foi injetado, ele está errado.
class HistoricoDemo {
  const HistoricoDemo._();

  /// Prefixo identificador. Nenhum id de clínica real começa assim.
  static const String prefixo = 'hist_demo_';

  static bool ehDemo(Appointment a) => a.id.startsWith(prefixo);

  /// Razão de chances da falta por mês (1 = janeiro).
  ///
  /// Não é enfeite: a sazonalidade é o motivo pelo qual `φ` estimado em agosto
  /// e congelado subestima o risco em janeiro. Chuva de verão e ondas
  /// respiratórias no inverno empurram a falta para cima; férias escolares de
  /// julho e dezembro, para baixo. A média geométrica é ~1, então a taxa anual
  /// fica no valor configurado.
  static const List<double> orMes = [
    1.30, // jan — chuva de verão
    1.22, // fev
    1.10, // mar
    0.95, // abr
    1.05, // mai — início do frio
    1.18, // jun — respiratória
    0.88, // jul — férias escolares
    1.12, // ago
    0.98, // set
    0.92, // out
    0.90, // nov
    0.82, // dez — festas, agenda curta
  ];

  /// Correlação latente por mês. Em mês de chuva as faltas se movem mais juntas.
  static const List<double> rhoMes = [
    0.075, 0.068, 0.048, 0.030, 0.036, 0.062,
    0.028, 0.052, 0.032, 0.026, 0.024, 0.040,
  ];

  /// Composição da agenda por faixa de risco.
  static const Map<RiskLevel, double> composicao = {
    RiskLevel.low: 0.55,
    RiskLevel.medium: 0.30,
    RiskLevel.high: 0.15,
  };

  /// Gera o histórico.
  ///
  /// [taxas] são as marginais anuais **verdadeiras** — o que o estimador deve
  /// recuperar. [dias] controla o tamanho; 210 dias já passa do mínimo de 120
  /// exigido pelo critério de saída da fase F2.
  static List<Appointment> gerar({
    String clinicId = 'c1',
    DateTime? ate,
    int dias = 210,
    int consultasPorDiaUtil = 22,
    ModeloRisco taxas = const ModeloRisco(
      pBaixo: 0.08,
      pMedio: 0.19,
      pAlto: 0.34,
      pCancelBaixo: 0.05,
      pCancelMedio: 0.08,
      pCancelAlto: 0.12,
    ),
    int seed = 20260902,
    bool comSazonalidade = true,
  }) {
    final rng = math.Random(seed);
    final fim = ate ?? DateTime.now();
    final out = <Appointment>[];
    var n = 0;

    double normal() {
      double u, v, s;
      do {
        u = rng.nextDouble() * 2 - 1;
        v = rng.nextDouble() * 2 - 1;
        s = u * u + v * v;
      } while (s >= 1 || s == 0);
      return u * math.sqrt(-2 * math.log(s) / s);
    }

    for (var d = dias; d >= 1; d--) {
      final dia = DateTime(fim.year, fim.month, fim.day - d);
      if (dia.weekday == DateTime.sunday) continue;
      final sabado = dia.weekday == DateTime.saturday;

      final mes = dia.month - 1;
      final orSazonal = comSazonalidade ? orMes[mes] : 1.0;
      final rho = comSazonalidade ? rhoMes[mes] : 0.04;
      final raizRho = math.sqrt(rho);
      final raizComp = math.sqrt(1 - rho);

      // Choque comum do dia: o que faz as faltas se moverem juntas.
      final zDia = normal();

      // Volume varia: meio de semana cheio, sábado curto, mais algum ruído.
      final base = sabado ? consultasPorDiaUtil ~/ 2 : consultasPorDiaUtil;
      final quantas = math.max(4, base + rng.nextInt(7) - 3);

      for (var k = 0; k < quantas; k++) {
        final risco = _sortearFaixa(rng);
        final pBase = taxas.pFaltaDe(risco);
        // Sazonalidade entra como razão de chances: nunca sai de (0,1).
        final pFalta = MonteCarloEngine.aplicarIntervencao(pBase, orSazonal);
        final pCancel = taxas.pCancelSeguroDe(risco);

        final zFalta = MonteCarloEngine.normalInv(pFalta);
        final zCancel = MonteCarloEngine.normalInv(
            (pFalta + pCancel).clamp(0.0, 0.999));

        final x = raizRho * zDia + raizComp * normal();
        final status = x <= zFalta
            ? AppointmentStatus.noShow
            : (x <= zCancel
                ? AppointmentStatus.cancelled
                : AppointmentStatus.completed);

        final hora = 8 + (k % 9);
        out.add(Appointment(
          id: '$prefixo${n++}',
          clinicId: clinicId,
          patientId: 'pd_${n % 900}',
          patientName: 'Paciente demo ${n % 900}',
          doctorId: 'd${1 + (k % 4)}',
          doctorName: 'Dr. demo ${1 + (k % 4)}',
          specialty: 'Clínica Geral',
          start: DateTime(dia.year, dia.month, dia.day, hora, (k % 2) * 30),
          durationMinutes: 30,
          status: status,
          patientRisk: risco,
          pFaltaPrevista: pFalta,
        ));
      }
    }
    return out;
  }

  static RiskLevel _sortearFaixa(math.Random rng) {
    final u = rng.nextDouble();
    var acum = 0.0;
    for (final e in composicao.entries) {
      acum += e.value;
      if (u < acum) return e.key;
    }
    return RiskLevel.low;
  }

  /// Taxa de falta anual verdadeira de cada faixa, já com a sazonalidade
  /// aplicada — é o alvo que o estimador deve recuperar.
  ///
  /// Não é `taxas.pFaltaDe(faixa)`: a modulação sazonal por razão de chances
  /// desloca ligeiramente a média anual, e comparar contra o valor sem
  /// sazonalidade produziria um falso negativo nos testes.
  static double taxaVerdadeira(
    RiskLevel faixa, {
    ModeloRisco taxas = const ModeloRisco(
      pBaixo: 0.08,
      pMedio: 0.19,
      pAlto: 0.34,
    ),
    bool comSazonalidade = true,
  }) {
    final p = taxas.pFaltaDe(faixa);
    if (!comSazonalidade) return p;
    var soma = 0.0;
    for (final or in orMes) {
      soma += MonteCarloEngine.aplicarIntervencao(p, or);
    }
    return soma / orMes.length;
  }
}
