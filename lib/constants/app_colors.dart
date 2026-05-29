import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class AppColors {
  static Color get azulMarino => ThemeService.instance.isDark
      ? const Color(0xFF0C1F41)
      : const Color(0xFFF0F5FC);

  static Color get azulProfundo => ThemeService.instance.isDark
      ? const Color(0xFF031035)
      : const Color(0xFFE2ECF8);

  static Color get azulClaro => const Color(0xFFDAE9FC);

  static Color get blanco => ThemeService.instance.isDark
      ? Colors.white
      : const Color(0xFF0D1B2A);

  static Color get grisBlue => ThemeService.instance.isDark
      ? const Color(0xFF627C9E)
      : const Color(0xFF455A7A);

  static Color get colorEnlace => ThemeService.instance.isDark
      ? const Color(0xFF7FC4FF)
      : const Color(0xFF0D5FB3);

  static const Color statusAvailable = Color(0xFF0F5132);
  static const Color statusUnavailable = Color(0xFF7F1D1D);
}
