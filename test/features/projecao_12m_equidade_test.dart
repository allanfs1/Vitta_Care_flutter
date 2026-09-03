import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/projecao_12m/equidade.dart';

/// Equidade e uso responsável do escore.
///
/// Estes testes existem porque a especificação pede que o piso de intervenção
/// seja **invariante no código**, não diretriz de treinamento de equipe. Uma
/// diretriz não sobrevive à próxima refatoração; um teste, sim.
void main() {
  group('Piso de intervenção', () {
    test('o escore só escala o esforço — nunca subtrai', () {
      PlanoContato? anterior;
      for (var s = 0.0; s <= 1.0; s += 0.01) {
        final p = PisoIntervencao.plano(s);
        expect(p.reservaVaga, isTrue, reason: 'vaga nunca é retirada por risco');
        expect(p.lembretes, greaterThanOrEqualTo(PlanoContato.piso.lembretes));
        expect(p.canais, contains(CanalContato.whatsapp));
        expect(p.respeitaPiso(PlanoContato.piso), isTrue);

        if (anterior != null) {
          expect(p.lembretes, greaterThanOrEqualTo(anterior.lembretes),
              reason: 'esforço é monótono no escore, em s=$s');
          expect(p.canais.length, greaterThanOrEqualTo(anterior.canais.length));
        }
        anterior = p;
      }
    });

    test('risco baixo recebe o piso; alto recebe contato humano', () {
      final baixo = PisoIntervencao.plano(0.05);
      expect(baixo.lembretes, 1);
      expect(baixo.canais, [CanalContato.whatsapp]);
      expect(baixo.contatoHumano48h, isFalse);

      final moderado = PisoIntervencao.plano(0.35);
      expect(moderado.lembretes, 2);
      expect(moderado.canais, containsAll([CanalContato.whatsapp, CanalContato.sms]));
      expect(moderado.contatoHumano48h, isFalse);

      final alto = PisoIntervencao.plano(0.70);
      expect(alto.lembretes, 3);
      expect(alto.canais.length, CanalContato.values.length);
      expect(alto.contatoHumano48h, isTrue);
    });

    test('escore negativo ou acima de 1 não quebra o piso', () {
      for (final s in [-3.0, -0.01, 1.5, 99.0, double.nan]) {
        final p = PisoIntervencao.plano(s);
        expect(p.reservaVaga, isTrue);
        expect(p.lembretes, greaterThanOrEqualTo(1));
      }
    });

    test('validar rejeita plano que retira a vaga', () {
      const mau = PlanoContato(
        lembretes: 3,
        canais: [CanalContato.whatsapp],
        reservaVaga: false,
      );
      expect(() => PisoIntervencao.validar(mau),
          throwsA(isA<PisoIntervencaoViolado>()));
    });

    test('validar rejeita plano abaixo do piso de lembretes ou de canais', () {
      expect(
        () => PisoIntervencao.validar(
            const PlanoContato(lembretes: 0, canais: [CanalContato.whatsapp])),
        throwsA(isA<PisoIntervencaoViolado>()),
      );
      expect(
        () => PisoIntervencao.validar(
            const PlanoContato(lembretes: 2, canais: [CanalContato.sms])),
        throwsA(isA<PisoIntervencaoViolado>()),
        reason: 'remover o canal do piso é subtrair serviço',
      );
    });

    test('a invariante vale em release — é exceção, não assert', () {
      // `assert` é removido em build de release, e é em produção que a regra
      // precisa valer. Se isto virar assert um dia, este teste falha.
      var lancou = false;
      try {
        PisoIntervencao.validar(const PlanoContato(
          lembretes: 1,
          canais: [CanalContato.whatsapp],
          reservaVaga: false,
        ));
      } on PisoIntervencaoViolado {
        lancou = true;
      }
      expect(lancou, isTrue);
    });
  });

  group('Usos proibidos', () {
    test('a guarda libera o uso permitido', () {
      expect(GuardaEscore.liberar(0.42, UsoEscore.priorizarContato), 0.42);
      expect(GuardaEscore.liberar(0.42, UsoEscore.dimensionarLembretes), 0.42);
    });

    test('todo uso proibido lança, sem exceção', () {
      expect(UsoEscore.proibidos, isNotEmpty);
      for (final uso in UsoEscore.proibidos) {
        expect(
          () => GuardaEscore.liberar(0.42, uso),
          throwsA(isA<UsoProibidoDoEscore>()),
          reason: '${uso.label} precisa ser bloqueado em código',
        );
        expect(uso.porQueProibido, isNotEmpty,
            reason: 'todo bloqueio precisa dizer por quê');
      }
    });

    test('os seis usos proibidos da especificação estão cobertos', () {
      expect(
        UsoEscore.proibidos.toSet(),
        containsAll([
          UsoEscore.negarAgendamento,
          UsoEscore.overbookingSobreAltoRisco,
          UsoEscore.exibirAoPaciente,
          UsoEscore.exibirNoAtendimento,
          UsoEscore.cobrarTaxa,
          UsoEscore.elegibilidadeDePlano,
        ]),
      );
    });

    test('overbooking sobre alto risco é proibido — a penalidade recairia '
        'sobre quem já tem menos acesso', () {
      expect(GuardaEscore.permitido(UsoEscore.overbookingSobreAltoRisco),
          isFalse);
    });
  });

  group('Métricas por subgrupo', () {
    /// Gera um subgrupo com escore **calibrado por construção**: sorteia o
    /// risco verdadeiro e o desfecho a partir dele. `vies` desloca o escore
    /// reportado sem tocar no desfecho, que é exatamente como a descalibração
    /// aparece na prática — o modelo continua ordenando e erra o nível.
    List<ObservacaoEquidade> gerar({
      required String grupo,
      required int n,
      required double taxaFalta,
      required double vies,
      required int seed,
      double taxaIntervencao = 0.5,
    }) {
      final rng = math.Random(seed);
      return [
        for (var i = 0; i < n; i++)
          () {
            // p com média igual a taxaFalta e cauda até ~3× ela, para que a
            // faixa de alto risco não fique vazia.
            final u = rng.nextDouble();
            final p = (taxaFalta * 3 * u * u).clamp(0.0, 1.0);
            return ObservacaoEquidade(
              subgrupo: grupo,
              escore: (p + vies).clamp(0.0, 1.0),
              faltou: rng.nextDouble() < p,
              intervencaoAplicada: rng.nextDouble() < taxaIntervencao,
            );
          }(),
      ];
    }

    const limiar = 0.30;

    test('subgrupo com amostra pequena não entra no critério de ECE', () {
      final obs = [
        ...gerar(grupo: 'UBS_01', n: 3000, taxaFalta: 0.2, vies: 0, seed: 1),
        // 50 observações não sustentam uma afirmação sobre calibração.
        ...gerar(grupo: 'UBS_99', n: 50, taxaFalta: 0.2, vies: 0.4, seed: 2),
      ];
      final p = Equidade.medir(obs, limiarAltoRisco: limiar);
      expect(p.subgrupos.length, 2);
      expect(p.comAmostraSuficiente.map((s) => s.subgrupo), ['UBS_01']);
      expect(p.eceForaDoCriterio, isEmpty,
          reason: 'o grupo pequeno é descartado do critério, não aprovado');
    });

    test('descalibração num único subgrupo é detectada', () {
      final obs = [
        ...gerar(grupo: 'centro', n: 3000, taxaFalta: 0.2, vies: 0, seed: 3),
        ...gerar(grupo: 'periferia', n: 3000, taxaFalta: 0.2, vies: 0.3, seed: 4),
      ];
      final p = Equidade.medir(obs, limiarAltoRisco: limiar);
      expect(p.eceForaDoCriterio.map((s) => s.subgrupo), contains('periferia'));
      expect(p.aprovado, isFalse);
    });

    test('recall desequilibrado entre grupos reprova o painel', () {
      // No grupo B o escore é deslocado para baixo: as mesmas faltas deixam de
      // ser sinalizadas como alto risco.
      final obs = [
        ...gerar(grupo: 'A', n: 3000, taxaFalta: 0.25, vies: 0.2, seed: 5),
        ...gerar(grupo: 'B', n: 3000, taxaFalta: 0.25, vies: -0.2, seed: 6),
      ];
      final p = Equidade.medir(obs, limiarAltoRisco: limiar);
      expect(p.razaoRecall, greaterThan(1.25));
      expect(p.recallEquilibrado, isFalse);
      expect(p.aprovado, isFalse);
    });

    test('nenhum subgrupo pode sair pior que o baseline', () {
      final obs = [
        ...gerar(grupo: 'A', n: 1500, taxaFalta: 0.15, vies: 0, seed: 7),
        ...gerar(grupo: 'B', n: 1500, taxaFalta: 0.30, vies: 0, seed: 8),
      ];
      // A melhorou (0,20 → ~0,15); B piorou (0,22 → ~0,30).
      final p = Equidade.medir(obs,
          limiarAltoRisco: limiar,
          faltaBaseline: const {'A': 0.20, 'B': 0.22});

      expect(p.subgruposQuePioraram.map((s) => s.subgrupo), ['B']);
      expect(p.nenhumSubgrupoPior, isFalse);
      expect(p.aprovado, isFalse,
          reason: 'redução agregada não compensa um grupo que piorou');
    });

    test('sem baseline, a verificação de piora não inventa aprovação', () {
      final obs = gerar(grupo: 'A', n: 600, taxaFalta: 0.30, vies: 0, seed: 9);
      final p = Equidade.medir(obs, limiarAltoRisco: limiar);
      expect(p.subgrupos.single.taxaFaltaBaseline, isNull);
      expect(p.subgrupos.single.piorouEmRelacaoAoBaseline, isFalse);
    });

    test('painel bem comportado é aprovado', () {
      final obs = [
        ...gerar(grupo: 'A', n: 4000, taxaFalta: 0.20, vies: 0, seed: 10),
        ...gerar(grupo: 'B', n: 4000, taxaFalta: 0.21, vies: 0, seed: 12),
      ];
      final p = Equidade.medir(obs,
          limiarAltoRisco: limiar,
          faltaBaseline: const {'A': 0.26, 'B': 0.26});
      expect(p.nenhumSubgrupoPior, isTrue);
      expect(p.recallEquilibrado, isTrue);
      expect(p.aprovado, isTrue);
    });

    test('painel vazio não explode', () {
      final p = Equidade.medir(const []);
      expect(p.subgrupos, isEmpty);
      expect(p.razaoRecall, 1.0);
      expect(p.aprovado, isTrue);
      expect(p.amplitudeIntervencao, 0);
    });
  });
}
