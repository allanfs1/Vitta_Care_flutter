import 'dart:async';

import '../models/enums.dart';

/// Mensagem do log do assistente WhatsApp (WA-03). Deriva de `chat_history`.
class WhatsappMessage {
  const WhatsappMessage({
    required this.contact,
    required this.phoneNumber,
    required this.preview,
    required this.time,
    required this.outbound,
    required this.statusLabel,
    this.contextText,
  });

  final String contact;
  final String phoneNumber;
  final String preview;
  final DateTime time;
  final bool outbound;
  final String statusLabel;
  final String? contextText;
}

/// Serviço compartilhado de integração com WhatsApp via **Z-API** (`.specify/ZAPI.md`).
///
/// Fluxo de produção:
/// - `GET  /instances/{id}/token/{token}/qr-code/image` → QR Code de pareamento (WA-01)
/// - `GET  /instances/{id}/token/{token}/status`        → status da conexão (WA-02)
/// - `POST /instances/{id}/token/{token}/send-text`     → mensagens automáticas (WA-04)
///
/// As credenciais ficam em `tb_config_whatsapp` e nunca no cliente. Aqui simulamos
/// o ciclo de conexão para desenvolvimento.
class WhatsappService {
  const WhatsappService();

  /// Sequência de status que simula um pareamento bem-sucedido.
  Stream<WhatsappStatus> connect() async* {
    yield WhatsappStatus.disconnected;
    await Future<void>.delayed(const Duration(seconds: 2));
    yield WhatsappStatus.reconnecting;
    await Future<void>.delayed(const Duration(seconds: 3));
    yield WhatsappStatus.connected;
  }

  List<WhatsappMessage> recentMessages() {
    final now = DateTime.now();
    return [
      WhatsappMessage(
        contact: 'Allan Ferreira de Souza',
        phoneNumber: '5511996106201',
        preview: 'Olá! 🥰 Como posso te ajudar hoje? Se precisar de algo, pode me fa...',
        time: now.subtract(const Duration(minutes: 10)),
        outbound: true,
        statusLabel: 'RECEBIDO',
        contextText: 'Clínico Geral 👨‍⚕️ Dra. Mariana Silva 🗓️ 19/02/2026 às 17:53',
      ),
      WhatsappMessage(
        contact: 'Allan Ferreira de Souza',
        phoneNumber: '5511996106201',
        preview: 'Olá! 🥰 Como posso te ajudar hoje? Se precisar de algo, pode me fa...',
        time: now.subtract(const Duration(minutes: 45)),
        outbound: true,
        statusLabel: 'RECEBIDO',
        contextText: 'Agendar uma nova consulta',
      ),
      WhatsappMessage(
        contact: 'Allan Ferreira de Souza',
        phoneNumber: '5511996106201',
        preview: 'Olá! 🥰 Como posso te ajudar hoje? Se precisar de algo, pode me fa...',
        time: now.subtract(const Duration(hours: 7)),
        outbound: true,
        statusLabel: 'RECEBIDO',
        contextText: 'Tire dúvidas sobre a clínica, consulte valores das consultas e receba...',
      ),
      WhatsappMessage(
        contact: 'Allan Ferreira de Souza',
        phoneNumber: '5511996106201',
        preview: 'Olá! 🥰 Como posso te ajudar hoje? Se precisar de algo, pode me fa...',
        time: now.subtract(const Duration(hours: 24)),
        outbound: true,
        statusLabel: 'RECEBIDO',
        contextText: 'Tire dúvidas sobre a clínica, consulte valores das consultas e receba...',
      ),
      WhatsappMessage(
        contact: 'Allan Ferreira de Souza',
        phoneNumber: '5511996106201',
        preview: 'Olá! 🥰 Como posso te ajudar hoje? Se precisar de algo, pode me fa...',
        time: now.subtract(const Duration(days: 2)),
        outbound: true,
        statusLabel: 'RECEBIDO',
        contextText: 'Tire dúvidas sobre a clínica, consulte valores das consultas e receba...',
      ),
    ];
  }
}

/// Modelos de mensagem automática configuráveis (WA-04).
class WhatsappTemplates {
  WhatsappTemplates({
    this.confirmation =
        'Olá {nome}! Confirmando sua consulta em {data} às {hora} com {medico}. '
        'Responda SIM para confirmar.',
    this.reminder =
        'Lembrete: sua consulta é {data} às {hora}. Chegue com 15 min de '
        'antecedência. 🏥',
    this.cancellation =
        'Sua consulta de {data} foi cancelada. Deseja reagendar? Responda '
        'REAGENDAR.',
  });

  String confirmation;
  String reminder;
  String cancellation;
}
