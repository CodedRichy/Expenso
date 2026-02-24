import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _key = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    switch (value) {
      case 'light':
        _themeMode = ThemeMode.light;
      case 'dark':
        _themeMode = ThemeMode.dark;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_key, 'light');
      case ThemeMode.dark:
        await prefs.setString(_key, 'dark');
      case ThemeMode.system:
        await prefs.remove(_key);
    }
  }

  String get label {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  IconData get icon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}
