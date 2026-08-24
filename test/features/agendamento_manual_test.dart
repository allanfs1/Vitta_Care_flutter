import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/core/models/appointment.dart';
import 'package:vitta_app/core/models/doctor.dart';
import 'package:vitta_app/core/models/patient.dart';
import 'package:vitta_app/core/services/app_providers.dart';
import 'package:vitta_app/core/services/email_service.dart';
import 'package:vitta_app/features/agendamentos/widgets/new_appointment_dialog.dart';

/// [EmailService] que registra as confirmações disparadas (sem rede).
class _RecordingEmailService extends EmailService {
  _RecordingEmailService();
  int emailCalls = 0;
  int whatsappCalls = 0;

  @override
  Future<bool> sendConfirmation({
    required String? to,
    required Appointment appointment,
    required bool isReschedule,
    required String clinicName,
    String? senha,
    String? footer,
  }) async {
    emailCalls++;
    return true;
  }

  @override
  Future<bool> sendWhatsappConfirmation({
    required String clinicaId,
    required String? phone,
    required Appointment appointment,
    required bool isReschedule,
    required String clinicName,
    String? senha,
    required String link,
  }) async {
    whatsappCalls++;
    return true;
  }
}

/// A-02 — Formulário de agendamento manual (aberto pelo botão "+" da agenda).
///
/// Os testes exercitam o próprio [NewAppointmentDialog] em isolamento (o FAB da
/// [AgendamentosScreen] apenas faz `showDialog(NewAppointmentDialog())`): o
/// formulário é alimentado por dados reais (pacientes/médicos dos providers) e
/// só habilita "Finalizar" quando os campos obrigatórios estão preenchidos.

/// Envolve o diálogo com ProviderScope + MaterialApp (SharedPreferences mockado)
/// numa superfície ampla (o layout é desenhado para desktop, 2 painéis).
Future<Widget> _wrapDialog() async {
  SharedPreferences.setMockInitialValues(const {});
  final sp = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(sp)],
    child: const MaterialApp(home: Scaffold(body: NewAppointmentDialog())),
  );
}

void main() {
  // `Fmt` formata datas em pt-BR; sem os dados de locale, os widgets que usam
  // DateFormat lançam LocaleDataException no ambiente de teste.
  setUpAll(() => initializeDateFormatting('pt_BR', null));

  testWidgets('o formulário abre com as seções e o resumo esperados',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _wrapDialog());
    await tester.pumpAndSettle();

    expect(find.text('IDENTIFICAÇÃO DO PACIENTE'), findsOneWidget);
    expect(find.text('ESPECIALISTA E SERVIÇO'), findsOneWidget);
    expect(find.text('AGENDA E HORÁRIO'), findsOneWidget);
    expect(find.text('RESUMO DO AGENDAMENTO'), findsOneWidget);
  });

  testWidgets('"Finalizar" começa desabilitado (validação de obrigatórios)',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _wrapDialog());
    await tester.pumpAndSettle();

    final botao = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('FINALIZAR AGENDAMENTO'),
        matching: find.byType(ElevatedButton),
      ),
    );
    // Sem paciente/médico/data selecionados, o botão fica inativo.
    expect(botao.onPressed, isNull);
  });

  testWidgets('paciente e médico vêm de dados reais e preenchem o resumo',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _wrapDialog());
    await tester.pumpAndSettle();

    // Dropdown de PACIENTE: itens vêm do catálogo real (MockData.patients),
    // não da lista fixa antiga ('João Silva'/'Maria Oliveira'/'Allan…').
    await tester.tap(find.byType(DropdownButtonFormField<Patient>));
    await tester.pumpAndSettle();
    expect(find.text('Maria Santos'), findsWidgets);
    expect(find.text('Carlos Souza'), findsWidgets);
    await tester.tap(find.text('Maria Santos').last);
    await tester.pumpAndSettle();

    // Dropdown de MÉDICO: itens vêm de doctorsProvider (Dr(a). …).
    await tester.tap(find.byType(DropdownButtonFormField<Doctor>));
    await tester.pumpAndSettle();
    final medico = find.textContaining(RegExp(r'^Dr')).last;
    await tester.tap(medico);
    await tester.pumpAndSettle();

    // O paciente escolhido aparece no painel de resumo à direita.
    expect(find.text('Maria Santos'), findsWidgets);
  });

  testWidgets('finalizar dispara a confirmação por WhatsApp (Z-API)',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final email = _RecordingEmailService();
    SharedPreferences.setMockInitialValues(const {});
    final sp = await SharedPreferences.getInstance();
    // Hospeda o diálogo atrás de um botão que o abre via showDialog, para que o
    // Navigator.pop do "Finalizar" tenha uma rota real para fechar.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(sp),
        emailServiceProvider.overrideWithValue(email),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                    context: ctx, builder: (_) => const NewAppointmentDialog()),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Paciente (tem telefone no mock → habilita WhatsApp) e médico.
    await tester.tap(find.byType(DropdownButtonFormField<Patient>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maria Santos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Doctor>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp(r'^Dr')).last);
    await tester.pumpAndSettle();

    // Data e hora via os seletores (aceita os valores iniciais com "OK").
    await tester.tap(find.text('DATA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HORÁRIO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Finaliza — deve criar o agendamento e disparar a confirmação.
    await tester.tap(find.text('FINALIZAR AGENDAMENTO'));
    await tester.pumpAndSettle();

    expect(email.whatsappCalls, greaterThanOrEqualTo(1));
    // O diálogo fechou e o snackbar de sucesso (com a senha) apareceu.
    expect(find.byType(NewAppointmentDialog), findsNothing);
    expect(find.textContaining('Senha:'), findsOneWidget);
  });
}
