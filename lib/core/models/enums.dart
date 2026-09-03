import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tipo da unidade de saúde (H-02 / PC-01).
enum ClinicType {
  ubs('UBS', 'Unidade Básica de Saúde', AppColors.ubs),
  upa('UPA', 'Unidade de Pronto Atendimento', AppColors.upa),
  aps('APS', 'Atenção Primária à Saúde', AppColors.aps),
  privada('Privada', 'Clínica Privada', AppColors.privada);

  const ClinicType(this.label, this.description, this.color);

  final String label;
  final String description;
  final Color color;

  /// Apenas clínicas privadas têm acesso a recursos B2B de IA (IA-01).
  bool get isB2B => this == ClinicType.privada;

  static ClinicType fromString(String? value) {
    return ClinicType.values.firstWhere(
      (t) => t.name == value || t.label.toLowerCase() == value?.toLowerCase(),
      orElse: () => ClinicType.ubs,
    );
  }
}

/// Status de um agendamento. Mapeia o campo `status` de `tb_agendamentos`.
enum AppointmentStatus {
  confirmed('Confirmado', AppColors.success, AppColors.successLight, Icons.check_circle),
  pending('Pré-agendado', AppColors.warning, AppColors.warningLight, Icons.schedule),
  cancelled('Cancelado', AppColors.danger, AppColors.dangerLight, Icons.cancel),
  noShow('Falta', AppColors.danger, AppColors.dangerLight, Icons.person_off),
  completed('Atendido', AppColors.secondary, AppColors.secondaryLight, Icons.task_alt);

  const AppointmentStatus(this.label, this.color, this.background, this.icon);

  final String label;
  final Color color;
  final Color background;
  final IconData icon;

  static AppointmentStatus fromString(String? value) {
    // Normaliza (trim + minúsculas) e cobre os rótulos gravados em
    // `tb_agendamentos`/Cloud Functions.
    //
    // Sinônimos de `completed` foram expandidos para cobrir variações clínicas
    // reais que chegam do Firestore (`finalizado`, `compareceu`, `presente`,
    // etc.). Sem esses mapeamentos, todos os atendimentos sem baixa manual
    // explícita caíam no default `pending`, zerando a contagem de `realizados`
    // e bloqueando a calibração de Monte Carlo (problema #1 da tela Calibração).
    switch (value?.toLowerCase().trim()) {
      case 'confirmado':
      case 'confirmed':
      // `agendado`/`scheduled` indicam consulta marcada — equivalente a
      // `confirmed` para fins de rastreamento de desfecho.
      case 'agendado':
      case 'scheduled':
        return AppointmentStatus.confirmed;
      case 'cancelado':
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'falta':
      case 'faltou':
      case 'no_show':
      case 'noshow':
      case 'no-show':
        return AppointmentStatus.noShow;
      // Sinônimos de "consulta realizada" — expandido em 2026-09-02 para cobrir
      // variações registradas por diferentes fluxos de clínica. O campo `status`
      // de `tb_agendamentos` não tem enum fixo; cada integração pode gravar um
      // rótulo ligeiramente diferente.
      case 'atendido':
      case 'completed':
      case 'realizado':
      case 'concluido':
      case 'concluído':
      case 'finalizado':
      case 'finalizada':
      case 'compareceu':
      case 'presente':
      case 'atendida':
      case 'concluida':
        return AppointmentStatus.completed;
      case 'pre-agendado':
      case 'pré-agendado':
      case 'pre_agendado':
      case 'pendente':
      case 'reagendado':
      case 'pending':
        return AppointmentStatus.pending;
      default:
        return AppointmentStatus.pending;
    }
  }

  /// Rótulo canônico gravado no campo `status` de `tb_agendamentos` — **inverso
  /// de [fromString]**. Fonte única para escrita (serviços/Cloud Functions),
  /// evitando divergência entre as várias camadas (ver `VARREDURA_QA` R6).
  String get apiLabel => switch (this) {
        AppointmentStatus.confirmed => 'confirmado',
        AppointmentStatus.cancelled => 'cancelado',
        AppointmentStatus.noShow => 'faltou',
        AppointmentStatus.completed => 'realizado',
        AppointmentStatus.pending => 'pre-agendado',
      };
}

/// Nível de risco de absenteísmo calculado por IA (AB-06).
enum RiskLevel {
  low('Baixo', AppColors.success, AppColors.successLight),
  medium('Médio', AppColors.warning, AppColors.warningLight),
  high('Alto', AppColors.danger, AppColors.dangerLight);

  const RiskLevel(this.label, this.color, this.background);

  final String label;
  final Color color;
  final Color background;

  static RiskLevel fromScore(double score) {
    if (score >= 0.66) return RiskLevel.high;
    if (score >= 0.33) return RiskLevel.medium;
    return RiskLevel.low;
  }

  /// Converte o rótulo gravado em `tb_faltas_data.risco_falta` (ou em campo
  /// denormalizado no agendamento) para a faixa.
  ///
  /// Devolve `null` quando não reconhece — de propósito. Cair em `low` por
  /// omissão faria todo paciente parecer de baixo risco, que é exatamente o
  /// modo de falha silenciosa que a estratificação deve evitar.
  static RiskLevel? fromString(String? v) {
    final t = v?.trim().toLowerCase();
    if (t == null || t.isEmpty) return null;
    return switch (t) {
      'low' || 'baixo' || 'baixa' || 'l' => RiskLevel.low,
      'medium' || 'medio' || 'médio' || 'media' || 'média' || 'm' =>
        RiskLevel.medium,
      'high' || 'alto' || 'alta' || 'h' => RiskLevel.high,
      _ => null,
    };
  }
}

/// Status da conexão WhatsApp via Z-API (WA-02).
enum WhatsappStatus {
  connected('Conectado', AppColors.success),
  disconnected('Desconectado', AppColors.danger),
  reconnecting('Reconectando', AppColors.warning);

  const WhatsappStatus(this.label, this.color);

  final String label;
  final Color color;
}
