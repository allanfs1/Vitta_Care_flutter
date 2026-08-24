import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/appointment.dart';

/// Host das Cloud Functions (Gen 2).
const String _functionsHost = 'https://api-wriqcan55q-uc.a.run.app';

/// Cloud Function de e-mail de confirmação (SendGrid). A chave fica no servidor
/// (ver `functions/sendConfirmationEmail.js`).
const String _sendConfirmationEmailUrl = '$_functionsHost/sendConfirmationEmail';

/// Cloud Function de envio de WhatsApp via Z-API (credenciais por clínica em
/// `tb_config_whatsapp`; ver `functions/whatsappProxy.js`).
const String _whatsappProxyUrl = '$_functionsHost/whatsappProxy';

/// Serviço de confirmações transacionais (e-mail e WhatsApp/Z-API).
class EmailService {
  const EmailService();

  /// Envia o e-mail de confirmação/remarcação via `sendConfirmationEmail`.
  /// Nunca lança: retorna `true` em sucesso e `false` caso contrário.
  Future<bool> sendConfirmation({
    required String? to,
    required Appointment appointment,
    required bool isReschedule,
    required String clinicName,
    String? senha,
    String? footer,
  }) async {
    final email = (to ?? '').trim();
    if (!email.contains('@')) return false;
    try {
      final res = await http
          .post(
            Uri.parse(_sendConfirmationEmailUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'to': email,
              'mode': isReschedule ? 'remarcar' : 'agendar',
              'patientName': appointment.patientName,
              'doctorName': appointment.doctorName,
              'specialty': appointment.specialty,
              'date': _fmtDate(appointment.start),
              'time': _fmtTime(appointment.start),
              if (senha != null && senha.isNotEmpty) 'senha': senha,
              'clinicName': clinicName,
              if (footer != null && footer.trim().isNotEmpty) 'footer': footer,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final ok = res.statusCode == 200;
      if (!ok) {
        debugPrint('sendConfirmationEmail falhou: ${res.statusCode} ${res.body}');
      }
      return ok;
    } catch (e) {
      debugPrint('sendConfirmationEmail erro: $e');
      return false;
    }
  }

  /// Envia a confirmação por **WhatsApp (Z-API)** via `whatsappProxy`, incluindo
  /// o link de confirmação. Nunca lança: retorna `true`/`false`.
  Future<bool> sendWhatsappConfirmation({
    required String clinicaId,
    required String? phone,
    required Appointment appointment,
    required bool isReschedule,
    required String clinicName,
    String? senha,
    required String link,
  }) async {
    final digits = _normalizePhone(phone);
    if (digits.length < 12) return false; // DDI+DDD+número
    final verb = isReschedule ? 'remarcada' : 'confirmada';
    final msg = StringBuffer()
      ..writeln('Olá ${appointment.patientName}! Sua consulta foi $verb. ✅')
      ..writeln('🩺 ${appointment.specialty} — ${appointment.doctorName}')
      ..writeln(
          '🗓️ ${_fmtDate(appointment.start)} às ${_fmtTime(appointment.start)}');
    if (senha != null && senha.isNotEmpty) msg.writeln('🎫 Senha: $senha');
    final l = link.trim();
    if (l.isNotEmpty) msg.writeln('Confirme sua presença: $l');

    try {
      final res = await http
          .post(
            Uri.parse(_whatsappProxyUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'clinicaId': clinicaId,
              'action': 'send-text',
              'phone': digits,
              'message': msg.toString().trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));
      final ok = res.statusCode == 200;
      if (!ok) {
        debugPrint('whatsapp confirmation falhou: ${res.statusCode} ${res.body}');
      }
      return ok;
    } catch (e) {
      debugPrint('whatsapp confirmation erro: $e');
      return false;
    }
  }

  /// Envia o e-mail de **cancelamento** via `sendConfirmationEmail`
  /// (`mode: cancelar`). Nunca lança: retorna `true`/`false`.
  Future<bool> sendCancellation({
    required String? to,
    required Appointment appointment,
    required String clinicName,
    String? footer,
  }) async {
    final email = (to ?? '').trim();
    if (!email.contains('@')) return false;
    try {
      final res = await http
          .post(
            Uri.parse(_sendConfirmationEmailUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'to': email,
              'mode': 'cancelar',
              'patientName': appointment.patientName,
              'doctorName': appointment.doctorName,
              'specialty': appointment.specialty,
              'date': _fmtDate(appointment.start),
              'time': _fmtTime(appointment.start),
              'clinicName': clinicName,
              if (footer != null && footer.trim().isNotEmpty) 'footer': footer,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final ok = res.statusCode == 200;
      if (!ok) {
        debugPrint('sendCancellationEmail falhou: ${res.statusCode} ${res.body}');
      }
      return ok;
    } catch (e) {
      debugPrint('sendCancellationEmail erro: $e');
      return false;
    }
  }

  /// Envia o aviso de **cancelamento por WhatsApp (Z-API)** via `whatsappProxy`.
  /// Nunca lança: retorna `true`/`false`.
  Future<bool> sendWhatsappCancellation({
    required String clinicaId,
    required String? phone,
    required Appointment appointment,
    required String clinicName,
  }) async {
    final digits = _normalizePhone(phone);
    if (digits.length < 12) return false; // DDI+DDD+número
    final msg = StringBuffer()
      ..writeln('Olá ${appointment.patientName}, sua consulta foi cancelada. ❌')
      ..writeln('🩺 ${appointment.specialty} — ${appointment.doctorName}')
      ..writeln(
          '🗓️ ${_fmtDate(appointment.start)} às ${_fmtTime(appointment.start)}')
      ..writeln('Para reagendar, entre em contato com $clinicName.');

    try {
      final res = await http
          .post(
            Uri.parse(_whatsappProxyUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'clinicaId': clinicaId,
              'action': 'send-text',
              'phone': digits,
              'message': msg.toString().trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));
      final ok = res.statusCode == 200;
      if (!ok) {
        debugPrint('whatsapp cancellation falhou: ${res.statusCode} ${res.body}');
      }
      return ok;
    } catch (e) {
      debugPrint('whatsapp cancellation erro: $e');
      return false;
    }
  }

  /// Normaliza o telefone para DDI+DDD+número (apenas dígitos). Assume Brasil
  /// (55) quando o número vem só com DDD+número (10 ou 11 dígitos).
  String _normalizePhone(String? raw) {
    var d = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return '';
    if (d.length == 10 || d.length == 11) d = '55$d';
    return d;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
