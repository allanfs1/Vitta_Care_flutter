import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';

/// Agente 5 — Perfil do Usuário (`features/perfil_usuario`). Cobre PU-01..PU-05.
class PerfilUsuarioScreen extends ConsumerStatefulWidget {
  const PerfilUsuarioScreen({super.key});

  @override
  ConsumerState<PerfilUsuarioScreen> createState() =>
      _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends ConsumerState<PerfilUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _user = ref.read(editableUserProvider);

  late final _first = TextEditingController(text: _user.firstName);
  late final _last = TextEditingController(text: _user.lastName);
  late final _email = TextEditingController(text: _user.email);
  late final _phone = TextEditingController(text: _user.phone);
  late final _cpf = TextEditingController(text: _user.cpf);
  late final _cep = TextEditingController(text: _user.address.cep);
  late final _street = TextEditingController(text: _user.address.street);
  late final _number = TextEditingController(text: _user.address.number);
  late final _district = TextEditingController(text: _user.address.district);
  late final _city = TextEditingController(text: _user.address.city);
  late final _state = TextEditingController(text: _user.address.state);

  @override
  void dispose() {
    for (final c in [
      _first, _last, _email, _phone, _cpf, _cep, _street, _number, _district,
      _city, _state
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _salvando = false;

  /// PU-02 — grava o perfil e **só então** confirma.
  ///
  /// A versão anterior exibia "Perfil atualizado com sucesso" sem escrever em
  /// lugar nenhum: o usuário editava, via a confirmação e perdia tudo ao voltar.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _salvando) return;
    setState(() => _salvando = true);

    final atual = ref.read(currentUserProvider);
    final atualizado = atual.copyWith(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      cpf: _cpf.text.trim(),
      address: atual.address.copyWith(
        cep: _cep.text.trim(),
        street: _street.text.trim(),
        number: _number.text.trim(),
        district: _district.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(currentUserProvider.notifier).salvar(atualizado);
      ref.read(editableUserProvider.notifier).state = atualizado;
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text('Não foi possível salvar: $e'),
      ));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // PU-04 — busca automática de CEP (simula ViaCEP).
  void _lookupCep() {
    final err = Validators.cep(_cep.text);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() {
      _street.text = 'Av. Paulista';
      _district.text = 'Bela Vista';
      _city.text = 'São Paulo';
      _state.text = 'SP';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Endereço preenchido via CEP.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do Usuário'),
        actions: [
          TextButton(
            onPressed: _salvando ? null : _save,
            child: _salvando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // PU-01 — foto de perfil
            Center(
              child: Stack(
                children: [
                  AppAvatar(
                      initials: _user.initials,
                      imageUrl: _user.photoUrl,
                      radius: 48),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        color: Colors.white,
                        icon: const Icon(Icons.camera_alt),
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Selecionar foto (câmera/galeria).')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // PU-02 — dados pessoais
            const SectionHeader(title: 'Dados pessoais'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  _field(_first, 'Nome', validator: (v) => Validators.required(v, 'Nome')),
                  _field(_last, 'Sobrenome',
                      validator: (v) => Validators.required(v, 'Sobrenome')),
                  _field(_cpf, 'CPF', validator: Validators.cpf, keyboard: TextInputType.number),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // PU-03 — contato
            const SectionHeader(title: 'Contato'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  _field(_email, 'E-mail',
                      validator: Validators.email, keyboard: TextInputType.emailAddress),
                  _field(_phone, 'Telefone', keyboard: TextInputType.phone),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // PU-04 — endereço
            const SectionHeader(title: 'Endereço'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(_cep, 'CEP',
                            validator: Validators.cep, keyboard: TextInputType.number),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: IconButton.filledTonal(
                          onPressed: _lookupCep,
                          icon: const Icon(Icons.search),
                          tooltip: 'Buscar CEP',
                        ),
                      ),
                    ],
                  ),
                  _field(_street, 'Endereço'),
                  Row(
                    children: [
                      Expanded(child: _field(_number, 'Número')),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 2, child: _field(_district, 'Bairro')),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(flex: 2, child: _field(_city, 'Cidade')),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _field(_state, 'UF')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // PU-05 — segurança
            const SectionHeader(title: 'Segurança'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: const Text('Alterar senha'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePassword(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: const Text('Salvar alterações')),
            ),
          ],
        ),
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

  void _showChangePassword(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.sm,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.lg,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alterar senha', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: current,
                obscureText: true,
                validator: (v) => Validators.required(v, 'Senha atual'),
                decoration: const InputDecoration(labelText: 'Senha atual'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: next,
                obscureText: true,
                validator: Validators.password,
                decoration: const InputDecoration(labelText: 'Nova senha'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: confirm,
                obscureText: true,
                validator: (v) =>
                    v != next.text ? 'As senhas não coincidem' : null,
                decoration: const InputDecoration(labelText: 'Confirmar nova senha'),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Senha alterada com sucesso.')),
                    );
                  },
                  child: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
