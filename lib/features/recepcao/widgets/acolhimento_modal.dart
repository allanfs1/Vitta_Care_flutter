import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/care_line.dart';
import '../models/manchester_priority.dart';
import '../models/vital_signs.dart';
import '../recepcao_provider.dart';

const _kBrandRed = Color(0xFFFF3B30);

/// Acolhimento com Classificação de Risco (ACCR) — formulário de entrada da
/// recepção de UBS/UPA/APS. Coleta vitais, classifica o risco (Manchester),
/// define a linha de cuidado, o tipo de demanda e o vínculo eSF.
class AcolhimentoModal extends ConsumerStatefulWidget {
  const AcolhimentoModal({super.key});

  @override
  ConsumerState<AcolhimentoModal> createState() => _AcolhimentoModalState();
}

class _AcolhimentoModalState extends ConsumerState<AcolhimentoModal> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _microarea = TextEditingController();
  final _acs = TextEditingController();

  // Vitais
  final _paSis = TextEditingController();
  final _paDia = TextEditingController();
  final _fc = TextEditingController();
  final _temp = TextEditingController();
  final _sat = TextEditingController();
  final _glicemia = TextEditingController();
  double _dor = 0;

  AttendanceType _attendance = AttendanceType.espontanea;
  CareLine _careLine = CareLine.geral;
  ManchesterPriority _manchester = ManchesterPriority.green;
  bool _manualPriority = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _microarea,
      _acs,
      _paSis,
      _paDia,
      _fc,
      _temp,
      _sat,
      _glicemia,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  VitalSigns _buildVitals() => VitalSigns(
        paSistolica: int.tryParse(_paSis.text),
        paDiastolica: int.tryParse(_paDia.text),
        fc: int.tryParse(_fc.text),
        temperatura: double.tryParse(_temp.text.replaceAll(',', '.')),
        satO2: int.tryParse(_sat.text),
        glicemia: int.tryParse(_glicemia.text),
        dor: _dor.round(),
      );

  /// Recalcula a sugestão de risco enquanto o profissional não fixa manualmente.
  void _recompute() {
    if (_manualPriority) return;
    setState(() => _manchester = _buildVitals().suggestedPriority);
  }

  static String _specialtyFor(CareLine line) => switch (line) {
        CareLine.geral => 'TRIAGEM GERAL',
        CareLine.preNatal => 'PRÉ-NATAL',
        CareLine.puericultura => 'PUERICULTURA',
        CareLine.hiperdia => 'HIPERDIA',
        CareLine.saudeMental => 'SAÚDE MENTAL',
      };

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(recepcaoProvider.notifier).checkInAcolhimento(
          name: _name.text,
          specialty: _specialtyFor(_careLine),
          manchester: _manchester,
          vitals: _buildVitals(),
          careLine: _careLine,
          attendanceType: _attendance,
          microarea: _microarea.text.trim(),
          acs: _acs.text.trim(),
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Acolhimento registrado: ${_name.text.trim()} (${_manchester.label}).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final suggestion = _buildVitals().suggestedPriority;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Container(
        width: screenWidth < 720 ? screenWidth * 0.92 : 680,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Acolhimento com Classificação de Risco',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Identificação
                _label(theme, 'NOME DO PACIENTE'),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _name,
                  decoration: _dec(theme, 'Ex: Maria das Dores'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Tipo de demanda + linha de cuidado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'TIPO DE DEMANDA'),
                          const SizedBox(height: AppSpacing.xs),
                          DropdownButtonFormField<AttendanceType>(
                            initialValue: _attendance,
                            decoration: _dec(theme, ''),
                            items: [
                              for (final t in AttendanceType.values)
                                DropdownMenuItem(
                                    value: t, child: Text(t.label)),
                            ],
                            onChanged: (v) =>
                                setState(() => _attendance = v ?? _attendance),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'LINHA DE CUIDADO'),
                          const SizedBox(height: AppSpacing.xs),
                          DropdownButtonFormField<CareLine>(
                            initialValue: _careLine,
                            decoration: _dec(theme, ''),
                            items: [
                              for (final l in CareLine.values)
                                DropdownMenuItem(
                                  value: l,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(l.icon, size: 16),
                                      const SizedBox(width: 8),
                                      Text(l.label),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _careLine = v ?? _careLine),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Sinais vitais
                _label(theme, 'SINAIS VITAIS'),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    _vitalField(theme, _paSis, 'PA SIS', 'mmHg', width: 90),
                    _vitalField(theme, _paDia, 'PA DIA', 'mmHg', width: 90),
                    _vitalField(theme, _fc, 'FC', 'bpm', width: 80),
                    _vitalField(theme, _temp, 'TEMP', '°C', width: 90, decimal: true),
                    _vitalField(theme, _sat, 'SatO₂', '%', width: 80),
                    _vitalField(theme, _glicemia, 'GLICEMIA', 'mg/dL', width: 110),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _label(theme, 'DOR'),
                    const SizedBox(width: AppSpacing.sm),
                    Text('${_dor.round()}/10',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _dor,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  activeColor: _kBrandRed,
                  label: '${_dor.round()}',
                  onChanged: (v) {
                    setState(() => _dor = v);
                    _recompute();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Classificação de risco
                Row(
                  children: [
                    _label(theme, 'CLASSIFICAÇÃO DE RISCO'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _manualPriority = false;
                        _manchester = _buildVitals().suggestedPriority;
                      }),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: Text('Sugestão: ${suggestion.label}'),
                      style: TextButton.styleFrom(foregroundColor: _kBrandRed),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final p in ManchesterPriority.values)
                      ChoiceChip(
                        label: Text(p.label),
                        selected: _manchester == p,
                        showCheckmark: false,
                        selectedColor: p.color,
                        labelStyle: TextStyle(
                          color: _manchester == p
                              ? p.onColor
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        avatar: CircleAvatar(backgroundColor: p.color, radius: 6),
                        onSelected: (_) => setState(() {
                          _manchester = p;
                          _manualPriority = true;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Vínculo eSF
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'MICROÁREA (eSF)'),
                          const SizedBox(height: AppSpacing.xs),
                          TextFormField(
                            controller: _microarea,
                            decoration: _dec(theme, 'Ex: 03'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'AGENTE COMUNITÁRIO (ACS)'),
                          const SizedBox(height: AppSpacing.xs),
                          TextFormField(
                            controller: _acs,
                            decoration: _dec(theme, 'Ex: Joana ACS'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancelar',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kBrandRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                      ),
                      child: const Text('REGISTRAR ACOLHIMENTO',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vitalField(
    ThemeData theme,
    TextEditingController controller,
    String label,
    String suffix, {
    required double width,
    bool decimal = false,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType:
            TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        onChanged: (_) => _recompute(),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Text(text,
      style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold));

  InputDecoration _dec(ThemeData theme, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      );
}
