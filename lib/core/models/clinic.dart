import 'enums.dart';

/// Unidade de saúde. Mapeia `tb_clinica` (+ campos de perfil estendido).
class Clinic {
  const Clinic({
    required this.id,
    required this.name,
    required this.type,
    this.razaoSocial,
    this.cnpj,
    this.email,
    this.phone,
    this.website,
    this.photoUrl,
    this.address = const ClinicAddress(),
    this.specialties = const [],
    this.businessHours = const [],
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final ClinicType type;
  final String? razaoSocial;
  final String? cnpj;
  final String? email;
  final String? phone;
  final String? website;
  final String? photoUrl;
  final ClinicAddress address;
  final List<String> specialties;
  final List<BusinessHour> businessHours;

  /// Coordenadas geográficas da unidade (quando cadastradas). Usadas para
  /// exibir o mapa de localização no detalhe da consulta.
  final double? latitude;
  final double? longitude;

  /// `true` quando há latitude e longitude válidas para plotar no mapa.
  bool get hasLocation => latitude != null && longitude != null;

  Clinic copyWith({
    String? name,
    ClinicType? type,
    String? razaoSocial,
    String? cnpj,
    String? email,
    String? phone,
    String? website,
    String? photoUrl,
    ClinicAddress? address,
    List<String>? specialties,
    List<BusinessHour>? businessHours,
    double? latitude,
    double? longitude,
  }) {
    return Clinic(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      razaoSocial: razaoSocial ?? this.razaoSocial,
      cnpj: cnpj ?? this.cnpj,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      specialties: specialties ?? this.specialties,
      businessHours: businessHours ?? this.businessHours,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// Cria um [Clinic] a partir de um documento `tb_clinica` do Firestore.
  factory Clinic.fromFirestore(String id, Map<String, dynamic> data) {
    // Parser de enum
    ClinicType parseType(String? typeStr) {
      if (typeStr == null) return ClinicType.privada;
      final t = typeStr.toLowerCase();
      if (t.contains('ubs')) return ClinicType.ubs;
      if (t.contains('upa')) return ClinicType.upa;
      if (t.contains('aps')) return ClinicType.aps;
      return ClinicType.privada;
    }

    // Parser de endereço — `endereco` pode vir como Map OU como String (alguns
    // cadastros gravam o endereço completo em texto). Cast seguro p/ não
    // derrubar o parse do documento inteiro.
    final endereco = data['endereco'] is Map
        ? Map<String, dynamic>.from(data['endereco'] as Map)
        : <String, dynamic>{};

    // Coordenadas: aceita `latitude`/`longitude` (ou `lat`/`lng`) tanto na raiz
    // quanto dentro de `endereco`/`geo`/`coordenadas`. Cobre os formatos mais
    // comuns de cadastro sem quebrar quando ausente.
    final geo = data['geo'] is Map
        ? Map<String, dynamic>.from(data['geo'] as Map)
        : (data['coordenadas'] is Map
            ? Map<String, dynamic>.from(data['coordenadas'] as Map)
            : <String, dynamic>{});
    double? parseCoord(List<String> keys) {
      for (final src in [data, endereco, geo]) {
        for (final k in keys) {
          final v = src[k];
          if (v is num) return v.toDouble();
          if (v is String) {
            final p = double.tryParse(v.replaceAll(',', '.'));
            if (p != null) return p;
          }
        }
      }
      return null;
    }

    return Clinic(
      id: id,
      name: (data['nome'] ?? data['nomeFantasia'] ?? 'Clínica').toString(),
      type: parseType(data['tipo']?.toString()),
      razaoSocial: data['razaoSocial']?.toString(),
      cnpj: data['cnpj']?.toString(),
      email: data['email']?.toString(),
      phone: (data['telefone'] ?? data['phone'])?.toString(),
      website: data['website']?.toString(),
      photoUrl: (data['foto'] ?? data['logo'] ?? data['photoUrl'])?.toString(),
      address: ClinicAddress(
        cep: (endereco['cep'] ?? data['cep'] ?? '').toString(),
        street: (endereco['logradouro'] ?? data['logradouro'] ?? '').toString(),
        number: (endereco['numero'] ?? data['numero'] ?? '').toString(),
        complement: (endereco['complemento'] ?? data['complemento'] ?? '').toString(),
        district: (endereco['bairro'] ?? data['bairro'] ?? '').toString(),
        city: (endereco['cidade'] ?? data['cidade'] ?? '').toString(),
        state: (endereco['uf'] ?? endereco['estado'] ?? data['uf'] ?? '').toString(),
      ),
      // Especialidades e horários podem ser refinados futuramente.
      specialties: (data['especialidades'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      latitude: parseCoord(const ['latitude', 'lat']),
      longitude: parseCoord(const ['longitude', 'lng', 'lon']),
    );
  }
}

class ClinicAddress {
  const ClinicAddress({
    this.cep = '',
    this.street = '',
    this.number = '',
    this.complement = '',
    this.district = '',
    this.city = '',
    this.state = '',
  });

  final String cep;
  final String street;
  final String number;
  final String complement;
  final String district;
  final String city;
  final String state;

  String get formatted {
    final parts = [
      if (street.isNotEmpty) '$street${number.isNotEmpty ? ', $number' : ''}',
      if (district.isNotEmpty) district,
      if (city.isNotEmpty) '$city${state.isNotEmpty ? ' - $state' : ''}',
      if (cep.isNotEmpty) 'CEP $cep',
    ];
    return parts.join(' • ');
  }

  ClinicAddress copyWith({
    String? cep,
    String? street,
    String? number,
    String? complement,
    String? district,
    String? city,
    String? state,
  }) {
    return ClinicAddress(
      cep: cep ?? this.cep,
      street: street ?? this.street,
      number: number ?? this.number,
      complement: complement ?? this.complement,
      district: district ?? this.district,
      city: city ?? this.city,
      state: state ?? this.state,
    );
  }
}

class BusinessHour {
  const BusinessHour({
    required this.weekday,
    this.open = '08:00',
    this.close = '18:00',
    this.closed = false,
  });

  /// 1 = segunda ... 7 = domingo (ISO).
  final int weekday;
  final String open;
  final String close;
  final bool closed;

  static const List<String> weekdayLabels = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  String get weekdayLabel => weekdayLabels[(weekday - 1) % 7];

  BusinessHour copyWith({String? open, String? close, bool? closed}) {
    return BusinessHour(
      weekday: weekday,
      open: open ?? this.open,
      close: close ?? this.close,
      closed: closed ?? this.closed,
    );
  }
}
