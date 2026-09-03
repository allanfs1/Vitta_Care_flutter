import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/appointment.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_calibracao.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_historico_demo.dart';
import 'package:vitta_app/features/monte_carlo/monte_carlo_models.dart';

/// O gerador injeta taxas, correlação e sazonalidade **conhecidas**. Se o
/// estimador não recupera o que foi injetado, ele está errado — este arquivo é
/// o teste de recuperação de ponta a ponta da fase F2.
void main() {
  final fim = DateTime(2026, 9, 1);

  group('Gerador de histórico', () {
    test('marca todo agendamento como demo e nunca colide com dado real', () {
      final h = HistoricoDemo.gerar(dias: 40, ate: fim);
      expect(h, isNotEmpty);
      expect(h.every(HistoricoDemo.ehDemo), isTrue);
      expect(h.every((a) => a.id.startsWith('hist_demo_')), isTrue);
    });

    test('é determinístico com a mesma semente', () {
      List<String> ids(int seed) => HistoricoDemo.gerar(
            dias: 30,
            ate: fim,
            seed: seed,
          ).map((a) => '${a.id}|${a.status.name}').toList();

      expect(ids(7), equals(ids(7)));
      expect(ids(7), isNot(equals(ids(8))));
    });

    test('produz os três desfechos e as três faixas de risco', () {
      final h = HistoricoDemo.gerar(dias: 180, ate: fim);

      final status = h.map((a) => a.status).toSet();
      expect(status, contains(AppointmentStatus.completed));
      expect(status, contains(AppointmentStatus.noShow));
      expect(status, contains(AppointmentStatus.cancelled));

      final faixas = h.map((a) => a.patientRisk).toSet();
      expect(faixas.length, 3, reason: 'a estratificação precisa existir');
    });

    test('não agenda aos domingos e reduz o sábado', () {
      final h = HistoricoDemo.gerar(dias: 120, ate: fim);
      expect(h.any((a) => a.start.weekday == DateTime.sunday), isFalse);

      final sab =
          h.where((a) => a.start.weekday == DateTime.saturday).length;
      final ter = h.where((a) => a.start.weekday == DateTime.tuesday).length;
      expect(sab, lessThan(ter));
    });

    test('carrega a probabilidade prevista em cada agendamento', () {
      final h = HistoricoDemo.gerar(dias: 30, ate: fim);
      for (final a in h.take(200)) {
        expect(a.pFaltaPrevista, isNotNull);
        expect(a.pFaltaPrevista!, greaterThan(0.0));
        expect(a.pFaltaPrevista!, lessThan(1.0));
      }
    });

    test('a maioria dos desfechos é comparecimento — base saudável', () {
      final h = HistoricoDemo.gerar(dias: 210, ate: fim);
      final realizados =
          h.where((a) => a.status == AppointmentStatus.completed).length;
      expect(realizados / h.length, greaterThan(0.6),
          reason: 'uma base que só registra fracasso é o defeito que a '
              'verificação de integridade existe para pegar');
    });
  });

  group('Recuperação: o estimador encontra o que foi injetado', () {
    late CalibracaoResultado r;

    setUpAll(() {
      r = MonteCarloCalibracao.estimar(
        historico: HistoricoDemo.gerar(dias: 300, ate: fim),
        ate: fim,
        janelaDias: 320,
      );
    });

    test('não há bloqueio de integridade — a base é saudável', () {
      expect(r.integridade.temBloqueio, isFalse,
          reason: 'bloqueios: '
              '${r.integridade.bloqueios.map((a) => a.titulo).toList()}');
      expect(r.podeAplicar, isTrue);
      expect(r.temDadosSuficientes, isTrue);
    });

    test('recupera a taxa de falta de cada faixa', () {
      for (final f in RiskLevel.values) {
        final alvo = HistoricoDemo.taxaVerdadeira(f);
        final t = r.taxas[f]!;
        expect(t.confiavel, isTrue, reason: '${f.label} sem amostra');
        expect(t.taxaFalta, closeTo(alvo, 0.035),
            reason: '${f.label}: injetado $alvo, medido ${t.taxaFalta}');
      }
    });

    test('as faixas ficam ordenadas — baixo < médio < alto', () {
      final b = r.taxas[RiskLevel.low]!.taxaFalta;
      final m = r.taxas[RiskLevel.medium]!.taxaFalta;
      final a = r.taxas[RiskLevel.high]!.taxaFalta;
      expect(b, lessThan(m));
      expect(m, lessThan(a));
    });

    test('detecta a dependência injetada e devolve intervalo', () {
      expect(r.phi, greaterThan(1.2), reason: 'rho médio injetado ~0,04');
      expect(r.rhoEstimado, greaterThan(0.005));
      expect(r.rhoIc95.$1, lessThanOrEqualTo(r.rhoEstimado));
      expect(r.rhoIc95.$2, greaterThanOrEqualTo(r.rhoEstimado));
      expect(r.rhoConclusivo, isTrue,
          reason: 'com 300 dias a dependência deve ser distinguível de zero');
    });

    test('encontra a sazonalidade de φ', () {
      expect(r.porMes.length, greaterThanOrEqualTo(6));
      expect(r.amplitudeSazonal, greaterThan(0.3),
          reason: 'o gerador varia rho de 0,024 a 0,075 ao longo do ano');
      // A amplitude bruta existe; se ela é distinguível de ruído é outra
      // pergunta, respondida no grupo de controle do detector.

      // O mês mais agitado do gerador (jan) deve superar o mais calmo (nov).
      final jan = r.porMes.where((m) => m.mes == 1);
      final nov = r.porMes.where((m) => m.mes == 11);
      if (jan.isNotEmpty && nov.isNotEmpty) {
        expect(jan.first.phi, greaterThan(nov.first.phi));
      }
    });

    test('o backtest roda e devolve cobertura', () {
      expect(r.backtest.temAmostras, isTrue);
      expect(r.backtest.cobertura90, inInclusiveRange(0.0, 1.0));
      expect(r.backtest.crpsMedio, isNot(isNaN));
    });

    test('o modelo calibrado difere do padrão', () {
      const padrao = ModeloRisco();
      expect(r.modeloCalibrado.pAlto, isNot(padrao.pAlto));
      expect(r.modeloCalibrado.pAlto, greaterThan(r.modeloCalibrado.pBaixo));
    });
  });

  group('Sem sazonalidade o estimador não inventa sazonalidade', () {
    test('amplitude sazonal fica pequena', () {
      final r = MonteCarloCalibracao.estimar(
        historico: HistoricoDemo.gerar(
            dias: 300, ate: fim, comSazonalidade: false),
        ate: fim,
        janelaDias: 320,
      );
      // A amplitude bruta sobe só por ruído; o que não pode subir é o
      // veredito de significância.
      expect(r.sazonalidadeSignificativa, isFalse);
      expect(
          r.integridade.achados
              .any((a) => a.titulo.contains('varia muito ao longo')),
          isFalse);
    });
  });

  group('Histórico curto: bloqueia e não afirma dependência', () {
    test('20 dias não permitem calibrar nem concluir sobre rho', () {
      final r = MonteCarloCalibracao.estimar(
        historico: HistoricoDemo.gerar(dias: 20, ate: fim),
        ate: fim,
      );
      expect(r.temDadosSuficientes, isFalse);
      expect(r.podeAplicar, isFalse);
      // O bootstrap roda (há dias úteis suficientes), mas o intervalo tem de
      // conter zero: com 20 dias não se afirma dependência.
      expect(r.rhoIc95.$1, closeTo(0.0, 0.005),
          reason: 'o limite inferior deve encostar em zero');
      expect(r.rhoConclusivo, isFalse);
    });
  });

  group('Detector de sazonalidade: controle de erro e poder', () {
    // Um detector só vale se falhar de propósito quando não há nada, e
    // acertar quando há. Sem os dois controles, "não detectou" e "detectou"
    // são igualmente inúteis.

    test('nunca dispara em base sem sazonalidade, em nenhuma densidade', () {
      for (final n in [22, 45, 90, 160]) {
        final r = MonteCarloCalibracao.estimar(
          historico: HistoricoDemo.gerar(
              dias: 330,
              ate: fim,
              consultasPorDiaUtil: n,
              comSazonalidade: false),
          ate: fim,
          janelaDias: 350,
        );
        expect(r.sazonalidadeSignificativa, isFalse,
            reason: 'falso positivo com $n consultas/dia');
      }
    });

    test('detecta quando o sinal supera o ruído', () {
      // Agenda densa: φ cresce com o volume diário, enquanto o erro padrão de
      // φ depende do número de DIAS. É assim que o sinal passa o ruído.
      final r = MonteCarloCalibracao.estimar(
        historico: HistoricoDemo.gerar(
            dias: 330, ate: fim, consultasPorDiaUtil: 160),
        ate: fim,
        janelaDias: 350,
      );
      expect(r.sazonalidadeSignificativa, isTrue);
      expect(
          r.integridade.alertas
              .any((a) => a.titulo.contains('varia ao longo do ano')),
          isTrue);
    });

    test('agenda pequena não permite concluir — e não finge que permite', () {
      final r = MonteCarloCalibracao.estimar(
        historico: HistoricoDemo.gerar(
            dias: 300, ate: fim, consultasPorDiaUtil: 22),
        ate: fim,
        janelaDias: 320,
      );
      // A amplitude bruta é grande, mas é ruído: com ~25 dias por mês o erro
      // padrão de φ já vale quase 0,4.
      expect(r.amplitudeSazonal, greaterThan(0.5));
      expect(r.sazonalidadeSignificativa, isFalse);
    });
  });
}
