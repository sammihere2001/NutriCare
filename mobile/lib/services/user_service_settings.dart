import 'package:nutricare/services/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nutricare/utils/app_urls.dart';

class UserSettingsService {
  static Future<String?> _getToken() async {
    final currentAuth = await AuthService().getAuth();
    final authDataString =
        currentAuth == null ? null : jsonEncode(currentAuth.toJson());
    if (authDataString == null) return null;

    final Map<String, dynamic> authData = jsonDecode(authDataString);
    return authData['access_token'];
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  // Get user settings summary
  static Future<Map<String, dynamic>?> getSettings() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(AppUrls.userSettings),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Error getting settings: $e");
      return null;
    }
  }

  // Change password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(AppUrls.changePassword),
        headers: headers,
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': result['message']};
      } else {
        return {
          'success': false,
          'message': result['detail'] ?? 'Failed to change password'
        };
      }
    } catch (e) {
      print("Error changing password: $e");
      return {
        'success': false,
        'message': 'Connection error. Please try again.'
      };
    }
  }

  // Get push notification status
  static Future<Map<String, dynamic>?> getPushNotificationStatus() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(AppUrls.pushNotificationsGet),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Error getting push notification status: $e");
      return null;
    }
  }

  // Toggle push notifications
  static Future<Map<String, dynamic>> togglePushNotifications({
    required bool enabled,
    String? deviceToken,
    String? platform,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'enabled': enabled,
      };

      if (enabled && deviceToken != null && platform != null) {
        body['device_token'] = deviceToken;
        body['platform'] = platform;
      }

      final response = await http.post(
        Uri.parse(AppUrls.pushNotificationsPost),
        headers: headers,
        body: jsonEncode(body),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': result['message'],
          'push_enabled': result['push_enabled']
        };
      } else {
        return {
          'success': false,
          'message': result['detail'] ?? 'Failed to update settings'
        };
      }
    } catch (e) {
      print("Error toggling push notifications: $e");
      return {
        'success': false,
        'message': 'Connection error. Please try again.'
      };
    }
  }

  // Delete account
  static Future<Map<String, dynamic>> deleteAccount({
    required String password,
    required bool confirmDelete,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse(AppUrls.deleteAccount),
        headers: headers,
        body: jsonEncode({
          'password': password,
          'confirm_delete': confirmDelete,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': result['message']};
      } else {
        return {
          'success': false,
          'message': result['detail'] ?? 'Failed to delete account'
        };
      }
    } catch (e) {
      print("Error deleting account: $e");
      return {
        'success': false,
        'message': 'Connection error. Please try again.'
      };
    }
  }

  // Export user data
  static Future<Map<String, dynamic>?> exportData() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(AppUrls.exportDataPdf),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Error exporting data: $e");
      return null;
    }
  }
}
