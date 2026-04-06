import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';
import '../services/temp_session_store.dart';
import '../services/otp_api.dart';
import 'login_screen.dart';

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  static const String routeName = '/two-factor';

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  String? _emailValue;
  String? _sessionId;
  bool _didLoadArgs = false;
  bool _showFullEmail = false;
  bool _sendingCode = false;
  final _otpApi = OtpApi();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _showVerifiedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cuenta verificada'),
          content: const Text('Disfruta la experiencia de Verificarte.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).pushReplacementNamed(LoginScreen.routeName);
              },
              child: const Text('Ir a iniciar sesión'),
            ),
          ],
        );
      },
    );
  }

  void _showMissingDataMessage() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Datos faltantes')));
  }

  String? _requiredFieldValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_didLoadArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final sessionArg = args['sessionId'];
        if (sessionArg is String && sessionArg.trim().isNotEmpty) {
          _sessionId = sessionArg.trim();
          _emailValue = TempSessionStore.getEmail(_sessionId!);
          // Aqui va el back: usar accountType real cuando exista.
        }
      } else if (args is String && args.trim().isNotEmpty) {
        _emailValue = args.trim();
      }
      if (_emailValue != null && _emailValue!.isNotEmpty) {
        _requestOtp();
      }
      _didLoadArgs = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Verificación en dos pasos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.mistBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirmamos tu correo',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Te llegará un correo con un código. Guárdalo, '
                      'será importante en el futuro.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AnimatedContainer(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepNavy.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.mistBlue.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.mistBlue.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            color: AppColors.slateBlue,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _emailValue?.isNotEmpty == true
                                  ? (_showFullEmail
                                        ? _emailValue!
                                        : _maskEmail(_emailValue!))
                                  : 'Correo no disponible',
                              style: const TextStyle(
                                color: AppColors.deepNavy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_emailValue?.isNotEmpty == true)
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _showFullEmail = !_showFullEmail;
                                });
                              },
                              icon: Icon(
                                _showFullEmail
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.slateBlue,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _sendingCode ? null : _requestOtp,
                        child: Text(
                          _sendingCode ? 'Enviando...' : 'Reenviar código',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      validator: _requiredFieldValidator,
                      decoration: const InputDecoration(
                        labelText: 'Código',
                        hintText: 'Ingresa el código',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Verificar',
                onPressed: () {
                  if (_emailValue == null || _emailValue!.trim().isEmpty) {
                    _showMissingDataMessage();
                    return;
                  }
                  if (!_formKey.currentState!.validate()) {
                    _showMissingDataMessage();
                    return;
                  }
                  _verifyOtpAndContinue();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestOtp() async {
    if (_emailValue == null || _emailValue!.trim().isEmpty) {
      _showMissingDataMessage();
      return;
    }
    setState(() {
      _sendingCode = true;
    });
    final ok = await _otpApi.requestTwoFactorCode(email: _emailValue!);
    if (!mounted) return;
    setState(() {
      _sendingCode = false;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el código')),
      );
    }
  }

  Future<void> _verifyOtpAndContinue() async {
    if (_emailValue == null || _emailValue!.trim().isEmpty) return;
    final ok = await _otpApi.verifyTwoFactorCode(
      email: _emailValue!,
      code: _codeController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      _showVerifiedDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código inválido o expirado')),
      );
    }
  }
}

String _maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2) return email;

  final user = parts[0];
  final domain = parts[1];

  String mask(String value) {
    if (value.length <= 2) return '${value[0]}*';
    return '${value[0]}***${value[value.length - 1]}';
  }

  final domainParts = domain.split('.');
  final maskedDomain = domainParts.isNotEmpty
      ? mask(domainParts.first)
      : mask(domain);
  final suffix = domainParts.length > 1
      ? '.${domainParts.sublist(1).join('.')}'
      : '';

  return '${mask(user)}@$maskedDomain$suffix';
}


