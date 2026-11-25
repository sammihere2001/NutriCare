import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nutricare/model/nutrition_plan_model.dart';
import 'package:nutricare/model/profile_setup_model.dart';
import 'package:nutricare/services/auth_service.dart';
import 'package:nutricare/utils/app_urls.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlanGenerationException implements Exception {
  final String message;
  final String code;
  const PlanGenerationException(this.message, this.code);
  @override
  String toString() => message;
}

class MealPlanService {
  static const String _keyMealPlan = 'cached_nutrition_plan';
  static const String _ownerKey = 'cached_nutrition_plan_owner';

  static Future<NutritionPlanResponse?> getCachedPlan() async {
    final auth = await AuthService().getAuth();
    if (auth == null) return null;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_ownerKey) != auth.user.userId) return null;
    final raw = prefs.getString(_keyMealPlan);
    if (raw == null) return null;
    try {
      final plan = NutritionPlanResponse.fromJson(jsonDecode(raw));
      if (plan.data.planningContext.engineVersion != 'medication_hybrid_v1')
        return null;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!plan.data.weeklyPlan
          .any((day) => DateTime.parse(day.date).isAtSameMomentAs(today)))
        return null;
      return plan;
    } catch (_) {
      return null;
    }
  }

  static Future<NutritionPlanResponse?> generateMealPlan(
      ProfileModel profile) async {
    try {
      final auth = await AuthService().getAuth();
      if (auth == null) return null;
      // The backend generates from the authenticated user's saved profile.
      final response = await http.post(
        Uri.parse(AppUrls.dietPlan),
        headers: {'Authorization': 'Bearer ${auth.accessToken}'},
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 422) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = body['detail'];
        throw PlanGenerationException(
            detail is Map
                ? (detail['message']?.toString() ??
                    'Please review your planning profile.')
                : detail is String
                    ? detail
                    : 'Please review your planning profile.',
            detail is Map
                ? (detail['code']?.toString() ?? 'planning_review_required')
                : 'planning_review_required');
      }
      if (response.statusCode != 200) return null;
      final plan = NutritionPlanResponse.fromJson(jsonDecode(response.body));
      if (plan.data.weeklyPlan.isEmpty) return null;
      final current = await AuthService().getAuth();
      if (current == null ||
          current.user.userId != auth.user.userId ||
          current.refreshToken != auth.refreshToken) return null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyMealPlan, jsonEncode(plan.toJson()));
      await prefs.setInt(_ownerKey, auth.user.userId);
      return plan;
    } on PlanGenerationException {
      rethrow;
    } catch (_) {
      // A failed regeneration must not destroy the previous usable plan.
      return null;
    }
  }

  // Compatibility for callers; regenerating meals does not require retraining.
  static Future<NutritionPlanResponse?> retrainAndGenerate(
          ProfileModel profile) =>
      generateMealPlan(profile);

  static Future<NutritionPlanResponse?> getMealPlan({ProfileModel? profile}) =>
      getCachedPlan();

  static Future<void> clearCachedPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMealPlan);
    await prefs.remove(_ownerKey);
  }
}
