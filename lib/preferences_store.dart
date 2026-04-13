import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PreferencesStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

class SharedPreferencesStore implements PreferencesStore {
  SharedPreferencesStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> getString(String key) => _prefs.getString(key);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}
