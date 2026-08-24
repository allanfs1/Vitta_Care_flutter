import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../schedule_util.dart';
import '../scheduled_task.dart';
import '../scheduled_tasks_service.dart';

/// Modal de criar/editar tarefa agendada (`TAREFAS_AGENDADAS.md` §9.3).
class TaskModal extends ConsumerStatefulWidget {
  const TaskModal({super.key, this.task});
  final ScheduledTask? task;

  @override
  ConsumerState<TaskModal> createState() => _TaskModalState();
}

class _TaskModalState extends ConsumerState<TaskModal> {
  late String _kind;
  late String _type;
  late final TextEditingController _titulo;
  late final TextEditingController _prompt;
  late final TextEditingController _email;
  late final TextEditingController _intervalo;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _weekdays = {1};
  int _dayOfMonth = 1;
  DateTime? _runAt;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _kind = t?.kind ?? 'action';
    _type = t?.schedule.type ?? 'once';
    _titulo = TextEditingController(text: t?.titulo ?? '');
    _prompt = TextEditingController(text: t?.prompt ?? '');
    _email = TextEditingController(text: t?.notifyEmail ?? '');
    _intervalo =
        TextEditingController(text: '${t?.schedule.intervalMinutes ?? 60}');
    if (t != null) {
      final s = t.schedule;
      if (s.time != null) {
        final p = s.time!.split(':');
        _time = TimeOfDay(
            hour: int.tryParse(p.first) ?? 8,
            minute: p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0);
      }
      if (s.weekdays.isNotEmpty) {
        _weekdays
          ..clear()
          ..addAll(s.weekdays);
      }
      _dayOfMonth = s.dayOfMonth ?? 1;
      _runAt = s.runAt?.toLocal();
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _prompt.dispose();
    _email.dispose();
    _intervalo.dispose();
    super.dispose();
  }

  String get _hhmm =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  TaskSchedule _buildSchedule() {
    switch (_type) {
      case 'interval':
        return TaskSchedule(
            type: 'interval',
            intervalMinutes: int.tryParse(_intervalo.text.trim()) ?? 0);
      case 'daily':
        return TaskSchedule(type: 'daily', time: _hhmm);
      case 'weekly':
        return TaskSchedule(
            type: 'weekly', time: _hhmm, weekdays: _weekdays.toList()..sort());
      case 'monthly':
        return TaskSchedule(type: 'monthly', time: _hhmm, dayOfMonth: _dayOfMonth);
      case 'once':
      default:
        return TaskSchedule(type: 'once', runAt: _runAt?.toUtc());
    }
  }

  Future<void> _save() async {
    final titulo = _titulo.text.trim();
    final prompt = _prompt.text.trim();
    if (titulo.isEmpty || prompt.isEmpty) {
      setState(() => _error = 'Preencha o título e a instrução.');
      return;
    }
    final schedule = _buildSchedule();
    final err = validateSchedule(schedule);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final svc = ref.read(scheduledTasksServiceProvider);
    final email = _email.text.trim().isEmpty ? null : _email.text.trim();
    try {
      if (_editing) {
        await svc.update(widget.task!.id,
            titulo: titulo,
            prompt: prompt,
            kind: _kind,
            schedule: schedule,
            notifyEmail: email);
      } else {
        await svc.create(
          titulo: titulo,
          prompt: prompt,
          kind: _kind,
          schedule: schedule,
          notifyEmail: email,
          clinicaId: ref.read(tarefasClinicaIdProvider),
          createdBy: ref.read(authProvider).uid,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(_editing ? 'Editar tarefa' : 'Nova tarefa agendada'),
      content: SizedBox(
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Tipo de tarefa'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'action', label: Text('Ação'), icon: Icon(Icons.bolt)),
                ButtonSegment(value: 'report', label: Text('Relatório'), icon: Icon(Icons.analytics_outlined)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titulo,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _prompt,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Instrução (linguagem natural)',
                hintText: _kind == 'report'
                    ? 'Ex.: Relatório de absenteísmo do mês com gráficos'
                    : 'Ex.: Enviar lembretes por WhatsApp dos agendamentos de amanhã',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _label('Quando executar'),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: const [
                DropdownMenuItem(value: 'once', child: Text('Uma vez')),
                DropdownMenuItem(value: 'interval', child: Text('Intervalo')),
                DropdownMenuItem(value: 'daily', child: Text('Diariamente')),
                DropdownMenuItem(value: 'weekly', child: Text('Semanalmente')),
                DropdownMenuItem(value: 'monthly', child: Text('Mensalmente')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'once'),
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._scheduleFields(),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail de notificação (opcional)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_editing ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }

  List<Widget> _scheduleFields() {
    switch (_type) {
      case 'once':
        return [
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(_runAt == null
                ? 'Escolher data e hora'
                : '${_runAt!.day.toString().padLeft(2, '0')}/${_runAt!.month.toString().padLeft(2, '0')}/${_runAt!.year} ${_runAt!.hour.toString().padLeft(2, '0')}:${_runAt!.minute.toString().padLeft(2, '0')}'),
            onPressed: _pickDateTime,
          ),
        ];
      case 'interval':
        return [
          TextField(
            controller: _intervalo,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Intervalo (minutos)', helperText: 'Mínimo 1',
            ),
          ),
        ];
      case 'weekly':
        return [
          _timePicker(),
          const SizedBox(height: AppSpacing.sm),
          _label('Dias da semana'),
          Wrap(
            spacing: 6,
            children: [
              for (var d = 0; d < 7; d++)
                FilterChip(
                  label: Text(const ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'][d]),
                  selected: _weekdays.contains(d),
                  onSelected: (sel) => setState(() =>
                      sel ? _weekdays.add(d) : _weekdays.remove(d)),
                ),
            ],
          ),
        ];
      case 'monthly':
        return [
          _timePicker(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Text('Dia do mês: '),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _dayOfMonth,
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (v) => setState(() => _dayOfMonth = v ?? 1),
              ),
            ],
          ),
        ];
      case 'daily':
      default:
        return [_timePicker()];
    }
  }

  Widget _timePicker() => OutlinedButton.icon(
        icon: const Icon(Icons.schedule),
        label: Text('Horário: $_hhmm'),
        onPressed: () async {
          final t = await showTimePicker(context: context, initialTime: _time);
          if (t != null) setState(() => _time = t);
        },
      );

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _runAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_runAt ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() => _runAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}
