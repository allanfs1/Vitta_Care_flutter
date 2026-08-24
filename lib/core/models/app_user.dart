import 'package:cloud_firestore/cloud_firestore.dart';

/// Usuário autenticado do app (gestor/profissional). Mapeia `users`.
class AppUser {
  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.cpf,
    this.birthDate,
    this.gender,
    this.photoUrl,
    this.roleLabel = 'Gestor',
    this.address = const UserAddress(),
    this.clinicIds = const [],
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? cpf;
  final DateTime? birthDate;
  final String? gender;
  final String? photoUrl;
  final String roleLabel;
  final UserAddress address;
  final List<String> clinicIds;

  /// Cria um [AppUser] a partir de um documento `users` do Firestore.
  factory AppUser.fromFirestore(String id, Map<String, dynamic> data) {
    final display = (data['display_name'] ?? data['nome'] ?? '').toString().trim();
    final parts = display.isEmpty
        ? <String>['Usuário']
        : display.split(RegExp(r'\s+'));

    // Extrai o id da clínica de `idclinica` (reference, string ou caminho).
    final clinicIds = <String>[];
    final ref = data['idclinica'];
    if (ref is DocumentReference) {
      clinicIds.add(ref.id);
    } else if (ref is String && ref.isNotEmpty) {
      clinicIds.add(ref.split('/').last);
    }
    // Suporte a múltiplas clínicas, se houver um array.
    final extra = data['clinicas'] ?? data['unidades'];
    if (extra is List) {
      for (final e in extra) {
        if (e is DocumentReference) {
          clinicIds.add(e.id);
        } else if (e != null) {
          clinicIds.add(e.toString().split('/').last);
        }
      }
    }

    DateTime? birth;
    final dn = data['dataNascimento'];
    if (dn is Timestamp) birth = dn.toDate();

    final roles = (data['roles'] as List?)?.map((e) => e.toString()).toList();

    return AppUser(
      id: id,
      firstName: parts.first,
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      email: data['email']?.toString(),
      phone: data['phone_number']?.toString(),
      cpf: data['cpf']?.toString(),
      birthDate: birth,
      gender: data['sexo']?.toString(),
      photoUrl: data['photo_url']?.toString(),
      roleLabel: (roles != null && roles.isNotEmpty) ? roles.first : 'Gestor',
      address: UserAddress.fromMap(data['endereco']),
      clinicIds: clinicIds.toSet().toList(),
    );
  }

  /// Campos que o app escreve de volta em `users/{id}`.
  ///
  /// Deliberadamente **parcial**: grava só o que a tela de perfil edita, com
  /// `SetOptions(merge: true)` no serviço. `roles`, `idclinica` e demais campos
  /// de permissão são administrados fora do app e não podem ser sobrescritos
  /// por uma edição de perfil.
  Map<String, dynamic> toFirestore() => {
        'display_name': fullName,
        'email': email,
        'phone_number': phone,
        'cpf': cpf,
        'sexo': gender,
        'photo_url': photoUrl,
        if (birthDate != null) 'dataNascimento': Timestamp.fromDate(birthDate!),
        'endereco': address.toMap(),
      };

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final res = '$f$l'.toUpperCase();
    return res.isEmpty ? '?' : res;
  }

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? cpf,
    DateTime? birthDate,
    String? gender,
    String? photoUrl,
    String? roleLabel,
    UserAddress? address,
    List<String>? clinicIds,
  }) {
    return AppUser(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      cpf: cpf ?? this.cpf,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      roleLabel: roleLabel ?? this.roleLabel,
      address: address ?? this.address,
      clinicIds: clinicIds ?? this.clinicIds,
    );
  }
}

class UserAddress {
  const UserAddress({
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

  /// Lê o subdocumento `endereco`. Tolera ausência e tipos inesperados — o
  /// campo é novo e a maior parte da base ainda não o tem.
  factory UserAddress.fromMap(Object? raw) {
    if (raw is! Map) return const UserAddress();
    String s(String k) => raw[k]?.toString() ?? '';
    return UserAddress(
      cep: s('cep'),
      street: s('logradouro'),
      number: s('numero'),
      complement: s('complemento'),
      district: s('bairro'),
      city: s('cidade'),
      state: s('uf'),
    );
  }

  Map<String, dynamic> toMap() => {
        'cep': cep,
        'logradouro': street,
        'numero': number,
        'complemento': complement,
        'bairro': district,
        'cidade': city,
        'uf': state,
      };

  bool get vazio =>
      cep.isEmpty &&
      street.isEmpty &&
      number.isEmpty &&
      complement.isEmpty &&
      district.isEmpty &&
      city.isEmpty &&
      state.isEmpty;

  UserAddress copyWith({
    String? cep,
    String? street,
    String? number,
    String? complement,
    String? district,
    String? city,
    String? state,
  }) {
    return UserAddress(
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
