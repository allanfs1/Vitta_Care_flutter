import 'package:flutter/material.dart';

import '../../core/i18n/textos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../navigation/app_router.dart';
import 'widgets/auth_scaffold.dart';

/// Tela de CADASTRO / criação de conta (módulo auth).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _clinic = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _accepted = false;
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    for (final c in [_name, _clinic, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aceite os termos para continuar.')),
      );
      return;
    }
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).register(
          email: _email.text.trim(),
          password: _password.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    // Após o cadastro, segue para a escolha do plano.
    context.go(AppRoutes.choosePlan);
  }

  Future<void> _registerGoogle() async {
    setState(() => _googleLoading = true);
    final error = await ref.read(authProvider.notifier).loginWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.go(AppRoutes.choosePlan);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.txt.t('auth.criarConta'),
      subtitle: context.txt.t('auth.comeceAGerenciarSuaClinicaEmMinutos'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              validator: (v) => Validators.required(v, 'Nome'),
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _clinic,
              validator: (v) => Validators.required(v, 'Nome da clínica'),
              decoration: const InputDecoration(
                labelText: 'Nome da clínica',
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              validator: Validators.password,
              decoration: InputDecoration(
                labelText: context.txt.t('auth.senha'),
                helperText: context.txt.t('auth.min8CaracteresComMaiusculaNumeroESimbolo'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              validator: (v) =>
                  v != _password.text ? 'As senhas não coincidem' : null,
              decoration: const InputDecoration(
                labelText: 'Confirmar senha',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Aceito os Termos de Uso e a Política de Privacidade'),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Criar conta'),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text('ou', style: Theme.of(context).textTheme.bodySmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _googleLoading ? null : _registerGoogle,
              icon: _googleLoading
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.g_mobiledata, size: 28),
              label: const Text('Cadastrar com Google'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Já tem conta?'),
                TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Entrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
