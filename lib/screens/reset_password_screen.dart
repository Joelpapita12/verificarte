import 'dart:async';

import 'package:flutter/material.dart';

import '../services/otp_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  static const String routeName = '/reset-password';

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showNewPasswordFields = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _sendingCode = false;
  final _otpApi = OtpApi();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    return null;
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    if (value != _newPasswordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  void _toggleUnlockFields(String value) {
    setState(() {
      _showNewPasswordFields = value.trim().isNotEmpty;
    });
  }

  Future<void> _requestResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa tu correo')));
      return;
    }
    setState(() {
      _sendingCode = true;
    });
    final ok = await _otpApi.requestResetCode(email: email);
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

  Future<void> _submitWithDelay() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_showNewPasswordFields) {
      return;
    }
    final ok = await _otpApi.verifyResetCodeAndChangePassword(
      email: _emailController.text.trim(),
      code: _codeController.text.trim(),
      newPassword: _newPasswordController.text.trim(),
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código inválido o expirado')),
      );
      return;
    }
    // Aquí va el back: restablecer contraseña real.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          title: Text('Restablecido'),
          content: Text('Tu contraseña fue actualizada correctamente.'),
        );
      },
    );
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.mistBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingresa tu correo',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Te llegará un mensaje al correo. Estate atento.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  hintText: 'ejemplo@correo.com',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _sendingCode ? null : _requestResetCode,
                  child: Text(_sendingCode ? 'Enviando...' : 'Enviar código'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                validator: _requiredValidator,
                decoration: const InputDecoration(
                  labelText: 'Código de restablecimiento',
                ),
                onChanged: _toggleUnlockFields,
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _showNewPasswordFields
                    ? Column(
                        key: const ValueKey('new-password-fields'),
                        children: [
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNew,
                            validator: _requiredValidator,
                            decoration: InputDecoration(
                              labelText: 'Nueva contraseña',
                              helperText:
                                  'Debe tener 8 caracteres, una mayúscula y un carácter especial.',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNew
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureNew = !_obscureNew;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            validator: _confirmPasswordValidator,
                            decoration: InputDecoration(
                              labelText: 'Confirmar contraseña',
                              helperText:
                                  'Debe tener 8 caracteres, una mayúscula y un carácter especial.',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirm = !_obscureConfirm;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        key: const ValueKey('locked-message'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.mistBlue.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.mistBlue.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'Ingresa el código para desbloquear la nueva contraseña.',
                          style: TextStyle(color: AppColors.slateBlue),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Restablecer',
                onPressed: _showNewPasswordFields ? _submitWithDelay : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

