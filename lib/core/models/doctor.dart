import 'dart:typed_data';

/// Profissional de saúde. Mapeia `tb_medicos`.
class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.crm,
    required this.specialties,
    this.clinicId = '',
    this.photoUrl,
    this.photoBytes,
    this.email,
    this.phone,
    this.address,
    this.bio,
    this.experience,
    this.active = true,
    this.ticket = 0,
    this.scaleHours = 8,
    this.monthlyConsultations = 0,
    this.occupancyRate = 0,
    this.absenceRate = 0,
    this.slotLimit = 1,
    this.maxOverbook = 0,
    this.maxPerSlot,
    this.dayOverbook = const {},
    this.periodOverbook = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String crm;
  final List<String> specialties;

  /// Clínica à qual o médico pertence (`idclinica`). A Equipe Médica lista
  /// apenas os médicos da clínica selecionada.
  final String clinicId;

  final String? photoUrl;

  /// Foto selecionada localmente (galeria/câmera), quando ainda não há URL
  /// remota. Renderizada via `MemoryImage` no [AppAvatar].
  final Uint8List? photoBytes;

  final String? email;
  final String? phone;

  /// Endereço de atendimento (`endereco`).
  final String? address;

  /// Biografia / apresentação do profissional (`biografia`).
  final String? bio;

  /// Experiência profissional resumida (`experiencia`).
  final String? experience;

  /// Status ativo/inativo (`status`). Médico inativo não aparece em seleções
  /// de agendamento, mas permanece nos registros (soft delete).
  final bool active;

  /// Valor do ticket / consulta particular (`tiket`).
  final double ticket;

  /// Escala de atendimento do médico (`scalaMedico`): carga horária da escala,
  /// em horas por dia de plantão (ex.: 4, 6, 8, 12, 24).
  final int scaleHours;

  /// Total de consultas no mês corrente (`estatisticas.totalConsultasMes`).
  final int monthlyConsultations;

  /// Estatísticas (`estatisticas.taxaOcupacaoMedia`, `estatisticas.mediaFaltas`).
  final double occupancyRate;
  final double absenceRate;

  /// Datas de cadastro/atualização (`dataCriacao` / `dataAtualizacao`).
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // --- Overbooking inteligente (§1 NEW_FEATURE) ----------------------------
  /// Limite base de pacientes por horário (`limiteSlot`).
  final int slotLimit;

  /// Overbook global permitido (`limitesSeguranca.maxOverbook`).
  final int maxOverbook;

  /// Teto rígido por horário (`limitesSeguranca.maxPacientesPorHorario`).
  final int? maxPerSlot;

  /// Overbook por dia da semana (1=segunda … 7=domingo) → `overbookingConfig`.
  final Map<int, int> dayOverbook;

  /// Overbook por período: `manha` / `tarde` / `noite` → `overbookingPeriodo`.
  final Map<String, int> periodOverbook;

  /// Capacidade total de um slot (`HH:mm`) num dado dia da semana: limite base
  /// + overbook, aplicando o override **mais específico** (período > dia da
  /// semana > global), limitado pelo teto rígido `maxPerSlot` quando definido.
  ///
  /// Regras (ver OVERBOOKING.md §M1):
  /// - o overbook por período tem precedência sobre o do dia, que tem
  ///   precedência sobre o global (`maxOverbook`) — assim um override de período
  ///   não é anulado por um valor de dia/global menor;
  /// - overbook negativo é tratado como 0;
  /// - o teto `maxPerSlot` só se aplica quando for > 0 (0/negativo = sem teto);
  /// - a capacidade nunca é menor que 1 (um slot sempre comporta 1 paciente).
  int capacityAt(int weekday, String hhmm) {
    final period = hhmm.compareTo('12:00') < 0
        ? 'manha'
        : (hhmm.compareTo('18:00') < 0 ? 'tarde' : 'noite');
    final overbook =
        periodOverbook[period] ?? dayOverbook[weekday] ?? maxOverbook;
    final base = slotLimit < 1 ? 1 : slotLimit;
    var total = base + (overbook < 0 ? 0 : overbook);
    final cap = maxPerSlot;
    if (cap != null && cap > 0 && total > cap) total = cap;
    return total < 1 ? 1 : total;
  }

  Doctor copyWith({
    String? name,
    String? crm,
    List<String>? specialties,
    String? clinicId,
    String? photoUrl,
    Uint8List? photoBytes,
    String? email,
    String? phone,
    String? address,
    String? bio,
    String? experience,
    bool? active,
    double? ticket,
    int? scaleHours,
    int? monthlyConsultations,
    double? occupancyRate,
    double? absenceRate,
    int? slotLimit,
    int? maxOverbook,
    int? maxPerSlot,
    Map<int, int>? dayOverbook,
    Map<String, int>? periodOverbook,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Doctor(
      id: id,
      name: name ?? this.name,
      crm: crm ?? this.crm,
      specialties: specialties ?? this.specialties,
      clinicId: clinicId ?? this.clinicId,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBytes: photoBytes ?? this.photoBytes,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      bio: bio ?? this.bio,
      experience: experience ?? this.experience,
      active: active ?? this.active,
      ticket: ticket ?? this.ticket,
      scaleHours: scaleHours ?? this.scaleHours,
      monthlyConsultations: monthlyConsultations ?? this.monthlyConsultations,
      occupancyRate: occupancyRate ?? this.occupancyRate,
      absenceRate: absenceRate ?? this.absenceRate,
      slotLimit: slotLimit ?? this.slotLimit,
      maxOverbook: maxOverbook ?? this.maxOverbook,
      maxPerSlot: maxPerSlot ?? this.maxPerSlot,
      dayOverbook: dayOverbook ?? this.dayOverbook,
      periodOverbook: periodOverbook ?? this.periodOverbook,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get primarySpecialty =>
      specialties.isNotEmpty ? specialties.first : 'Clínico Geral';

  String get initials {
    final clean = name.replaceAll('Dr. ', '').replaceAll('Dra. ', '').trim();
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
