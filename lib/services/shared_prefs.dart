import 'package:shared_preferences/shared_preferences.dart';

/// Shared Preferences ile ilgili yardımcı fonksiyonlar
class SharedPrefs {
  static SharedPreferences? _prefs;

  // SharedPreferences örneğini başlat
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // String değer kaydetme
  static Future<bool> setString(String key, String value) async {
    if (_prefs == null) await init();
    return await _prefs!.setString(key, value);
  }

  // String değer okuma
  static String getString(String key, {String defaultValue = ''}) {
    if (_prefs == null) return defaultValue;
    return _prefs!.getString(key) ?? defaultValue;
  }

  // Boolean değer kaydetme
  static Future<bool> setBool(String key, bool value) async {
    if (_prefs == null) await init();
    return await _prefs!.setBool(key, value);
  }

  // Boolean değer okuma
  static bool getBool(String key, {bool defaultValue = false}) {
    if (_prefs == null) return defaultValue;
    return _prefs!.getBool(key) ?? defaultValue;
  }

  // Int değer kaydetme
  static Future<bool> setInt(String key, int value) async {
    if (_prefs == null) await init();
    return await _prefs!.setInt(key, value);
  }

  // Int değer okuma
  static int getInt(String key, {int defaultValue = 0}) {
    if (_prefs == null) return defaultValue;
    return _prefs!.getInt(key) ?? defaultValue;
  }

  // Değer silme
  static Future<bool> remove(String key) async {
    if (_prefs == null) await init();
    return await _prefs!.remove(key);
  }

  // Tüm değerleri silme
  static Future<bool> clear() async {
    if (_prefs == null) await init();
    return await _prefs!.clear();
  }
} 