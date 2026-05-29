import 'dart:async';

import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';
import '../services/auth_api.dart';
import '../services/current_user_store.dart';
import 'create_account_screen.dart';
import 'loading_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _googleLoading = false;
  bool _loading = false;
  final _authApi = AuthApi();

  // Brute-force protection
  static int _failedAttempts = 0;
  static DateTime? _lockedUntil;
  int _lockoutSecondsLeft = 0;
  Timer? _lockoutTimer;

  static const int _maxAttempts = 5;
  static const int _lockoutSeconds = 60;

  @override
  void initState() {
    super.initState();
    _checkLockout();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _checkLockout() {
    final until = _lockedUntil;
    if (until == null || DateTime.now().isAfter(until)) {
      _lockoutSecondsLeft = 0;
      return;
    }
    _startCountdown(until.difference(DateTime.now()).inSeconds + 1);
  }

  void _startCountdown(int seconds) {
    _lockoutTimer?.cancel();
    setState(() { _lockoutSecondsLeft = seconds; });
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { _lockoutSecondsLeft--; });
      if (_lockoutSecondsLeft <= 0) {
        t.cancel();
        setState(() { _lockoutSecondsLeft = 0; });
      }
    });
  }

  bool get _isLocked => _lockoutSecondsLeft > 0;

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    // Aqui no validamos formato; se hara con el back mas adelante.
    return null;
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    return null;
  }

  void _submit() {
    if (_isLocked) return;
    if (!_formKey.currentState!.validate()) return;
    _login();
  }

  Future<void> _login() async {
    if (_loading || _isLocked) return;
    setState(() { _loading = true; });
    final result = await _authApi.login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    if (!mounted) return;
    setState(() { _loading = false; });
    if (result.ok) {
      _failedAttempts = 0;
      _lockedUntil = null;
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      CurrentUserStore.setUserId(result.userId);
      CurrentUserStore.setRole(result.role);
      if (result.userId != null) {
        final me = await _authApi.fetchMe(userId: result.userId!);
        if (me.ok && me.profile != null) {
          CurrentUserStore.setProfile(
            publicName: me.profile!.publicName,
            photoUrl: me.profile!.photoUrl,
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(LoadingScreen.routeName);
    } else {
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: _lockoutSeconds));
        _failedAttempts = 0;
        _startCountdown(_lockoutSeconds);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'No se pudo iniciar sesión')),
      );
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    final result = await _authApi.loginWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (result.ok) {
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      CurrentUserStore.setUserId(result.userId);
      CurrentUserStore.setRole(result.role);
      if (result.userId != null) {
        final me = await _authApi.fetchMe(userId: result.userId!);
        if (me.ok && me.profile != null) {
          CurrentUserStore.setProfile(
            publicName: me.profile!.publicName,
            photoUrl: me.profile!.photoUrl,
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(LoadingScreen.routeName);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'No se pudo iniciar sesión')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 900;
          final double cardWidth = isWide
              ? 420
              : (constraints.maxWidth * 0.92).clamp(320, 520);

          final isDark = ThemeService.instance.isDark;
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF031035), const Color(0xFF0C1F41)]
                    : [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.deepNavy.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Autenticidad en cada trazo',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 2,
                                width: 40,
                                color: AppColors.mistBlue,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 100,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: _emailValidator,
                                decoration: const InputDecoration(
                                  labelText: 'Correo electrónico',
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                validator: _requiredValidator,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              PrimaryButton(
                                label: _isLocked
                                    ? 'Bloqueado ($_lockoutSecondsLeft s)'
                                    : _loading ? 'Ingresando...' : 'Ingresar',
                                onPressed: (_isLocked || _loading) ? null : _submit,
                              ),
                              if (_isLocked)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Demasiados intentos fallidos. Espera $_lockoutSecondsLeft segundos.',
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _googleLoading
                                    ? null
                                    : _loginWithGoogle,
                                icon: const Icon(Icons.g_mobiledata, size: 26),
                                label: Text(
                                  _googleLoading
                                      ? 'Conectando...'
                                      : 'Ingresar con Google',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pushNamed(
                                          ResetPasswordScreen.routeName,
                                        );
                                      },
                                      child: const Text(
                                        '¿Olvidaste tu contraseña?',
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pushNamed(
                                          CreateAccountScreen.routeName,
                                        );
                                      },
                                      child: const Text('Crear cuenta'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.mistBlue.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.mistBlue.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              color: AppColors.slateBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Lo más importante para nosotros es la seguridad de tu arte.',
                                style: const TextStyle(
                                  color: AppColors.slateBlue,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


