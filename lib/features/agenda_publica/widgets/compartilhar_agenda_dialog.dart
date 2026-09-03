import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/models/doctor.dart';
import '../../../core/utils/platform_share.dart';
import '../../totem/models/totem_config.dart';

/// Modal e Sistema de Compartilhamento da Agenda Pública.
class CompartilharAgendaDialog extends StatefulWidget {
  const CompartilharAgendaDialog({
    super.key,
    required this.doctor,
    required this.config,
    this.customUrl,
  });

  final Doctor doctor;
  final TotemConfig config;
  final String? customUrl;

  /// Método utilitário para exibir o modal de forma responsiva.
  static Future<void> show(
    BuildContext context, {
    required Doctor doctor,
    required TotemConfig config,
    String? customUrl,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CompartilharAgendaDialog(
        doctor: doctor,
        config: config,
        customUrl: customUrl,
      ),
    );
  }

  @override
  State<CompartilharAgendaDialog> createState() =>
      _CompartilharAgendaDialogState();
}

class _CompartilharAgendaDialogState extends State<CompartilharAgendaDialog> {
  bool _linkCopiado = false;
  bool _textoCopiado = false;
  bool _imprimindo = false;
  Timer? _timerLink;
  Timer? _timerTexto;

  String get _shareUrl {
    if (widget.customUrl != null && widget.customUrl!.trim().isNotEmpty) {
      return widget.customUrl!.trim();
    }
    final origin = getCurrentOrigin();
    final docId = widget.doctor.id;
    if (origin.isNotEmpty) {
      return '$origin/#/agenda-publica/$docId';
    }
    return 'https://vitta.app/#/agenda-publica/$docId';
  }

  String get _textoFormatado {
    final d = widget.doctor;
    final tc = widget.config;
    final specs = d.specialties.isEmpty ? '' : '\n📋 ${d.specialties.join(', ')}';
    final crm = d.crm.isEmpty ? '' : '\n🩺 CRM ${d.crm}';
    return 'Agende sua consulta com Dr(a). ${d.name} na ${tc.clinicName}:$specs$crm\n\n'
        '👉 Escolha a data e o horário pelo link:\n$_shareUrl';
  }

  @override
  void dispose() {
    _timerLink?.cancel();
    _timerTexto?.cancel();
    super.dispose();
  }

  Future<void> _copiarLink() async {
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    _timerLink?.cancel();
    if (mounted) {
      setState(() => _linkCopiado = true);
      _timerLink = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _linkCopiado = false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Link da agenda copiado para a área de transferência!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _copiarTextoCompleto() async {
    await Clipboard.setData(ClipboardData(text: _textoFormatado));
    _timerTexto?.cancel();
    if (mounted) {
      setState(() => _textoCopiado = true);
      _timerTexto = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _textoCopiado = false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Mensagem completa copiada com sucesso!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _compartilharWhatsApp() {
    final msg = Uri.encodeComponent(_textoFormatado);
    final waUrl = 'https://api.whatsapp.com/send?text=$msg';
    openExternalUrl(waUrl);
  }

  void _compartilharEmail() {
    final d = widget.doctor;
    final subject = Uri.encodeComponent('Agenda de Consultas - Dr(a). ${d.name}');
    final body = Uri.encodeComponent(
      'Olá,\n\n'
      'Você pode visualizar os horários disponíveis e agendar sua consulta diretamente com o(a) Dr(a). ${d.name} acessando o link abaixo:\n\n'
      '$_shareUrl\n\n'
      'Atenciosamente,\n'
      '${widget.config.clinicName}',
    );
    final mailtoUrl = 'mailto:?subject=$subject&body=$body';
    openExternalUrl(mailtoUrl);
  }

  Future<void> _compartilharNativo() async {
    final compartilhou = await tryNativeShare(
      title: 'Agenda de ${widget.doctor.name}',
      text: _textoFormatado,
      url: _shareUrl,
    );
    if (!compartilhou && mounted) {
      await _copiarLink();
    }
  }

  Future<void> _imprimirCartazPdf() async {
    if (_imprimindo) return;
    setState(() => _imprimindo = true);
    try {
      final doc = pw.Document();
      final doctor = widget.doctor;
      final config = widget.config;
      final url = _shareUrl;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context ctx) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              ),
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Cabeçalho da clínica
                  pw.Column(
                    children: [
                      pw.Text(
                        config.clinicName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800,
                          letterSpacing: 1.5,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        width: 80,
                        height: 3,
                        color: PdfColors.redAccent,
                      ),
                    ],
                  ),

                  // Dados do médico
                  pw.Column(
                    children: [
                      pw.Text(
                        'AGENDE SUA CONSULTA ONLINE',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        doctor.name,
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      if (doctor.specialties.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          doctor.specialties.join(' • '),
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                      if (doctor.crm.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'CRM ${doctor.crm}',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // QR Code Central
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(12)),
                      color: PdfColors.white,
                    ),
                    child: pw.Column(
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: url,
                          width: 180,
                          height: 180,
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'Aponte a câmera do seu celular',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Link textual e rodapé
                  pw.Column(
                    children: [
                      pw.Text(
                        'Ou acesse diretamente pelo endereço:',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        url,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        'Vitta Care • Sistema de Gestão e Atendimento Clínico',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        name: 'cartaz-agenda-${widget.doctor.id}',
        onLayout: (_) => doc.save(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível gerar a impressão do cartaz.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _imprimindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.config.accentColor;
    final doctor = widget.doctor;
    final tc = widget.config;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho estilizado
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.12),
                      Colors.white,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.share_rounded, color: accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Compartilhar Agenda',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF11151C),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dr(a). ${doctor.name} • ${tc.clinicName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Corpo do diálogo (Scrollable)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Seção: Link direto
                      const Text(
                        'LINK DIRETO DA PÁGINA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link, size: 20, color: Colors.grey),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SelectableText(
                                _shareUrl,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _copiarLink,
                              style: FilledButton.styleFrom(
                                backgroundColor: _linkCopiado
                                    ? const Color(0xFF2E9E5B)
                                    : accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: Icon(
                                _linkCopiado ? Icons.check : Icons.copy,
                                size: 16,
                              ),
                              label: Text(
                                _linkCopiado ? 'Copiado!' : 'Copiar',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Seção: Canais de compartilhamento
                      const Text(
                        'ENVIAR DIRETAMENTE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          // WhatsApp
                          OutlinedButton.icon(
                            onPressed: _compartilharWhatsApp,
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Color(0xFF25D366),
                              size: 18,
                            ),
                            label: const Text(
                              'WhatsApp',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF128C7E),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF25D366).withValues(alpha: 0.08),
                              side: const BorderSide(color: Color(0xFF25D366)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          // E-mail
                          OutlinedButton.icon(
                            onPressed: _compartilharEmail,
                            icon: Icon(
                              Icons.mail_outline_rounded,
                              color: accent,
                              size: 18,
                            ),
                            label: Text(
                              'E-mail',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: accent.withValues(alpha: 0.08),
                              side: BorderSide(color: accent),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          // Copiar Mensagem Completa
                          OutlinedButton.icon(
                            onPressed: _copiarTextoCompleto,
                            icon: Icon(
                              _textoCopiado
                                  ? Icons.check_circle
                                  : Icons.text_snippet_outlined,
                              color: _textoCopiado
                                  ? const Color(0xFF2E9E5B)
                                  : const Color(0xFF475569),
                              size: 18,
                            ),
                            label: Text(
                              _textoCopiado
                                  ? 'Mensagem Copiada!'
                                  : 'Copiar Mensagem Formatada',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _textoCopiado
                                    ? const Color(0xFF2E9E5B)
                                    : const Color(0xFF334155),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          // Nativo / Mais Opções
                          OutlinedButton.icon(
                            onPressed: _compartilharNativo,
                            icon: const Icon(
                              Icons.share_outlined,
                              size: 18,
                              color: Color(0xFF475569),
                            ),
                            label: const Text(
                              'Mais Opções',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF334155),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Seção: QR Code & Impressão
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.18)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Moldura do QR Code
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color:
                                        Colors.grey.withValues(alpha: 0.2)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: _shareUrl,
                                version: QrVersions.auto,
                                size: 120,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: accent,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF11151C),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'QR Code da Agenda',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF11151C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Aponte a câmera do celular para abrir esta agenda diretamente, ou imprima um cartaz profissional para a recepção da clínica.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: _imprimindo
                                        ? null
                                        : _imprimirCartazPdf,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: _imprimindo
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.print_outlined,
                                            size: 16),
                                    label: Text(
                                      _imprimindo
                                          ? 'Gerando...'
                                          : 'Imprimir Cartaz A4 (PDF)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Rodapé do Diálogo
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Link público sem necessidade de login',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Concluir',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
