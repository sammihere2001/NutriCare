import 'mealplan_service.dart';
import 'package:nutricare/services/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_urls.dart';

class DailyTrackerData {
  final bool exists;
  final int? trackerId;
  final String? trackerDate;
  final double morningGlucose;
  final double eveningGlucose;
  final double weight;
  final double exercise;
  final String? exerciseTime;
  final double waterIntake;
  final double sleepHours;
  final double stressLevel;
  final String? notes;
  final List<MealData> meals;

  DailyTrackerData({
    required this.exists,
    this.trackerId,
    this.trackerDate,
    this.morningGlucose = 0,
    this.eveningGlucose = 0,
    this.weight = 0,
    this.exercise = 0,
    this.exerciseTime,
    this.waterIntake = 0,
    this.sleepHours = 0,
    this.stressLevel = 0,
    this.notes,
    this.meals = const [],
  });

  factory DailyTrackerData.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data == null) {
      return DailyTrackerData(exists: false);
    }

    List<MealData> meals = [];
    if (data['meals'] != null) {
      meals = (data['meals'] as List).map((m) => MealData.fromJson(m)).toList();
    }

    return DailyTrackerData(
      exists: true,
      trackerId: data['tracker_id'],
      trackerDate: data['tracker_date'],
      morningGlucose: (data['morning_glucose'] ?? 0).toDouble(),
      eveningGlucose: (data['evening_glucose'] ?? 0).toDouble(),
      weight: (data['weight'] ?? 0).toDouble(),
      exercise: (data['exercise'] ?? 0).toDouble(),
      exerciseTime: data['exercise_time'],
      waterIntake: (data['water_intake'] ?? 0).toDouble(),
      sleepHours: (data['sleep_hours'] ?? 0).toDouble(),
      stressLevel: (data['stress_level'] ?? 0).toDouble(),
      notes: data['notes'],
      meals: meals,
    );
  }

  // Helper getters for dashboard
  bool get hasMorningGlucose => morningGlucose > 0;
  bool get hasEveningGlucose => eveningGlucose > 0;
  bool get hasCompleteData =>
      hasMorningGlucose && hasEveningGlucose && weight > 0 && waterIntake > 0;
  bool get hasPartialData =>
      hasMorningGlucose || hasEveningGlucose || waterIntake > 0;

  double get averageGlucose {
    if (hasMorningGlucose && hasEveningGlucose) {
      return (morningGlucose + eveningGlucose) / 2;
    } else if (hasMorningGlucose) {
      return morningGlucose;
    } else if (hasEveningGlucose) {
      return eveningGlucose;
    }
    return 0;
  }

  String getMorningGlucoseStatus() {
    if (!hasMorningGlucose) return 'No Data';
    if (morningGlucose < 70) return 'Low';
    if (morningGlucose <= 130) return 'Normal';
    if (morningGlucose <= 180) return 'High';
    return 'Very High';
  }

  String getEveningGlucoseStatus() {
    if (!hasEveningGlucose) return 'No Data';
    if (eveningGlucose < 70) return 'Low';
    if (eveningGlucose <= 140) return 'Normal';
    if (eveningGlucose <= 180) return 'High';
    return 'Very High';
  }

  bool get isMorningNormal => getMorningGlucoseStatus() == 'Normal';
  bool get isEveningNormal => getEveningGlucoseStatus() == 'Normal';
}

class MealData {
  final String mealName;
  final double calories;
  final String mealTime;
  final String mealType;

  MealData({
    required this.mealName,
    required this.calories,
    required this.mealTime,
    required this.mealType,
  });

  factory MealData.fromJson(Map<String, dynamic> json) {
    return MealData(
      mealName: json['meal_name'] ?? '',
      calories: (json['calories'] ?? 0).toDouble(),
      mealTime: json['meal_time'] ?? '',
      mealType: json['meal_type'] ?? 'Snack',
    );
  }
}

class GlucoseHistoryData {
  final String date;
  final double morningGlucose;
  final double eveningGlucose;

  GlucoseHistoryData({
    required this.date,
    this.morningGlucose = 0,
    this.eveningGlucose = 0,
  });

  factory GlucoseHistoryData.fromJson(Map<String, dynamic> json) {
    return GlucoseHistoryData(
      date: json['tracker_date'] ?? '',
      morningGlucose: (json['morning_glucose'] ?? 0).toDouble(),
      eveningGlucose: (json['evening_glucose'] ?? 0).toDouble(),
    );
  }
}

class DailyTrackerService {
  static DailyTrackerService? _instance;

  factory DailyTrackerService() {
    _instance ??= DailyTrackerService._internal();
    return _instance!;
  }

  DailyTrackerService._internal();

  Future<String?> _getToken() async {
    final currentAuth = await AuthService().getAuth();
    final authDataString =
        currentAuth == null ? null : jsonEncode(currentAuth.toJson());
    if (authDataString == null) return null;

    final Map<String, dynamic> authData = jsonDecode(authDataString);
    return authData['access_token'];
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  Future<DailyTrackerData> getTodayTracker() async {
    try {
      final today = DateTime.now();
      final dateStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      final url = Uri.parse('${AppUrls.dailyTrackerGet}?tracker_date=$dateStr');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return DailyTrackerData.fromJson(jsonDecode(response.body));
      }

      return DailyTrackerData(exists: false);
    } catch (e) {
      print("Error fetching today's tracker: $e");
      return DailyTrackerData(exists: false);
    }
  }

  Future<List<GlucoseHistoryData>> getGlucoseHistory({int days = 7}) async {
    try {
      final url = Uri.parse('${AppUrls.dailyTrackerHistory}?days=$days');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final history = data['history'] as List?;

        if (history != null) {
          return history.map((h) => GlucoseHistoryData.fromJson(h)).toList();
        }
      }

      return [];
    } catch (e) {
      print("Error fetching glucose history: $e");
      return [];
    }
  }

  Future<bool> quickLogGlucose({
    required String glucoseType,
    required double glucoseValue,
  }) async {
    try {
      final today = DateTime.now();
      final dateStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      // Build URL with query parameters
      final url = Uri.parse('${AppUrls.dailyTrackerQuickLogGlucose}'
          '?tracker_date=$dateStr'
          '&glucose_type=$glucoseType'
          '&glucose_value=$glucoseValue');

      final headers = await _getHeaders();

      final response = await http.post(
        url,
        headers: headers,
        // Don't send JSON body for query parameters
      );

      print("Quick log response: ${response.statusCode}");

      if (response.statusCode == 200) await MealPlanService.clearCachedPlan();
      return response.statusCode == 200;
    } catch (e) {
      print("Error logging glucose: $e");
      return false;
    }
  }
}
