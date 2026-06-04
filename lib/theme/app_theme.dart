import 'package:flutter/material.dart';

// Paleta de colores verificARTE:
//   #192744 — navy muy oscuro
//   #3D5A8A — azul navy medio
//   #6B8DC5 — azul cornflower
//   #B5C8E8 — azul periwinkle claro
//   #EFF3FA — casi blanco

class AppTheme {
  AppTheme._();

  // Modo claro: fondo blanco/gris, acentos azules de la paleta.
  static final ThemeData lightTheme = ThemeData(
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF3D5A8A),
      onPrimary: Colors.white,
      secondary: Color(0xFF6B8DC5),
      onSecondary: Colors.white,
      error: Color(0xFFB00020),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF192744),
    ),
    scaffoldBackgroundColor: const Color(0xFFEFF3FA),
    fontFamily: 'Georgia',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF3D5A8A),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFB5C8E8),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFB5C8E8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFB5C8E8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF3D5A8A), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFB00020), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFB00020), width: 2),
      ),
      labelStyle: TextStyle(color: Color(0xFF6B8DC5)),
      hintStyle: TextStyle(color: Color(0xFFB5C8E8)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3D5A8A),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF3D5A8A),
        side: const BorderSide(color: Color(0xFF3D5A8A)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0xFF3D5A8A)),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: Color(0xFF192744),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF192744),
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Color(0xFF3D5A8A),
      ),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF3D5A8A)),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF3D5A8A),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );

  // Modo oscuro: azul marino casi negro — aspecto original.
  static final ThemeData darkTheme = ThemeData(
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Colors.white,
      onPrimary: Color(0xFF0C1F41),
      secondary: Color(0xFF5E7FB0),
      onSecondary: Colors.white,
      error: Color(0xFFCF6679),
      onError: Colors.black,
      surface: Color(0xFF0C1F41),
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF0C1F41),
    fontFamily: 'Georgia',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF071330),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: const Color(0xFF132040),
    dividerColor: const Color(0xFF2D4A7A),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF132040),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF2D4A7A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF2D4A7A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF5E7FB0), width: 1.5),
      ),
      labelStyle: TextStyle(color: Color(0xFF8EB0D9)),
      hintStyle: TextStyle(color: Color(0xFF627C9E)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E5FA3),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0xFF8EB0D9)),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: Colors.white,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Color(0xFF8EB0D9),
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF132040),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
