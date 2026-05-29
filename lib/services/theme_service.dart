import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._internal();

  bool _isDark = true;

  ThemeService._internal() {
    try {
      final stored = html.window.localStorage['theme_mode'];
      _isDark = stored != 'light';
    } catch (_) {}
  }

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggle() {
    _isDark = !_isDark;
    try {
      html.window.localStorage['theme_mode'] = _isDark ? 'dark' : 'light';
    } catch (_) {}
    notifyListeners();
  }
}
