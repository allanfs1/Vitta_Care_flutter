import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../navigation/app_router.dart';
import '../../../tarefas_agendadas/schedule_util.dart';
import '../../../tarefas_agendadas/scheduled_tasks_service.dart';
import '../../data/models/nota.dart';
import '../../services/rotina_preventiva_service.dart';

/// Card interativo que exibe a análise de problemas da nota
/// e permite tanto AGENDAR quanto EXECUTAR IMEDIATAMENTE medidas preventivas por IA.
class CardRotinaPreventiva extends ConsumerStatefulWidget {
  const CardRotinaPreventiva({
    super.key,
    required this.nota,
    this.aoAgendarSucesso,
  });

  final Nota nota;
  final VoidCallback? aoAgendarSucesso;

  @override
  ConsumerState<CardRotinaPreventiva> createState() =>
      _CardRotinaPreventivaState();
}

class _CardRotinaPreventivaState extends ConsumerState<CardRotinaPreventiva> {
  late SugestaoRotina _sugestao;
  bool _salvando = false;
  bool _executandoAgora = false;
  bool _agendadaComSucesso = false;
  ResultadoExecucaoImediata? _resultadoImediato;
  bool _expandido = true;

  @override
  void initState() {
    super.initState();
    _sugestao = const RotinaPreventivaService().analisar(widget.nota);
  }

  void _alterarFrequencia(String tipo, TaskSchedule schedule, String label) {
    setState(() {
      _sugestao = _sugestao.copyWith(
        schedule: schedule,
        frequenciaLabel: label,
      );
    });
  }

  Future<void> _executarImediatamente() async {
    setState(() {
      _executandoAgora = true;
    });

    try {
      final res =
          await const RotinaPreventivaService().executarAcaoImediata(_sugestao);
      if (!mounted) return;
      setState(() {
        _executandoAgora = false;
        _resultadoImediato = res;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _executandoAgora = false;
      });
    }
  }

  Future<void> _agendarRotina() async {
    setState(() {
      _salvando = true;
    });

    try {
      final clinicaId = ref.read(tarefasClinicaIdProvider);
      final idEfetivo = clinicaId.isNotEmpty ? clinicaId : 'clinica-padrao';

      await ref.read(scheduledTasksServiceProvider).create(
            titulo: _sugestao.titulo,
            descricao: _sugestao.descricao,
            prompt: _sugestao.prompt,
            kind: _sugestao.kind,
            schedule: _sugestao.schedule,
            clinicaId: idEfetivo,
            createdBy: 'Cérebro - Agente IA',
          );

      if (!mounted) return;
      setState(() {
        _salvando = false;
        _agendadaComSucesso = true;
      });
      widget.aoAgendarSucesso?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _agendadaComSucesso = true;
      });
      widget.aoAgendarSucesso?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1B4B).withValues(alpha: 0.5)
            : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho da Sugestão
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(AppSpacing.radiusMd),
              bottom: Radius.circular(_expandido ? 0 : AppSpacing.radiusMd),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'MEDIDA PREVENTIVA IA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _sugestao.kind == 'action'
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _sugestao.kind == 'action'
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _sugestao.kind == 'action'
                          ? '⚡ Ação Automática'
                          : '📊 Relatório Periódico',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _sugestao.kind == 'action'
                            ? const Color(0xFFD97706)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),

          if (_expandido) ...[
            const Divider(height: 1, color: Color(0xFF8B5CF6)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _resultadoImediato != null
                  ? _buildResultadoExecucao(context)
                  : (_agendadaComSucesso
                      ? _buildSucesso(context)
                      : _buildConteudoSugestao(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConteudoSugestao(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Diagnóstico do Problema
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Color(0xFFF59E0B)),
            const SizedBox(width: 6),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textPrimaryOf(context),
                    height: 1.35,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Problema / Ponto de Atenção: ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: _sugestao.problemaDetectado),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Título e Descrição da Rotina Sugerida
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_sugestao.icone, size: 14, color: const Color(0xFF8B5CF6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _sugestao.titulo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _sugestao.prompt,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Seletor Rápido de Frequência
        Row(
          children: [
            Text(
              'Recorrência:',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 6),
            Wrap(
              spacing: 4,
              children: [
                _ChipFrequencia(
                  rotulo: 'Diário (07:30)',
                  ativo: _sugestao.schedule.type == 'daily',
                  aoClicar: () => _alterarFrequencia(
                    'daily',
                    const TaskSchedule(type: 'daily', time: '07:30'),
                    'Diário às 07:30 (BRT)',
                  ),
                ),
                _ChipFrequencia(
                  rotulo: 'Semanal (Seg 08:00)',
                  ativo: _sugestao.schedule.type == 'weekly',
                  aoClicar: () => _alterarFrequencia(
                    'weekly',
                    const TaskSchedule(
                        type: 'weekly', weekdays: [1], time: '08:00'),
                    'Semanal (Segunda às 08:00)',
                  ),
                ),
                _ChipFrequencia(
                  rotulo: 'A cada 2h',
                  ativo: _sugestao.schedule.type == 'interval',
                  aoClicar: () => _alterarFrequencia(
                    'interval',
                    const TaskSchedule(
                        type: 'interval', intervalMinutes: 120),
                    'A cada 2 horas',
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Impacto Estimado e Botões de Ação
        Row(
          children: [
            const Icon(Icons.trending_up, size: 14, color: Color(0xFF10B981)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _sugestao.impactoEstimado,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF059669),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Botão Executar Ação Agora (1-Clique)
            OutlinedButton.icon(
              onPressed: (_executandoAgora || _salvando)
                  ? null
                  : _executarImediatamente,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _executandoAgora
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF8B5CF6),
                      ),
                    )
                  : const Icon(Icons.bolt, size: 14),
              label: Text(
                _executandoAgora ? 'Executando...' : 'Executar Agora',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),

            // Botão Agendar Rotina
            FilledButton.icon(
              onPressed: (_salvando || _executandoAgora) ? null : _agendarRotina,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _salvando
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.schedule_send, size: 14),
              label: Text(
                _salvando ? 'Agendando...' : 'Agendar Rotina',
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultadoExecucao(BuildContext context) {
    final res = _resultadoImediato!;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 18, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  res.resumo,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6D28D9),
                  ),
                ),
              ),
              Text(
                '${res.pacientesImpactados} pacientes',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final d in res.detalhes)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _resultadoImediato = null),
                child: const Text('Voltar', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: _agendarRotina,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.schedule, size: 12),
                label: const Text('Também Agendar como Rotina Recorrente',
                    style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSucesso(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 20, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rotina preventiva agendada com sucesso!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
                Text(
                  'A tarefa já está ativa em /tarefas-agendadas com recorrência ${_sugestao.frequenciaLabel}.',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.go(AppRoutes.tarefasAgendadas);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.arrow_outward, size: 13),
            label: const Text(
              'Ver em Tarefas Agendadas',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipFrequencia extends StatelessWidget {
  const _ChipFrequencia({
    required this.rotulo,
    required this.ativo,
    required this.aoClicar,
  });

  final String rotulo;
  final bool ativo;
  final VoidCallback aoClicar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: aoClicar,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ativo
              ? const Color(0xFF8B5CF6)
              : AppColors.surfaceOf(context).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: ativo
                ? const Color(0xFF8B5CF6)
                : AppColors.borderOf(context),
          ),
        ),
        child: Text(
          rotulo,
          style: TextStyle(
            fontSize: 10,
            fontWeight: ativo ? FontWeight.w700 : FontWeight.normal,
            color: ativo ? Colors.white : AppColors.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }
}
