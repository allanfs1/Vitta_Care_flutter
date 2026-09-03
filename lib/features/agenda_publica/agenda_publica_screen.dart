import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/doctor.dart';
import '../../core/utils/formatters.dart';
import '../overbooking/occupancy.dart';
import '../totem/models/totem_config.dart';
import 'public_agenda_service.dart';
import 'widgets/compartilhar_agenda_dialog.dart';

const _kBrand = Color(0xFFFF3B30);
const _kAccent = Color(0xFF23BAD4);
const _kInk = Color(0xFF11151C);

/// Etapas da página: escolher o horário → identificar-se → comprovante.
enum _Etapa { agenda, dados, sucesso }

/// Horário com ocupação dinâmica (overbooking §1) — mesma regra do totem, mas
/// restrita a um único médico.
class _Slot {
  const _Slot({
    required this.time,
    required this.booked,
    required this.capacity,
  });

  final String time;
  final int booked;
  final int capacity;

  /// Capacidade normalizada (>= 1): evita divisão por zero e o falso "LOTADO"
  /// quando a config zera a capacidade (ver OVERBOOKING.md §B3).
  int get _cap => capacity < 1 ? 1 : capacity;
  OccupancyLevel get level =>
      OccupancyLevel.from(booked: booked, capacity: _cap);
  bool get full => level.isFull;
  int get remaining => (_cap - booked) < 0 ? 0 : _cap - booked;
}

/// Página **pública** da agenda de um médico (acessível sem login, pelo link /
/// QR Code que o próprio profissional compartilha).
///
/// Reaproveita a lógica de horários do Totem (`totem_screen.dart`): a grade sai
/// da [TotemConfig] da clínica do médico (abertura/fechamento, duração da
/// consulta, almoço, sábado/domingo) e a ocupação de cada slot vem dos
/// agendamentos ativos, com a capacidade calculada por `capacityAt`
/// (overbooking §1). O que muda é o cenário: aqui não há sessão nem
/// autoatendimento — a página mostra a foto e as informações do profissional e
/// os horários **disponíveis**, em tempo real.
///
/// O paciente pode **solicitar** um horário: a consulta é gravada como
/// `pre-agendado`, para a clínica confirmar — nunca já confirmada. Duas
/// diferenças deliberadas em relação ao totem, que é um aparelho **dentro** da
/// clínica enquanto isto é um link na internet:
///
/// - **Sem busca por CPF.** O totem identifica o paciente consultando `users`
///   pelo CPF; num link aberto isso viraria um oráculo de enumeração (digitar
///   CPFs até descobrir quem é cadastrado). Aqui a identificação é nome +
///   telefone, e a clínica confere na confirmação.
/// - **Anti-abuso sem varrer a clínica.** O totem lê todos os agendamentos
///   para aplicar os limites; esta tela usa só a agenda **deste** médico, que
///   já está carregada.
///
/// **Nunca fala com o Firestore direto.** Tanto a leitura (perfil + horários
/// ocupados) quanto a escrita (solicitar um horário) passam por
/// [PublicAgendaService], que chama duas Cloud Functions com Admin SDK
/// (`functions/publicAgendaProxy.js` e `functions/publicAgendaSolicitar` em
/// `publicAgendaProxy.js`). Isso existe porque o Firestore não filtra campos:
/// se o cliente lesse `tb_agendamentos` direto (como o SDK normalmente faz),
/// o documento inteiro viria junto — nome, CPF, telefone e motivo de cada
/// paciente do médico, exatamente o que vazou por leitura anônima em
/// 2026-08-26 (ver `.specify/ATENCAO.md`, 🔴 Crítico, e
/// `EMERGENCIA-firestore.rules`). As Functions devolvem só o que esta tela
/// usa (perfil profissional, config de horário, horários **de início**
/// ocupados) e validam a solicitação no servidor — nome, telefone, vaga
/// disponível e duplicidade — antes de gravar. `firestore.rules` pode ficar
/// **fechado** (leitura e escrita) para quem não está logado sem quebrar esta
/// tela.
///
/// `/agenda-medico/:id` (`medico_agenda_screen.dart`) é uma tela diferente,
/// usada de dentro do app pela equipe da clínica — mostra nome de paciente de
/// propósito e continua lendo `tb_agendamentos` direto; não é afetada por
/// esta mudança.
class AgendaPublicaScreen extends ConsumerStatefulWidget {
  const AgendaPublicaScreen({super.key, required this.doctorId});

  final String doctorId;

  @override
  ConsumerState<AgendaPublicaScreen> createState() =>
      _AgendaPublicaScreenState();
}

class _AgendaPublicaScreenState extends ConsumerState<AgendaPublicaScreen> {
  static const _weekdaysShort = [
    'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'
  ];

  late DateTime _date;
  DateTime _now = DateTime.now();
  Timer? _ticker;
  String? _selTime;

  // Perfil do médico e config da clínica não mudam ao trocar de dia — ficam
  // em cache para a troca de data não apagar a página inteira (perfil
  // incluso) enquanto só a ocupação do novo dia ainda está chegando.
  Doctor? _doctorCache;
  TotemConfig? _tcCache;

  // Solicitação de horário
  _Etapa _etapa = _Etapa.agenda;
  final _nomeCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _busy = false;
  String? _protocolo;

  @override
  void initState() {
    super.initState();
    _date = _startOfDay(DateTime.now());
    // Mantém o relógio e o corte de "horários passados" atualizados. Não há
    // contador de sessão como no totem (aqui nada expira por inatividade).
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [_nomeCtrl, _telCtrl, _emailCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------- helpers
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _pickDate(DateTime d) => setState(() {
        _date = _startOfDay(d);
        _selTime = null;
      });

  /// Gera os horários do dia selecionado com **ocupação dinâmica**: conta os
  /// horários já ocupados do médico por slot da grade e compara com a
  /// capacidade dele naquele horário (limite base + overbooking). [ocupados]
  /// já vem filtrado (só não-cancelados) pela Cloud Function — ver
  /// `PublicAgendaService`.
  List<_Slot> _buildSlots(
      Doctor doctor, TotemConfig tc, List<DateTime> ocupados) {
    final wd = _date.weekday; // 1 seg .. 7 dom
    if (wd == DateTime.sunday && !tc.openSunday) return [];
    if (wd == DateTime.saturday && !tc.openSaturday) return [];

    final endHour =
        wd == DateTime.saturday ? tc.saturdayCloseHour : tc.closeHour;
    // Grade no passo da duração da consulta; o slot só entra se a consulta
    // inteira couber antes do fechamento.
    final step = tc.appointmentDuration < 5 ? 5 : tc.appointmentDuration;
    final openMin = tc.openHour * 60;
    String hhmm(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

    final times = [
      for (var m = openMin; m + step <= endHour * 60; m += step)
        // Pula o intervalo de almoço quando configurado.
        if (!(tc.lunchBreakEnabled &&
            (m ~/ 60) >= tc.lunchStartHour &&
            (m ~/ 60) < tc.lunchEndHour))
          hhmm(m)
    ];

    // Ancora cada horário ocupado no slot da grade que o contém — um horário
    // às 09:15 numa grade de 30 min ocupa o slot 09:00.
    final bookedCount = <String, int>{};
    for (final start in ocupados) {
      if (!_sameDay(start, _date)) continue;
      final startMin = start.hour * 60 + start.minute;
      if (startMin < openMin) continue;
      final t = hhmm(openMin + ((startMin - openMin) ~/ step) * step);
      bookedCount[t] = (bookedCount[t] ?? 0) + 1;
    }

    final isToday = _sameDay(_date, _now);
    final nowMin = _now.hour * 60 + _now.minute;
    final slots = <_Slot>[];
    for (final t in times) {
      if (isToday) {
        final m =
            int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3, 5));
        if (m <= nowMin) continue; // não mostra horários passados hoje
      }
      slots.add(_Slot(
        time: t,
        booked: bookedCount[t] ?? 0,
        capacity: doctor.capacityAt(wd, t),
      ));
    }
    return slots;
  }

  // ------------------------------------------------- solicitar horário
  static String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// Traduz o código de erro devolvido por `publicAgendaSolicitar` — a
  /// validação de verdade é sempre refeita no servidor (ver o cabeçalho desta
  /// classe); estas mensagens só orientam o visitante.
  String _mensagemErro(String? codigo) => switch (codigo) {
        'nome_invalido' => 'Informe o nome completo.',
        'telefone_invalido' => 'Informe um telefone com DDD.',
        'email_invalido' => 'E-mail inválido. Corrija ou deixe em branco.',
        'horario_passado' =>
          'Este horário não está mais disponível. Escolha outro.',
        'sem_vaga' => 'Este horário acabou de ser preenchido. Escolha outro.',
        'duplicado_no_dia' => 'Já existe uma consulta para este telefone '
            'nesta data com este profissional.',
        'limite_futuras' => 'Este telefone já tem consultas futuras com este '
            'profissional. Fale com a clínica para marcar outra.',
        'medico_inativo' =>
          'Este profissional não está atendendo no momento.',
        'medico_nao_encontrado' => 'Profissional não encontrado.',
        _ => 'Não foi possível enviar a solicitação. Tente novamente.',
      };

  Future<void> _enviarSolicitacao(Doctor doctor, TotemConfig tc) async {
    final nome = _nomeCtrl.text.trim();
    final telefone = _digits(_telCtrl.text);
    final email = _emailCtrl.text.trim();

    // Validação leve no cliente (resposta imediata); o servidor refaz tudo.
    if (nome.length < 3) {
      _aviso(_mensagemErro('nome_invalido'));
      return;
    }
    if (telefone.length < 10) {
      _aviso(_mensagemErro('telefone_invalido'));
      return;
    }
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _aviso(_mensagemErro('email_invalido'));
      return;
    }

    final hora = _selTime;
    if (hora == null) {
      setState(() => _etapa = _Etapa.agenda);
      return;
    }
    final partes = hora.split(':');
    final inicio = DateTime(_date.year, _date.month, _date.day,
        int.parse(partes[0]), int.parse(partes[1]));
    final diaInicio = _startOfDay(_date);
    final diaFim = diaInicio.add(const Duration(days: 1));

    setState(() => _busy = true);
    final resultado = await ref.read(publicAgendaServiceProvider).solicitar(
          doctorId: doctor.id,
          start: inicio,
          duracao: tc.appointmentDuration,
          diaInicio: diaInicio,
          diaFim: diaFim,
          nome: nome,
          telefone: _telCtrl.text.trim(),
          email: email.isEmpty ? null : email,
        );
    if (!mounted) return;

    if (!resultado.ok) {
      setState(() => _busy = false);
      // Vaga preenchida ou horário virou passado: volta para a grade
      // atualizada em vez de deixar o visitante reenviar o mesmo horário.
      if (resultado.erro == 'sem_vaga' || resultado.erro == 'horario_passado') {
        setState(() {
          _selTime = null;
          _etapa = _Etapa.agenda;
        });
        ref.invalidate(publicAgendaDataProvider);
      }
      _aviso(_mensagemErro(resultado.erro));
      return;
    }

    setState(() {
      _busy = false;
      _protocolo = resultado.protocolo;
      _etapa = _Etapa.sucesso;
    });
  }

  void _voltarParaAgenda() => setState(() {
        _etapa = _Etapa.agenda;
        _selTime = null;
        _protocolo = null;
        for (final c in [_nomeCtrl, _telCtrl, _emailCtrl]) {
          c.clear();
        }
        ref.invalidate(publicAgendaDataProvider);
      });

  void _aviso(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  /// Chave do dia atual para [publicAgendaDataProvider]: início/fim do dia
  /// local em epoch ms — o mesmo instante que `publicAgendaProxy.js` usa para
  /// bater a janela `[inicioMs, fimMs)` de `dataConsulta` no Firestore, sem
  /// depender de qual fuso o servidor roda.
  (String, int, int) get _agendaKey {
    final inicio = _startOfDay(_date);
    final fim = inicio.add(const Duration(days: 1));
    return (
      widget.doctorId,
      inicio.millisecondsSinceEpoch,
      fim.millisecondsSinceEpoch,
    );
  }

  // ------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final key = _agendaKey;
    final dadosAsync = ref.watch(publicAgendaDataProvider(key));
    // Atualiza o cache assim que um dia carrega — perfil/config valem para
    // qualquer dia, então ficam prontos para a próxima troca de data.
    ref.listen(publicAgendaDataProvider(key), (_, next) {
      final d = next.valueOrNull;
      if (d != null && d.found && d.doctor != null) {
        _doctorCache = d.doctor;
        _tcCache = d.totemConfig;
      }
    });

    final doctor = dadosAsync.valueOrNull?.doctor ?? _doctorCache;
    final tc = dadosAsync.valueOrNull?.totemConfig ?? _tcCache;
    final naoEncontrado =
        dadosAsync.valueOrNull != null && !dadosAsync.valueOrNull!.found;

    Widget body;
    if (naoEncontrado) {
      body = _message(
        icon: Icons.person_off_outlined,
        title: 'Profissional não encontrado',
        subtitle: 'Este link de agenda não é mais válido.',
      );
    } else if (doctor == null || tc == null) {
      // Primeira carga: sem cache ainda, mostra carregando/erro em tela cheia.
      body = dadosAsync.hasError
          ? _message(
              icon: Icons.wifi_off,
              title: 'Não foi possível carregar a agenda',
              subtitle: 'Verifique sua conexão e tente novamente.',
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      // Já há perfil (atual ou em cache): desenha a página, com a grade de
      // horários mostrando o próprio spinner se o novo dia ainda carrega.
      final ocupados = dadosAsync.valueOrNull?.appointments ?? const [];
      body = _content(doctor, tc, ocupados,
          carregandoDia: dadosAsync.isLoading || dadosAsync.hasError);
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFEEF3F7)],
            center: Alignment.topLeft,
            radius: 1.5,
          ),
        ),
        child: SafeArea(child: body),
      ),
    );
  }

  Widget _content(Doctor doctor, TotemConfig tc, List<DateTime> ocupados,
      {required bool carregandoDia}) {
    final slots = _buildSlots(doctor, tc, ocupados);
    final free = slots.where((s) => !s.full).length;

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(tc.scale)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          return SingleChildScrollView(
            padding: EdgeInsets.all(narrow ? 16 : 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _topBar(doctor, tc, narrow: narrow),
                    const SizedBox(height: 16),
                    _doctorHero(doctor, tc, narrow: narrow),
                    const SizedBox(height: 16),
                    if (!doctor.active)
                      _banner(
                        icon: Icons.pause_circle_outline,
                        color: const Color(0xFFF5A623),
                        text:
                            'Este profissional não está atendendo no momento.',
                      )
                    else ...[
                      switch (_etapa) {
                        _Etapa.agenda => _agendaCard(doctor, tc, slots, free,
                            loading: carregandoDia, narrow: narrow),
                        _Etapa.dados => _dadosCard(doctor, tc, narrow: narrow),
                        _Etapa.sucesso =>
                          _sucessoCard(doctor, tc, narrow: narrow),
                      },
                      const SizedBox(height: 16),
                      _footer(tc),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- top bar
  Widget _topBar(Doctor doctor, TotemConfig tc, {required bool narrow}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: _card(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.health_and_safety, color: tc.accentColor, size: 24),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  tc.clinicName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900, color: _kInk),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => CompartilharAgendaDialog.show(
              context,
              doctor: doctor,
              config: tc,
            ),
            child: _card(
              padding: EdgeInsets.symmetric(
                  horizontal: narrow ? 12 : 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share_rounded, color: tc.accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    narrow ? 'Compartilhar' : 'Compartilhar Página',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: tc.accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (tc.showClock && !narrow) ...[
          const SizedBox(width: 10),
          _card(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule, color: tc.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _kInk,
                    fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------- médico
  Widget _doctorHero(Doctor d, TotemConfig tc, {required bool narrow}) {
    final photo = _photoOf(d);
    final avatar = CircleAvatar(
      radius: narrow ? 40 : 48,
      backgroundColor: tc.accentColor.withValues(alpha: 0.1),
      backgroundImage: photo,
      child: photo == null
          ? Text(d.initials,
              style: TextStyle(
                  color: tc.accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: narrow ? 24 : 30))
          : null,
    );

    final info = Column(
      crossAxisAlignment:
          narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          d.name,
          textAlign: narrow ? TextAlign.center : TextAlign.start,
          style: TextStyle(
              fontSize: narrow ? 22 : 26,
              fontWeight: FontWeight.w900,
              color: tc.accentColor),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: narrow ? WrapAlignment.center : WrapAlignment.start,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in d.specialties)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(s,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('CRM ${d.crm}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600])),
        if ((d.experience ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(d.experience!.trim(),
              textAlign: narrow ? TextAlign.center : TextAlign.start,
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ],
      ],
    );

    return _card(
      padding: EdgeInsets.all(narrow ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (narrow)
            Column(children: [
              avatar,
              const SizedBox(height: 14),
              info,
            ])
          else
            Row(
              children: [
                avatar,
                const SizedBox(width: 20),
                Expanded(child: info),
              ],
            ),
          if ((d.bio ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(d.bio!.trim(),
                style:
                    const TextStyle(fontSize: 14, height: 1.5, color: _kInk)),
          ],
          if (_hasContact(d)) ...[
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                if ((d.address ?? '').trim().isNotEmpty)
                  _contactLine(Icons.place_outlined, d.address!.trim(), tc),
                if ((d.phone ?? '').trim().isNotEmpty)
                  _contactLine(Icons.phone_outlined, d.phone!.trim(), tc),
                if ((d.email ?? '').trim().isNotEmpty)
                  _contactLine(Icons.mail_outline, d.email!.trim(), tc),
              ],
            ),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment:
                narrow ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: () => CompartilharAgendaDialog.show(
                  context,
                  doctor: d,
                  config: tc,
                ),
                icon: Icon(Icons.qr_code_2_rounded,
                    size: 18, color: tc.accentColor),
                label: const Text(
                  'QR Code & Compartilhar Página',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tc.accentColor,
                  side: BorderSide(
                      color: tc.accentColor.withValues(alpha: 0.35)),
                  backgroundColor: tc.accentColor.withValues(alpha: 0.05),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasContact(Doctor d) =>
      (d.address ?? '').trim().isNotEmpty ||
      (d.phone ?? '').trim().isNotEmpty ||
      (d.email ?? '').trim().isNotEmpty;

  ImageProvider? _photoOf(Doctor d) {
    final bytes = d.photoBytes;
    if (bytes != null && bytes.isNotEmpty) return MemoryImage(bytes);
    final url = (d.photoUrl ?? '').trim();
    return url.isEmpty ? null : NetworkImage(url);
  }

  Widget _contactLine(IconData icon, String value, TotemConfig tc) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tc.accentColor),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: SelectableText(value,
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ),
        ],
      );

  // ------------------------------------------------------------- agenda
  Widget _agendaCard(
    Doctor doctor,
    TotemConfig tc,
    List<_Slot> slots,
    int free, {
    required bool loading,
    required bool narrow,
  }) {
    return _card(
      padding: EdgeInsets.all(narrow ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Horários disponíveis',
                    style: TextStyle(
                        fontSize: narrow ? 19 : 22,
                        fontWeight: FontWeight.w900,
                        color: _kInk)),
              ),
              _liveDot(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              'Agenda em tempo real • ${tc.appointmentDuration} min por consulta',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('DATA'),
              if (tc.showCalendarButton)
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: const Text('ABRIR CALENDÁRIO',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.5)),
                  onPressed: () => _openCalendar(tc),
                  style: TextButton.styleFrom(
                    foregroundColor: tc.accentColor,
                    backgroundColor: tc.accentColor.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _weekStrip(tc),
          const SizedBox(height: 10),
          Text(
            '${Fmt.weekdayFull(_date)}, ${Fmt.fullDate(_date)}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600]),
          ),
          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('HORÁRIO'),
              if (slots.isNotEmpty && tc.showOccupancy) _occLegend(),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (slots.isEmpty)
            _emptyBox(_sameDay(_date, _now)
                ? 'Não há mais horários para hoje. Escolha outra data.'
                : 'Nenhum horário disponível nesta data.')
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final s in slots) _slotChip(s, tc)],
            ),
            const SizedBox(height: 14),
            Text(
              free == 0
                  ? 'Todos os horários deste dia estão lotados.'
                  : '$free horário(s) com vaga disponível.',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      free == 0 ? Colors.grey[600] : const Color(0xFF2E9E5B)),
            ),
          ],

          if (_selTime != null) ...[
            const SizedBox(height: 22),
            _selectionSummary(doctor, tc),
          ],
        ],
      ),
    );
  }

  Widget _liveDot() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Color(0xFF2E9E5B), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('AO VIVO',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.grey[500])),
        ],
      );

  Future<void> _openCalendar(TotemConfig tc) async {
    final start = _startOfDay(DateTime.now());
    final last = start.add(Duration(days: tc.maxDaysAhead));
    // initialDate precisa ficar entre firstDate e lastDate (senão estoura).
    final initial =
        _date.isBefore(start) ? start : (_date.isAfter(last) ? last : _date);
    final accent = tc.accentColor;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start,
      lastDate: last,
      helpText: 'ESCOLHA A DATA',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: accent,
            onPrimary: Colors.white,
            onSurface: _kInk,
            secondary: accent,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: accent),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) _pickDate(picked);
  }

  Widget _weekStrip(TotemConfig tc) {
    final today = _startOfDay(DateTime.now());
    final last = today.add(Duration(days: tc.maxDaysAhead));
    final diff = _date.difference(today).inDays;
    final startDay = (diff >= 0 && diff < 7) ? today : _date;
    final days = [for (var i = 0; i < 7; i++) startDay.add(Duration(days: i))];

    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: Opacity(
              opacity: d.isAfter(last) ? 0.35 : 1,
              child: GestureDetector(
                onTap: d.isAfter(last) ? null : () => _pickDate(d),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        _sameDay(d, _date) ? tc.accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _sameDay(d, _date)
                            ? tc.accentColor
                            : Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(_weekdaysShort[d.weekday - 1],
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: _sameDay(d, _date)
                                  ? Colors.white70
                                  : Colors.grey[500])),
                      const SizedBox(height: 2),
                      Text('${d.day}',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color:
                                  _sameDay(d, _date) ? Colors.white : _kInk)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Intensidade de ocupação — regra/cores unificadas em [OccupancyLevel]
  // (ver OVERBOOKING.md §M2/§B6).
  Color _occColor(_Slot s, TotemConfig tc) {
    if (s.full) return OccupancyLevel.lotado.color;
    if (!tc.showOccupancy) return tc.accentColor;
    return s.level.color;
  }

  String? _occBadge(_Slot s, TotemConfig tc) {
    if (s.full) return OccupancyLevel.lotado.label;
    if (tc.showOccupancy && s.level == OccupancyLevel.ultimas) {
      return OccupancyLevel.ultimas.label;
    }
    return null;
  }

  Widget _occLegend() {
    Widget dot(OccupancyLevel l) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: l.color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(l.label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[500])),
        ]);
    return Wrap(spacing: 10, children: [
      for (final l in OccupancyLevel.values) dot(l),
    ]);
  }

  Widget _slotChip(_Slot slot, TotemConfig tc) {
    final full = slot.full;
    final occ = _occColor(slot, tc);
    final badge = _occBadge(slot, tc);
    final selected = _selTime == slot.time;

    return Opacity(
      opacity: full ? 0.5 : 1,
      child: GestureDetector(
        onTap: full
            ? null
            : () => setState(() => _selTime = selected ? null : slot.time),
        child: Container(
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? tc.accentColor
                : full
                    ? Colors.grey.withValues(alpha: 0.08)
                    : occ.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected
                  ? Colors.transparent
                  : occ.withValues(alpha: full ? 0.5 : 0.9),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(slot.time,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : _kInk)),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : occ.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: selected ? Colors.white : occ)),
                )
              else if (tc.showOccupancy)
                Text('${slot.remaining} vaga(s)',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  /// Resumo do horário escolhido. A página é pública e **não grava** consultas:
  /// o visitante leva os dados para a recepção / totem, onde é identificado.
  Widget _selectionSummary(Doctor doctor, TotemConfig tc) {
    final time = _selTime!;
    final phone = (doctor.phone ?? '').trim();
    final summary = '${doctor.name} — ${Fmt.shortDate(_date)} às $time'
        '${phone.isEmpty ? '' : ' • $phone'}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tc.accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.event_available, color: tc.accentColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Horário escolhido: ${Fmt.shortDate(_date)} às $time',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 15, color: _kInk),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'A clínica confirma a solicitação antes da consulta valer.',
            style:
                TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => _etapa = _Etapa.dados),
              style: FilledButton.styleFrom(
                backgroundColor: tc.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              child: const Text('SOLICITAR ESTE HORÁRIO'),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: summary));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Dados do horário copiados.'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar dados'),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selTime = null),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Limpar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------- dados do paciente
  Widget _dadosCard(Doctor doctor, TotemConfig tc, {required bool narrow}) {
    return _card(
      padding: EdgeInsets.all(narrow ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seus dados',
              style: TextStyle(
                  fontSize: narrow ? 19 : 22,
                  fontWeight: FontWeight.w900,
                  color: tc.accentColor)),
          const SizedBox(height: 4),
          Text(
            '${Fmt.weekdayFull(_date)}, ${Fmt.fullDate(_date)} às $_selTime '
            '• ${doctor.name}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 22),

          _label('NOME COMPLETO'),
          const SizedBox(height: 8),
          TextField(
            controller: _nomeCtrl,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: _input('Como está no seu documento'),
          ),
          const SizedBox(height: 16),

          _label('TELEFONE (COM DDD)'),
          const SizedBox(height: 8),
          TextField(
            controller: _telCtrl,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            inputFormatters: [_PhoneFormatter()],
            decoration: _input('(00) 00000-0000'),
          ),
          const SizedBox(height: 16),

          _label('E-MAIL (OPCIONAL)'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            decoration: _input('para receber a confirmação'),
          ),
          const SizedBox(height: 18),

          _banner(
            icon: Icons.info_outline,
            color: tc.accentColor,
            text: 'A consulta fica como pré-agendada até a clínica confirmar. '
                'Não informe CPF nem dados de saúde por aqui.',
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  _busy ? null : () => _enviarSolicitacao(doctor, tc),
              style: FilledButton.styleFrom(
                backgroundColor: tc.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('ENVIAR SOLICITAÇÃO'),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => setState(() => _etapa = _Etapa.agenda),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Escolher outro horário'),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- comprovante
  Widget _sucessoCard(Doctor doctor, TotemConfig tc, {required bool narrow}) {
    // `_selTime`/`_date` continuam com o horário solicitado — só
    // `_voltarParaAgenda` os limpa, e essa etapa é chamada antes disso.
    final horario = _selTime;
    final protocolo = _protocolo ?? '—';
    final comprovante = horario == null
        ? 'Protocolo $protocolo'
        : 'Protocolo $protocolo\n${doctor.name}\n'
            '${Fmt.shortDate(_date)} às $horario\n'
            'Status: pré-agendado (aguardando confirmação da clínica)';

    return _card(
      padding: EdgeInsets.all(narrow ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.check_circle, color: const Color(0xFF2E9E5B), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Solicitação enviada',
                  style: TextStyle(
                      fontSize: narrow ? 19 : 22,
                      fontWeight: FontWeight.w900,
                      color: _kInk)),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tc.accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: tc.accentColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text('PROTOCOLO',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.grey[600])),
                const SizedBox(height: 4),
                SelectableText(protocolo,
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: tc.accentColor)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _resumoLinha(Icons.person_outline, 'Profissional', doctor.name, tc),
          const SizedBox(height: 8),
          if (horario != null) ...[
            _resumoLinha(
                Icons.event, 'Data', '${Fmt.shortDate(_date)} às $horario', tc),
            const SizedBox(height: 8),
          ],
          _resumoLinha(
              Icons.schedule, 'Status', 'Pré-agendado (a confirmar)', tc),
          const SizedBox(height: 16),
          _banner(
            icon: Icons.info_outline,
            color: const Color(0xFFF5A623),
            text: 'A consulta ainda não está confirmada. A clínica entra em '
                'contato pelo telefone informado. Guarde o protocolo.',
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: comprovante));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Comprovante copiado.'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: tc.accentColor,
                    side: BorderSide(
                        color: tc.accentColor.withValues(alpha: 0.5))),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar comprovante'),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: _voltarParaAgenda,
                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                icon: const Icon(Icons.event_note_outlined, size: 18),
                label: const Text('Ver a agenda'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resumoLinha(
          IconData icon, String label, String value, TotemConfig tc) =>
      Row(
        children: [
          Icon(icon, size: 18, color: tc.accentColor),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      );

  Widget _footer(TotemConfig tc) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [_kAccent, _kBrand],
            ).createShader(rect),
            child: const Icon(Icons.favorite, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Agenda pública de ${tc.clinicName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
        ],
      );

  // ------------------------------------------------------------- shared
  Widget _banner({
    required IconData icon,
    required Color color,
    required String text,
  }) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, color: _kInk)),
          ),
        ]),
      );

  Widget _message({
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _card(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 44, color: Colors.grey[400]),
                  const SizedBox(height: 14),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _kInk)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _label(String t) => Text(t,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: Colors.grey[500]));

  Widget _emptyBox(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600])),
      );

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x12000000),
                blurRadius: 24,
                offset: Offset(0, 12)),
          ],
        ),
        child: child,
      );
}

/// Máscara de telefone: (00) 00000-0000.
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 11) d = d.substring(0, 11);
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 0) b.write('(');
      if (i == 2) b.write(') ');
      if (i == 7) b.write('-');
      b.write(d[i]);
    }
    final t = b.toString();
    return TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
