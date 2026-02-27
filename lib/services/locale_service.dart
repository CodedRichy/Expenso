import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  static const _key = 'number_locale';
  String? _localeCode;

  String? get localeCode => _localeCode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _localeCode = prefs.getString(_key);
    notifyListeners();
  }

  Future<void> setLocale(String? code) async {
    if (_localeCode == code) return;
    _localeCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, code);
    }
  }

  static const List<MapEntry<String, String>> options = [
    MapEntry('Device default', ''),
    MapEntry('India (en_IN)', 'en_IN'),
    MapEntry('United States (en_US)', 'en_US'),
    MapEntry('United Kingdom (en_GB)', 'en_GB'),
    MapEntry('Germany (de_DE)', 'de_DE'),
    MapEntry('France (fr_FR)', 'fr_FR'),
  ];
}
