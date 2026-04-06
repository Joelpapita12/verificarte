import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';
import '../services/temp_session_store.dart';
import '../services/auth_api.dart';
import '../services/current_user_store.dart';
import '../services/local_image_picker.dart';
import 'login_screen.dart';
import 'loading_screen.dart';
import 'two_factor_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  static const String routeName = '/create-account';

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _publicNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _googleLoading = false;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  AccountType? _selectedAccountType;
  String? _selectedAccountTypeValue;
  Uint8List? _profileImageBytes;
  String? _profileImageName;
  final _authApi = AuthApi();

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _publicNameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final image = await pickLocalImage();
    if (image == null) return;
    setState(() {
      _profileImageBytes = image.bytes;
      _profileImageName = image.fileName;
    });
  }

  Future<void> _showTwoFactorPrompt() async {
    if (!_formKey.currentState!.validate()) {
      _showMissingDataMessage();
      return;
    }
    if (_selectedAccountType == null) {
      _showMissingDataMessage();
      return;
    }
    if (!_acceptedTerms || !_acceptedPrivacy) {
      _showLegalRequiredMessage();
      return;
    }

    final result = await _authApi.register(
      username: _usernameController.text.trim(),
      publicName: _publicNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      accountType: _selectedAccountTypeValue ?? 'buyer',
      acceptedTerms: _acceptedTerms,
      acceptedPrivacy: _acceptedPrivacy,
    );
    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'No se pudo crear la cuenta')),
      );
      return;
    }

    CurrentUserStore.setUserId(result.userId);
    CurrentUserStore.setRole(
      result.role ??
          (_selectedAccountTypeValue == 'artist' ? 'artista' : 'seguidor'),
    );
    CurrentUserStore.setProfile(
      publicName: _publicNameController.text.trim(),
      photoUrl: null,
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Verificacion en dos pasos'),
          content: const Text('Deseas hacer la verificacion en dos pasos?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).pushReplacementNamed(LoginScreen.routeName);
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                final signupPayload = <String, String?>{
                  // Aqui va el back: manda estos datos al backend cuando exista.
                  'sessionId': TempSessionStore.createSession(
                    email: _emailController.text.trim(),
                    accountType: _selectedAccountTypeValue ?? 'unknown',
                  ),
                };
                Navigator.of(context).pushReplacementNamed(
                  TwoFactorScreen.routeName,
                  arguments: signupPayload,
                );
              },
              child: const Text('Si'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _registerWithGoogle() async {
    if (_googleLoading) return;
    if (_selectedAccountType == null) {
      _showMissingDataMessage();
      return;
    }
    if (!_acceptedTerms || !_acceptedPrivacy) {
      _showLegalRequiredMessage();
      return;
    }

    setState(() {
      _googleLoading = true;
    });

    final result = await _authApi.loginWithGoogle(
      accountType: _selectedAccountTypeValue ?? 'buyer',
      acceptedTerms: _acceptedTerms,
      acceptedPrivacy: _acceptedPrivacy,
    );

    if (!mounted) return;
    setState(() {
      _googleLoading = false;
    });

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'No se pudo crear la cuenta')),
      );
      return;
    }

    CurrentUserStore.setUserId(result.userId);
    CurrentUserStore.setRole(
      result.role ??
          (_selectedAccountTypeValue == 'artist' ? 'artista' : 'seguidor'),
    );
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
  }

  void _showMissingDataMessage() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Datos faltantes')));
  }

  void _showLegalRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Debes aceptar los Terminos y Condiciones y el Aviso de Privacidad para crear la cuenta',
        ),
      ),
    );
  }

  Future<void> _showLongTermsDialog() async {
    await _showLegalDialog(
      title: 'Terminos y Condiciones de uso',
      content: _termsAndConditionsLongText,
    );
  }

  Future<void> _showPrivacyDialog() async {
    await _showLegalDialog(
      title: 'Aviso de Privacidad',
      content: _privacyNoticeLongText,
    );
  }

  Future<void> _showLegalDialog({
    required String title,
    required String content,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                  decoration: const BoxDecoration(
                    color: AppColors.deepNavy,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: SelectableText(
                        content,
                        style: textTheme.bodyMedium?.copyWith(height: 1.55),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    final email = value.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Correo invalido';
    }
    return null;
  }

  String? _requiredFieldValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    if (value.trim().length < 8) {
      return 'Minimo 8 caracteres';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo requerido';
    }
    if (value != _passwordController.text) {
      return 'Las contrasenas no coinciden';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
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
                      'Bienvenido a Verificarte',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Completa los datos para crear tu cuenta.',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Que tipo de cuenta quieres?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _AccountTypeOption(
                      label: 'Artista',
                      value: AccountType.artist,
                      isSelected: _selectedAccountType == AccountType.artist,
                      onSelected: (value) {
                        setState(() {
                          _selectedAccountType = value;
                          _selectedAccountTypeValue = 'artist';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _AccountTypeOption(
                      label: 'Comprador',
                      value: AccountType.buyer,
                      isSelected: _selectedAccountType == AccountType.buyer,
                      onSelected: (value) {
                        setState(() {
                          _selectedAccountType = value;
                          _selectedAccountTypeValue = 'buyer';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _googleLoading ? null : _registerWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 26),
                      label: Text(
                        _googleLoading
                            ? 'Conectando...'
                            : 'Crear cuenta con Google',
                      ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aviso importante',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.mistBlue.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.deepNavy.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        _termsAndConditionsShortText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          onChanged: (value) {
                            setState(() {
                              _acceptedTerms = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text.rich(
                              TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium,
                                children: [
                                  const TextSpan(text: 'Acepto los '),
                                  TextSpan(
                                    text: 'Terminos y Condiciones',
                                    style: const TextStyle(
                                      color: AppColors.deepNavy,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = _showLongTermsDialog,
                                  ),
                                  const TextSpan(
                                    text:
                                        ' para crear y usar una cuenta en verificARTE.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptedPrivacy,
                          onChanged: (value) {
                            setState(() {
                              _acceptedPrivacy = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text.rich(
                              TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium,
                                children: [
                                  const TextSpan(text: 'Acepto el '),
                                  TextSpan(
                                    text: 'Aviso de Privacidad',
                                    style: const TextStyle(
                                      color: AppColors.deepNavy,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = _showPrivacyDialog,
                                  ),
                                  const TextSpan(
                                    text:
                                        ' y autorizo el tratamiento de mis datos conforme a dicho aviso.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed: _showLongTermsDialog,
                          child: const Text('Leer terminos'),
                        ),
                        OutlinedButton(
                          onPressed: _showPrivacyDialog,
                          child: const Text('Leer aviso de privacidad'),
                        ),
                      ],
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
                      color: AppColors.deepNavy.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Foto de perfil',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: size.width < 400 ? 36 : 42,
                          backgroundColor: AppColors.steelBlue.withValues(alpha: 
                            0.15,
                          ),
                          backgroundImage: _profileImageBytes != null
                              ? MemoryImage(_profileImageBytes!)
                              : null,
                          child: _profileImageBytes == null
                              ? const Icon(
                                  Icons.person,
                                  color: AppColors.slateBlue,
                                  size: 34,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Sube una imagen para que tu perfil se vea profesional.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickProfileImage,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Subir foto de perfil'),
                    ),
                    if (_profileImageName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Imagen seleccionada: $_profileImageName',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
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
                    TextFormField(
                      controller: _usernameController,
                      validator: _requiredFieldValidator,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de usuario',
                        hintText: 'Tu usuario unico',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _publicNameController,
                      validator: _requiredFieldValidator,
                      decoration: const InputDecoration(
                        labelText: 'Nombre publico',
                        hintText: 'Como quieres que te vean',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailValidator,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        hintText: 'ejemplo@correo.com',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      validator: _passwordValidator,
                      decoration: InputDecoration(
                        labelText: 'Contrasena',
                        helperText:
                            'Debe tener 8 caracteres, una mayuscula y un caracter especial.',
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      validator: _confirmPasswordValidator,
                      decoration: InputDecoration(
                        labelText: 'Confirmar contrasena',
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
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Siguiente',
                onPressed: _showTwoFactorPrompt,
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Salir',
                onPressed: () {
                  // Aqui puedes cerrar sesion o salir del flujo.
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTypeOption extends StatelessWidget {
  const _AccountTypeOption({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final AccountType value;
  final bool isSelected;
  final ValueChanged<AccountType> onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.mistBlue.withValues(alpha: 0.6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.deepNavy : AppColors.mistBlue,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.deepNavy : AppColors.slateBlue,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.deepNavy : AppColors.slateBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AccountType { artist, buyer }

const String _termsAndConditionsShortText =
    'Al crear tu cuenta en verificARTE aceptas usar la plataforma de forma '
    'responsable, declarar que tienes derechos sobre el contenido que publiques, '
    'respetar los derechos de terceros y permitir que la plataforma gestione '
    'certificados digitales, marcas de agua, reportes y sanciones cuando sea necesario.';

const String _termsAndConditionsLongText =
    'TERMINOS Y CONDICIONES DE USO - verificARTE\n\n'
    '1. Aceptacion de los terminos\n\n'
    'El acceso y uso de la plataforma verificARTE implica la aceptacion de los presentes Terminos y Condiciones. '
    'Al registrarse, iniciar sesion o utilizar cualquier funcionalidad del servicio, el usuario acepta cumplir con las disposiciones establecidas en este documento.\n\n'
    'Si el usuario no esta de acuerdo con estos terminos, debera abstenerse de utilizar la plataforma.\n\n'
    '2. Uso de la plataforma\n\n'
    'verificARTE es una plataforma digital destinada al registro, publicacion y certificacion de obras artisticas.\n\n'
    'Los usuarios se comprometen a utilizar el servicio de manera responsable, respetando las normas de la plataforma y los derechos de terceros.\n\n'
    'Queda prohibido utilizar verificARTE para actividades fraudulentas, ilegales o que puedan afectar el correcto funcionamiento del servicio.\n\n'
    '3. Cuentas de usuario\n\n'
    'Para acceder a determinadas funciones, el usuario debera crear una cuenta o iniciar sesion mediante los metodos disponibles.\n\n'
    'El usuario es responsable de mantener la confidencialidad de sus credenciales de acceso y de todas las actividades realizadas desde su cuenta.\n\n'
    'La plataforma podra suspender o eliminar cuentas que incumplan estos terminos o que presenten un uso indebido del servicio.\n\n'
    '4. Contenido publicado por los usuarios\n\n'
    'Los usuarios pueden publicar y registrar obras dentro de verificARTE. Al hacerlo, el usuario declara que posee los derechos necesarios sobre el contenido que publica.\n\n'
    'El usuario es el unico responsable del contenido que comparte en la plataforma.\n\n'
    'No esta permitido publicar contenido que infrinja derechos de autor, que suplante la autoria de terceros o que viole las normas de la plataforma.\n\n'
    '5. Propiedad intelectual\n\n'
    'Los derechos de autor de las obras registradas pertenecen a sus respectivos creadores o titulares.\n\n'
    'verificARTE actua como una plataforma de registro y certificacion digital, sin reclamar la autoria de las obras publicadas por los usuarios.\n\n'
    '6. Certificados digitales\n\n'
    'La plataforma puede generar certificados digitales asociados a las obras registradas por los usuarios.\n\n'
    'Estos certificados tienen el objetivo de proporcionar una referencia de autenticidad dentro del sistema y pueden incluir informacion relacionada con la obra, su registro y su identificacion dentro de la plataforma.\n\n'
    '7. Marcas de agua\n\n'
    'Para proteger el origen del contenido publicado, verificARTE puede aplicar marcas de agua automaticas a las obras visualizadas dentro de la plataforma o a los certificados generados por el sistema.\n\n'
    'Estas marcas de agua identifican el origen del contenido dentro de verificARTE.\n\n'
    '8. Reportes y denuncias\n\n'
    'Los usuarios pueden reportar contenido o actividades que consideren que violan estos terminos.\n\n'
    'La administracion de verificARTE podra revisar dichas denuncias y tomar las medidas correspondientes, incluyendo la eliminacion de contenido o la aplicacion de sanciones.\n\n'
    '9. Sanciones y suspension de cuentas\n\n'
    'El incumplimiento de estos terminos podra resultar en medidas como advertencias, aplicacion de strikes, suspension temporal o eliminacion de la cuenta del usuario.\n\n'
    'verificARTE se reserva el derecho de aplicar estas medidas cuando lo considere necesario para proteger la integridad de la plataforma y su comunidad.\n\n'
    '10. Limitacion de responsabilidad\n\n'
    'verificARTE proporciona un servicio digital basado en contenido generado por los usuarios. Cada usuario es responsable del contenido que publica.\n\n'
    'La plataforma no se hace responsable por conflictos entre usuarios relacionados con derechos de autor o uso indebido del contenido fuera del sistema.\n\n'
    '11. Modificaciones de los terminos\n\n'
    'verificARTE se reserva el derecho de modificar estos Terminos y Condiciones en cualquier momento. Las modificaciones entraran en vigor una vez publicadas dentro de la plataforma.\n\n'
    '12. Contacto y administracion\n\n'
    'La administracion de verificARTE es responsable de la gestion del servicio y de la aplicacion de estos terminos dentro de la plataforma.';
const String _privacyNoticeLongText =
    'AVISO DE PRIVACIDAD - verificARTE\n\n'
    'En verificARTE, la privacidad de nuestros usuarios y la seguridad de su '
    'propiedad intelectual son nuestra prioridad. Este Aviso de Privacidad '
    'explica como recopilamos, usamos y protegemos su informacion personal al '
    'utilizar nuestra plataforma de registro y certificacion de obras '
    'artisticas.\n\n'
    '1. Responsable del Tratamiento de Datos\n\n'
    'La administracion de verificARTE es la entidad responsable de recabar sus '
    'datos personales, del uso que se le de a los mismos y de su proteccion, '
    'asegurando que el tratamiento sea legitimo, controlado e informado.\n\n'
    '2. Datos Personales que Recabamos\n\n'
    'Para cumplir con las finalidades senaladas en este documento, recabamos '
    'los siguientes datos:\n\n'
    '- Datos de Identificacion: Nombre completo, nombre artistico o '
    'seudonimo.\n'
    '- Datos de Contacto: Correo electronico.\n'
    '- Datos de Registro de Obra: Titulo de la obra, descripcion, archivos '
    'digitales de la obra y metadatos asociados.\n'
    '- Datos de Acceso: Credenciales de inicio de sesion y metodos de '
    'autenticacion.\n\n'
    '3. Finalidades del Tratamiento\n\n'
    'Utilizamos su informacion para las siguientes finalidades necesarias para '
    'el servicio:\n\n'
    '- Gestion de Cuentas: Crear y administrar su perfil de usuario.\n'
    '- Certificacion Digital: Generar certificados de autenticidad y registros '
    'vinculados a su identidad.\n'
    '- Proteccion de Contenido: Aplicar marcas de agua automaticas para '
    'identificar el origen de sus obras.\n'
    '- Seguridad: Monitorear el uso correcto de la plataforma, gestionar '
    'reportes de abuso y aplicar sanciones en caso de incumplimiento de los '
    'Terminos y Condiciones.\n'
    '- Comunicacion: Enviarle notificaciones administrativas sobre su cuenta o '
    'cambios en nuestros servicios.\n\n'
    '4. Proteccion de la Propiedad Intelectual\n\n'
    'De acuerdo con nuestros terminos, verificARTE no reclama la autoria de '
    'sus obras. Los datos y archivos subidos se utilizan exclusivamente para '
    'los fines de registro y certificacion solicitados por el usuario. La '
    'plataforma actua como un repositorio de fe publica digital para el '
    'creador.\n\n'
    '5. Transferencia de Datos\n\n'
    'verificARTE no vende, alquila ni comparte sus datos personales con '
    'terceros, salvo en los siguientes casos:\n\n'
    '- Cuando sea requerido por una autoridad judicial o administrativa '
    'competente.\n'
    '- Para la resolucion de disputas de derechos de autor, siempre que medie '
    'un proceso legal formal.\n'
    '- Cuando el usuario decida hacer publica su obra y perfil dentro de la '
    'plataforma para fines de exhibicion.\n\n'
    '6. Derechos ARCO (Acceso, Rectificacion, Cancelacion y Oposicion)\n\n'
    'Usted tiene derecho a conocer que datos personales tenemos de usted, para '
    'que los utilizamos y las condiciones del uso que les damos. Asimismo, es '
    'su derecho:\n\n'
    '- Acceder a su informacion.\n'
    '- Rectificarla en caso de que sea inexacta.\n'
    '- Cancelarla de nuestros registros cuando considere que no esta siendo '
    'utilizada adecuadamente.\n'
    '- Oponerse al uso de sus datos para fines especificos.\n\n'
    'Para ejercer estos derechos, puede gestionar su informacion directamente '
    'desde su cuenta o ponerse en contacto con la administracion de '
    'verificARTE.\n\n'
    '7. Uso de Cookies y Tecnologias de Rastreo\n\n'
    'Utilizamos cookies para mejorar la experiencia de navegacion, recordar su '
    'sesion y analizar el trafico de la plataforma. Puede desactivar las '
    'cookies desde la configuracion de su navegador, aunque esto podria '
    'afectar la funcionalidad de la plataforma.\n\n'
    '8. Modificaciones al Aviso de Privacidad\n\n'
    'Nos reservamos el derecho de efectuar en cualquier momento modificaciones '
    'o actualizaciones al presente Aviso de Privacidad para la atencion de '
    'novedades legislativas o politicas internas. Cualquier cambio sera '
    'publicado en esta misma seccion.\n\n'
    'Ultima actualizacion: 15 de marzo de 2026';

