import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/models/app_user.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/core/services/user_service.dart';
import 'package:vitta_app/features/admin_agentes/models/agent_model.dart';
import 'package:vitta_app/features/admin_agentes/models/queue_model.dart';
import 'package:vitta_app/features/admin_agentes/providers/agent_provider.dart';
import 'package:vitta_app/features/admin_agentes/providers/queue_provider.dart';
import 'package:vitta_app/features/admin_agentes/services/admin_agentes_repository.dart';
import 'package:vitta_app/features/notificacoes_centro/notificacoes_provider.dart';
import 'package:vitta_app/features/notificacoes_centro/notificacoes_repository.dart';
import 'package:vitta_app/features/relatorios/models/relatorio.dart';
import 'package:vitta_app/features/relatorios/providers/relatorios_provider.dart';
import 'package:vitta_app/features/relatorios/providers/relatorios_repository.dart';

// Os quatro módulos que a auditoria de 2026-08-20 encontrou sem persistência:
// perfil do usuário, agentes/filas, notificações e relatórios. Cada ação
// mudava só o `StateNotifier` e se perdia ao fechar o app — e o perfil ainda
// exibia "atualizado com sucesso" sem ter escrito nada.
//
// O teste aqui é sempre o mesmo: age numa "sessão", descarta o container e
// abre outra sobre o MESMO repositório. O que não persistiu não reaparece.
void main() {
  const clinica = 'clinica-real';

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Lê o provider (Riverpod é lazy: sem isso o notifier nem é construído) e
  /// deixa o `carregar()` do construtor terminar antes de conferir o estado.
  Future<T> aoAbrir<T>(
      ProviderContainer c, ProviderListenable<T> provider) async {
    c.read(provider);
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return c.read(provider);
  }

  group('perfil do usuário', () {
    test('salvar grava de verdade e o perfil volta na sessão seguinte',
        () async {
      final servico = MockUserService();
      final container = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        userServiceProvider.overrideWithValue(servico),
      ]);
      addTearDown(container.dispose);

      final base = container.read(currentUserProvider);
      await container.read(currentUserProvider.notifier).salvar(
            base.copyWith(
              firstName: 'Alessandra',
              phone: '(11) 98888-7777',
              address: base.address.copyWith(
                cep: '01001-000',
                city: 'São Paulo',
                state: 'SP',
              ),
            ),
          );

      // Sessão nova sobre o mesmo serviço.
      final salvo = await servico.fetchByUid('qualquer');
      expect(salvo, isNotNull);
      expect(salvo!.firstName, 'Alessandra');
      expect(salvo.phone, '(11) 98888-7777');
      expect(salvo.address.city, 'São Paulo');
    });

    test('o endereço sobrevive à ida e volta do Firestore', () {
      const endereco = UserAddress(
        cep: '04567-000',
        street: 'Rua das Palmeiras',
        number: '42',
        complement: 'sala 3',
        district: 'Brooklin',
        city: 'São Paulo',
        state: 'SP',
      );
      const user = AppUser(
        id: 'u1',
        firstName: 'Ana',
        lastName: 'Souza',
        address: endereco,
      );

      // `fromFirestore` ignorava `endereco` — gravar era inútil.
      final volta = UserAddress.fromMap(user.toFirestore()['endereco']);
      expect(volta.cep, endereco.cep);
      expect(volta.street, endereco.street);
      expect(volta.complement, endereco.complement);
      expect(volta.state, endereco.state);
    });

    test('a gravação é parcial e não apaga campos administrativos', () {
      const user = AppUser(id: 'u1', firstName: 'Ana', lastName: 'Souza');
      final campos = user.toFirestore().keys;
      expect(campos, isNot(contains('roles')));
      expect(campos, isNot(contains('idclinica')));
    });
  });

  group('agentes e filas', () {
    ProviderContainer sessao(AdminAgentesRepository repo) {
      final c = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        adminAgentesRepositoryProvider.overrideWithValue(repo),
        clinicaResolvidaProvider.overrideWithValue(clinica),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('agente cadastrado reaparece na sessão seguinte', () async {
      final repo = MemoriaAdminAgentesRepository();

      final s1 = sessao(repo);
      await aoAbrir(s1, agentsProvider);
      await s1.read(agentsProvider.notifier).addAgent(const AgentModel(
            id: 'ag-1',
            nomeOperacional: 'Carla Recepção',
            email: 'carla@clinica.com',
            pin: '445566',
            setores: ['SUPORTE GERAL'],
          ));
      s1.dispose();

      final s2 = sessao(repo);
      final agentes = await aoAbrir(s2, agentsProvider);
      expect(agentes, hasLength(1));
      expect(agentes.single.nomeOperacional, 'Carla Recepção');
      expect(agentes.single.setores, ['SUPORTE GERAL']);
    });

    test('disponibilidade persiste; carga de atendimento não', () async {
      final repo = MemoriaAdminAgentesRepository();
      final s1 = sessao(repo);
      await aoAbrir(s1, agentsProvider);
      final n1 = s1.read(agentsProvider.notifier);
      await n1.addAgent(const AgentModel(
        id: 'ag-1',
        nomeOperacional: 'Carla',
        email: 'c@c.com',
        pin: '1',
      ));
      await n1.updateAvailability('ag-1', AgentAvailability.online);
      n1.incrementLoad('ag-1');
      expect(s1.read(agentsProvider).single.cargaAtivos, 1);
      s1.dispose();

      final s2 = sessao(repo);
      final agente = (await aoAbrir(s2, agentsProvider)).single;
      expect(agente.disponibilidade, AgentAvailability.online);
      expect(agente.cargaAtivos, 0,
          reason: 'carga ativa é estado de sessão, por decisão explícita');
    });

    test('remover agente também remove do repositório', () async {
      final repo = MemoriaAdminAgentesRepository();
      final s1 = sessao(repo);
      await aoAbrir(s1, agentsProvider);
      await s1.read(agentsProvider.notifier).addAgent(const AgentModel(
          id: 'ag-1', nomeOperacional: 'X', email: 'x@x.com', pin: '1'));
      await s1.read(agentsProvider.notifier).removeAgent('ag-1');
      s1.dispose();

      final s2 = sessao(repo);
      expect(await aoAbrir(s2, agentsProvider), isEmpty);
    });

    test('fila criada e editada sobrevive', () async {
      final repo = MemoriaAdminAgentesRepository();
      final s1 = sessao(repo);
      await aoAbrir(s1, queuesProvider);
      const fila = QueueModel(id: 'q-1', name: 'FINANCEIRO');
      await s1.read(queuesProvider.notifier).addQueue(fila);
      await s1
          .read(queuesProvider.notifier)
          .updateQueue(fila.copyWith(name: 'FINANCEIRO E COBRANÇA'));
      s1.dispose();

      final s2 = sessao(repo);
      final filas = await aoAbrir(s2, queuesProvider);
      expect(filas.single.name, 'FINANCEIRO E COBRANÇA');
    });

    test('serialização preserva SLA e estratégia', () {
      const fila = QueueModel(
        id: 'q-1',
        name: 'TRIAGEM',
        distributionStrategy: DistributionStrategy.roundRobin,
        sla: QueueSla(
          firstResponse: Duration(minutes: 2),
          resolution: Duration(minutes: 45),
        ),
        agentIds: ['ag-1', 'ag-2'],
      );
      final volta = QueueModel.fromFirestore('q-1', fila.toFirestore(clinica));
      expect(volta.name, 'TRIAGEM');
      expect(volta.distributionStrategy, DistributionStrategy.roundRobin);
      expect(volta.sla.firstResponse, const Duration(minutes: 2));
      expect(volta.sla.resolution, const Duration(minutes: 45));
      expect(volta.agentIds, ['ag-1', 'ag-2']);
    });
  });

  group('notificações', () {
    ProviderContainer sessao(NotificacoesRepository repo) {
      final c = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        notificacoesRepositoryProvider.overrideWithValue(repo),
        clinicaResolvidaProvider.overrideWithValue(clinica),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('marcar como lida sobrevive ao restart (o badge não volta do zero)',
        () async {
      final repo = MemoriaNotificacoesRepository();
      final s1 = sessao(repo);
      await aoAbrir(s1, notificacoesProvider);
      await s1.read(notificacoesProvider.notifier).push(
            type: NotificationType.overbooking,
            title: 'Horário realocado',
            message: 'Consulta das 14h remanejada.',
          );
      final id = (await aoAbrir(s1, notificacoesProvider)).single.id;
      expect(s1.read(unreadCountProvider), 1);
      await s1.read(notificacoesProvider.notifier).markRead(id);
      s1.dispose();

      final s2 = sessao(repo);
      final feed = await aoAbrir(s2, notificacoesProvider);
      expect(feed.single.read, isTrue);
      expect(s2.read(unreadCountProvider), 0);
    });

    test('marcar todas e remover persistem', () async {
      final repo = MemoriaNotificacoesRepository();
      final s1 = sessao(repo);
      await aoAbrir(s1, notificacoesProvider);
      final n1 = s1.read(notificacoesProvider.notifier);
      for (var i = 0; i < 3; i++) {
        await n1.add(NotificationItem(
          id: 'evt_$i',
          type: NotificationType.risco,
          title: 'Risco $i',
          message: 'msg',
          time: DateTime(2026, 8, 20, 10, i),
        ));
      }
      await n1.markAllRead();
      await n1.remove('evt_1');
      s1.dispose();

      final s2 = sessao(repo);
      final feed = await aoAbrir(s2, notificacoesProvider);
      expect(feed, hasLength(2));
      expect(feed.every((n) => n.read), isTrue);
      expect(feed.any((n) => n.id == 'evt_1'), isFalse);
    });
  });

  group('relatórios', () {
    test('relatório gerado sobrevive à sessão', () async {
      final repo = MemoriaRelatoriosRepository();
      ProviderContainer sessao() {
        final c = ProviderContainer(overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          relatoriosRepositoryProvider.overrideWithValue(repo),
          clinicaResolvidaProvider.overrideWithValue(clinica),
        ]);
        addTearDown(c.dispose);
        return c;
      }

      final s1 = sessao();
      await aoAbrir(s1, relatoriosProvider);
      await s1.read(relatoriosProvider.notifier).add(Relatorio(
            id: 'rel-1',
            title: 'Absenteísmo — agosto',
            type: RelatorioType.absenteismo,
            createdAt: DateTime(2026, 8, 20),
            period: 'Últimos 30 dias',
            body: 'Faltas concentradas às segundas.',
            metrics: const [RelatorioMetric('Absenteísmo', '18%')],
          ));
      s1.dispose();

      final s2 = sessao();
      final lista = await aoAbrir(s2, relatoriosProvider);
      expect(lista, hasLength(1));
      expect(lista.single.title, 'Absenteísmo — agosto');
      expect(lista.single.metrics.single.value, '18%');
    });
  });
}
