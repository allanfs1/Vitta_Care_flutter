import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../mcp_tool.dart';

/// Cloud Function de envio direto de e-mail (SendGrid). A chave fica no servidor
/// (ver `cloud_functions/emailProxy.js`).
const String _emailProxyUrl =
    'https://us-central1-agendaclinica-457713.cloudfunctions.net/emailProxy';

/// Cloud Function de envio direto de WhatsApp (Z-API). As credenciais por
/// clínica ficam no Firestore/servidor (ver `cloud_functions/whatsappProxy.js`).
const String _whatsappProxyUrl =
    'https://us-central1-agendaclinica-457713.cloudfunctions.net/whatsappProxy';

/// Ferramentas MCP de comunicação — e-mails transacionais, Google Workspace
/// e WhatsApp via Z-API (§6.14–§6.17 de `.specify/MCP.md`).
///
/// **Padrão cliente-seguro**: este é um aplicativo cliente. Segredos não são
/// embutidos e dependências HTTP externas não são adicionadas. Cada tool de
/// "envio" persiste um registro na coleção Firestore adequada para que Cloud
/// Functions existentes (ex.: `ffProcessEmailQueue`) processem a entrega
/// assincronamente.
///
/// Expõe [buildComunicacaoTools].
List<McpTool> buildComunicacaoTools(McpContext ctx) {
  return [
    // §6.14 Cloud Functions — e-mails transacionais
    _enviarEmailConfirmacao(ctx),
    _enviarEmailOverbooking(ctx),
    _enviarEmailRealocacao(ctx),

    // §6.15 Google Workspace
    _googleAgendarEvento(ctx),
    _googleListarEventos(ctx),
    _googleEnviarEmail(ctx),
    _googleBuscarDrive(ctx),

    // §6.16 SendGrid
    _emailEnviarLivre(ctx),
    _emailConfirmarConsulta(ctx),
    _emailLembreteConsulta(ctx),
    _emailAvisoOverbooking(ctx),
    _emailRelatorio(ctx),
    _emailEnviarEmLote(ctx),

    // §6.17 WhatsApp Z-API
    _whatsappStatus(ctx),
    _whatsappValidarNumero(ctx),
    _whatsappEnviarTexto(ctx),
    _whatsappConfirmarConsulta(ctx),
    _whatsappLembreteConsulta(ctx),
    _whatsappAvisoOverbooking(ctx),
    _whatsappEnviarListaConfirmacao(ctx),
    _whatsappEnviarEmLote(ctx),
  ];
}

// ---------------------------------------------------------------------------
// Helpers privados
// ---------------------------------------------------------------------------

/// Normaliza um número de telefone: remove não-dígitos e, se o resultado
/// tiver 10–11 dígitos sem código de país, prefixa '55' (Brasil).
String _normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 10 && digits.length <= 11 && !digits.startsWith('55')) {
    return '55$digits';
  }
  return digits;
}

/// Envia o e-mail **diretamente** via `emailProxy` (SendGrid) e registra em
/// `email_queue` como log. Se o envio direto falhar (proxy indisponível), o
/// registro fica `status: 'queued'` para entrega assíncrona por
/// `ffProcessEmailQueue` (fallback). Sempre carimba `idclinica` (multi-tenant).
Future<DocumentReference<Map<String, dynamic>>> _enqueueEmail(
  McpContext ctx,
  Map<String, dynamic> payload,
) async {
  var status = 'queued';
  final to = payload['para']?.toString();
  if (to != null && to.contains('@')) {
    try {
      final res = await http
          .post(
            Uri.parse(_emailProxyUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'to': to,
              'subject': _emailSubject(payload),
              'markdown': _emailBody(payload),
              'idclinica': ctx.clinicaId(),
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) status = 'sent';
    } catch (_) {
      // Mantém 'queued' → fallback pela Cloud Function de fila.
    }
  }
  return ctx.db.collection('email_queue').add({
    ...payload,
    'status': status,
    'idclinica': ctx.clinicaId(),
    'createdAt': FieldValue.serverTimestamp(),
    'origem': 'mcp',
  });
}

/// Deriva um assunto a partir do payload (campo `assunto` ou pelo `tipo`).
String _emailSubject(Map<String, dynamic> p) {
  final assunto = p['assunto']?.toString();
  if (assunto != null && assunto.isNotEmpty) return assunto;
  switch (p['tipo']?.toString()) {
    case 'confirmacao':
      return 'Confirmação de consulta';
    case 'lembrete':
      return 'Lembrete de consulta';
    case 'overbooking':
    case 'realocacao':
      return 'Atualização do seu agendamento';
    case 'relatorio':
      return 'Relatório';
    default:
      return 'Mensagem da clínica';
  }
}

/// Deriva o corpo (markdown) a partir do payload.
String _emailBody(Map<String, dynamic> p) {
  final corpo = p['corpo']?.toString() ?? p['mensagem']?.toString();
  if (corpo != null && corpo.isNotEmpty) return corpo;
  final nome = p['nomePaciente']?.toString();
  final data = p['dataConsulta']?.toString();
  final saud = nome != null ? 'Olá, $nome!' : 'Olá!';
  switch (p['tipo']?.toString()) {
    case 'confirmacao':
      return '$saud Confirmando sua consulta${data != null ? ' em **$data**' : ''}.';
    case 'lembrete':
      return '$saud Lembrete da sua consulta${data != null ? ' em **$data**' : ''}.';
    case 'overbooking':
    case 'realocacao':
      final link = p['linkReagendamento']?.toString();
      return '$saud Houve uma atualização no seu agendamento.'
          '${link != null ? '\n\nReagende aqui: $link' : ''}';
    default:
      return saud;
  }
}

/// Envia a mensagem WhatsApp **diretamente** via `whatsappProxy` (Z-API, com
/// credenciais por clínica no servidor) e registra em `tb_conversas` como log.
/// Se o envio direto falhar, mantém `status: 'enfileirado'` (fallback). Sempre
/// carimba `idclinica` (multi-tenant).
Future<DocumentReference<Map<String, dynamic>>> _writeWhatsapp(
  McpContext ctx,
  Map<String, dynamic> payload,
) async {
  var status = 'enfileirado';
  final phone = payload['telefone']?.toString();
  // Não tenta enviar para os registros de log internos (sem texto real).
  final isButtonList = payload['tipo']?.toString() == 'button-list';
  if (phone != null && phone.isNotEmpty) {
    try {
      final res = await http
          .post(
            Uri.parse(_whatsappProxyUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'clinicaId': ctx.clinicaId(),
              'action': isButtonList ? 'send-button-list' : 'send-text',
              'phone': phone,
              'message': payload['mensagem']?.toString() ?? '',
              if (isButtonList && payload['botoes'] is List)
                'buttons': payload['botoes'],
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) status = 'enviado';
    } catch (_) {
      // Mantém 'enfileirado' (sem entrega automática por enquanto).
    }
  }
  return ctx.db.collection('tb_conversas').add({
    ...payload,
    'status': status,
    'idclinica': ctx.clinicaId(),
    'createdAt': FieldValue.serverTimestamp(),
    'origem': 'mcp',
  });
}

// ---------------------------------------------------------------------------
// §6.14 — Cloud Functions — e-mails transacionais
// ---------------------------------------------------------------------------

// 1. enviar_email_confirmacao
McpTool _enviarEmailConfirmacao(McpContext ctx) {
  return McpTool(
    name: 'enviar_email_confirmacao',
    description:
        'Enfileira um e-mail de confirmação de consulta em email_queue '
        '(tipo: confirmacao) para processamento pela Cloud Function '
        'ffProcessEmailQueue. Não realiza envio direto.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'para': {
          'type': 'string',
          'description': 'Endereço de e-mail do destinatário.',
        },
        'nomePaciente': {
          'type': 'string',
          'description': 'Nome do paciente. Opcional.',
        },
        'dataConsulta': {
          'type': 'string',
          'description': 'Data/hora da consulta (ISO 8601 ou dd/MM/yyyy HH:mm). Opcional.',
        },
        'agendamentoId': {
          'type': 'string',
          'description': 'ID do agendamento relacionado. Opcional.',
        },
      },
      'required': ['para'],
    },
    handler: (args) async {
      try {
        final para = args.str('para');
        if (para == null || para.isEmpty) {
          return err('O campo "para" (e-mail) é obrigatório.');
        }
        final ref = await _enqueueEmail(ctx, {
          'tipo': 'confirmacao',
          'para': para,
          if (args.str('nomePaciente') != null)
            'nomePaciente': args.str('nomePaciente'),
          if (args.str('dataConsulta') != null)
            'dataConsulta': args.str('dataConsulta'),
          if (args.str('agendamentoId') != null)
            'agendamentoId': args.str('agendamentoId'),
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'tipo': 'confirmacao',
          'para': para,
          'mensagem': 'E-mail de confirmação enfileirado em email_queue.',
        });
      } catch (e) {
        return err('enviar_email_confirmacao: $e');
      }
    },
  );
}

// 2. enviar_email_overbooking
McpTool _enviarEmailOverbooking(McpContext ctx) {
  return McpTool(
    name: 'enviar_email_overbooking',
    description:
        'Enfileira um e-mail de aviso de overbooking em email_queue '
        '(tipo: overbooking) para processamento pela Cloud Function '
        'ffProcessEmailQueue. Não realiza envio direto.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'para': {
          'type': 'string',
          'description': 'Endereço de e-mail do destinatário.',
        },
        'nomePaciente': {
          'type': 'string',
          'description': 'Nome do paciente. Opcional.',
        },
        'mensagem': {
          'type': 'string',
          'description': 'Mensagem informativa adicional. Opcional.',
        },
      },
      'required': ['para'],
    },
    handler: (args) async {
      try {
        final para = args.str('para');
        if (para == null || para.isEmpty) {
          return err('O campo "para" (e-mail) é obrigatório.');
        }
        final ref = await _enqueueEmail(ctx, {
          'tipo': 'overbooking',
          'para': para,
          if (args.str('nomePaciente') != null)
            'nomePaciente': args.str('nomePaciente'),
          if (args.str('mensagem') != null) 'mensagem': args.str('mensagem'),
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'tipo': 'overbooking',
          'para': para,
          'mensagem': 'E-mail de overbooking enfileirado em email_queue.',
        });
      } catch (e) {
        return err('enviar_email_overbooking: $e');
      }
    },
  );
}

// 3. enviar_email_realocacao
McpTool _enviarEmailRealocacao(McpContext ctx) {
  return McpTool(
    name: 'enviar_email_realocacao',
    description:
        'Enfileira um e-mail de realocação/reagendamento em email_queue '
        '(tipo: realocacao) para processamento pela Cloud Function '
        'ffProcessEmailQueue. Não realiza envio direto.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'para': {
          'type': 'string',
          'description': 'Endereço de e-mail do destinatário.',
        },
        'nomePaciente': {
          'type': 'string',
          'description': 'Nome do paciente. Opcional.',
        },
        'agendamentoId': {
          'type': 'string',
          'description': 'ID do agendamento a ser reagendado. Opcional.',
        },
        'linkReagendamento': {
          'type': 'string',
          'description': 'Link seguro para o paciente reagendar. Opcional.',
        },
      },
      'required': ['para'],
    },
    handler: (args) async {
      try {
        final para = args.str('para');
        if (para == null || para.isEmpty) {
          return err('O campo "para" (e-mail) é obrigatório.');
        }
        final ref = await _enqueueEmail(ctx, {
          'tipo': 'realocacao',
          'para': para,
          if (args.str('nomePaciente') != null)
            'nomePaciente': args.str('nomePaciente'),
          if (args.str('agendamentoId') != null)
            'agendamentoId': args.str('agendamentoId'),
          if (args.str('linkReagendamento') != null)
            'linkReagendamento': args.str('linkReagendamento'),
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'tipo': 'realocacao',
          'para': para,
          'mensagem': 'E-mail de realocação enfileirado em email_queue.',
        });
      } catch (e) {
        return err('enviar_email_realocacao: $e');
      }
    },
  );
}

// ---------------------------------------------------------------------------
// §6.15 — Google Workspace
// ---------------------------------------------------------------------------

// 4. google_agendar_evento
McpTool _googleAgendarEvento(McpContext ctx) {
  return McpTool(
    name: 'google_agendar_evento',
    description:
        'Registra intenção de criar um evento no Google Calendar da clínica '
        'gravando um documento em google_tasks (acao: calendar.create). '
        'A execução real ocorre server-side via OAuth configurado na clínica.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'titulo': {
          'type': 'string',
          'description': 'Título do evento no calendário.',
        },
        'inicio': {
          'type': 'string',
          'description': 'Data/hora de início (ISO 8601 ou dd/MM/yyyy HH:mm).',
        },
        'fim': {
          'type': 'string',
          'description': 'Data/hora de término. Opcional.',
        },
        'descricao': {
          'type': 'string',
          'description': 'Descrição ou observações do evento. Opcional.',
        },
        'clinicaId': {
          'type': 'string',
          'description': 'ID da clínica. Opcional — usa a clínica padrão.',
        },
      },
      'required': ['titulo', 'inicio'],
    },
    handler: (args) async {
      try {
        final titulo = args.str('titulo');
        if (titulo == null || titulo.isEmpty) {
          return err('O campo "titulo" é obrigatório.');
        }
        final inicio = args.str('inicio');
        if (inicio == null || inicio.isEmpty) {
          return err('O campo "inicio" é obrigatório.');
        }
        final clinicaId = ctx.clinicaId(args.str('clinicaId'));
        final ref = await ctx.db.collection('google_tasks').add({
          'acao': 'calendar.create',
          'clinicaId': clinicaId,
          'titulo': titulo,
          'inicio': inicio,
          if (args.str('fim') != null) 'fim': args.str('fim'),
          if (args.str('descricao') != null) 'descricao': args.str('descricao'),
          'createdAt': FieldValue.serverTimestamp(),
          'origem': 'mcp',
        });
        return ok({
          'registrado': true,
          'id': ref.id,
          'acao': 'calendar.create',
          'titulo': titulo,
          'inicio': inicio,
          'clinicaId': clinicaId,
          'mensagem':
              'Intenção de criar evento gravada em google_tasks para processamento server-side.',
        });
      } catch (e) {
        return err('google_agendar_evento: $e');
      }
    },
  );
}

// 5. google_listar_eventos
McpTool _googleListarEventos(McpContext ctx) {
  return McpTool(
    name: 'google_listar_eventos',
    description:
        'Lista eventos registrados localmente em google_tasks (acao: calendar.create). '
        'Aplica filtro em memória por timeMin/timeMax quando informados. '
        'Não consulta a API do Google Calendar diretamente (requer OAuth server-side).',
    inputSchema: {
      'type': 'object',
      'properties': {
        'timeMin': {
          'type': 'string',
          'description': 'Data/hora mínima de início (ISO 8601). Opcional.',
        },
        'timeMax': {
          'type': 'string',
          'description': 'Data/hora máxima de início (ISO 8601). Opcional.',
        },
        'clinicaId': {
          'type': 'string',
          'description': 'ID da clínica. Opcional — usa a clínica padrão.',
        },
      },
      'required': <String>[],
    },
    handler: (args) async {
      try {
        final clinicaId = ctx.clinicaId(args.str('clinicaId'));
        final timeMinStr = args.str('timeMin');
        final timeMaxStr = args.str('timeMax');
        final timeMin = timeMinStr != null ? DateTime.tryParse(timeMinStr) : null;
        final timeMax = timeMaxStr != null ? DateTime.tryParse(timeMaxStr) : null;

        final snap = await ctx.db
            .collection('google_tasks')
            .where('acao', isEqualTo: 'calendar.create')
            .where('clinicaId', isEqualTo: clinicaId)
            .get();

        final eventos = <Map<String, dynamic>>[];
        for (final doc in snap.docs) {
          final data = doc.data();
          final inicioStr = data['inicio'] as String?;
          if (inicioStr != null && (timeMin != null || timeMax != null)) {
            final inicio = DateTime.tryParse(inicioStr);
            if (inicio != null) {
              if (timeMin != null && inicio.isBefore(timeMin)) continue;
              if (timeMax != null && inicio.isAfter(timeMax)) continue;
            }
          }
          eventos.add(<String, dynamic>{
            'id': doc.id,
            ...?(jsonSafe(data) as Map<String, dynamic>?),
          });
        }

        return ok({
          'total': eventos.length,
          'eventos': eventos,
          'nota':
              'Eventos listados são registros locais (google_tasks). '
              'Eventos criados diretamente na API do Google Calendar requerem consulta server-side com OAuth.',
        });
      } catch (e) {
        return err('google_listar_eventos: $e');
      }
    },
  );
}

// 6. google_enviar_email
McpTool _googleEnviarEmail(McpContext ctx) {
  return McpTool(
    name: 'google_enviar_email',
    description:
        'Enfileira um e-mail a ser enviado via Gmail da clínica em email_queue '
        '(tipo: google_gmail). Processamento real ocorre server-side via OAuth. '
        'Não realiza envio direto.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'para': {
          'type': 'string',
          'description': 'Endereço de e-mail do destinatário.',
        },
        'assunto': {
          'type': 'string',
          'description': 'Assunto do e-mail.',
        },
        'corpo': {
          'type': 'string',
          'description': 'Corpo do e-mail (aceita Markdown).',
        },
        'clinicaId': {
          'type': 'string',
          'description': 'ID da clínica. Opcional — usa a clínica padrão.',
        },
      },
      'required': ['para', 'assunto', 'corpo'],
    },
    handler: (args) async {
      try {
        final para = args.str('para');
        if (para == null || para.isEmpty) {
          return err('O campo "para" é obrigatório.');
        }
        final assunto = args.str('assunto');
        if (assunto == null || assunto.isEmpty) {
          return err('O campo "assunto" é obrigatório.');
        }
        final corpo = args.str('corpo');
        if (corpo == null || corpo.isEmpty) {
          return err('O campo "corpo" é obrigatório.');
        }
        final clinicaId = ctx.clinicaId(args.str('clinicaId'));
        final ref = await _enqueueEmail(ctx, {
          'tipo': 'google_gmail',
          'para': para,
          'assunto': assunto,
          'corpo': corpo,
          'clinicaId': clinicaId,
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'tipo': 'google_gmail',
          'para': para,
          'assunto': assunto,
          'mensagem': 'E-mail via Gmail enfileirado em email_queue.',
        });
      } catch (e) {
        return err('google_enviar_email: $e');
      }
    },
  );
}

// 7. google_buscar_drive
McpTool _googleBuscarDrive(McpContext ctx) {
  return McpTool(
    name: 'google_buscar_drive',
    description:
        'Informa que a busca no Google Drive requer OAuth server-side e não '
        'está disponível no cliente. Retorna lista vazia com explicação.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Termo de busca para arquivos no Google Drive.',
        },
        'clinicaId': {
          'type': 'string',
          'description': 'ID da clínica. Opcional.',
        },
      },
      'required': ['query'],
    },
    handler: (args) async {
      try {
        final query = args.str('query');
        if (query == null || query.isEmpty) {
          return err('O campo "query" é obrigatório.');
        }
        return ok({
          'arquivos': <dynamic>[],
          'query': query,
          'nota':
              'A busca no Google Drive requer autenticação OAuth server-side '
              'com as credenciais da clínica. Esta operação não está disponível '
              'no cliente. Para buscar arquivos, acesse o painel de administração '
              'ou utilize as integrações server-side do sistema.',
        });
      } catch (e) {
        return err('google_buscar_drive: $e');
      }
    },
  );
}

// ---------------------------------------------------------------------------
// §6.16 — SendGrid
// ---------------------------------------------------------------------------

// 8. email_enviar_livre
McpTool _emailEnviarLivre(McpContext ctx) {
  return McpTool(
    name: 'email_enviar_livre',
    description:
        'Enfileira um e-mail de texto livre em email_queue '
        '(tipo: livre, template: htmlMensagemLivre). O corpo aceita Markdown '
        'e será renderizado no template de marca pelo servidor.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'para': {
          'type': 'string',
          'description': 'Endereço de e-mail do destinatário.',
        },
        'assunto': {
          'type': 'string',
          'description': 'Assunto do e-mail.',
        },
        'corpo': {
          'type': 'string',
          'description': 'Corpo do e-mail em Markdown.',
        },
      },
      'required': ['para', 'assunto', 'corpo'],
    },
    handler: (args) async {
      try {
        final para = args.str('para');
        if (para == null || para.isEmpty) {
          return err('O campo "para" é obrigatório.');
        }
        final assunto = args.str('assunto');
        if (assunto == null || assunto.isEmpty) {
          return err('O campo "assunto" é obrigatório.');
        }
        final corpo = args.str('corpo');
        if (corpo == null || corpo.isEmpty) {
          return err('O campo "corpo" é obrigatório.');
        }
        final ref = await _enqueueEmail(ctx, {
          'tipo': 'livre',
          'template': 'htmlMensagemLivre',
          'para': para,
          'assunto': assunto,
          'corpo': corpo,
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'para': para,
          'assunto': assunto,
          'mensagem': 'E-mail livre enfileirado em email_queue.',
        });
      } catch (e) {
        return err('email_enviar_livre: $e');
      }
    },
  );
}

// 9. email_confirmar_consulta
McpTool _emailConfirmarConsulta(McpContext ctx) {
  return McpTool(
    name: 'email_confirmar_consulta',
    description:
        'Enfileira um e-mail de confirmação de consulta em email_queue '
        '(tipo: confirmacao, template: htmlConfirmacao) para envio via SendGrid.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'para': {
          'type': 'string',
          'description': 'Endereço de e-mail do paciente.',
        },
        'nomePaciente': {
          'type': 'string',
          'description': 'Nome do paciente. Opcional.',
        },
        'dataConsulta': {
          'type': 'string',
          'description': 'Data/hora da consulta. Opcional.',
        },
        'medico': {
          'type': 'string',
          'description': 'Nome do médico responsável. Opcional.',
        },
      },
      'required': ['para'],
    },
    handler: (args) async {
      try {
        final para = args.str('para');
        if (para == null || para.isEmpty) {
          return err('O campo "para" é obrigatório.');
        }
        final ref = await _enqueueEmail(ctx, {
          'tipo': 'confirmacao',
          'template': 'htmlConfirmacao',
          'para': para,
          if (args.str('nomePaciente') != null)
            'nomePaciente': args.str('nomePaciente'),
          if (args.str('dataConsulta') != null)
            'dataConsulta': args.str('dataConsulta'),
          if (args.str('medico') != null) 'medico': args.str('medico'),
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'para': para,
          'mensagem': 'E-mail de confirmação de consulta enfileirado em email_queue.',
        });
      } catch (e) {
        return err('email_confirmar_consulta: $e');
      }
    },
  );
}

// 10. email_lembrete_consulta
McpTool _emailLembreteConsulta(McpContext ctx) {
  return McpTool(
    name: 'email_lembrete_consulta',
    description:
        'Enfileira um e-mail de lembrete de consulta em email_queue '
        '(tipo: lembrete, template: htmlLembrete) para envio via SendGrid.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'para': {
          'type': 'string',
          'description': 'Endereço de e-mail do paciente.',
        },
        'nomePaciente': {
          'type': 'string',
          'description': 'Nome do paciente. Opcional.',
        },
        'dataConsulta': {
          'type': 'string',
          'description': 'Data/hora da consulta. Opcional.',
        },
      },
      'required': ['para'],
    },
    handler: (args) async {
      try {
        final para = args.str('para');
        if (para == null || para.isEmpty) {
          return err('O campo "para" é obrigatório.');
        }
        final ref = await _enqueueEmail(ctx, {
          'tipo': 'lembrete',
          'template': 'htmlLembrete',
          'para': para,
          if (args.str('nomePaciente') != null)
            'nomePaciente': args.str('nomePaciente'),
          if (args.str('dataConsulta') != null)
            'dataConsulta': args.str('dataConsulta'),
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'para': para,
          'mensagem': 'E-mail de lembrete de consulta enfileirado em email_queue.',
        });
      } catch (e) {
        return err('email_lembrete_consulta: $e');
      }
    },
  );
}

// 11. email_aviso_overbooking
McpTool _emailAvisoOverbooking(McpContext ctx) {
  return McpTool(
    name: 'email_aviso_overbooking',
    description:
        'Enfileira um e-mail de aviso de overbooking/realocação em email_queue '
        '(tipo: overbooking, template: htmlOverbooking) para envio via SendGrid.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'para': {
          'type': 'string',
          'description': 'Endereço de e-mail do paciente.',
        },
        'nomePaciente': {
          'type': 'string',
          'description': 'Nome do paciente. Opcional.',
        },
        'linkReagendamento': {
          'type': 'string',
          'description': 'Link para o paciente reagendar. Opcional.',
        },
      },
      'required': ['para'],
    },
    handler: (args) async {
      try {
        final para = args.str('para');
        if (para == null || para.isEmpty) {
          return err('O campo "para" é obrigatório.');
        }
        final ref = await _enqueueEmail(ctx, {
          'tipo': 'overbooking',
          'template': 'htmlOverbooking',
          'para': para,
          if (args.str('nomePaciente') != null)
            'nomePaciente': args.str('nomePaciente'),
          'linkReagendamento': args.str('linkReagendamento'),
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'para': para,
          'mensagem': 'E-mail de aviso de overbooking enfileirado em email_queue.',
        });
      } catch (e) {
        return err('email_aviso_overbooking: $e');
      }
    },
  );
}

// 12. email_relatorio
McpTool _emailRelatorio(McpContext ctx) {
  return McpTool(
    name: 'email_relatorio',
    description:
        'Enfileira um e-mail de relatório executivo em email_queue '
        '(tipo: relatorio, template: htmlRelatorio) para envio via SendGrid.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'para': {
          'type': 'string',
          'description': 'Endereço de e-mail do destinatário.',
        },
        'assunto': {
          'type': 'string',
          'description': 'Assunto do e-mail de relatório.',
        },
        'corpo': {
          'type': 'string',
          'description': 'Corpo do relatório (aceita Markdown).',
        },
      },
      'required': ['para', 'assunto', 'corpo'],
    },
    handler: (args) async {
      try {
        final para = args.str('para');
        if (para == null || para.isEmpty) {
          return err('O campo "para" é obrigatório.');
        }
        final assunto = args.str('assunto');
        if (assunto == null || assunto.isEmpty) {
          return err('O campo "assunto" é obrigatório.');
        }
        final corpo = args.str('corpo');
        if (corpo == null || corpo.isEmpty) {
          return err('O campo "corpo" é obrigatório.');
        }
        final ref = await _enqueueEmail(ctx, {
          'tipo': 'relatorio',
          'template': 'htmlRelatorio',
          'para': para,
          'assunto': assunto,
          'corpo': corpo,
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'para': para,
          'assunto': assunto,
          'mensagem': 'E-mail de relatório enfileirado em email_queue.',
        });
      } catch (e) {
        return err('email_relatorio: $e');
      }
    },
  );
}

// 13. email_enviar_em_lote
McpTool _emailEnviarEmLote(McpContext ctx) {
  return McpTool(
    name: 'email_enviar_em_lote',
    description:
        'Enfileira um e-mail para cada destinatário da lista em email_queue '
        '(tipo: livre, template: htmlMensagemLivre). '
        'Substitui {{nome}} pelo nome de cada destinatário quando disponível. '
        'Máximo de 15 destinatários por chamada.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'destinatarios': {
          'type': 'array',
          'description':
              'Lista de e-mails (strings) ou objetos {email, nome}. '
              'Máximo 15 itens.',
          'items': {
            'oneOf': [
              {'type': 'string'},
              {
                'type': 'object',
                'properties': {
                  'email': {'type': 'string'},
                  'nome': {'type': 'string'},
                },
                'required': ['email'],
              },
            ],
          },
        },
        'assunto': {
          'type': 'string',
          'description': 'Assunto do e-mail.',
        },
        'corpo': {
          'type': 'string',
          'description':
              'Corpo do e-mail em Markdown. Use {{nome}} para personalização.',
        },
      },
      'required': ['destinatarios', 'assunto', 'corpo'],
    },
    handler: (args) async {
      try {
        final assunto = args.str('assunto');
        if (assunto == null || assunto.isEmpty) {
          return err('O campo "assunto" é obrigatório.');
        }
        final corpo = args.str('corpo');
        if (corpo == null || corpo.isEmpty) {
          return err('O campo "corpo" é obrigatório.');
        }

        final rawList = args['destinatarios'];
        if (rawList == null || rawList is! List || (rawList).isEmpty) {
          return err('O campo "destinatarios" é obrigatório e deve ser uma lista.');
        }
        final list = rawList;
        if (list.length > 15) {
          return err(
              'Limite de 15 destinatários por chamada excedido (recebido: ${list.length}).');
        }

        int enfileirados = 0;
        for (final item in list) {
          String email;
          String nome;
          if (item is String) {
            email = item.trim();
            nome = '';
          } else if (item is Map) {
            email = (item['email'] ?? '').toString().trim();
            nome = (item['nome'] ?? '').toString().trim();
          } else {
            continue;
          }
          if (email.isEmpty) continue;
          final corpoPersonalizado =
              nome.isNotEmpty ? corpo.replaceAll('{{nome}}', nome) : corpo;
          await _enqueueEmail(ctx, {
            'tipo': 'livre',
            'template': 'htmlMensagemLivre',
            'para': email,
            'assunto': assunto,
            'corpo': corpoPersonalizado,
            if (nome.isNotEmpty) 'nomePaciente': nome,
          });
          enfileirados++;
        }

        return ok({
          'enfileirados': enfileirados,
          'mensagem':
              '$enfileirados e-mail(s) enfileirado(s) em email_queue para envio via SendGrid.',
        });
      } catch (e) {
        return err('email_enviar_em_lote: $e');
      }
    },
  );
}

// ---------------------------------------------------------------------------
// §6.17 — WhatsApp Z-API
// ---------------------------------------------------------------------------

// 14. whatsapp_status
McpTool _whatsappStatus(McpContext ctx) {
  return McpTool(
    name: 'whatsapp_status',
    description:
        'Retorna o status da instância WhatsApp Z-API. '
        'Status real requer chamada server-side à Z-API (não disponível no cliente).',
    inputSchema: {
      'type': 'object',
      'properties': <String, dynamic>{},
      'required': <String>[],
    },
    handler: (args) async {
      try {
        return ok({
          'status': 'desconhecido',
          'nota':
              'O status real da instância Z-API requer uma chamada server-side '
              'com as credenciais da clínica. Esta verificação não está disponível '
              'no cliente por razões de segurança.',
        });
      } catch (e) {
        return err('whatsapp_status: $e');
      }
    },
  );
}

// 15. whatsapp_validar_numero
McpTool _whatsappValidarNumero(McpContext ctx) {
  return McpTool(
    name: 'whatsapp_validar_numero',
    description:
        'Normaliza e retorna informações sobre um número de telefone. '
        'A validação real (se o número tem WhatsApp ativo) requer chamada '
        'server-side à Z-API.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'telefone': {
          'type': 'string',
          'description': 'Número de telefone a validar.',
        },
      },
      'required': ['telefone'],
    },
    handler: (args) async {
      try {
        final telefone = args.str('telefone');
        if (telefone == null || telefone.isEmpty) {
          return err('O campo "telefone" é obrigatório.');
        }
        return ok({
          'telefone': _normalizePhone(telefone),
          'valido': null,
          'nota':
              'A validação real (se o número possui WhatsApp ativo) requer '
              'chamada server-side à Z-API com credenciais da clínica.',
        });
      } catch (e) {
        return err('whatsapp_validar_numero: $e');
      }
    },
  );
}

// 16. whatsapp_enviar_texto
McpTool _whatsappEnviarTexto(McpContext ctx) {
  return McpTool(
    name: 'whatsapp_enviar_texto',
    description:
        'Enfileira uma mensagem de texto WhatsApp em tb_conversas '
        '(tipo: texto) para envio via Z-API pelo servidor.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'telefone': {
          'type': 'string',
          'description': 'Número de telefone do destinatário.',
        },
        'mensagem': {
          'type': 'string',
          'description': 'Texto da mensagem a enviar.',
        },
        'delay': {
          'type': 'integer',
          'description': 'Delay em milissegundos antes do envio. Opcional.',
        },
      },
      'required': ['telefone', 'mensagem'],
    },
    handler: (args) async {
      try {
        final telefone = args.str('telefone');
        if (telefone == null || telefone.isEmpty) {
          return err('O campo "telefone" é obrigatório.');
        }
        final mensagem = args.str('mensagem');
        if (mensagem == null || mensagem.isEmpty) {
          return err('O campo "mensagem" é obrigatório.');
        }
        final telefoneNorm = _normalizePhone(telefone);
        final ref = await _writeWhatsapp(ctx, {
          'tipo': 'texto',
          'telefone': telefoneNorm,
          'mensagem': mensagem,
          if (args.intArg('delay') != null) 'delay': args.intArg('delay'),
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'telefone': telefoneNorm,
          'mensagem': 'Mensagem de texto WhatsApp enfileirada em tb_conversas.',
        });
      } catch (e) {
        return err('whatsapp_enviar_texto: $e');
      }
    },
  );
}

// 17. whatsapp_confirmar_consulta
McpTool _whatsappConfirmarConsulta(McpContext ctx) {
  return McpTool(
    name: 'whatsapp_confirmar_consulta',
    description:
        'Enfileira uma mensagem WhatsApp de confirmação de consulta em tb_conversas '
        '(tipo: confirmacao) com template formatado. Envio via Z-API pelo servidor.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'telefone': {
          'type': 'string',
          'description': 'Número de telefone do paciente.',
        },
        'nomePaciente': {
          'type': 'string',
          'description': 'Nome do paciente. Opcional.',
        },
        'data': {
          'type': 'string',
          'description': 'Data da consulta. Opcional.',
        },
        'hora': {
          'type': 'string',
          'description': 'Horário da consulta. Opcional.',
        },
        'medico': {
          'type': 'string',
          'description': 'Nome do médico. Opcional.',
        },
      },
      'required': ['telefone'],
    },
    handler: (args) async {
      try {
        final telefone = args.str('telefone');
        if (telefone == null || telefone.isEmpty) {
          return err('O campo "telefone" é obrigatório.');
        }
        final telefoneNorm = _normalizePhone(telefone);
        final nome = args.str('nomePaciente') ?? 'Paciente';
        final data = args.str('data') ?? '';
        final hora = args.str('hora') ?? '';
        final medico = args.str('medico') ?? '';

        final sb = StringBuffer();
        sb.writeln('Olá, $nome! 👋');
        sb.writeln();
        sb.writeln('Confirmamos sua consulta:');
        if (data.isNotEmpty) sb.writeln('📅 Data: $data');
        if (hora.isNotEmpty) sb.writeln('🕐 Horário: $hora');
        if (medico.isNotEmpty) sb.writeln('👨‍⚕️ Médico: $medico');
        sb.writeln();
        sb.writeln('Caso precise reagendar ou cancelar, entre em contato conosco.');

        final ref = await _writeWhatsapp(ctx, {
          'tipo': 'confirmacao',
          'telefone': telefoneNorm,
          'mensagem': sb.toString().trim(),
          if (args.str('nomePaciente') != null)
            'nomePaciente': args.str('nomePaciente'),
          if (data.isNotEmpty) 'data': data,
          if (hora.isNotEmpty) 'hora': hora,
          if (medico.isNotEmpty) 'medico': medico,
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'telefone': telefoneNorm,
          'mensagem': 'Confirmação de consulta enfileirada em tb_conversas.',
        });
      } catch (e) {
        return err('whatsapp_confirmar_consulta: $e');
      }
    },
  );
}

// 18. whatsapp_lembrete_consulta
McpTool _whatsappLembreteConsulta(McpContext ctx) {
  return McpTool(
    name: 'whatsapp_lembrete_consulta',
    description:
        'Enfileira uma mensagem WhatsApp de lembrete de consulta em tb_conversas '
        '(tipo: lembrete) com template formatado. Envio via Z-API pelo servidor.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'telefone': {
          'type': 'string',
          'description': 'Número de telefone do paciente.',
        },
        'nomePaciente': {
          'type': 'string',
          'description': 'Nome do paciente. Opcional.',
        },
        'data': {
          'type': 'string',
          'description': 'Data da consulta. Opcional.',
        },
        'hora': {
          'type': 'string',
          'description': 'Horário da consulta. Opcional.',
        },
      },
      'required': ['telefone'],
    },
    handler: (args) async {
      try {
        final telefone = args.str('telefone');
        if (telefone == null || telefone.isEmpty) {
          return err('O campo "telefone" é obrigatório.');
        }
        final telefoneNorm = _normalizePhone(telefone);
        final nome = args.str('nomePaciente') ?? 'Paciente';
        final data = args.str('data') ?? '';
        final hora = args.str('hora') ?? '';

        final sb = StringBuffer();
        sb.writeln('Olá, $nome! 🔔');
        sb.writeln();
        sb.writeln('Este é um lembrete da sua consulta:');
        if (data.isNotEmpty) sb.writeln('📅 Data: $data');
        if (hora.isNotEmpty) sb.writeln('🕐 Horário: $hora');
        sb.writeln();
        sb.writeln('Contamos com sua presença!');

        final ref = await _writeWhatsapp(ctx, {
          'tipo': 'lembrete',
          'telefone': telefoneNorm,
          'mensagem': sb.toString().trim(),
          if (args.str('nomePaciente') != null)
            'nomePaciente': args.str('nomePaciente'),
          if (data.isNotEmpty) 'data': data,
          if (hora.isNotEmpty) 'hora': hora,
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'telefone': telefoneNorm,
          'mensagem': 'Lembrete de consulta enfileirado em tb_conversas.',
        });
      } catch (e) {
        return err('whatsapp_lembrete_consulta: $e');
      }
    },
  );
}

// 19. whatsapp_aviso_overbooking
McpTool _whatsappAvisoOverbooking(McpContext ctx) {
  return McpTool(
    name: 'whatsapp_aviso_overbooking',
    description:
        'Enfileira uma mensagem WhatsApp de aviso de overbooking/realocação '
        'em tb_conversas (tipo: overbooking). Envio via Z-API pelo servidor.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'telefone': {
          'type': 'string',
          'description': 'Número de telefone do paciente.',
        },
        'nomePaciente': {
          'type': 'string',
          'description': 'Nome do paciente. Opcional.',
        },
        'link': {
          'type': 'string',
          'description': 'Link para reagendamento. Opcional.',
        },
      },
      'required': ['telefone'],
    },
    handler: (args) async {
      try {
        final telefone = args.str('telefone');
        if (telefone == null || telefone.isEmpty) {
          return err('O campo "telefone" é obrigatório.');
        }
        final telefoneNorm = _normalizePhone(telefone);
        final nome = args.str('nomePaciente') ?? 'Paciente';
        final link = args.str('link') ?? '';

        final sb = StringBuffer();
        sb.writeln('Olá, $nome!');
        sb.writeln();
        sb.writeln(
            'Informamos que ocorreu uma alteração na sua consulta agendada. '
            'Precisamos reagendá-la para um novo horário.');
        if (link.isNotEmpty) {
          sb.writeln();
          sb.writeln('Utilize o link abaixo para selecionar um novo horário:');
          sb.writeln(link);
        }
        sb.writeln();
        sb.writeln('Pedimos desculpas pelo inconveniente. Contamos com sua compreensão!');

        final ref = await _writeWhatsapp(ctx, {
          'tipo': 'overbooking',
          'telefone': telefoneNorm,
          'mensagem': sb.toString().trim(),
          if (args.str('nomePaciente') != null)
            'nomePaciente': args.str('nomePaciente'),
          if (link.isNotEmpty) 'link': link,
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'telefone': telefoneNorm,
          'mensagem': 'Aviso de overbooking enfileirado em tb_conversas.',
        });
      } catch (e) {
        return err('whatsapp_aviso_overbooking: $e');
      }
    },
  );
}

// 20. whatsapp_enviar_lista_confirmacao
McpTool _whatsappEnviarListaConfirmacao(McpContext ctx) {
  return McpTool(
    name: 'whatsapp_enviar_lista_confirmacao',
    description:
        'Enfileira uma mensagem WhatsApp com lista de botões de confirmação '
        '(Sim / Reagendar / Cancelar) em tb_conversas (tipo: button-list). '
        'Envio via Z-API pelo servidor.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'telefone': {
          'type': 'string',
          'description': 'Número de telefone do paciente.',
        },
        'nomePaciente': {
          'type': 'string',
          'description': 'Nome do paciente. Opcional.',
        },
      },
      'required': ['telefone'],
    },
    handler: (args) async {
      try {
        final telefone = args.str('telefone');
        if (telefone == null || telefone.isEmpty) {
          return err('O campo "telefone" é obrigatório.');
        }
        final telefoneNorm = _normalizePhone(telefone);
        final nome = args.str('nomePaciente') ?? 'Paciente';

        final ref = await _writeWhatsapp(ctx, {
          'tipo': 'button-list',
          'telefone': telefoneNorm,
          'mensagem':
              'Olá, $nome! Você confirma sua consulta? Selecione uma das opções abaixo.',
          'botoes': ['Sim', 'Reagendar', 'Cancelar'],
          if (args.str('nomePaciente') != null)
            'nomePaciente': args.str('nomePaciente'),
        });
        return ok({
          'enfileirado': true,
          'id': ref.id,
          'telefone': telefoneNorm,
          'botoes': ['Sim', 'Reagendar', 'Cancelar'],
          'mensagem': 'Lista de confirmação WhatsApp enfileirada em tb_conversas.',
        });
      } catch (e) {
        return err('whatsapp_enviar_lista_confirmacao: $e');
      }
    },
  );
}

// 21. whatsapp_enviar_em_lote
McpTool _whatsappEnviarEmLote(McpContext ctx) {
  return McpTool(
    name: 'whatsapp_enviar_em_lote',
    description:
        'Enfileira uma mensagem WhatsApp para cada destinatário em tb_conversas '
        '(tipo: texto). Substitui {{nome}} pelo nome quando disponível. '
        'Máximo de 20 destinatários por chamada.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'destinatarios': {
          'type': 'array',
          'description':
              'Lista de telefones (strings) ou objetos {telefone, nome}. '
              'Máximo 20 itens.',
          'items': {
            'oneOf': [
              {'type': 'string'},
              {
                'type': 'object',
                'properties': {
                  'telefone': {'type': 'string'},
                  'nome': {'type': 'string'},
                },
                'required': ['telefone'],
              },
            ],
          },
        },
        'mensagem': {
          'type': 'string',
          'description':
              'Texto da mensagem. Use {{nome}} para personalização por destinatário.',
        },
      },
      'required': ['destinatarios', 'mensagem'],
    },
    handler: (args) async {
      try {
        final mensagemTemplate = args.str('mensagem');
        if (mensagemTemplate == null || mensagemTemplate.isEmpty) {
          return err('O campo "mensagem" é obrigatório.');
        }

        final rawList = args['destinatarios'];
        if (rawList == null || rawList is! List || (rawList).isEmpty) {
          return err('O campo "destinatarios" é obrigatório e deve ser uma lista.');
        }
        final list = rawList;
        if (list.length > 20) {
          return err(
              'Limite de 20 destinatários por chamada excedido (recebido: ${list.length}).');
        }

        int enviados = 0;
        for (final item in list) {
          String telefone;
          String nome;
          if (item is String) {
            telefone = item.trim();
            nome = '';
          } else if (item is Map) {
            telefone = (item['telefone'] ?? '').toString().trim();
            nome = (item['nome'] ?? '').toString().trim();
          } else {
            continue;
          }
          if (telefone.isEmpty) continue;
          final telefoneNorm = _normalizePhone(telefone);
          final mensagemPersonalizada = nome.isNotEmpty
              ? mensagemTemplate.replaceAll('{{nome}}', nome)
              : mensagemTemplate;
          await _writeWhatsapp(ctx, {
            'tipo': 'texto',
            'telefone': telefoneNorm,
            'mensagem': mensagemPersonalizada,
            if (nome.isNotEmpty) 'nomePaciente': nome,
          });
          enviados++;
        }

        return ok({
          'enviados': enviados,
          'mensagem':
              '$enviados mensagem(ns) WhatsApp enfileirada(s) em tb_conversas.',
        });
      } catch (e) {
        return err('whatsapp_enviar_em_lote: $e');
      }
    },
  );
}
