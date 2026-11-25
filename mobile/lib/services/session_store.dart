import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serializes session storage operations, including migration from older builds.
class SessionStore {
  static const key = 'nutricare_auth_session';
  static const _storage = FlutterSecureStorage();
  static Future<void> _pending = Future<void>.value();

  static Future<T> _locked<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<String?> _read() async {
    final prefs = await SharedPreferences.getInstance();
    var raw = await _storage.read(key: key);
    final legacy = prefs.getString('auth_data');
    if (raw == null && legacy != null) {
      // Delete the legacy copy only after secure storage confirms the write.
      await _storage.write(key: key, value: legacy);
      raw = legacy;
    }
    await prefs.remove('auth_data');
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    return raw;
  }

  static Future<String?> read() => _locked(_read);

  static Future<void> write(String raw) => _locked(() async {
        await _storage.write(key: key, value: raw);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_data');
        await prefs.remove('access_token');
        await prefs.remove('refresh_token');
      });

  static Future<bool> replace(String expected, String raw) => _locked(() async {
        if (await _read() != expected) return false;
        await _storage.write(key: key, value: raw);
        return true;
      });

  static Future<bool> clear({String? expected}) => _locked(() async {
        if (expected != null && await _read() != expected) return false;
        await _storage.delete(key: key);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_data');
        await prefs.remove('access_token');
        await prefs.remove('refresh_token');
        return true;
      });
}
