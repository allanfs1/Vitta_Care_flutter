import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/clinic.dart';
import '../../core/models/enums.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';

/// Agente 6 — Perfil da Clínica (`features/perfil_clinica`). Cobre PC-01..PC-06.
class PerfilClinicaScreen extends ConsumerStatefulWidget {
  const PerfilClinicaScreen({super.key});

  @override
  ConsumerState<PerfilClinicaScreen> createState() =>
      _PerfilClinicaScreenState();
}

class _PerfilClinicaScreenState extends ConsumerState<PerfilClinicaScreen> {
  final _formKey = GlobalKey<FormState>();
  late Clinic _clinic = ref.read(selectedClinicProvider);

  late final _name = TextEditingController(text: _clinic.name);
  late final _razao = TextEditingController(text: _clinic.razaoSocial);
  late final _cnpj = TextEditingController(text: _clinic.cnpj);
  late final _phone = TextEditingController(text: _clinic.phone);
  late final _email = TextEditingController(text: _clinic.email);
  late final _website = TextEditingController(text: _clinic.website);
  late ClinicType _type = _clinic.type;
  late List<String> _specialties = [..._clinic.specialties];
  late List<BusinessHour> _hours = _clinic.businessHours.isEmpty
      ? [for (var d = 1; d <= 7; d++) BusinessHour(weekday: d)]
      : [..._clinic.businessHours];

  @override
  void dispose() {
    for (final c in [_name, _razao, _cnpj, _phone, _email, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados da clínica atualizados.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentClinic = ref.watch(selectedClinicProvider);

    // Se a clínica mudar globalmente, atualizamos os campos locais.
    if (currentClinic.id != _clinic.id) {
      _clinic = currentClinic;
      _name.text = _clinic.name;
      _razao.text = _clinic.razaoSocial ?? '';
      _cnpj.text = _clinic.cnpj ?? '';
      _phone.text = _clinic.phone ?? '';
      _email.text = _clinic.email ?? '';
      _website.text = _clinic.website ?? '';
      _type = _clinic.type;
      _specialties = [..._clinic.specialties];
      _hours = _clinic.businessHours.isEmpty
          ? [for (var d = 1; d <= 7; d++) BusinessHour(weekday: d)]
          : [..._clinic.businessHours];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil da Clínica'),
        actions: [TextButton(onPressed: _save, child: const Text('Salvar'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // PC-04 — logotipo
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: _type.color.withValues(alpha: 0.15),
                    backgroundImage: _clinic.photoUrl != null && _clinic.photoUrl!.isNotEmpty
                        ? NetworkImage(_clinic.photoUrl!)
                        : null,
                    child: _clinic.photoUrl == null || _clinic.photoUrl!.isEmpty
                        ? Icon(Icons.local_hospital, size: 36, color: _type.color)
                        : null,
                  ),
                  TextButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Atualizar logotipo.')),
                    ),
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text('Alterar logotipo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // PC-01 — dados da clínica
            const SectionHeader(title: 'Dados da clínica'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  _field(_name, 'Nome fantasia',
                      validator: (v) => Validators.required(v, 'Nome')),
                  _field(_razao, 'Razão social'),
                  _field(_cnpj, 'CNPJ',
                      validator: Validators.cnpj, keyboard: TextInputType.number),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<ClinicType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Tipo de unidade'),
                    items: [
                      for (final t in ClinicType.values)
                        DropdownMenuItem(value: t, child: Text(t.description)),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // PC-03 — contato
            const SectionHeader(title: 'Contato'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  _field(_phone, 'Telefone', keyboard: TextInputType.phone),
                  _field(_email, 'E-mail institucional',
                      validator: Validators.email,
                      keyboard: TextInputType.emailAddress),
                  _field(_website, 'Website'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // PC-06 — especialidades
            const SectionHeader(title: 'Especialidades'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final s in _specialties)
                        Chip(
                          label: Text(s),
                          onDeleted: () => setState(() => _specialties.remove(s)),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: _addSpecialty,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar especialidade'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // PC-05 — horário de funcionamento
            const SectionHeader(title: 'Horário de funcionamento'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < _hours.length; i++)
                    _HoursRow(
                      hour: _hours[i],
                      onChanged: (h) => setState(() => _hours[i] = h),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Endereço completo com busca por CEP disponível na edição (PC-02).',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: const Text('Salvar alterações')),
            ),
          ],
        ),
      ),
    );
  }

  void _addSpecialty() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova especialidade'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex.: Cardiologia'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _specialties.add(controller.text.trim()));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({required this.hour, required this.onChanged});

  final BusinessHour hour;
  final ValueChanged<BusinessHour> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(hour.weekdayLabel, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: hour.closed
                ? Text('Fechado', style: theme.textTheme.bodyMedium)
                : Text('${hour.open} – ${hour.close}',
                    style: theme.textTheme.bodyMedium),
          ),
          Switch(
            value: !hour.closed,
            onChanged: (v) => onChanged(hour.copyWith(closed: !v)),
          ),
        ],
      ),
    );
  }
}
