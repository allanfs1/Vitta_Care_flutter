import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/features/ia/vigia/vigia_models.dart';
import 'package:vitta_app/features/tarefas_agendadas/scheduled_task.dart';
import 'package:vitta_app/features/tarefas_agendadas/schedule_util.dart';

// O Vigia é o ciclo diário que lê a clínica, escreve um relatório e propõe
// rotinas de prevenção. A propriedade que o desenho inteiro existe para
// garantir: **uma rotina proposta pela IA nunca executa sozinha**.
//
// São três travas independentes, e cada uma é testada aqui ou já é garantida
// pelo código de produção:
//   1. a sugestão é gravada sem `nextRunAt`;
//   2. `getDue` (Dart) só devolve `status == 'active'`;
//   3. o cron (functions/scheduledTasksCron.js) filtra o mesmo status.
void main() {
  ScheduledTask tarefa({
    required String status,
    String titulo = 'Confirmação ativa',
    String kind = 'action',
    DateTime? nextRunAt,
    String origem = 'ia',
  }) =>
      ScheduledTask(
        id: 't1',
        titulo: titulo,
        prompt: 'faça algo',
        kind: kind,
        schedule: const TaskSchedule(type: 'daily', time: '07:30'),
        status: status,
        nextRunAt: nextRunAt,
        clinicaId: 'c1',
        origem: origem,
      );

  group('uma sugestão não é uma tarefa vigente', () {
    test('o status a mantém fora de qualquer execução', () {
      final s = tarefa(status: 'suggested');
      expect(s.isSugestao, isTrue);
      expect(s.isActive, isFalse,
          reason: 'os dois runners só pegam tarefas ativas');
      expect(s.daIa, isTrue);
    });

    test('aprovar é o único caminho que liga a execução', () {
      // Aprovar é uma transição de estado, não uma cópia: o mesmo documento
      // vira 'active'. Isso mantém o histórico da proposta junto da rotina.
      final antes = tarefa(status: 'suggested');
      expect(antes.isActive, isFalse);

      final depois = tarefa(status: 'active', nextRunAt: DateTime(2026, 8, 22));
      expect(depois.isActive, isTrue);
      expect(depois.isSugestao, isFalse);
    });

    test('recusada não volta a rodar nem some do histórico', () {
      final r = tarefa(status: 'rejected');
      expect(r.isRecusada, isTrue);
      expect(r.isActive, isFalse);
      expect(r.isSugestao, isFalse,
          reason: 'recusada não pode reaparecer na fila de aprovação');
    });
  });

  group('deduplicação entre ciclos', () {
    test('ignora prefixo de origem, caixa e pontuação', () {
      final a = ScheduledTask.chaveDedupeDe(
          '[Preventiva] Confirmação Ativa — Manhã', 'action');
      final b = ScheduledTask.chaveDedupeDe(
          '[IA] confirmacao ativa manha', 'action');
      // Acentos diferem, então não colidem — mas prefixo e pontuação, sim.
      final c = ScheduledTask.chaveDedupeDe(
          'Confirmação Ativa   Manhã!!!', 'action');
      expect(a, c, reason: 'mesma rotina proposta com pontuação diferente');
      expect(a, isNot(b));
    });

    test('mesma rotina em kinds diferentes não colide', () {
      final acao = ScheduledTask.chaveDedupeDe('Auditoria de faltas', 'action');
      final rel = ScheduledTask.chaveDedupeDe('Auditoria de faltas', 'report');
      expect(acao, isNot(rel),
          reason: 'agir e relatar sobre o mesmo tema são rotinas distintas');
    });

    test('a proposta e a tarefa gerada compartilham a chave', () {
      const p = RotinaProposta(
        titulo: '[IA] Auditoria de faltas',
        descricao: '',
        prompt: 'x',
        kind: 'action',
        schedule: TaskSchedule(type: 'daily', time: '08:00'),
        problemaDetectado: '',
        impactoEstimado: '',
        evidencias: [],
        confianca: 0.9,
      );
      final t = tarefa(titulo: '[IA] Auditoria de faltas', status: 'suggested');
      expect(p.chaveDedupe, t.chaveDedupe,
          reason: 'sem isso o Vigia repropõe o que já sugeriu ontem');
    });
  });

  group('o parser descarta proposta malformada', () {
    // Uma proposta incompleta não pode virar um card pela metade na frente do
    // gestor. Melhor perder a sugestão do que pedir aprovação para algo vago.
    test('sem título ou sem prompt, não vira rotina', () {
      expect(RotinaProposta.doJson({'prompt': 'x', 'schedule': {'type': 'daily'}}),
          isNull);
      expect(RotinaProposta.doJson({'titulo': 'x', 'schedule': {'type': 'daily'}}),
          isNull);
    });

    test('sem agendamento válido, não vira rotina', () {
      expect(
        RotinaProposta.doJson({'titulo': 'x', 'prompt': 'y'}),
        isNull,
        reason: 'schedule ausente',
      );
      expect(
        RotinaProposta.doJson({
          'titulo': 'x',
          'prompt': 'y',
          'schedule': {'type': 'quando_der'},
        }),
        isNull,
        reason: 'tipo de agendamento inventado pelo modelo',
      );
      expect(
        RotinaProposta.doJson({
          'titulo': 'x',
          'prompt': 'y',
          // 'daily' sem horário não passa em validateSchedule.
          'schedule': {'type': 'daily'},
        }),
        isNull,
      );
    });

    test('aceita uma proposta completa e normaliza o que falta', () {
      final p = RotinaProposta.doJson({
        'titulo': 'Confirmação ativa',
        'prompt': 'Ligar para pacientes de risco',
        'schedule': {'type': 'daily', 'time': '07:30'},
        'evidencias': ['22% de falta', '  ', 'nota: protocolos/x.md'],
        'confianca': 0.83,
      });

      expect(p, isNotNull);
      expect(p!.kind, 'action', reason: 'kind ausente vira ação');
      expect(p.evidencias, ['22% de falta', 'nota: protocolos/x.md'],
          reason: 'evidência vazia é descartada');
      expect(p.confianca, closeTo(0.83, 0.001));
    });

    test('confiança fora da faixa é contida, não rejeitada', () {
      final alto = RotinaProposta.doJson({
        'titulo': 'x',
        'prompt': 'y',
        'schedule': {'type': 'daily', 'time': '08:00'},
        'confianca': 4.2,
      });
      expect(alto!.confianca, 1.0);

      final semConf = RotinaProposta.doJson({
        'titulo': 'x',
        'prompt': 'y',
        'schedule': {'type': 'daily', 'time': '08:00'},
      });
      expect(semConf!.confianca, 0.5,
          reason: 'sem confiança declarada, assume meio-termo');
    });

    test('weekday inválido é filtrado em vez de derrubar a proposta', () {
      final p = RotinaProposta.doJson({
        'titulo': 'x',
        'prompt': 'y',
        'schedule': {
          'type': 'weekly',
          'time': '08:00',
          'weekdays': [1, 9, -3, 5],
        },
      });
      expect(p, isNotNull);
      expect(p!.schedule.weekdays, [1, 5]);
    });
  });

  group('relatório proposto', () {
    test('exige título e corpo', () {
      expect(RelatorioProposto.doJson({'titulo': 'x'}), isNull);
      expect(RelatorioProposto.doJson({'corpo': 'y'}), isNull);
    });

    test('lê métricas em qualquer um dos dois formatos', () {
      final r = RelatorioProposto.doJson({
        'titulo': 'Panorama',
        'corpo': '# Panorama',
        'metricas': [
          {'label': 'Absenteísmo', 'valor': '18%'},
          {'rotulo': 'Ocupação', 'value': '78%'},
          {'label': '', 'valor': 'ignorado'},
        ],
      });
      expect(r, isNotNull);
      expect(r!.metricas, hasLength(2));
      expect(r.metricas.first.$1, 'Absenteísmo');
      expect(r.metricas.last.$2, '78%');
      expect(r.periodo, 'Últimas 24 horas', reason: 'período tem padrão');
    });
  });
}
