import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/enums.dart';
import 'package:vitta_app/features/overbooking/overbooking_models.dart';
import 'package:vitta_app/features/overbooking/realocacao_service.dart';

RealocacaoProposta _proposta() => RealocacaoProposta(
      appointmentId: 'ag123',
      patientName: 'Maria Souza',
      patientRisk: RiskLevel.low,
      doctorId: 'd1',
      doctorName: 'Dr. Silva',
      specialty: 'Clínico Geral',
      crm: 'CRM/SP 1',
      slotOrigem: DateTime(2026, 7, 8, 9),
      slotDestino: DateTime(2026, 7, 10, 14, 30),
      motivoDestino: 'Mesmo médico, vaga livre',
      canal: RealoCanal.email,
      status: RealocacaoStatus.sugerida,
      emailStatus: RealoEmailStatus.naoEnviado,
      criadaEm: DateTime(2026, 7, 6),
    );

void main() {
  group('mapeamento de realocação (payloads Firestore)', () {
    test('queue_realoc mapeia campos essenciais e usa enum.name', () {
      final doc = realocQueueDoc('clin1', _proposta());
      expect(doc['idclinica'], 'clin1');
      expect(doc['agendamentoOrigemId'], 'ag123');
      expect(doc['pacienteNome'], 'Maria Souza');
      expect(doc['status'], 'sugerida');
      expect(doc['canal'], 'email');
      expect(doc['slotDestino'], DateTime(2026, 7, 10, 14, 30));
    });

    test('tb_overbooking_events registra ator/texto e decisao filtrável', () {
      final d = DecisaoOverbooking(
        at: DateTime(2026, 7, 6, 10, 42),
        ator: 'Motor',
        texto: 'Sugerido realocar Maria Souza',
        icon: Icons.auto_awesome,
        cor: const Color(0xFF000000),
      );
      final doc = overbookingEventDoc('clin1', d);
      expect(doc['idclinica'], 'clin1');
      expect(doc['ator'], 'Motor');
      expect(doc['decisao'], 'realocacao');
      expect(doc['texto'], contains('Maria Souza'));
    });

    test('tb_scheduled_tasks fica ativa, do tipo certo e com prompt acionável',
        () {
      final doc =
          scheduledTaskDoc('clin1', _proposta(), DateTime(2026, 7, 6, 8));
      expect(doc['kind'], 'realocacao_overbooking');
      expect(doc['status'], 'active');
      expect(doc['clinicaId'], 'clin1');
      expect(doc['nextRunAt'], DateTime(2026, 7, 6, 8));
      expect(doc['prompt'], contains('ag123'));
      expect(doc['prompt'], contains('10/07 14:30'));
      expect(doc['prompt'], contains('reagendado'));
    });
  });
}
