import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/models/doctor.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/features/agenda_publica/agenda_publica_screen.dart';
import 'package:vitta_app/features/agenda_publica/public_agenda_service.dart';
import 'package:vitta_app/features/totem/models/totem_config.dart';

/// Página pública do médico (`/agenda-publica/:id`) — link que o profissional
/// compartilha por QR Code. Reaproveita a grade de horários do totem
/// (abertura 8h, fechamento 17h, consultas de 30 min na config padrão) e a
/// ocupação por `capacityAt`, mostrando foto/informações do médico.
///
/// A tela nunca fala com o Firestore direto — só com [PublicAgendaService]
/// (as Cloud Functions `publicAgendaProxy`/`publicAgendaSolicitar`, ver o
/// cabeçalho de `agenda_publica_screen.dart`). O fake abaixo simula o
/// servidor: guarda telefone internamente (como `tb_agendamentos` faria),
/// mas só devolve `startMs` em [PublicAgendaService.fetchAgenda] — a mesma
/// fronteira de privacidade que o backend real aplica.

const _doctorId = 'doc-publico';

/// Primeiro dia útil (seg–sex) **depois de hoje** dentro da faixa de 7 dias da
/// tira de datas: horários passados somem no dia corrente e a config padrão
/// fecha aos domingos, então o teste ancora num dia previsível.
DateTime _proximoDiaUtil() {
  final hoje = DateTime.now();
  var d = DateTime(hoje.year, hoje.month, hoje.day).add(const Duration(days: 1));
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

Doctor _medico({bool active = true}) => Doctor(
      id: _doctorId,
      name: 'Dra. Helena Prado',
      crm: 'CRM/SP 123456',
      specialties: const ['Cardiologia', 'Clínico Geral'],
      clinicId: 'clinica-1',
      bio: 'Atende adultos com foco em prevenção cardiovascular.',
      experience: '12 anos de experiência',
      phone: '(11) 98888-7777',
      active: active,
      slotLimit: 2, // capacidade 2 por horário (sem overbooking extra)
    );

/// Um horário já ocupado, do jeito que o servidor real guarda internamente
/// (com telefone, para a checagem de duplicidade) — nunca exposto ao cliente.
class _Ocupacao {
  const _Ocupacao(this.start, {this.telefoneDigits = '', this.cancelado = false});
  final DateTime start;
  final String telefoneDigits;
  final bool cancelado;
}

/// Simula as duas Cloud Functions (`publicAgendaProxy`/`publicAgendaSolicitar`)
/// para os testes de widget — sem rede, sem Firestore.
class _FakePublicAgendaService implements PublicAgendaService {
  _FakePublicAgendaService({
    this.doctor,
    this.totemConfig = const TotemConfig(),
    List<_Ocupacao>? ocupacoes,
  }) : ocupacoes = List.of(ocupacoes ?? const []);

  Doctor? doctor;
  TotemConfig totemConfig;
  final List<_Ocupacao> ocupacoes;

  /// Solicitações aceitas — o que teria ido para `tb_agendamentos`.
  final List<({String nome, String telefone, String? email, DateTime start})>
      aceitas = [];

  static String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  @override
  Future<AgendaPublicaDados> fetchAgenda({
    required String doctorId,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    if (doctor == null || doctor!.id != doctorId) {
      return const AgendaPublicaDados(found: false);
    }
    final ativos = ocupacoes.where((o) =>
        !o.cancelado && !o.start.isBefore(inicio) && o.start.isBefore(fim));
    return AgendaPublicaDados(
      found: true,
      doctor: doctor,
      totemConfig: totemConfig,
      // Só o horário — nunca o telefone (ver classe [_Ocupacao]).
      appointments: ativos.map((o) => o.start).toList(),
    );
  }

  @override
  Future<SolicitacaoResultado> solicitar({
    required String doctorId,
    required DateTime start,
    required int duracao,
    required DateTime diaInicio,
    required DateTime diaFim,
    required String nome,
    required String telefone,
    String? email,
  }) async {
    if (doctor == null || doctor!.id != doctorId) {
      return const SolicitacaoResultado.falha('medico_nao_encontrado');
    }
    if (doctor!.active == false) {
      return const SolicitacaoResultado.falha('medico_inativo');
    }
    final digits = _digits(telefone);
    final fimSlot = start.add(Duration(minutes: duracao));
    final ocupadosNoSlot = ocupacoes
        .where((o) =>
            !o.cancelado && !o.start.isBefore(start) && o.start.isBefore(fimSlot))
        .length;
    final capacidade =
        (doctor!.slotLimit < 1 ? 1 : doctor!.slotLimit) +
            (doctor!.maxOverbook < 0 ? 0 : doctor!.maxOverbook);
    if (ocupadosNoSlot >= capacidade) {
      return const SolicitacaoResultado.falha('sem_vaga');
    }
    final duplicadoNoDia = ocupacoes.any((o) =>
        !o.cancelado &&
        !o.start.isBefore(diaInicio) &&
        o.start.isBefore(diaFim) &&
        o.telefoneDigits == digits);
    if (duplicadoNoDia) {
      return const SolicitacaoResultado.falha('duplicado_no_dia');
    }
    final futuras = ocupacoes
        .where((o) =>
            !o.cancelado &&
            o.telefoneDigits == digits &&
            o.start.isAfter(DateTime.now()))
        .length;
    if (futuras >= 3) {
      return const SolicitacaoResultado.falha('limite_futuras');
    }

    ocupacoes.add(_Ocupacao(start, telefoneDigits: digits));
    aceitas.add((nome: nome, telefone: telefone, email: email, start: start));
    return const SolicitacaoResultado.ok(protocolo: 'AP-TESTE');
  }
}

Future<Widget> _wrap({
  Doctor? doctor,
  _FakePublicAgendaService? servico,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final sp = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(sp),
      publicAgendaServiceProvider.overrideWithValue(
          servico ?? _FakePublicAgendaService(doctor: doctor ?? _medico())),
    ],
    child: const MaterialApp(
      home: AgendaPublicaScreen(doctorId: _doctorId),
    ),
  );
}

/// Leva a tela do horário escolhido até o formulário de identificação.
Future<void> _abrirFormulario(WidgetTester tester, DateTime dia,
    {String hora = '08:00'}) async {
  await _irPara(tester, dia);
  await tester.tap(find.text(hora));
  await tester.pumpAndSettle();
  await tester.tap(find.text('SOLICITAR ESTE HORÁRIO'));
  await tester.pumpAndSettle();
}

/// Preenche o formulário de identificação e envia a solicitação.
Future<void> _preencherEEnviar(
  WidgetTester tester, {
  required String nome,
  required String telefone,
  String email = '',
}) async {
  await tester.enterText(find.byType(TextField).at(0), nome);
  await tester.enterText(find.byType(TextField).at(1), telefone);
  if (email.isNotEmpty) {
    await tester.enterText(find.byType(TextField).at(2), email);
  }
  await tester.pumpAndSettle();
  await tester.tap(find.text('ENVIAR SOLICITAÇÃO'));
  await tester.pumpAndSettle();
}

/// Move a página para [dia] tocando o número correspondente na tira de datas.
Future<void> _irPara(WidgetTester tester, DateTime dia) async {
  await tester.tap(find.text('${dia.day}').first);
  await tester.pumpAndSettle();
}

void main() {
  // `Fmt` formata datas em pt-BR; sem os dados de locale, DateFormat lança
  // LocaleDataException no ambiente de teste.
  setUpAll(() => initializeDateFormatting('pt_BR', null));

  setUp(() {
    // A página é desenhada para uma coluna centrada; superfície alta evita
    // que os horários fiquem fora da viewport nos testes.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('mostra foto/iniciais e as informações do profissional',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    expect(find.text('Dra. Helena Prado'), findsOneWidget);
    expect(find.text('CRM CRM/SP 123456'), findsOneWidget);
    expect(find.text('Cardiologia'), findsOneWidget);
    expect(find.text('Clínico Geral'), findsOneWidget);
    expect(find.text('12 anos de experiência'), findsOneWidget);
    expect(
        find.text('Atende adultos com foco em prevenção cardiovascular.'),
        findsOneWidget);
    // Sem photoUrl/photoBytes, o avatar cai nas iniciais do médico.
    expect(find.text('HP'), findsOneWidget);
  });

  testWidgets('gera a grade do totem (08:00–16:30 de 30 em 30 min)',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();
    await _irPara(tester, _proximoDiaUtil());

    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('16:30'), findsOneWidget);
    // 17:00 é o fechamento — a consulta não caberia inteira.
    expect(find.text('17:00'), findsNothing);
  });

  testWidgets('horário sem vaga aparece como LOTADO e não é selecionável',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dia = _proximoDiaUtil();
    final nove = DateTime(dia.year, dia.month, dia.day, 9);
    final servico = _FakePublicAgendaService(doctor: _medico(), ocupacoes: [
      _Ocupacao(nove, telefoneDigits: '11900000001'),
      // Ancorada no slot das 09:00 mesmo começando 09:15 (grade de 30 min).
      _Ocupacao(nove.add(const Duration(minutes: 15)),
          telefoneDigits: '11900000002'),
      // Cancelada não ocupa vaga.
      _Ocupacao(DateTime(dia.year, dia.month, dia.day, 10),
          telefoneDigits: '11900000003', cancelado: true),
    ]);

    await tester.pumpWidget(await _wrap(servico: servico));
    await tester.pumpAndSettle();
    await _irPara(tester, dia);

    // Capacidade 2 e 2 horários ativos às 09:00 → LOTADO.
    expect(find.text('LOTADO'), findsWidgets);

    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Horário escolhido'), findsNothing);

    // Às 10:00 o único horário está cancelado — as 2 vagas seguem livres.
    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets('selecionar um horário livre abre o resumo e a solicitação',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();
    await _irPara(tester, _proximoDiaUtil());

    await tester.tap(find.text('08:00'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Horário escolhido'), findsOneWidget);
    expect(find.textContaining('08:00'), findsWidgets);
    expect(find.text('SOLICITAR ESTE HORÁRIO'), findsOneWidget);
    expect(find.text('Copiar dados'), findsOneWidget);

    // "Limpar" desfaz a seleção.
    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Horário escolhido'), findsNothing);
  });

  testWidgets('médico inativo não expõe agenda', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _wrap(doctor: _medico(active: false)));
    await tester.pumpAndSettle();

    expect(find.text('Este profissional não está atendendo no momento.'),
        findsOneWidget);
    expect(find.text('Horários disponíveis'), findsNothing);
  });

  testWidgets('solicitação vira pré-agendado na clínica do médico',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final servico = _FakePublicAgendaService(doctor: _medico());
    await tester.pumpWidget(await _wrap(servico: servico));
    await tester.pumpAndSettle();

    final dia = _proximoDiaUtil();
    await _abrirFormulario(tester, dia);
    await _preencherEEnviar(tester,
        nome: 'Joana Ribeiro', telefone: '11987654321');

    expect(servico.aceitas, hasLength(1));
    final aceita = servico.aceitas.single;
    expect(aceita.nome, 'Joana Ribeiro');
    expect(aceita.start, DateTime(dia.year, dia.month, dia.day, 8));

    // Comprovante com protocolo e aviso de que ainda não está confirmada.
    expect(find.text('Solicitação enviada'), findsOneWidget);
    expect(find.text('PROTOCOLO'), findsOneWidget);
    expect(find.text('AP-TESTE'), findsOneWidget);
    expect(find.textContaining('ainda não está confirmada'), findsOneWidget);
  });

  testWidgets('formulário recusa nome curto e telefone incompleto',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final servico = _FakePublicAgendaService(doctor: _medico());
    await tester.pumpWidget(await _wrap(servico: servico));
    await tester.pumpAndSettle();

    await _abrirFormulario(tester, _proximoDiaUtil());

    await _preencherEEnviar(tester, nome: 'Jo', telefone: '11987654321');
    expect(find.text('Informe o nome completo.'), findsOneWidget);
    expect(servico.aceitas, isEmpty);

    // Sem limpar, o segundo aviso ficaria na fila atrás deste.
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
        .clearSnackBars();
    await tester.pumpAndSettle();

    await _preencherEEnviar(tester, nome: 'Joana Ribeiro', telefone: '119876');
    expect(find.text('Informe um telefone com DDD.'), findsOneWidget);
    expect(servico.aceitas, isEmpty);
  });

  testWidgets('mesmo telefone não solicita duas vezes no mesmo dia',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dia = _proximoDiaUtil();
    // Já existe um horário desse telefone com esse médico nesse dia — o
    // cliente nunca vê esse telefone; só o servidor (aqui, o fake) sabe.
    final servico = _FakePublicAgendaService(doctor: _medico(), ocupacoes: [
      _Ocupacao(DateTime(dia.year, dia.month, dia.day, 14),
          telefoneDigits: '11987654321'),
    ]);
    await tester.pumpWidget(await _wrap(servico: servico));
    await tester.pumpAndSettle();

    await _abrirFormulario(tester, dia);
    await _preencherEEnviar(tester,
        nome: 'Joana Ribeiro', telefone: '11987654321');

    expect(find.textContaining('Já existe uma consulta para este telefone'),
        findsOneWidget);
    expect(servico.aceitas, isEmpty);
  });

  testWidgets('id inexistente mostra link inválido', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const {});
    final sp = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(sp),
        publicAgendaServiceProvider.overrideWithValue(
            _FakePublicAgendaService(doctor: null)),
      ],
      child: const MaterialApp(
        home: AgendaPublicaScreen(doctorId: 'nao-existe'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Profissional não encontrado'), findsOneWidget);
  });
}
