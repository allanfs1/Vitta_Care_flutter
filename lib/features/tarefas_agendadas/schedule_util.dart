import 'package:cloud_firestore/cloud_firestore.dart';

/// Lógica de agendamento das Tarefas Agendadas (`.specify/TAREFAS_AGENDADAS.md` §4).
/// Fuso fixo **BRT (UTC-3)** — o Brasil não tem horário de verão desde 2019.

const Duration _brt = Duration(hours: -3);

/// Componentes de parede (wall clock) BRT de um instante UTC.
DateTime _toBrt(DateTime utc) => utc.toUtc().add(_brt);

/// Converte componentes BRT de volta para o instante UTC.
DateTime _fromBrt(int y, int mo, int d, int h, int mi) =>
    DateTime.utc(y, mo, d, h, mi).subtract(_brt);

/// Configuração de recorrência de uma tarefa.
class TaskSchedule {
  const TaskSchedule({
    required this.type,
    this.time,
    this.weekdays = const [],
    this.dayOfMonth,
    this.intervalMinutes,
    this.runAt,
  });

  /// once | interval | daily | weekly | monthly
  final String type;
  final String? time; // 'HH:MM' (BRT)
  final List<int> weekdays; // 0=Dom..6=Sáb
  final int? dayOfMonth; // 1-31
  final int? intervalMinutes;
  final DateTime? runAt; // once (UTC)

  Map<String, dynamic> toMap() => {
        'type': type,
        if (time != null) 'time': time,
        if (weekdays.isNotEmpty) 'weekdays': weekdays,
        if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
        if (intervalMinutes != null) 'intervalMinutes': intervalMinutes,
        if (runAt != null) 'runAt': Timestamp.fromDate(runAt!),
      };

  /// Lê o schedule tolerando o formato da spec E o gravado pelas tools MCP
  /// (`recorrencia`/`horario`/`diasSemana`/`diaDoMes`/`intervaloMinutos`/`dataOnce`).
  factory TaskSchedule.fromMap(Map<String, dynamic> m) {
    String typeOf(Object? v) {
      final s = (v ?? 'once').toString();
      const map = {
        'acao': 'once',
        'once': 'once',
        'interval': 'interval',
        'intervalo': 'interval',
        'daily': 'daily',
        'diario': 'daily',
        'diária': 'daily',
        'weekly': 'weekly',
        'semanal': 'weekly',
        'monthly': 'monthly',
        'mensal': 'monthly',
      };
      return map[s.toLowerCase()] ?? s.toLowerCase();
    }

    final weekdays = <int>[];
    final raw = m['weekdays'] ?? m['diasSemana'];
    if (raw is List) {
      const names = {
        'domingo': 0,
        'segunda': 1,
        'terca': 2,
        'terça': 2,
        'quarta': 3,
        'quinta': 4,
        'sexta': 5,
        'sabado': 6,
        'sábado': 6,
      };
      for (final e in raw) {
        if (e is int) {
          weekdays.add(e);
        } else if (e is num) {
          weekdays.add(e.toInt());
        } else {
          final n = names[e.toString().toLowerCase()];
          if (n != null) weekdays.add(n);
        }
      }
    }

    DateTime? runAt;
    final r = m['runAt'] ?? m['dataOnce'];
    if (r is Timestamp) {
      runAt = r.toDate();
    } else if (r is String && r.isNotEmpty) {
      runAt = parseFlexibleDate(r);
    }

    int? intArg(Object? v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));

    return TaskSchedule(
      type: typeOf(m['type'] ?? m['recorrencia']),
      time: (m['time'] ?? m['horario'])?.toString(),
      weekdays: weekdays,
      dayOfMonth: intArg(m['dayOfMonth'] ?? m['diaDoMes']),
      intervalMinutes: intArg(m['intervalMinutes'] ?? m['intervaloMinutos']),
      runAt: runAt,
    );
  }

  (int, int) get _hm {
    final parts = (time ?? '08:00').split(':');
    final h = int.tryParse(parts.first) ?? 8;
    final mi = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return (h, mi);
  }
}

/// Próxima execução (UTC) após [from], ou `null` se não houver.
DateTime? computeNextRun(TaskSchedule s, DateTime from) {
  final fromUtc = from.toUtc();
  switch (s.type) {
    case 'once':
      if (s.runAt == null) return null;
      return s.runAt!.toUtc().isAfter(fromUtc) ? s.runAt!.toUtc() : null;
    case 'interval':
      final mins = (s.intervalMinutes ?? 0) < 1 ? 1 : s.intervalMinutes!;
      return fromUtc.add(Duration(minutes: mins));
    case 'daily':
    case 'weekly':
    case 'monthly':
      final (h, mi) = s._hm;
      final brtFrom = _toBrt(fromUtc);
      // Itera dia-a-dia no calendário BRT até achar o 1º candidato válido.
      for (var i = 0; i <= 370; i++) {
        final day = DateTime.utc(brtFrom.year, brtFrom.month, brtFrom.day)
            .add(Duration(days: i));
        if (s.type == 'weekly' && s.weekdays.isNotEmpty) {
          if (!s.weekdays.contains(day.weekday % 7)) continue;
        }
        if (s.type == 'monthly') {
          final dom = s.dayOfMonth ?? 1;
          final last = DateTime.utc(day.year, day.month + 1, 0).day;
          final target = dom > last ? last : dom; // ajusta meses curtos
          if (day.day != target) continue;
        }
        final candidate = _fromBrt(day.year, day.month, day.day, h, mi);
        if (candidate.isAfter(fromUtc)) return candidate;
      }
      return null;
    default:
      return null;
  }
}

/// Descrição legível em pt-BR.
String describeSchedule(TaskSchedule s) {
  final (h, mi) = s._hm;
  final hhmm = '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
  switch (s.type) {
    case 'once':
      if (s.runAt == null) return 'Uma vez';
      final b = _toBrt(s.runAt!.toUtc());
      return 'Uma vez em ${b.day.toString().padLeft(2, '0')}/${b.month.toString().padLeft(2, '0')}/${b.year} às ${b.hour.toString().padLeft(2, '0')}:${b.minute.toString().padLeft(2, '0')}';
    case 'interval':
      final m = s.intervalMinutes ?? 0;
      if (m % 60 == 0 && m >= 60) return 'A cada ${m ~/ 60}h';
      return 'A cada $m min';
    case 'daily':
      return 'Todos os dias às $hhmm';
    case 'weekly':
      const dn = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
      final dias = (s.weekdays.toList()..sort()).map((d) => dn[d % 7]).join(', ');
      return 'Semanal ($dias) às $hhmm';
    case 'monthly':
      return 'Todo dia ${s.dayOfMonth ?? 1} às $hhmm';
    default:
      return s.type;
  }
}

/// Valida o schedule; retorna mensagem de erro amigável ou `null` se válido.
String? validateSchedule(TaskSchedule s) {
  switch (s.type) {
    case 'once':
      if (s.runAt == null) return 'Defina a data/hora da execução.';
      if (!s.runAt!.toUtc().isAfter(DateTime.now().toUtc())) {
        return 'A data de execução deve ser no futuro.';
      }
      return null;
    case 'interval':
      if ((s.intervalMinutes ?? 0) < 1) {
        return 'O intervalo deve ser de pelo menos 1 minuto.';
      }
      return null;
    case 'daily':
      return _validTime(s.time);
    case 'weekly':
      if (s.weekdays.isEmpty) return 'Selecione ao menos um dia da semana.';
      return _validTime(s.time);
    case 'monthly':
      final d = s.dayOfMonth ?? 0;
      if (d < 1 || d > 31) return 'O dia do mês deve estar entre 1 e 31.';
      return _validTime(s.time);
    default:
      return 'Tipo de recorrência inválido.';
  }
}

String? _validTime(String? t) {
  if (t == null || !RegExp(r'^\d{1,2}:\d{2}$').hasMatch(t)) {
    return 'Informe um horário válido (HH:MM).';
  }
  return null;
}

/// Converte data flexível → UTC. Aceita ISO (com/sem TZ) e `DD/MM/AAAA HH:MM`
/// (sem TZ ⇒ interpretado como BRT).
DateTime? parseFlexibleDate(String input) {
  final s = input.trim();
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})(?:[ T](\d{1,2}):(\d{2}))?$')
      .firstMatch(s);
  if (br != null) {
    final d = int.parse(br.group(1)!);
    final mo = int.parse(br.group(2)!);
    final y = int.parse(br.group(3)!);
    final h = br.group(4) != null ? int.parse(br.group(4)!) : 0;
    final mi = br.group(5) != null ? int.parse(br.group(5)!) : 0;
    return _fromBrt(y, mo, d, h, mi); // BRT → UTC
  }
  final iso = DateTime.tryParse(s);
  if (iso == null) return null;
  // ISO sem TZ é parseado como local; tratamos como BRT.
  if (!s.endsWith('Z') && !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s)) {
    return _fromBrt(iso.year, iso.month, iso.day, iso.hour, iso.minute);
  }
  return iso.toUtc();
}
