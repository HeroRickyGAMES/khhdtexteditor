// app_settings.dart
// Configurações persistentes do motor de tradução via SharedPreferences.
// Programado por HeroRickyGAMES com a ajuda de Deus!

import 'package:shared_preferences/shared_preferences.dart';
import 'kh1_exchange.dart';

class AppSettings {
  static const String _keyPref        = 'translator_pref';
  static const String _keyLlamaUrl    = 'llama_url';
  static const String _keyHelsinkiUrl = 'helsinki_url';

  // Padrão: Google Translate (sempre disponível, sem dependências externas)
  static const String defaultPref        = 'google';
  static const String defaultLlamaUrl    = 'http://127.0.0.1:8080';
  static const String defaultHelsinkiUrl = 'http://127.0.0.1:7654';

  final SharedPreferences _prefs;
  AppSettings._(this._prefs);

  static Future<AppSettings> load() async =>
      AppSettings._(await SharedPreferences.getInstance());

  String get translatorPref => _prefs.getString(_keyPref)        ?? defaultPref;
  String get llamaUrl        => _prefs.getString(_keyLlamaUrl)    ?? defaultLlamaUrl;
  String get helsinkiUrl     => _prefs.getString(_keyHelsinkiUrl) ?? defaultHelsinkiUrl;

  Future<void> saveAll({
    required String pref,
    required String llamaUrl,
    required String helsinkiUrl,
  }) async {
    await _prefs.setString(_keyPref,        pref);
    await _prefs.setString(_keyLlamaUrl,    llamaUrl);
    await _prefs.setString(_keyHelsinkiUrl, helsinkiUrl);
  }

  /// Constrói o adaptador de tradução de acordo com a preferência salva.
  TranslatorAdapter buildAdapter() =>
      FallbackTranslatorAdapter.fromPreference(translatorPref, llamaUrl, helsinkiUrl);
}
