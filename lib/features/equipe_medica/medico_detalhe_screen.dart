import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/appointment.dart';
import '../../core/models/doctor.dart';
import '../../core/models/enums.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/next_appointments_carousel.dart';
import '../../core/widgets/section_header.dart';
import '../../navigation/app_router.dart';
import 'medico_form_screen.dart';

/// Detalhe do médico com estatísticas, ativação/desativação e exclusão lógica
/// (EM-05, EM-06, EM-08).
class MedicoDetalheScreen extends ConsumerWidget {
  const MedicoDetalheScreen({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final matches =
        ref.watch(clinicDoctorsProvider).where((d) => d.id == doctorId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Médico')),
        body: const EmptyView(
            icon: Icons.badge_outlined, message: 'Médico não encontrado.'),
      );
    }
    final d = matches.first;

    // Consultas reais deste médico (cross-clínica, tempo real via idMedico).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final doctorAppointments =
        ref.watch(doctorAgendaProvider(d.id)).valueOrNull ??
            const <Appointment>[];
    final futureAppointments =
        doctorAppointments.where((a) => a.start.isAfter(now)).length;
    // Próximas consultas (não canceladas) para o carrossel da página.
    final upcoming = doctorAppointments
        .where((a) =>
            a.status != AppointmentStatus.cancelled &&
            !a.start.isBefore(today))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Médico'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MedicoFormScreen(doctorId: d.id),
            )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    AppAvatar(
                      initials: d.initials,
                      imageUrl: d.photoUrl,
                      imageBytes: d.photoBytes,
                      radius: 32,
                      color:
                          d.active ? AppColors.primary : AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name, style: theme.textTheme.titleLarge),
                          Text('CRM ${d.crm}',
                              style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md, vertical: 4),
                            decoration: BoxDecoration(
                              color: d.active
                                  ? AppColors.successLight
                                  : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusPill),
                            ),
                            child: Text(
                              d.active ? 'Ativo' : 'Inativo',
                              style: TextStyle(
                                color: d.active
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xl),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in d.specialties)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                        child: Text(s,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: AppColors.primaryDark)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Carrossel com as próximas consultas do médico.
          if (upcoming.isNotEmpty) ...[
            NextAppointmentsCarousel(
              appointments: upcoming,
              onTapAppointment: (id) =>
                  context.go(AppRoutes.appointmentDetail(id)),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Escala de atendimento (`scalaMedico`).
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.schedule, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Escala de atendimento',
                          style: theme.textTheme.titleMedium),
                      Text('Carga horária por dia de plantão',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text('${d.scaleHours}h',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Contato
          const SectionHeader(title: 'Contato', icon: Icons.contact_page_outlined),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                _row(context, Icons.email_outlined, 'E-mail', d.email ?? '—'),
                const SizedBox(height: AppSpacing.sm),
                _row(context, Icons.phone_outlined, 'Telefone', d.phone ?? '—'),
                const SizedBox(height: AppSpacing.sm),
                _row(context, Icons.location_on_outlined, 'Endereço',
                    d.address ?? '—'),
              ],
            ),
          ),

          if ((d.bio ?? '').isNotEmpty || (d.experience ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
                title: 'Sobre', icon: Icons.person_outline),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((d.bio ?? '').isNotEmpty) ...[
                    Text('Biografia',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(d.bio!, style: theme.textTheme.bodyMedium),
                  ],
                  if ((d.experience ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Experiência',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(d.experience!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Estatísticas (EM-05)
          const SectionHeader(title: 'Estatísticas', icon: Icons.bar_chart),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        value: '${d.monthlyConsultations}',
                        label: 'Consultas/mês',
                        color: AppColors.primary,
                        bg: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatBox(
                        value: '${(d.occupancyRate * 100).round()}%',
                        label: 'Ocupação média',
                        color: AppColors.secondary,
                        bg: AppColors.secondaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        value: '${(d.absenceRate * 100).round()}%',
                        label: 'Média de faltas',
                        color: AppColors.danger,
                        bg: AppColors.dangerLight,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatBox(
                        value: 'R\$ ${d.ticket.toStringAsFixed(0)}',
                        label: 'Ticket',
                        color: AppColors.warning,
                        bg: AppColors.warningLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Gráficos de desempenho (ajudam a leitura do perfil do médico).
          const SectionHeader(title: 'Desempenho', icon: Icons.insights),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                // Ocupação x faltas (donut duplo lado a lado).
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          DonutChart(
                            percent: (d.occupancyRate * 100).clamp(0, 100),
                            color: AppColors.secondary,
                            size: 120,
                            centerLabel: 'Ocupação',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Taxa de ocupação',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          DonutChart(
                            percent: (d.absenceRate * 100).clamp(0, 100),
                            color: AppColors.danger,
                            size: 120,
                            centerLabel: 'Faltas',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Média de faltas',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Consultas nos últimos 6 meses',
                      style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: AppSpacing.md),
                SimpleLineChart(
                  data: _monthlyConsultationSeries(d, doctorAppointments),
                  height: 180,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Agenda em tempo real deste médico — só as consultas dele (EM-05/PM-09).
          AppCard(
            onTap: () => context.push(AppRoutes.agendaMedicoPath(d.id)),
            child: Row(
              children: [
                const Icon(Icons.event_note_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ver agenda em tempo real',
                          style: theme.textTheme.titleMedium),
                      Text('Somente as consultas deste profissional',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // QR Code para a agenda pública (qualquer pessoa acessa sem login).
          _AgendaQrCard(doctorId: d.id),
          const SizedBox(height: AppSpacing.xl),

          // Ações: ativar/desativar (EM-06) e excluir (EM-08)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: d.active ? AppColors.warning : AppColors.success,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () =>
                _toggleActive(context, ref, d, futureAppointments),
            icon: Icon(d.active
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline),
            label: Text(d.active ? 'Desativar médico' : 'Reativar médico'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (d.active)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => _delete(context, ref, d, futureAppointments),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir médico'),
            ),
        ],
      ),
    );
  }

  /// Consultas por mês nos últimos 6 meses, agregadas dos agendamentos reais do
  /// médico (`tb_agendamentos`, exceto cancelados). Quando não há histórico
  /// nesse período, cai para uma série determinística baseada nas estatísticas.
  List<TimeSeriesPoint> _monthlyConsultationSeries(
      Doctor d, List<Appointment> appointments) {
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago',
        'Set', 'Out', 'Nov', 'Dez'];
    final now = DateTime.now();

    // Contagem real por (ano, mês).
    final counts = <String, int>{};
    for (final a in appointments) {
      if (a.status == AppointmentStatus.cancelled) continue;
      counts['${a.start.year}-${a.start.month}'] =
          (counts['${a.start.year}-${a.start.month}'] ?? 0) + 1;
    }

    final real = [
      for (var i = 5; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i, 1);
          return TimeSeriesPoint(
            months[m.month - 1],
            (counts['${m.year}-${m.month}'] ?? 0).toDouble(),
          );
        }(),
    ];

    // Se há qualquer consulta real no período, usa os dados reais.
    if (real.any((p) => p.value > 0)) return real;

    // Fallback determinístico (sem histórico ainda).
    final base = d.monthlyConsultations > 0 ? d.monthlyConsultations : 40;
    final seed = d.id.hashCode.abs();
    return [
      for (var i = 5; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i, 1);
          final factor = i == 0 ? 1.0 : 1 - (((seed >> i) % 26) / 100);
          return TimeSeriesPoint(
            months[m.month - 1],
            (base * factor).roundToDouble(),
          );
        }(),
    ];
  }

  Widget _row(BuildContext c, IconData icon, String label, String value) {
    final t = Theme.of(c).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        Flexible(
          child: Text(value,
              style: t.bodyMedium, textAlign: TextAlign.right, maxLines: 2),
        ),
      ],
    );
  }

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, Doctor d, int futureCount) async {
    final deactivating = d.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(deactivating ? 'Desativar médico?' : 'Reativar médico?'),
        content: Text(deactivating
            ? '${d.name} não aparecerá em novas seleções de agendamento.'
                '${futureCount > 0 ? '\n\nAtenção: há $futureCount agendamento(s) futuro(s) para este médico.' : ''}'
            : '${d.name} voltará a aparecer nas seleções de agendamento.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(clinicDoctorsProvider.notifier).setActive(d.id, !d.active);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(deactivating
                ? 'Médico desativado.'
                : 'Médico reativado.')));
      }
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Doctor d, int futureCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir médico?'),
        content: Text(
            'Esta ação faz uma exclusão lógica — o cadastro é preservado para '
            'manter a integridade dos agendamentos.'
            '${futureCount > 0 ? '\n\n${d.name} possui $futureCount agendamento(s) futuro(s).' : ''}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(clinicDoctorsProvider.notifier).softDelete(d.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Médico excluído (desativado).')));
        Navigator.of(context).pop();
      }
    }
  }
}

/// Card com QR Code da agenda pública do médico (acessível sem login).
class _AgendaQrCard extends StatelessWidget {
  const _AgendaQrCard({required this.doctorId});
  final String doctorId;

  /// URL absoluta da agenda pública. O app usa hash-routing (`/#/rota`), então
  /// prefixamos a origem atual + `#` ao caminho da rota.
  String get _url {
    final base = Uri.base;
    final origin =
        (base.hasScheme && base.host.isNotEmpty) ? base.origin : '';
    return '$origin/#${AppRoutes.agendaMedicoPath(doctorId)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = _url;
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Agenda pública', style: theme.textTheme.titleMedium),
                    Text('Escaneie para abrir a agenda em tempo real',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: QrImageView(
              data: url,
              version: QrVersions.auto,
              size: 180,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(url,
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copiado.')));
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar link'),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
    required this.bg,
  });

  final String value;
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.headlineSmall?.copyWith(color: color)),
          Text(label,
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
