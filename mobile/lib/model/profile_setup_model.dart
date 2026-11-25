import 'treatment_model.dart';

class ProfileModel {
  TreatmentProfile treatment;
  int? userId;
  String? name;
  String? email;
  String? gender;
  int? age;
  double? weight;
  double? height;
  String? diabetesStatus;
  bool? insulinUsage;
  num? insulinMorningUnits; // ✅ New field - Morning insulin units
  num? insulinNightUnits; // ✅ New field - Night insulin units
  String? activityLevel;
  List<int>? healthGoals;
  List<int>? dietaryPreferences;
  BloodSugar? bloodSugar;
  bool? profileCompleted;
  String? profileImagePath;

  ProfileModel({
    this.treatment = const TreatmentProfile(),
    this.userId,
    this.name,
    this.email,
    this.gender,
    this.age,
    this.weight,
    this.height,
    this.diabetesStatus,
    this.insulinUsage,
    this.insulinMorningUnits, // ✅ New
    this.insulinNightUnits, // ✅ New
    this.activityLevel,
    this.healthGoals,
    this.dietaryPreferences,
    this.bloodSugar,
    this.profileImagePath,
    this.profileCompleted,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    // FIX: Prefer 'name' field, otherwise construct from first_name + last_name
    String constructedName = json['name'] as String? ?? '';
    if (constructedName.isEmpty &&
        (json['first_name'] != null || json['last_name'] != null)) {
      constructedName =
          "${json['first_name'] ?? ''} ${json['last_name'] ?? ''}".trim();
    }

    return ProfileModel(
      treatment: json['treatment'] is Map
          ? TreatmentProfile.fromJson(
              Map<String, dynamic>.from(json['treatment']))
          : const TreatmentProfile().withInsulin(json['insulin_usage'] == true),
      userId: json['user_id'],
      name: constructedName,
      email: json['email'],
      gender: json['gender'],
      age: json['age'],
      weight: (json['weight_kg'] != null)
          ? (json['weight_kg'] as num).toDouble()
          : null,
      height: (json['height_cm'] != null)
          ? (json['height_cm'] as num).toDouble()
          : null,
      diabetesStatus: json['diabetes_status'],
      insulinUsage: json['insulin_usage'],
      insulinMorningUnits: json['insulin_morning_units'], // ✅ New
      insulinNightUnits: json['insulin_night_units'], // ✅ New
      activityLevel: json['activity_level'],
      healthGoals: (json['health_goals'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      dietaryPreferences: (json['dietary_preferences'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      profileCompleted: json['profile_completed'] ?? false,
      profileImagePath: json['profile_picture'],
      bloodSugar: json['blood_sugar'] != null
          ? BloodSugar.fromJson(json['blood_sugar'])
          : json['latest_blood_sugar'] != null
              ? BloodSugar(
                  readingValue: (json['latest_blood_sugar'] as num).toDouble(),
                  readingUnit: 'mg/dL')
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'treatment': treatment.toJson(),
      'user_id': userId,
      'name': name,
      'email': email,
      'profile_picture': profileImagePath,
      'age': age,
      'gender': gender?.toLowerCase(),
      'weight_kg': weight,
      'height_cm': height,
      'diabetes_status': diabetesStatus,
      'insulin_usage': insulinUsage,
      'insulin_morning_units': insulinMorningUnits, // ✅ New
      'insulin_night_units': insulinNightUnits, // ✅ New
      'activity_level': activityLevel,
      'health_goals': healthGoals,
      'dietary_preferences': dietaryPreferences,
      'blood_sugar': bloodSugar?.toJson(),
      'profile_completed': profileCompleted,
    };
  }
}

class BloodSugar {
  double? readingValue;
  String? readingUnit;
  String? notes;

  BloodSugar({this.readingValue, this.readingUnit, this.notes});

  factory BloodSugar.fromJson(Map<String, dynamic> json) {
    return BloodSugar(
      readingValue: (json['reading_value'] != null)
          ? (json['reading_value'] as num).toDouble()
          : null,
      readingUnit: json['reading_unit'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reading_value': readingValue,
      'reading_unit': readingUnit ?? 'mg/dL',
      'notes': notes,
    };
  }
}
