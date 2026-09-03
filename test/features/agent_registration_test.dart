import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/admin_agentes/models/agent_model.dart';
import 'package:vitta_app/features/admin_agentes/providers/agent_provider.dart';
import 'package:vitta_app/features/admin_agentes/services/admin_agentes_repository.dart';
import 'package:vitta_app/features/admin_agentes/services/agent_registration_service.dart';

// `AgentRegistrationService` tinha os dois passos do cadastro (criar o login
// no Auth, gravar o perfil em `users`) marcados como `TODO(firebase)` —
// cadastrar um agente só logava no console, ninguém conseguia entrar de
// verdade. Aqui cobrimos o que dá para testar sem um emulador de Auth: o
// caminho sem Firebase (modo demonstração), que precisa continuar
// funcionando idêntico, e as validações antes de qualquer chamada ao Auth.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer container(AdminAgentesRepository repo, {bool firebase = false}) {
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      firebaseEnabledProvider.overrideWithValue(firebase),
      adminAgentesRepositoryProvider.overrideWithValue(repo),
      clinicaResolvidaProvider.overrideWithValue('clinica-real'),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('sem Firebase (modo demonstração)', () {
    test('cadastra e persiste no repositório operacional', () async {
      final repo = MemoriaAdminAgentesRepository();
      final c = container(repo);

      final r = await c.read(agentRegistrationServiceProvider).registerAgent(
            nomeOperacional: 'Carla Recepção',
            email: 'Carla@Clinica.com',
            pin: '445566',
            disponibilidade: AgentAvailability.online,
            setores: const ['SUPORTE GERAL'],
          );

      expect(r.ok, isTrue);
      expect(r.agent!.email, 'carla@clinica.com',
          reason: 'e-mail deve ser normalizado para minúsculo');

      final agentes = await repo.carregarAgentes('clinica-real');
      expect(agentes, hasLength(1));
      expect(agentes.single.nomeOperacional, 'Carla Recepção');
    });

    test('recusa e-mail duplicado antes de qualquer gravação', () async {
      final repo = MemoriaAdminAgentesRepository();
      final c = container(repo);
      final servico = c.read(agentRegistrationServiceProvider);

      await servico.registerAgent(
        nomeOperacional: 'Carla',
        email: 'carla@clinica.com',
        pin: '111111',
        disponibilidade: AgentAvailability.online,
      );

      final r2 = await servico.registerAgent(
        nomeOperacional: 'Outra Carla',
        email: 'CARLA@clinica.com',
        pin: '222222',
        disponibilidade: AgentAvailability.offline,
      );

      expect(r2.ok, isFalse);
      expect(r2.error, contains('Já existe'));

      final agentes = await repo.carregarAgentes('clinica-real');
      expect(agentes, hasLength(1),
          reason: 'a tentativa duplicada não pode ter gravado nada');
    });

    test('o agente cadastrado aparece no provider da tela', () async {
      final repo = MemoriaAdminAgentesRepository();
      final c = container(repo);

      c.read(agentsProvider);
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      await c.read(agentRegistrationServiceProvider).registerAgent(
            nomeOperacional: 'Novo Agente',
            email: 'novo@clinica.com',
            pin: '999999',
            disponibilidade: AgentAvailability.online,
          );

      expect(
        c.read(agentsProvider).any((a) => a.email == 'novo@clinica.com'),
        isTrue,
      );
    });
  });
}
