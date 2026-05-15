import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gère la langue de l'application (fr / en / ar).
/// L'arabe déclenche automatiquement le mode RTL via flutter_localizations.
class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_locale';

  Locale _locale = const Locale('fr');
  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;
  bool get isRtl => _locale.languageCode == 'ar';

  LocaleProvider() {
    _load();
  }

  Future<void> setLocale(String languageCode) async {
    if (_locale.languageCode == languageCode) return;
    _locale = Locale(languageCode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, languageCode);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'fr';
    _locale = Locale(code);
    notifyListeners();
  }
}
