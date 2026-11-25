import 'package:nutricare/services/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/notification_model.dart';
import '../utils/app_urls.dart';

class NotificationService {
  static const String _baseUrl = '${AppUrls.baseUrl}/notifications';

  // Listeners for real-time updates
  static final List<void Function(int)> _unreadCountListeners = [];

  static void addUnreadCountListener(void Function(int) listener) {
    _unreadCountListeners.add(listener);
  }

  static void removeUnreadCountListener(void Function(int) listener) {
    _unreadCountListeners.remove(listener);
  }

  static void _notifyUnreadCountListeners(int count) {
    for (var listener in _unreadCountListeners) {
      listener(count);
    }
  }

  // Get all notifications for current user
  static Future<List<NotificationModel>> getNotifications() async {
    try {
      final currentAuth = await AuthService().getAuth();
      final authDataString =
          currentAuth == null ? null : jsonEncode(currentAuth.toJson());

      if (authDataString == null) return [];

      final authData = jsonDecode(authDataString);
      final token = authData['access_token'];

      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/get'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => NotificationModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("Error getting notifications: $e");
      return [];
    }
  }

  // Get unread count
  static Future<int> getUnreadCount() async {
    try {
      final currentAuth = await AuthService().getAuth();
      final authDataString =
          currentAuth == null ? null : jsonEncode(currentAuth.toJson());

      if (authDataString == null) return 0;

      final authData = jsonDecode(authDataString);
      final token = authData['access_token'];

      if (token == null) return 0;

      final response = await http.get(
        Uri.parse('$_baseUrl/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final count = data['count'] ?? 0;
        _notifyUnreadCountListeners(count);
        return count;
      }
      return 0;
    } catch (e) {
      print("Error getting unread count: $e");
      return 0;
    }
  }

  // Force refresh unread count
  static Future<void> refreshUnreadCount() async {
    await getUnreadCount();
  }

  // Mark notification as read
  static Future<bool> markAsRead(int notificationId) async {
    try {
      final currentAuth = await AuthService().getAuth();
      final authDataString =
          currentAuth == null ? null : jsonEncode(currentAuth.toJson());

      if (authDataString == null) return false;

      final authData = jsonDecode(authDataString);
      final token = authData['access_token'];

      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/mark-read/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Immediately refresh count after marking as read
        await refreshUnreadCount();
        return true;
      }
      return false;
    } catch (e) {
      print("Error marking notification as read: $e");
      return false;
    }
  }

  // Mark all as read
  static Future<bool> markAllAsRead() async {
    try {
      final currentAuth = await AuthService().getAuth();
      final authDataString =
          currentAuth == null ? null : jsonEncode(currentAuth.toJson());

      if (authDataString == null) return false;

      final authData = jsonDecode(authDataString);
      final token = authData['access_token'];

      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/mark-all-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        await refreshUnreadCount();
        return true;
      }
      return false;
    } catch (e) {
      print("Error marking all as read: $e");
      return false;
    }
  }

  // Delete single notification
  static Future<bool> deleteNotification(int notificationId) async {
    try {
      final currentAuth = await AuthService().getAuth();
      final authDataString =
          currentAuth == null ? null : jsonEncode(currentAuth.toJson());
      if (authDataString == null) return false;

      final authData = jsonDecode(authDataString);
      final token = authData['access_token'];
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/delete/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        await refreshUnreadCount();
        return true;
      }
      return false;
    } catch (e) {
      print("Error deleting notification: $e");
      return false;
    }
  }

  // Delete all notifications
  static Future<bool> deleteAllNotifications() async {
    try {
      final currentAuth = await AuthService().getAuth();
      final authDataString =
          currentAuth == null ? null : jsonEncode(currentAuth.toJson());
      if (authDataString == null) return false;

      final authData = jsonDecode(authDataString);
      final token = authData['access_token'];
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/delete-all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        await refreshUnreadCount();
        return true;
      }
      return false;
    } catch (e) {
      print("Error deleting all notifications: $e");
      return false;
    }
  }
}
