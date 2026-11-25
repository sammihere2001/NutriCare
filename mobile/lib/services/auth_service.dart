import 'session_store.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutricare/model/auth_model.dart';
import 'package:nutricare/utils/app_urls.dart';
import 'package:nutricare/services/profile_services.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<AuthResponse?>? _refreshing;

  Future<void> saveSession(AuthResponse auth) async {
    final prefs = await SharedPreferences.getInstance();
    await UserProfileService.clearProfileCache();
    await prefs.remove('cached_nutrition_plan');
    await prefs.remove('cached_nutrition_plan_owner');
    await SessionStore.write(jsonEncode(auth.toJson()));
  }

  Future<AuthResponse?> getAuth() async {
    final raw = await SessionStore.read();
    if (raw == null) return null;
    AuthResponse auth;
    try {
      auth = AuthResponse.fromJson(jsonDecode(raw));
      final payload = jsonDecode(utf8.decode(base64Url
          .decode(base64Url.normalize(auth.accessToken.split('.')[1]))));
      final expiry = DateTime.fromMillisecondsSinceEpoch(
          (payload['exp'] as num).toInt() * 1000,
          isUtc: true);
      if (expiry
          .isAfter(DateTime.now().toUtc().add(const Duration(seconds: 30)))) {
        return auth;
      }
    } catch (_) {
      await _clearLocalSession();
      return null;
    }
    final pending = _refreshing;
    if (pending != null) return pending;
    final refresh = _refreshSession(auth, raw);
    _refreshing = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshing, refresh)) _refreshing = null;
    }
  }

  Future<AuthResponse?> _refreshSession(
      AuthResponse auth, String original) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppUrls.refresh),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': auth.refreshToken}),
          )
          .timeout(const Duration(seconds: 10));
      // A response from an old session must never restore it after logout/login.
      if (await SessionStore.read() != original) return null;
      if (response.statusCode == 200) {
        final updated = AuthResponse.fromJson(jsonDecode(response.body));
        return await SessionStore.replace(
                original, jsonEncode(updated.toJson()))
            ? updated
            : null;
      }
      if (response.statusCode == 401) {
        await _clearLocalSession(expected: original);
      }
    } catch (_) {
      // Keep the saved session on a temporary connection failure.
    }
    return null;
  }

  Future<String?> register(
      String email, String password, String firstName, String lastName) async {
    final response = await http
        .post(
          Uri.parse(AppUrls.register),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'first_name': firstName,
            'last_name': lastName
          }),
        )
        .timeout(const Duration(seconds: 20));
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) {
      await saveSession(AuthResponse.fromJson(result));
      return null;
    }
    final detail = result['detail'];
    return detail is String
        ? detail
        : 'Please check your registration details.';
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppUrls.login),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return false;
      await saveSession(AuthResponse.fromJson(jsonDecode(response.body)));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearLocalSession({String? expected}) async {
    if (!await SessionStore.clear(expected: expected)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_nutrition_plan');
    await prefs.remove('cached_nutrition_plan_owner');
    await UserProfileService.clearProfileCache();
  }

  Future<void> clearAuth() async {
    final raw = await SessionStore.read();
    await _clearLocalSession();
    if (raw == null) return;
    try {
      final refreshToken = jsonDecode(raw)['refresh_token'];
      if (refreshToken == null) return;
      await http
          .post(
            Uri.parse(AppUrls.logout),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Local logout still succeeds if the server cannot be reached.
    }
  }

  Future<void> updateAuthUser(User updatedUser) async {
    final raw = await SessionStore.read();
    if (raw == null) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['user']?['user_id'] != updatedUser.userId) return;
    data['user'] = updatedUser.toJson();
    await SessionStore.replace(raw, jsonEncode(data));
  }
}
