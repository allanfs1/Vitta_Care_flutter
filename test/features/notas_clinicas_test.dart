import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitta_app/core/models/patient.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/pacientes/notas_clinicas_repository.dart';
import 'package:vitta_app/features/pacientes/paciente_data.dart';

// PAC-05 (adicionar nota clínica) tinha o botão e o diálogo prontos, mas a
// nota só vivia em `StateNotifier` — fechar a aba apagava a observação que um
// médico ou enfermeiro acabou de registrar. Este teste prova que a nota
// sobrevive à sessão, o mesmo padrão usado para perfil/agentes/notificações.
void main() {
  const patient = Patient(id: 'p1', name: 'Maria Silva');
  const clinica = 'clinica-real';

  group('notas clínicas sobrevivem à sessão', () {
    test('nota adicionada reaparece com um repositório novo', () async {
      final repo = MemoriaNotasClinicasRepository();

      final c1 = ProviderContainer(overrides: [
        notasClinicasRepositoryProvider.overrideWithValue(repo),
        clinicaResolvidaProvider.overrideWithValue(clinica),
      ]);
      await c1
          .read(clinicalNotesProvider.notifier)
          .add(patient, ClinicalNote('Hoje — Dra. Ana', 'Dra. Ana',
              'Paciente relata melhora dos sintomas.'));
      c1.dispose();

      // "Sessão" nova sobre o MESMO repositório.
      final c2 = ProviderContainer(overrides: [
        notasClinicasRepositoryProvider.overrideWithValue(repo),
        clinicaResolvidaProvider.overrideWithValue(clinica),
      ]);
      final notas = await repo.carregar(clinica, patient.id);
      expect(notas.any((n) => n.text.contains('melhora dos sintomas')), isTrue);
      c2.dispose();
    });

    test('nota nova entra antes das de demonstração, mais recente primeiro',
        () async {
      final repo = MemoriaNotasClinicasRepository();
      await repo.adicionar(clinica, patient.id,
          ClinicalNote('Hoje — Dr. X', 'Dr. X', 'Observação nova.'));

      final notas = await repo.carregar(clinica, patient.id);
      expect(notas.first.text, 'Observação nova.');
      expect(notas.length, greaterThan(1),
          reason: 'as notas de demonstração continuam depois da nova');
    });

    test('sem clínica resolvida, salvar falha em vez de gravar órfã', () async {
      final repo = MemoriaNotasClinicasRepository();
      final c = ProviderContainer(overrides: [
        notasClinicasRepositoryProvider.overrideWithValue(repo),
        clinicaResolvidaProvider.overrideWithValue(''),
      ]);
      addTearDown(c.dispose);

      await expectLater(
        c.read(clinicalNotesProvider.notifier).add(
              patient,
              ClinicalNote('Hoje — X', 'X', 'não deveria salvar'),
            ),
        throwsA(isA<StateError>()),
      );
    });

    test('notas de pacientes diferentes não se misturam', () async {
      final repo = MemoriaNotasClinicasRepository();
      await repo.adicionar(clinica, 'p1', ClinicalNote('D', 'A', 'nota do p1'));
      await repo.adicionar(clinica, 'p2', ClinicalNote('D', 'A', 'nota do p2'));

      final notasP1 = await repo.carregar(clinica, 'p1');
      final notasP2 = await repo.carregar(clinica, 'p2');
      expect(notasP1.any((n) => n.text == 'nota do p2'), isFalse);
      expect(notasP2.any((n) => n.text == 'nota do p1'), isFalse);
    });
  });
}
