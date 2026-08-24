import 'manchester_priority.dart';

/// Registro de uma chamada exibida no Monitor da Recepção (§4.1).
class CallRecord {
  const CallRecord({
    required this.senha,
    required this.patientName,
    required this.local,
    required this.attendant,
    required this.at,
    this.manchester = ManchesterPriority.green,
    this.photoUrl,
  });

  final String senha;
  final String patientName;

  /// Guichê / consultório / setor para onde o paciente deve se dirigir.
  final String local;
  final String attendant;
  final DateTime at;
  final ManchesterPriority manchester;
  final String? photoUrl;

  /// Frase locutada no monitor (TTS, §4.1).
  String get announcement =>
      'Paciente $patientName, favor dirigir-se a $local'
      '${attendant.isEmpty ? '' : ' com $attendant'}.';
}
