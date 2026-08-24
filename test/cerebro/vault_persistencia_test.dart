import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/models/app_user.dart';
import 'package:vitta_app/core/models/clinic.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/core/services/mock_data.dart';
import 'package:vitta_app/features/cerebro/data/models/nota.dart';
import 'package:vitta_app/features/cerebro/data/nota_repository.dart';
import 'package:vitta_app/features/cerebro/data/vault_demo.dart';
import 'package:vitta_app/features/cerebro/providers/cerebro_providers.dart';

// Regressões de persistência do Cérebro.
//
// O módulo tinha três defeitos que se somavam no mesmo sintoma — "abro em uma
// sessão nova e minhas notas sumiram, sobrou a oferta de carregar 1.200 notas
// de teste":
//
//  1. `carregar()` auto-populava 1.200 notas sintéticas sempre que a leitura
//     voltava com ≤1 nota — no Firestore isso é escrita de verdade.
//  2. O vault abria com a clínica placeholder de MockData (`c1`), porque
//     `clinicsProvider` só troca pelos dados reais quando o snapshot chega.
//     As notas escritas nessa janela ficavam órfãs em uma clínica fantasma.
//  3. A falha de leitura virava um ícone discreto na status bar, então a tela
//     parecia apenas vazia.
/// Repositório que conta escritas — é assim que se prova que o boot não grava
/// nada por conta própria.
class RepoEspiao extends MemoriaNotaRepository {
  int lotes = 0;
  int salvamentos = 0;

  @override
  Future<void> salvarLote(List<Nota> notas) {
    lotes++;
    return super.salvarLote(notas);
  }

  @override
  Future<Nota> salvar(Nota nota, {required String autor}) {
    salvamentos++;
    return super.salvar(nota, autor: autor);
  }
}

void main() {
  const clinica = 'clinica-real';

  // `VaultNotifier._autor` lê `authProvider`, que depende de SharedPreferences.
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer containerCom(NotaRepository repo, {String id = clinica}) {
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      firebaseEnabledProvider.overrideWithValue(false),
      vaultProvider.overrideWith((ref) => VaultNotifier(ref, repo, id)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<void> aguardarBoot(ProviderContainer c) async {
    c.read(vaultProvider);
    while (c.read(vaultProvider).carregando) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('boot do vault', () {
    test('vault vazio continua vazio — nada de auto-popular 1.200 notas',
        () async {
      final repo = RepoEspiao();
      final c = containerCom(repo);
      await aguardarBoot(c);

      final estado = c.read(vaultProvider);
      expect(estado.index.totalNotas, 0);
      expect(estado.vazio, isTrue,
          reason: 'a tela deve oferecer a carga demo, não executá-la');
      expect(repo.lotes, 0, reason: 'boot não pode escrever no banco');
      expect(repo.salvamentos, 0);
    });

    test('vault com 1 nota só não dispara carga sintética', () async {
      final repo = RepoEspiao();
      await repo.salvarLote([
        VaultDemo.gerar(clinica, alvo: 60).first.copyWith(),
      ]);
      repo.lotes = 0;

      final c = containerCom(repo);
      await aguardarBoot(c);

      expect(c.read(vaultProvider).index.totalNotas, 1);
      expect(repo.lotes, 0);
    });

    test('a nota escrita em uma sessão reabre na sessão seguinte', () async {
      final repo = RepoEspiao();

      final sessao1 = containerCom(repo);
      await aguardarBoot(sessao1);
      final id = await sessao1
          .read(vaultProvider.notifier)
          .criar(path: 'protocolos/confirmacao-ativa.md');
      sessao1.dispose();

      // Sessão nova: mesmo banco, notifier do zero.
      final sessao2 = containerCom(repo);
      await aguardarBoot(sessao2);

      final reaberta = sessao2.read(vaultProvider.notifier).index.porId(id);
      expect(reaberta, isNotNull);
      expect(reaberta!.path, 'protocolos/confirmacao-ativa.md');
    });
  });

  group('clínica do vault', () {
    ProviderContainer comClinicas(List<dynamic> clinicas, {required bool fb}) {
      final container = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        firebaseEnabledProvider.overrideWithValue(fb),
        selectedClinicIdProvider.overrideWith((ref) => SelectedClinicNotifier(
              prefs,
              clinicas.cast(),
              const AppUser(id: 'u1', firstName: 'A', lastName: 'B'),
            )),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('com Firebase, o placeholder do mock não vira chave do vault', () {
      final c = comClinicas(MockData.clinics, fb: true);
      expect(c.read(selectedClinicIdProvider), MockData.clinics.first.id);
      expect(c.read(clinicaVaultProvider), '',
          reason: 'melhor esperar do que ler/gravar na clínica errada');
    });

    test('com a clínica real resolvida, o id passa', () {
      final reais = [
        Clinic(
          id: 'AbC123FirestoreDocId',
          name: 'Clínica Real',
          type: MockData.clinics.first.type,
        ),
      ];
      final c = comClinicas(reais, fb: true);
      expect(c.read(clinicaVaultProvider), 'AbC123FirestoreDocId');
    });

    test('sem Firebase o mock é fonte legítima e passa direto', () {
      final c = comClinicas(MockData.clinics, fb: false);
      expect(c.read(clinicaVaultProvider), MockData.clinics.first.id);
    });

    test('sem clínica o vault aguarda e recusa escrever', () async {
      final repo = RepoEspiao();
      final c = containerCom(repo, id: '');
      final estado = c.read(vaultProvider);

      expect(estado.aguardandoClinica, isTrue);
      expect(estado.carregando, isFalse);
      expect(estado.vazio, isFalse,
          reason: 'sem clínica não é vault vazio — é vault sem dono');

      await expectLater(
        c.read(vaultProvider.notifier).criar(path: 'orfa.md'),
        throwsA(isA<CerebroException>()),
      );
      expect(repo.salvamentos, 0);
    });
  });

  group('limpeza da carga de demonstração', () {
    test('remove só o que tem id nt_demo_ e preserva o resto', () async {
      final repo = RepoEspiao();
      final c = containerCom(repo);
      await aguardarBoot(c);

      final notifier = c.read(vaultProvider.notifier);
      await notifier.popularDemo(alvo: 60);
      final minha = await notifier.criar(path: 'decisoes/minha-nota.md');

      expect(notifier.totalDemo, greaterThan(0));
      final antes = notifier.index.totalNotas;

      final removidas = await notifier.limparDemo();

      expect(removidas, greaterThan(0));
      expect(notifier.totalDemo, 0);
      expect(notifier.index.porId(minha), isNotNull,
          reason: 'nota escrita por gente não pode sair na limpeza');
      expect(notifier.index.totalNotas, antes - removidas);
    });
  });
}
