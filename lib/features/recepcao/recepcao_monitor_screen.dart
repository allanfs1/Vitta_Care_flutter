import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/call_record.dart';
import 'models/manchester_priority.dart';
import 'models/monitor_config.dart';
import 'models/queue_entry.dart';
import 'providers/monitor_config_provider.dart';
import 'recepcao_provider.dart';
import 'services/recepcao_tts.dart';

/// Monitor da Recepção (§4.1): painel público de chamada de senhas, com
/// personalização completa (foto do paciente, privacidade, tema, voz, layout).
class RecepcaoMonitorScreen extends ConsumerStatefulWidget {
  const RecepcaoMonitorScreen({super.key});

  @override
  ConsumerState<RecepcaoMonitorScreen> createState() =>
      _RecepcaoMonitorScreenState();
}

class _RecepcaoMonitorScreenState extends ConsumerState<RecepcaoMonitorScreen>
    with SingleTickerProviderStateMixin {
  static const double _rowHeight = 76;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _listController = ScrollController();
  late final AnimationController _pulse;
  Timer? _clock;
  DateTime _now = DateTime.now();

  late MonitorConfig _cfg;
  int _advanceCounter = 0;
  MonitorPalette get _p => _cfg.palette;

  /// Atualiza a config localmente (rebuild) e persiste em disco.
  void _apply(MonitorConfig c) {
    setState(() => _cfg = c);
    ref.read(monitorConfigProvider.notifier).update(c);
  }

  Color _accentFor(ManchesterPriority? risk) =>
      (_cfg.useRiskAsAccent && risk != null) ? risk.color : _cfg.accent;

  @override
  void initState() {
    super.initState();
    _cfg = ref.read(monitorConfigProvider);
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      final notifier = ref.read(recepcaoProvider.notifier);
      // Chamada automática de agendados no horário.
      if (_cfg.autoCall) notifier.autoCallDue(_now);
      // Auto-avanço por intervalo fixo ("chamar próximo" no timer).
      if (_cfg.autoAdvance) {
        final queueEmpty = ref.read(recepcaoProvider).triagedQueue.isEmpty;
        if (_cfg.pauseWhenEmpty && queueEmpty) {
          _advanceCounter = 0; // pausado enquanto a fila estiver vazia
        } else {
          _advanceCounter++;
          final remaining = _cfg.autoAdvanceSeconds - _advanceCounter;
          // Aviso sonoro nos segundos finais antes da troca.
          if (_cfg.warnBeforeAdvance && _cfg.sound && remaining == 3) beep();
          if (_advanceCounter >= _cfg.autoAdvanceSeconds) {
            _advanceCounter = 0;
            notifier.callNext();
          }
        }
      } else {
        _advanceCounter = 0;
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _pulse.dispose();
    _listController.dispose();
    cancelSpeech();
    super.dispose();
  }

  void _onCall() {
    final call = ref.read(recepcaoProvider).currentCall;
    if (call == null) return;
    if (_cfg.sound) {
      speakPtBr(call.announcement,
          rate: _cfg.voiceRate,
          pitch: _cfg.voicePitch,
          times: _cfg.announceRepeat);
    }
    if (_cfg.pulse) _pulse.forward(from: 0);
    _advanceCounter = 0; // reinicia o timer de auto-avanço a cada chamada
    if (_cfg.autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  void _scrollToCurrent() {
    if (!_listController.hasClients) return;
    final calledCount = ref.read(recepcaoProvider).calledHistory.length;
    if (calledCount == 0) return;
    final index = calledCount - 1;
    final pos = _listController.position;
    final target = ((index + 0.5) * _rowHeight - pos.viewportDimension / 2)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    _listController.animateTo(target,
        duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
  }

  String _hhmmss(DateTime d) =>
      '${_pad(d.hour)}:${_pad(d.minute)}:${_pad(d.second)}';
  String _hhmm(DateTime d) => '${_pad(d.hour)}:${_pad(d.minute)}';
  static String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
        recepcaoProvider.select((s) => s.callTick), (prev, next) => _onCall());

    final state = ref.watch(recepcaoProvider);
    final current = state.currentCall;
    final history = state.calledHistory.skip(1).take(6).toList();
    final p = _p;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: p.bg,
      endDrawer: _settingsDrawer(),
      body: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(_cfg.scale)),
        child: Container(
          decoration: _cfg.gradient
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [p.bg, Color.alphaBlend(_cfg.accent.withValues(alpha: 0.18), p.bg)],
                  ),
                )
              : null,
          child: SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildBody(state, current, history),
                  ),
                ),
                _controlBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- BODY
  Widget _buildBody(
      RecepcaoState state, CallRecord? current, List<CallRecord> history) {
    if (_cfg.density == MonitorDensity.lista) return _listBody(state);
    final call = _currentCallPanel(current);

    if (_cfg.density == MonitorDensity.simples) {
      if (_cfg.orientation == MonitorOrientation.horizontal) return call;
      return Column(children: [
        Expanded(flex: 4, child: call),
        const SizedBox(height: 20),
        Expanded(flex: 1, child: _historyPanel(history)),
      ]);
    }

    if (_cfg.orientation == MonitorOrientation.horizontal) {
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 3, child: call),
        const SizedBox(width: 20),
        Expanded(
          flex: 2,
          child: Column(children: [
            Expanded(flex: 3, child: _historyPanel(history)),
            const SizedBox(height: 20),
            Expanded(flex: 2, child: _queuePanel(state)),
          ]),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(flex: 3, child: call),
      const SizedBox(height: 20),
      Expanded(
        flex: 2,
        child: Row(children: [
          Expanded(child: _historyPanel(history)),
          const SizedBox(width: 20),
          Expanded(child: _queuePanel(state)),
        ]),
      ),
    ]);
  }

  Widget _currentCallPanel(CallRecord? call) {
    final p = _p;
    final accent = _accentFor(call?.manchester);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow =
            0.25 + 0.55 * (1 - (_pulse.value - 0.5).abs() * 2).clamp(0, 1);
        return Container(
          decoration: BoxDecoration(
            color: p.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent, width: 3),
            boxShadow: [
              BoxShadow(
                  color: accent.withValues(alpha: glow.toDouble()),
                  blurRadius: 40,
                  spreadRadius: 2),
            ],
          ),
          child: child,
        );
      },
      child: call == null
          ? Center(
              child: Text('AGUARDANDO\nCHAMADA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: p.textSecondary.withValues(alpha: 0.4),
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1.1)),
            )
          : Padding(
              padding: const EdgeInsets.all(36),
              child: Row(
                children: [
                  if (_cfg.showPhoto) ...[
                    _avatar(call.photoUrl, call.patientName, 150, accent),
                    const SizedBox(width: 36),
                  ],
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_cfg.showRiskBadge) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: call.manchester.color,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(call.manchester.label.toUpperCase(),
                                      style: TextStyle(
                                          color: call.manchester.onColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14)),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Text('SENHA',
                                  style: TextStyle(
                                      color: p.textSecondary
                                          .withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      letterSpacing: 2)),
                            ],
                          ),
                          Text(call.senha,
                              style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 132,
                                  fontWeight: FontWeight.w900,
                                  height: 1)),
                          const SizedBox(height: 8),
                          Text(_cfg.formatName(call.patientName),
                              style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 24),
                          Row(children: [
                            if (_cfg.showLocal) ...[
                              _infoChip(Icons.meeting_room_outlined, 'LOCAL',
                                  call.local),
                              const SizedBox(width: 20),
                            ],
                            if (_cfg.showAttendant)
                              _infoChip(Icons.badge_outlined, 'ATENDENTE',
                                  call.attendant),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _avatar(String? url, String name, double size, Color ring) {
    final p = _p;
    final fallback = Center(
      child: Text(_initials(name),
          style: TextStyle(
              color: p.textSecondary,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.34)),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.panelAlt,
        border: Border.all(color: ring, width: 4),
      ),
      child: (url == null || url.isEmpty)
          ? fallback
          : Image.network(url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (context, child, prog) =>
                  prog == null ? child : fallback),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _infoChip(IconData icon, String label, String value) {
    final p = _p;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
          color: p.panelAlt, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: p.textSecondary, size: 22),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: p.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          Text(value,
              style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _historyPanel(List<CallRecord> history) {
    final p = _p;
    return _panelBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _panelTitle('ÚLTIMAS CHAMADAS'),
        const SizedBox(height: 12),
        Expanded(
          child: history.isEmpty
              ? Center(
                  child: Text('—',
                      style: TextStyle(
                          color: p.textSecondary.withValues(alpha: 0.3),
                          fontSize: 32)))
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: p.panelAlt, height: 16),
                  itemBuilder: (context, i) {
                    final c = history[i];
                    return Row(children: [
                      Container(
                          width: 10,
                          height: 36,
                          decoration: BoxDecoration(
                              color: c.manchester.color,
                              borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 12),
                      Text(c.senha,
                          style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_cfg.formatName(c.patientName),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: p.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600)),
                              Text(c.local,
                                  style: TextStyle(
                                      color: p.textSecondary
                                          .withValues(alpha: 0.6),
                                      fontSize: 13)),
                            ]),
                      ),
                      Text(_hhmm(c.at),
                          style: TextStyle(
                              color: p.textSecondary.withValues(alpha: 0.6),
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ]);
                  },
                ),
        ),
      ]),
    );
  }

  Widget _queuePanel(RecepcaoState state) {
    final p = _p;
    final counts = state.riskCounts;
    return _panelBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _panelTitle('AGUARDANDO (${state.waiting.length})'),
        const SizedBox(height: 14),
        Expanded(
          child: Row(children: [
            for (final pr in ManchesterPriority.values)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: pr.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: pr.color, width: 2),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${counts[pr] ?? 0}',
                            style: TextStyle(
                                color: pr.color,
                                fontSize: 40,
                                fontWeight: FontWeight.w900)),
                        Text(pr.label.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------- LISTA
  Widget _listBody(RecepcaoState state) {
    final p = _p;
    final called = state.calledHistory.reversed.toList();
    final currentIndex = called.length - 1;
    final upcoming = state.triagedQueue;

    final rows = <Widget>[
      for (var i = 0; i < called.length; i++)
        _listCalledRow(called[i], isCurrent: i == currentIndex),
      _nowDivider(),
      for (final e in upcoming) _listWaitingRow(e),
    ];

    return _panelBox(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
          child: Row(children: [
            Icon(Icons.format_list_bulleted, color: p.textSecondary),
            const SizedBox(width: 10),
            Text('PAINEL DE CHAMADAS',
                style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
            const Spacer(),
            Text('${upcoming.length} aguardando',
                style: TextStyle(
                    color: p.textSecondary.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
        Divider(height: 1, color: p.panelAlt),
        Expanded(
          child: (called.isEmpty && upcoming.isEmpty)
              ? Center(
                  child: Text('SEM CHAMADAS',
                      style: TextStyle(
                          color: p.textSecondary.withValues(alpha: 0.3),
                          fontSize: 28,
                          fontWeight: FontWeight.w900)))
              : ListView(
                  controller: _listController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: rows,
                ),
        ),
      ]),
    );
  }

  Widget _listCalledRow(CallRecord c, {required bool isCurrent}) {
    final p = _p;
    return SizedBox(
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isCurrent ? p.panelAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isCurrent ? _cfg.accent : p.panelAlt,
                width: isCurrent ? 2 : 1),
          ),
          child: Row(children: [
            Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                    color: c.manchester.color,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 14),
            if (_cfg.showPhoto) ...[
              _avatar(c.photoUrl, c.patientName, 44, c.manchester.color),
              const SizedBox(width: 12),
            ],
            Text(c.senha,
                style: TextStyle(
                    color: p.textPrimary,
                    fontSize: isCurrent ? 32 : 24,
                    fontWeight: FontWeight.w900)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_cfg.formatName(c.patientName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.textPrimary,
                            fontSize: isCurrent ? 22 : 18,
                            fontWeight: FontWeight.w700)),
                    Text(c.local,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.textSecondary.withValues(alpha: 0.6),
                            fontSize: 13)),
                  ]),
            ),
            const SizedBox(width: 12),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: _cfg.accent,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('EM CHAMADA',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
              )
            else
              Text(_hhmm(c.at),
                  style: TextStyle(
                      color: p.textSecondary.withValues(alpha: 0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _listWaitingRow(QueueEntry e) {
    final p = _p;
    return SizedBox(
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.panelAlt)),
          child: Row(children: [
            Container(
                width: 8,
                height: 36,
                decoration: BoxDecoration(
                    color: e.manchester.color.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 14),
            Text(e.senha,
                style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(_cfg.formatName(e.patientName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
            ),
            Text(e.scheduledAt != null ? _hhmm(e.scheduledAt!) : 'AGUARDANDO',
                style: TextStyle(
                    color: p.textSecondary.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }

  Widget _nowDivider() {
    return SizedBox(
      height: 44,
      child: Row(children: [
        Expanded(child: Divider(color: _cfg.accent, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('AGORA • ${_hhmm(_now)}',
              style: TextStyle(
                  color: _cfg.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
        ),
        Expanded(child: Divider(color: _cfg.accent, thickness: 1)),
      ]),
    );
  }

  // ---------------------------------------------------------------- CHROME
  Widget _panelBox({required Widget child, EdgeInsets? padding}) {
    final p = _p;
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }

  Widget _panelTitle(String text) => Text(text,
      style: TextStyle(
          color: _p.textSecondary.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 1));

  Widget _header() {
    final p = _p;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: p.panel,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _cfg.accent, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.connected_tv, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(_cfg.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
        ),
        const Spacer(),
        if (_cfg.showClock)
          Text(_hhmmss(_now),
              style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(width: 12),
        _iconToggle(
          tooltip: 'Layout: ${_densityLabel(_cfg.density)}',
          icon: _densityIcon(_cfg.density),
          onTap: () {
            const order = MonitorDensity.values;
            final next = order[(_cfg.density.index + 1) % order.length];
            _apply(_cfg.copyWith(density: next));
            if (next == MonitorDensity.lista) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToCurrent());
            }
          },
        ),
        if (_cfg.density != MonitorDensity.lista)
          _iconToggle(
            tooltip: 'Orientação',
            icon: _cfg.orientation == MonitorOrientation.horizontal
                ? Icons.stay_current_landscape
                : Icons.stay_current_portrait,
            onTap: () => _apply(_cfg.copyWith(
                orientation: _cfg.orientation == MonitorOrientation.horizontal
                    ? MonitorOrientation.vertical
                    : MonitorOrientation.horizontal)),
          ),
        _iconToggle(
          tooltip: _cfg.autoCall ? 'Auto-chamada: ON' : 'Auto-chamada: OFF',
          icon: _cfg.autoCall ? Icons.alarm_on : Icons.alarm_off,
          active: _cfg.autoCall,
          onTap: () => _apply(_cfg.copyWith(autoCall: !_cfg.autoCall)),
        ),
        _iconToggle(
          tooltip: _cfg.sound ? 'Som ligado' : 'Som desligado',
          icon: _cfg.sound ? Icons.volume_up : Icons.volume_off,
          active: _cfg.sound,
          onTap: () {
            final v = !_cfg.sound;
            _apply(_cfg.copyWith(sound: v));
            if (!v) cancelSpeech();
          },
        ),
        _iconToggle(
          tooltip: 'Personalizar',
          icon: Icons.tune,
          onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        IconButton(
          tooltip: 'Sair do monitor',
          onPressed: () => context.pop(),
          icon: Icon(Icons.close_fullscreen, color: p.textSecondary),
        ),
      ]),
    );
  }

  Widget _iconToggle({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
            backgroundColor: active ? _cfg.accent : _p.panelAlt),
        icon: Icon(icon,
            color: active ? Colors.white : _p.textSecondary, size: 20),
      ),
    );
  }

  Widget _controlBar() {
    final p = _p;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: p.panel,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FilledButton.icon(
          onPressed: () => ref.read(recepcaoProvider.notifier).callNext(),
          icon: const Icon(Icons.campaign),
          label: const Text('CHAMAR PRÓXIMO'),
          style: FilledButton.styleFrom(
              backgroundColor: _cfg.accent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 16)),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: () => ref.read(recepcaoProvider.notifier).recall(),
          icon: Icon(Icons.replay, color: p.textPrimary),
          label: Text('RECHAMAR', style: TextStyle(color: p.textPrimary)),
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: p.border),
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 16)),
        ),
        if (_cfg.autoAdvance) ...[
          const SizedBox(width: 16),
          _countdownChip(),
        ],
      ]),
    );
  }

  Widget _countdownChip() {
    final queueEmpty = ref.read(recepcaoProvider).triagedQueue.isEmpty;
    final paused = _cfg.pauseWhenEmpty && queueEmpty;
    final remaining = (_cfg.autoAdvanceSeconds - _advanceCounter)
        .clamp(0, _cfg.autoAdvanceSeconds);
    final warning = !paused && _cfg.warnBeforeAdvance && remaining <= 3;
    final color = paused
        ? _p.textSecondary
        : (warning ? const Color(0xFFFF3B30) : _cfg.accent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: warning ? color.withValues(alpha: 0.15) : _p.panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: warning ? 2 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            paused
                ? Icons.pause_circle_outline
                : (warning
                    ? Icons.notifications_active
                    : Icons.hourglass_bottom),
            color: color,
            size: 18),
        const SizedBox(width: 8),
        Text(paused ? 'Aguardando fila' : 'Próxima em ${remaining}s',
            style: TextStyle(
                color: paused ? _p.textSecondary : _p.textPrimary,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }

  IconData _densityIcon(MonitorDensity d) => switch (d) {
        MonitorDensity.simples => Icons.crop_din,
        MonitorDensity.avancado => Icons.dashboard_outlined,
        MonitorDensity.lista => Icons.format_list_bulleted,
      };
  String _densityLabel(MonitorDensity d) => switch (d) {
        MonitorDensity.simples => 'Simples',
        MonitorDensity.avancado => 'Avançado',
        MonitorDensity.lista => 'Lista',
      };

  // ---------------------------------------------------------------- SETTINGS
  Widget _settingsDrawer() {
    return Drawer(
      width: 380,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              const Icon(Icons.tune, color: Color(0xFFFF3B30)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Personalização do Monitor',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                tooltip: 'Restaurar padrões',
                icon: const Icon(Icons.restart_alt),
                onPressed: () => _apply(const MonitorConfig()),
              ),
            ]),
            const SizedBox(height: 8),

            _sectionLabel('LAYOUT'),
            _chips<MonitorDensity>(
              MonitorDensity.values,
              _cfg.density,
              (d) => _densityLabel(d),
              (d) => _apply(_cfg.copyWith(density: d)),
            ),
            _chips<MonitorOrientation>(
              MonitorOrientation.values,
              _cfg.orientation,
              (o) => o == MonitorOrientation.horizontal
                  ? 'Horizontal'
                  : 'Vertical',
              (o) => _apply(_cfg.copyWith(orientation: o)),
            ),

            _sectionLabel('CONTEÚDO'),
            _switch('Foto do paciente', _cfg.showPhoto,
                (v) => _cfg.copyWith(showPhoto: v)),
            _switch('Classificação de risco', _cfg.showRiskBadge,
                (v) => _cfg.copyWith(showRiskBadge: v)),
            _switch('Local / guichê', _cfg.showLocal,
                (v) => _cfg.copyWith(showLocal: v)),
            _switch('Atendente', _cfg.showAttendant,
                (v) => _cfg.copyWith(showAttendant: v)),
            _switch('Relógio', _cfg.showClock,
                (v) => _cfg.copyWith(showClock: v)),

            _sectionLabel('PRIVACIDADE — NOME'),
            _chips<NameDisplay>(
              NameDisplay.values,
              _cfg.nameDisplay,
              (n) => n.label,
              (n) => _apply(_cfg.copyWith(nameDisplay: n)),
            ),

            _sectionLabel('APARÊNCIA'),
            _chips<MonitorThemeMode>(
              MonitorThemeMode.values,
              _cfg.themeMode,
              (t) => switch (t) {
                MonitorThemeMode.escuro => 'Escuro',
                MonitorThemeMode.claro => 'Claro',
                MonitorThemeMode.contraste => 'Alto contraste',
              },
              (t) => _apply(_cfg.copyWith(themeMode: t)),
            ),
            const SizedBox(height: 8),
            const Text('Cor de destaque',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            _colorRow(),
            _switch('Usar cor de risco como destaque', _cfg.useRiskAsAccent,
                (v) => _cfg.copyWith(useRiskAsAccent: v)),
            _switch('Fundo com gradiente', _cfg.gradient,
                (v) => _cfg.copyWith(gradient: v)),
            _sliderTile('Tamanho da fonte', _cfg.scale, 0.8, 1.8,
                '${(_cfg.scale * 100).round()}%',
                (v) => _cfg.copyWith(scale: v)),

            _sectionLabel('VOZ'),
            _switch('Locução por voz', _cfg.sound,
                (v) => _cfg.copyWith(sound: v)),
            _sliderTile('Velocidade', _cfg.voiceRate, 0.5, 1.3,
                _cfg.voiceRate.toStringAsFixed(2),
                (v) => _cfg.copyWith(voiceRate: v)),
            _sliderTile('Tom (pitch)', _cfg.voicePitch, 0.7, 1.4,
                _cfg.voicePitch.toStringAsFixed(2),
                (v) => _cfg.copyWith(voicePitch: v)),
            _stepperTile('Repetir locução', _cfg.announceRepeat, 1, 3,
                (v) => _apply(_cfg.copyWith(announceRepeat: v))),

            _sectionLabel('CHAMADA AUTOMÁTICA'),
            _switch('Chamar próximo automaticamente', _cfg.autoAdvance,
                (v) => _cfg.copyWith(autoAdvance: v)),
            if (_cfg.autoAdvance) ...[
              _sliderTile(
                'Intervalo entre chamadas',
                _cfg.autoAdvanceSeconds.toDouble(),
                5,
                120,
                '${_cfg.autoAdvanceSeconds}s',
                (v) => _cfg.copyWith(autoAdvanceSeconds: v.round()),
                divisions: 23,
              ),
              _switch('Pausar quando a fila esvaziar', _cfg.pauseWhenEmpty,
                  (v) => _cfg.copyWith(pauseWhenEmpty: v)),
              _switch('Aviso antes da troca (som + visual)',
                  _cfg.warnBeforeAdvance,
                  (v) => _cfg.copyWith(warnBeforeAdvance: v)),
            ],
            _switch('Chamar agendados no horário', _cfg.autoCall,
                (v) => _cfg.copyWith(autoCall: v)),

            _sectionLabel('COMPORTAMENTO'),
            _switch('Animação de destaque', _cfg.pulse,
                (v) => _cfg.copyWith(pulse: v)),
            _switch('Rolagem automática (modo lista)', _cfg.autoScroll,
                (v) => _cfg.copyWith(autoScroll: v)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFFF3B30),
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1)),
      );

  Widget _switch(String label, bool value, MonitorConfig Function(bool) build) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: value,
      activeThumbColor: const Color(0xFFFF3B30),
      onChanged: (v) => _apply(build(v)),
    );
  }

  Widget _sliderTile(String label, double value, double min, double max,
      String display, MonitorConfig Function(double) build,
      {int? divisions}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(display, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        activeColor: const Color(0xFFFF3B30),
        onChanged: (v) => _apply(build(v)),
      ),
    ]);
  }

  Widget _stepperTile(
      String label, int value, int min, int max, void Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - 1) : null),
        Text('${value}x', style: const TextStyle(fontWeight: FontWeight.w900)),
        IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChanged(value + 1) : null),
      ]),
    );
  }

  Widget _chips<T>(List<T> values, T current, String Function(T) labelOf,
      void Function(T) onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(labelOf(v)),
            selected: current == v,
            selectedColor: const Color(0xFFFFE0DE),
            onSelected: (_) => onSelect(v),
          ),
      ],
    );
  }

  Widget _colorRow() {
    const colors = [
      Color(0xFFFF3B30),
      Color(0xFF2563EB),
      Color(0xFF1FAA59),
      Color(0xFF7C3AED),
      Color(0xFFF59E0B),
      Color(0xFF0EA5E9),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 10,
        children: [
          for (final c in colors)
            GestureDetector(
              onTap: () => _apply(_cfg.copyWith(accent: c)),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _cfg.accent == c ? Colors.black : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: _cfg.accent == c
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
