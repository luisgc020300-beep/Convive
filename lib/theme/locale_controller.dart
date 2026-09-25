// lib/theme/locale_controller.dart
//
// Preferencia de idioma, local al dispositivo -- mismo patrón que
// ThemeController. null = seguir el idioma del sistema.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _clavePrefs = 'convive_locale';

class LocaleController extends ChangeNotifier {
  LocaleController._(this._locale);

  static LocaleController? _instance;

  static LocaleController get instance => _instance!;

  Locale? _locale;
  Locale? get locale => _locale;

  static Future<LocaleController> load() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clavePrefs);
    _instance = LocaleController._(guardado == null ? null : Locale(guardado));
    return _instance!;
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_clavePrefs);
    } else {
      await prefs.setString(_clavePrefs, locale.languageCode);
    }
  }
}
