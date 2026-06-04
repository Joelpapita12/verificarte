import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class AppColors {
  // Oscuro: navy casi negro. Claro: azul navy medio de la paleta.
  static Color get azulMarino => ThemeService.instance.isDark
      ? const Color(0xFF0C1F41)
      : const Color(0xFF3D5A8A);

  static Color get azulProfundo => ThemeService.instance.isDark
      ? const Color(0xFF031035)
      : const Color(0xFF192744);

  static Color get fondoPrincipal => ThemeService.instance.isDark
      ? const Color(0xFF0C1F41)
      : const Color(0xFFEFF3FA);

  static const Color azulClaro = Color(0xFFEFF3FA);
  static const Color blanco = Colors.white;

  static Color get grisBlue => ThemeService.instance.isDark
      ? const Color(0xFF627C9E)
      : const Color(0xFF6B8DC5);

  static Color get colorEnlace => ThemeService.instance.isDark
      ? const Color(0xFF7FC4FF)
      : const Color(0xFF3D5A8A);

  static Color get textoSobreFondo => ThemeService.instance.isDark
      ? Colors.white
      : const Color(0xFF192744);

  static const Color statusAvailable = Color(0xFF0F5132);
  static const Color statusUnavailable = Color(0xFF7F1D1D);
}
