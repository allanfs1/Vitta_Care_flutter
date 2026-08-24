import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/doctor.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_avatar.dart';

/// Formulário de cadastro/edição de médico (EM-03, EM-04). Quando [doctorId]
/// é informado, pré-preenche os campos e atualiza o registro existente.
class MedicoFormScreen extends ConsumerStatefulWidget {
  const MedicoFormScreen({super.key, this.doctorId});

  final String? doctorId;

  @override
  ConsumerState<MedicoFormScreen> createState() => _MedicoFormScreenState();
}

class _MedicoFormScreenState extends ConsumerState<MedicoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _crm = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _bio = TextEditingController();
  final _experience = TextEditingController();
  final _ticket = TextEditingController();
  final _newSpecialty = TextEditingController();

  final Set<String> _specialties = {};
  Set<String> _suggestions = {};

  /// Escala de atendimento (`scalaMedico`) em horas por dia de plantão.
  static const _scaleOptions = [2, 4, 6, 8, 10, 12, 16, 20, 24];
  int _scaleHours = 8;

  /// Quando o valor não é um dos presets, o usuário informa a escala manualmente.
  bool _customScale = false;
  final _customScaleCtrl = TextEditingController();

  /// Foto de perfil selecionada (galeria/câmera).
  Uint8List? _photoBytes;

  Doctor? _editing;
  bool _loaded = false;

  bool get _isEdit => widget.doctorId != null;

  @override
  void initState() {
    super.initState();
    _ticket.text = '0';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    final all = ref.read(clinicDoctorsProvider);
    _suggestions = {for (final d in all) ...d.specialties};

    if (_isEdit) {
      final match = all.where((d) => d.id == widget.doctorId);
      if (match.isNotEmpty) {
        final d = match.first;
        _editing = d;
        _name.text = d.name;
        _crm.text = d.crm;
        _email.text = d.email ?? '';
        _phone.text = d.phone ?? '';
        _address.text = d.address ?? '';
        _bio.text = d.bio ?? '';
        _experience.text = d.experience ?? '';
        _ticket.text = d.ticket.toStringAsFixed(0);
        _scaleHours = d.scaleHours;
        if (!_scaleOptions.contains(d.scaleHours)) {
          _customScale = true;
          _customScaleCtrl.text = '${d.scaleHours}';
        }
        _photoBytes = d.photoBytes;
        _specialties.addAll(d.specialties);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _crm.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _bio.dispose();
    _experience.dispose();
    _ticket.dispose();
    _newSpecialty.dispose();
    _customScaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSpecialties = {..._suggestions, ..._specialties}.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Editar médico' : 'Novo médico')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Foto de perfil — o usuário pode escolher/trocar (câmera/galeria).
            Center(
              child: Stack(
                children: [
                  AppAvatar(
                    initials: _name.text.trim().isEmpty
                        ? '+'
                        : _name.text.trim()[0].toUpperCase(),
                    imageBytes: _photoBytes,
                    imageUrl: _editing?.photoUrl,
                    radius: 48,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickPhoto,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.photo_camera,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(_photoBytes == null
                    ? 'Adicionar foto'
                    : 'Trocar foto'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Nome completo *', prefixIcon: Icon(Icons.person)),
              validator: (v) {
                final base = Validators.required(v, 'Nome');
                if (base != null) return base;
                if (v!.trim().length < 3) return 'Mínimo de 3 caracteres';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _crm,
              // CRM é imutável após o cadastro (somente admin cria/edita aqui).
              enabled: !_isEdit,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'CRM *',
                prefixIcon: const Icon(Icons.badge_outlined),
                helperText: _isEdit ? 'CRM não pode ser alterado' : null,
              ),
              validator: (v) => Validators.required(v, 'CRM'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'E-mail *', prefixIcon: Icon(Icons.email_outlined)),
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Telefone *',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '(11) 99999-9999'),
              validator: (v) => Validators.required(v, 'Telefone'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                  labelText: 'Endereço',
                  prefixIcon: Icon(Icons.location_on_outlined)),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _ticket,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Valor do ticket (R\$)',
                  prefixIcon: Icon(Icons.attach_money)),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Escala de atendimento (`scalaMedico`).
            Row(
              children: [
                const Icon(Icons.schedule, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Escala de atendimento',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 2),
            Text('Carga horária por dia de plantão',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final h in _scaleOptions)
                  ChoiceChip(
                    label: Text('${h}h'),
                    selected: !_customScale && _scaleHours == h,
                    onSelected: (_) => setState(() {
                      _customScale = false;
                      _scaleHours = h;
                    }),
                  ),
                // Escala personalizada — habilita a entrada manual de horas.
                ChoiceChip(
                  label: const Text('Personalizada'),
                  selected: _customScale,
                  onSelected: (_) => setState(() => _customScale = true),
                ),
              ],
            ),
            if (_customScale) ...[
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _customScaleCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Escala personalizada (horas/dia)',
                  prefixIcon: Icon(Icons.timelapse),
                  hintText: 'Ex.: 36',
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null) setState(() => _scaleHours = n);
                },
                validator: (v) {
                  if (!_customScale) return null;
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0 || n > 24) {
                    return 'Informe as horas (1 a 24)';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Especialidades (multiselect) — pelo menos uma obrigatória.
            Text('Especialidades *',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in allSpecialties)
                  FilterChip(
                    label: Text(s),
                    selected: _specialties.contains(s),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _specialties.add(s);
                      } else {
                        _specialties.remove(s);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSpecialty,
                    decoration: const InputDecoration(
                      labelText: 'Adicionar especialidade',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addSpecialty(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filledTonal(
                  onPressed: _addSpecialty,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            TextFormField(
              controller: _bio,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                  labelText: 'Biografia', alignLabelWithHint: true),
            ),
            TextFormField(
              controller: _experience,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                  labelText: 'Experiência', alignLabelWithHint: true),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              style:
                  ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Salvar alterações' : 'Cadastrar médico'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBytes = bytes);
  }

  void _addSpecialty() {
    final value = _newSpecialty.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _specialties.add(value);
      _suggestions.add(value);
      _newSpecialty.clear();
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_specialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecione pelo menos uma especialidade.')));
      return;
    }

    final ticket = double.tryParse(_ticket.text.trim().replaceAll(',', '.')) ?? 0;
    final scaleHours = _customScale
        ? (int.tryParse(_customScaleCtrl.text.trim()) ?? _scaleHours)
        : _scaleHours;
    final notifier = ref.read(clinicDoctorsProvider.notifier);

    if (_isEdit && _editing != null) {
      notifier.update(_editing!.copyWith(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        bio: _bio.text.trim(),
        experience: _experience.text.trim(),
        ticket: ticket,
        scaleHours: scaleHours,
        photoBytes: _photoBytes,
        specialties: _specialties.toList(),
      ));
    } else {
      notifier.add(Doctor(
        id: 'd${DateTime.now().millisecondsSinceEpoch}',
        name: _name.text.trim(),
        crm: _crm.text.trim(),
        specialties: _specialties.toList(),
        // EM-03 — idclinica preenchido com a clínica selecionada.
        clinicId: ref.read(selectedClinicIdProvider),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        bio: _bio.text.trim(),
        experience: _experience.text.trim(),
        ticket: ticket,
        scaleHours: scaleHours,
        photoBytes: _photoBytes,
        active: true,
        createdAt: DateTime.now(),
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Médico atualizado.' : 'Médico cadastrado.')));
    Navigator.of(context).pop();
  }
}
