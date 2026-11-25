class NutritionPlanResponse {
  final bool success;
  final String message;
  final NutritionPlanData data;

  NutritionPlanResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory NutritionPlanResponse.fromJson(Map<String, dynamic> json) {
    return NutritionPlanResponse(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String? ?? '',
      // ✅ Backend wraps data in 'data' key
      data: NutritionPlanData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data.toJson(),
    };
  }
}

class NutritionPlanData {
  final PlanningContext planningContext;
  final HealthAnalysis
      healthAnalysis; // ✅ NEW: Health metrics + nutrition averages
  final HealthConditions
      healthConditions; // ✅ NEW: Diabetes, insulin, blood sugar
  final String recommendedPlanType;
  final String mealCategory;
  final List<WeeklyDayPlan> weeklyPlan;

  NutritionPlanData({
    this.planningContext = const PlanningContext(),
    required this.healthAnalysis,
    required this.healthConditions,
    required this.recommendedPlanType,
    required this.mealCategory,
    required this.weeklyPlan,
  });

  factory NutritionPlanData.fromJson(Map<String, dynamic> json) {
    return NutritionPlanData(
      planningContext: PlanningContext.fromJson(
          Map<String, dynamic>.from(json['planning_context'] as Map? ?? {})),
      healthAnalysis: HealthAnalysis.fromJson(
          json['health_analysis'] as Map<String, dynamic>),
      healthConditions: HealthConditions.fromJson(
          json['health_conditions'] as Map<String, dynamic>),
      recommendedPlanType: json['recommended_plan_type'] as String? ?? '',
      mealCategory: json['meal_category'] as String? ?? '',
      weeklyPlan: (json['weekly_plan'] as List<dynamic>)
          .map((e) => WeeklyDayPlan.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'health_analysis': healthAnalysis.toJson(),
      'planning_context': planningContext.toJson(),
      'health_conditions': healthConditions.toJson(),
      'recommended_plan_type': recommendedPlanType,
      'meal_category': mealCategory,
      'weekly_plan': weeklyPlan.map((day) => day.toJson()).toList(),
    };
  }
}

class PlanningContext {
  final String engineVersion;
  final Map<String, dynamic> details;
  const PlanningContext(
      {this.engineVersion = 'legacy', this.details = const {}});

  factory PlanningContext.fromJson(Map<String, dynamic> json) =>
      PlanningContext(
          engineVersion: json['engine_version'] as String? ?? 'legacy',
          details: json);

  List<String> get medicationClasses =>
      (details['medication_context']?['medication_classes'] as List? ?? [])
          .whereType<String>()
          .toList();
  List<String> get warnings =>
      (details['warnings'] as List? ?? []).whereType<String>().toList();
  List<String> get reasons =>
      (details['ranking_reasons'] as List? ?? []).whereType<String>().toList();
  Map<String, dynamic> toJson() =>
      {...details, 'engine_version': engineVersion};
}

/// ✅ NEW: Health Analysis Model
class HealthAnalysis {
  final double bmi;
  final String bmiStatus;
  final double bmr;
  final double tdee;
  final double targetCalories;
  final double avgDailyCalories;
  final double avgDailyProtein;
  final double avgDailyCarbs;
  final double avgDailyFat;

  HealthAnalysis({
    required this.bmi,
    required this.bmiStatus,
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.avgDailyCalories,
    required this.avgDailyProtein,
    required this.avgDailyCarbs,
    required this.avgDailyFat,
  });

  factory HealthAnalysis.fromJson(Map<String, dynamic> json) {
    return HealthAnalysis(
      bmi: (json['bmi'] as num).toDouble(),
      bmiStatus: json['bmi_status'] as String? ?? 'Normal',
      bmr: (json['bmr'] as num).toDouble(),
      tdee: (json['tdee'] as num).toDouble(),
      targetCalories: (json['target_calories'] as num).toDouble(),
      avgDailyCalories: (json['avg_daily_calories'] as num?)?.toDouble() ?? 0,
      avgDailyProtein: (json['avg_daily_protein'] as num?)?.toDouble() ?? 0,
      avgDailyCarbs: (json['avg_daily_carbs'] as num?)?.toDouble() ?? 0,
      avgDailyFat: (json['avg_daily_fat'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bmi': bmi,
      'bmi_status': bmiStatus,
      'bmr': bmr,
      'tdee': tdee,
      'target_calories': targetCalories,
      'avg_daily_calories': avgDailyCalories,
      'avg_daily_protein': avgDailyProtein,
      'avg_daily_carbs': avgDailyCarbs,
      'avg_daily_fat': avgDailyFat,
    };
  }
}

/// ✅ NEW: Health Conditions Model
class HealthConditions {
  final bool hasDiabetes;
  final bool usesInsulin;
  final double insulinMorning;
  final double insulinNight;
  final int bloodSugarLevel;

  HealthConditions({
    required this.hasDiabetes,
    required this.usesInsulin,
    required this.insulinMorning,
    required this.insulinNight,
    required this.bloodSugarLevel,
  });

  factory HealthConditions.fromJson(Map<String, dynamic> json) {
    return HealthConditions(
      hasDiabetes: json['has_diabetes'] as bool? ?? false,
      usesInsulin: json['uses_insulin'] as bool? ?? false,
      insulinMorning: (json['insulin_morning'] as num?)?.toDouble() ?? 0.0,
      insulinNight: (json['insulin_night'] as num?)?.toDouble() ?? 0.0,
      bloodSugarLevel: json['blood_sugar_level'] as int? ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_diabetes': hasDiabetes,
      'uses_insulin': usesInsulin,
      'insulin_morning': insulinMorning,
      'insulin_night': insulinNight,
      'blood_sugar_level': bloodSugarLevel,
    };
  }
}

// ✅ EXISTING MODELS (keep as they are)
class WeeklyDayPlan {
  final String? sourcePlanId;
  final int day;
  final String date;
  final List<Meal> meals;
  final DailyTotals dailyTotals;

  WeeklyDayPlan({
    this.sourcePlanId,
    required this.day,
    required this.date,
    required this.meals,
    required this.dailyTotals,
  });

  factory WeeklyDayPlan.fromJson(Map<String, dynamic> json) {
    return WeeklyDayPlan(
      sourcePlanId: json['source_plan_id'] as String?,
      day: json['day'] as int,
      date: json['date'] as String,
      meals: (json['meals'] as List<dynamic>)
          .map((e) => Meal.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailyTotals:
          DailyTotals.fromJson(json['daily_totals'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        if (sourcePlanId != null) 'source_plan_id': sourcePlanId,
        'day': day,
        'date': date,
        'meals': meals.map((m) => m.toJson()).toList(),
        'daily_totals': dailyTotals.toJson(),
      };
}

class Meal {
  final String mealType;
  final String time;
  final Food food;

  Meal({required this.mealType, required this.time, required this.food});

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        mealType: json['meal_type'] as String,
        time: json['time'] as String,
        food: Food.fromJson(json['food'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'meal_type': mealType,
        'time': time,
        'food': food.toJson(),
      };
}

class Food {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  Food(
      {required this.name,
      required this.calories,
      required this.protein,
      required this.carbs,
      required this.fat});

  factory Food.fromJson(Map<String, dynamic> json) => Food(
        name: json['name'] as String,
        calories: (json['calories'] as num).toDouble(),
        protein: (json['protein'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };
}

class DailyTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  DailyTotals(
      {required this.calories,
      required this.protein,
      required this.carbs,
      required this.fat});

  factory DailyTotals.fromJson(Map<String, dynamic> json) => DailyTotals(
        calories: (json['calories'] as num).toDouble(),
        protein: (json['protein'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };
}
