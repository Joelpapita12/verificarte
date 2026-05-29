import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class AppColors {
  // Modo oscuro: azul marino casi negro. Modo claro: azul medio vibrante.
  static Color get azulMarino => ThemeService.instance.isDark
      ? const Color(0xFF0C1F41)
      : const Color(0xFF1565C0);

  static Color get azulProfundo => ThemeService.instance.isDark
      ? const Color(0xFF031035)
      : const Color(0xFF0D47A1);

  static const Color azulClaro = Color(0xFFDAE9FC);

  // Siempre blanco: el texto blanco funciona tanto en navy oscuro como en azul medio.
  static const Color blanco = Colors.white;

  static Color get grisBlue => ThemeService.instance.isDark
      ? const Color(0xFF627C9E)
      : const Color(0xFF90CAF9);

  static Color get colorEnlace => ThemeService.instance.isDark
      ? const Color(0xFF7FC4FF)
      : const Color(0xFFBBDEFB);

  static const Color statusAvailable = Color(0xFF0F5132);
  static const Color statusUnavailable = Color(0xFF7F1D1D);
}
