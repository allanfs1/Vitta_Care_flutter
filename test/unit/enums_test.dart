import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/enums.dart';

/// Testes unitários das regras de domínio nos enums.
void main() {
  group('ClinicType', () {
    test('apenas Privada é B2B (regra IA-01)', () {
      expect(ClinicType.privada.isB2B, true);
      expect(ClinicType.ubs.isB2B, false);
      expect(ClinicType.upa.isB2B, false);
      expect(ClinicType.aps.isB2B, false);
    });
    test('fromString mapeia e tem fallback', () {
      expect(ClinicType.fromString('privada'), ClinicType.privada);
      expect(ClinicType.fromString('UPA'), ClinicType.upa);
      expect(ClinicType.fromString('desconhecido'), ClinicType.ubs);
    });
  });

  group('AppointmentStatus.fromString', () {
    test('mapeia termos em pt e en', () {
      expect(AppointmentStatus.fromString('confirmado'), AppointmentStatus.confirmed);
      expect(AppointmentStatus.fromString('cancelled'), AppointmentStatus.cancelled);
      expect(AppointmentStatus.fromString('falta'), AppointmentStatus.noShow);
      expect(AppointmentStatus.fromString('realizado'), AppointmentStatus.completed);
      expect(AppointmentStatus.fromString(null), AppointmentStatus.pending);
    });
  });

  group('RiskLevel.fromScore', () {
    test('classifica por faixas', () {
      expect(RiskLevel.fromScore(0.1), RiskLevel.low);
      expect(RiskLevel.fromScore(0.4), RiskLevel.medium);
      expect(RiskLevel.fromScore(0.8), RiskLevel.high);
    });
  });
}
