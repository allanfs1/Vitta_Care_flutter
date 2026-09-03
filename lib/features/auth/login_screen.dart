import 'package:flutter/material.dart';

import '../../core/i18n/textos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../navigation/app_router.dart';
import 'widgets/auth_scaffold.dart';

/// Tela de LOGIN (módulo auth): e-mail/senha, recuperação de senha, login
/// biométrico (digital/Windows Hello), login com Google e primeiro acesso.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _biometricAvailable = false;
  bool _biometricLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await ref.read(biometricServiceProvider).isAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goAfterAuth() {
    final hasPlan = ref.read(authProvider).hasPlan;
    context.go(hasPlan ? AppRoutes.home : AppRoutes.choosePlan);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).login(
          email: _email.text.trim(),
          password: _password.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _maybeOfferBiometric();
    if (!mounted) return;
    _goAfterAuth();
  }

  Future<void> _loginGoogle() async {
    setState(() => _googleLoading = true);
    final error = await ref.read(authProvider.notifier).loginWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _maybeOfferBiometric();
    if (!mounted) return;
    _goAfterAuth();
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  /// Login biométrico: desbloqueia a sessão salva neste dispositivo.
  Future<void> _loginBiometric() async {
    final auth = ref.read(authProvider.notifier);
    final bio = ref.read(biometricServiceProvider);
    setState(() => _biometricLoading = true);

    final available = await bio.isAvailable();
    if (!mounted) return;
    if (!available) {
      setState(() => _biometricLoading = false);
      _snack('Este dispositivo/navegador não oferece biometria (Windows Hello, '
          'Touch ID ou digital). Entre com e-mail e senha.');
      return;
    }
    final enrolled = await bio.isEnrolled();
    if (!mounted) return;
    if (!enrolled || !auth.canRestoreSession) {
      setState(() => _biometricLoading = false);
      _snack('Entre uma vez com e-mail e senha e ative a biometria para '
          'poder usá-la aqui.');
      return;
    }

    final ok = await bio.authenticate(reason: 'Entrar no Vitta');
    if (!mounted) return;
    if (!ok) {
      setState(() => _biometricLoading = false);
      return;
    }
    final error = await auth.completeBiometricLogin();
    if (!mounted) return;
    setState(() => _biometricLoading = false);
    if (error != null) {
      _snack(error);
      return;
    }
    _goAfterAuth();
  }

  /// Após login por senha, oferece habilitar a biometria se ainda não
  /// configurada. Na web isso cria uma passkey (WebAuthn → Windows Hello/Touch
  /// ID); no nativo confirma a digital.
  Future<void> _maybeOfferBiometric() async {
    final auth = ref.read(authProvider.notifier);
    final bio = ref.read(biometricServiceProvider);
    if (!_biometricAvailable || auth.biometricEnabled) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ativar login por biometria?'),
        content: const Text(
            'Use sua biometria (digital, Windows Hello ou Touch ID) para entrar '
            'mais rápido da próxima vez neste dispositivo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Agora não')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ativar')),
        ],
      ),
    );
    if (enable != true || !mounted) return;
    final ok = await bio.enroll(
      reason: 'Cadastre sua biometria para entrar no Vitta',
      accountName: ref.read(authProvider).email,
    );
    if (!mounted) return;
    if (ok) {
      await auth.setBiometricEnabled(true);
      _snack('Biometria ativada neste dispositivo.');
    } else {
      _snack('Não foi possível ativar a biometria agora.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseEnabled = ref.watch(firebaseEnabledProvider);

    return AuthScaffold(
      title: context.txt.t('auth.bemVindoDeVolta'),
      subtitle: context.txt.t('auth.acesseOPainelDaSuaClinica'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner de setup do Firebase (login real indisponível).
            if (!firebaseEnabled) ...[
              _FirebaseSetupBanner(),
              const SizedBox(height: AppSpacing.lg),
            ],

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
              validator: (v) => Validators.required(v, context.txt.t('auth.senha')),
              decoration: InputDecoration(
                labelText: context.txt.t('auth.senha'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                child: const Text('Esqueci minha senha'),
              ),
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
                  : const Text('Entrar'),
            ),

            // Login por biometria (digital / Windows Hello) — sempre visível.
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _biometricLoading ? null : _loginBiometric,
              icon: _biometricLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.fingerprint),
              label: const Text('Entrar com biometria'),
            ),
            if (_biometricAvailable && !ref.read(authProvider.notifier).biometricEnabled)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Entre uma vez com e-mail e senha para ativar a biometria.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.lg),
            const _OrDivider(),
            const SizedBox(height: AppSpacing.lg),

            // Login com Google.
            OutlinedButton.icon(
              onPressed: _googleLoading ? null : _loginGoogle,
              icon: _googleLoading
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.g_mobiledata, size: 28),
              label: const Text('Continuar com Google'),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Primeiro acesso → criar conta (em destaque).
            _FirstAccessCard(onCreate: () => context.go(AppRoutes.register)),
          ],
        ),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Informe seu e-mail. Enviaremos um link para redefinir a senha.'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    final error = await ref.read(authProvider.notifier).resetPassword(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'E-mail de recuperação enviado para $email.'),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('ou', style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _FirebaseSetupBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.txt.t('auth.modoDemonstracao'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: AppColors.warning)),
                const SizedBox(height: 2),
                Text(
                  'O Firebase não foi inicializado nesta plataforma. O login '
                  'funciona em modo simulado. Para login real, rode no Chrome/'
                  'Android e habilite "Email/Password" e "Google" no Firebase '
                  'Authentication.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstAccessCard extends StatelessWidget {
  const _FirstAccessCard({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.txt.t('auth.primeiroAcesso'), style: theme.textTheme.titleMedium),
                Text(context.txt.t('auth.crieSuaContaEConfigureAClinica'),
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: onCreate, child: const Text('Criar conta')),
        ],
      ),
    );
  }
}
