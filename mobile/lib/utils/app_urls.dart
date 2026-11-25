class AppUrls {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000');
  static const String aiBaseUrl = String.fromEnvironment('AI_BASE_URL',
      defaultValue: 'http://127.0.0.1:8002'); // For direct AI calls if needed

  // Auth endpoints
  static const String register = "$baseUrl/auth/register";
  static const String login = "$baseUrl/auth/login";
  static const String forgotPassword = "$baseUrl/auth/forgot-password";
  static const String refresh = "$baseUrl/auth/refresh";
  static const String logout = "$baseUrl/auth/logout";
  static const String usersMe = "$baseUrl/auth/users/me";

  // Profile endpoints
  static const String profileCreate = "$baseUrl/profile/create";
  static const String profileGet = "$baseUrl/profile/get";
  static const String profileEdit = "$baseUrl/profile/edit";
  static const String profileMe = "$baseUrl/profile/me";

  // ✅ FIXED: Diet plan now goes through backend
  static const String dietPlan = "$baseUrl/diet-plan/generate";
  static const String dietPlanCustom = "$baseUrl/diet-plan/generate-custom";
  static const String dietPlanRetrain =
      "$baseUrl/diet-plan/retrain-and-generate"; // ✅ NEW
  static const String healthAnalysis = "$baseUrl/diet-plan/health-analysis";

  // Notifications
  static const String notificationsGet = "$baseUrl/notifications/get";
  static const String notificationsUnread =
      "$baseUrl/notifications/unread-count";
  static const String notificationsMarkRead =
      "$baseUrl/notifications/mark-read";
  static const String notificationsMarkAllRead =
      "$baseUrl/notifications/mark-all-read";

  // Daily Tracker - Add these// Add these to your existing AppUrls class in app_urls.dart
  static const String dailyTrackerGet = "$baseUrl/daily-tracker/get";
  static const String dailyTrackerHistory = "$baseUrl/daily-tracker/history";
  static const String dailyTrackerQuickLogGlucose =
      "$baseUrl/daily-tracker/quick-log-glucose";

  // Daily Tracker
  static const String dailyTracker = "$baseUrl/daily-tracker";
  static const String dailyTrackerCheck = "$baseUrl/daily-tracker/check";

  // Weekly Reports
  static const String weeklyReportGenerate = "$baseUrl/weekly-reports/generate";

  // User Settings (Privacy & Security)
  static const String userSettings = "$baseUrl/user-settings/settings";
  static const String changePassword = "$baseUrl/user-settings/change-password";
  static const String pushNotificationsGet =
      "$baseUrl/user-settings/push-notifications";
  static const String pushNotificationsPost =
      "$baseUrl/user-settings/push-notifications";
  static const String deleteAccount = "$baseUrl/user-settings/delete-account";
  static const String exportDataPdf = "$baseUrl/user-settings/export-data-pdf";
  // Helper method for Cloudinary URLs
  static String getCloudinaryUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return path;
  }
}
