import 'dart:convert';
import 'dart:io';
import 'package:nutricare/model/auth_model.dart';
import 'package:nutricare/model/profile_setup_model.dart';
import 'package:nutricare/services/auth_service.dart';
import 'package:nutricare/utils/app_urls.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class UserProfileService {
  static const String _keyProfile = 'user_profile';
  static ProfileModel? _cachedProfile;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 1);
  static Future<ProfileModel?>? _pendingFetch;
  static String? _pendingSession;
  static int _cacheGeneration = 0;
  static bool _isEditing = false;

  // Listeners for profile updates
  static final List<void Function(ProfileModel)> _listeners = [];

  static void addListener(void Function(ProfileModel) listener) {
    _listeners.add(listener);
  }

  static void removeListener(void Function(ProfileModel) listener) {
    _listeners.remove(listener);
  }

  static void _notifyListeners(ProfileModel profile) {
    print("Notifying ${_listeners.length} listeners about profile update");
    for (var listener in _listeners) {
      listener(profile);
    }
  }

  static void notifyListeners() {
    if (_cachedProfile != null) {
      print("Public notifyListeners called, notifying about cached profile");
      for (var listener in _listeners) {
        listener(_cachedProfile!);
      }
    }
  }

  static Future<void> saveProfile(ProfileModel profile) async {
    final auth = await AuthService().getAuth();
    if (auth == null ||
        (profile.userId != null && profile.userId != auth.user.userId)) return;
    final generation = _cacheGeneration;
    final prefs = await SharedPreferences.getInstance();
    // This cache is only read from memory. Remove old plaintext profile copies.
    await prefs.remove(_keyProfile);
    if (generation != _cacheGeneration) return;
    profile.userId = auth.user.userId;
    _cachedProfile = profile;
    _cacheTime = DateTime.now();
    _notifyListeners(profile);
  }

  static Future<void> clearProfileCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfile);
    _cachedProfile = null;
    _cacheTime = null;
    _pendingFetch = null;
    _pendingSession = null;
    _cacheGeneration++;
  }

  static Future<ProfileModel?> getProfile({bool forceRefresh = false}) async {
    final auth = await AuthService().getAuth();
    if (auth == null) return null;
    if (!forceRefresh &&
        _cachedProfile?.userId == auth.user.userId &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration)
      return _cachedProfile;
    final pending = _pendingFetch;
    if (pending != null && _pendingSession == auth.refreshToken) return pending;
    final request = _fetchProfile(auth, _cacheGeneration);
    _pendingFetch = request;
    _pendingSession = auth.refreshToken;
    try {
      return await request;
    } finally {
      if (identical(_pendingFetch, request)) {
        _pendingFetch = null;
        _pendingSession = null;
      }
    }
  }

  static Future<ProfileModel?> _fetchProfile(
      AuthResponse auth, int generation) async {
    try {
      final response = await http.get(
        Uri.parse('${AppUrls.profileGet}?user_id=${auth.user.userId}'),
        headers: {'Authorization': 'Bearer ${auth.accessToken}'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data == null || data['success'] == false) return null;
      final profile = ProfileModel.fromJson(Map<String, dynamic>.from(data));
      final current = await AuthService().getAuth();
      if (current == null ||
          current.user.userId != auth.user.userId ||
          current.refreshToken != auth.refreshToken) return null;
      if (generation != _cacheGeneration) return _cachedProfile;
      await saveProfile(profile);
      return profile;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> createProfile(ProfileModel profile) async {
    try {
      final auth = await AuthService().getAuth();
      if (auth == null) {
        return false;
      }

      final token = auth.accessToken;

      final Map<String, dynamic> requestBody = {
        "treatment": profile.treatment
            .withInsulin(profile.insulinUsage ?? false)
            .toJson(),
        "user_id": auth.user.userId,
        "age": profile.age ?? 0,
        "gender": profile.gender ?? "male",
        "weight_kg": profile.weight ?? 0,
        "height_cm": profile.height ?? 0,
        "diabetes_status": (profile.diabetesStatus ?? "none").toLowerCase(),
        "insulin_usage": profile.insulinUsage ?? false,
        "insulin_morning_units": profile.insulinMorningUnits ?? 0,
        "insulin_night_units": profile.insulinNightUnits ?? 0,
        "activity_level":
            (profile.activityLevel ?? "moderately_active").toLowerCase(),
        "health_goals": profile.healthGoals ?? [],
        "dietary_preferences": profile.dietaryPreferences ?? [],
        "blood_sugar": {
          "reading_value": profile.bloodSugar?.readingValue ?? 100,
          "reading_unit": profile.bloodSugar?.readingUnit ?? "mg/dL",
          "notes": profile.bloodSugar?.notes ?? "fasting"
        },
      };

      final response = await http.post(
        Uri.parse('${AppUrls.baseUrl}/profile/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print("📥 Profile create response: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        if (result['profile_completed'] == true) {
          final current = await AuthService().getAuth();
          if (current == null || current.refreshToken != auth.refreshToken)
            return false;
          await saveProfile(profile);
          return true;
        }
      }

      return false;
    } catch (e) {
      print("❌ Create profile error: $e");
      return false;
    }
  }

  static Future<bool> editProfile(
    ProfileModel profile, {
    File? imageFile,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    if (_isEditing) {
      return false;
    }

    _isEditing = true;

    try {
      final auth = await AuthService().getAuth();
      if (auth == null) {
        return false;
      }

      final token = auth.accessToken;
      final userId = auth.user.userId;

      var request = http.MultipartRequest(
          "PUT", Uri.parse("${AppUrls.baseUrl}/profile/edit"));

      request.headers['Authorization'] = 'Bearer $token';

      final nameParts = profile.name?.split(' ') ?? [];
      final firstName = nameParts.isNotEmpty ? nameParts[0] : "";
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : "";

      request.fields["user_id"] = userId.toString();
      request.fields["treatment"] = jsonEncode(profile.treatment
          .withInsulin(profile.insulinUsage ?? false)
          .toJson());
      request.fields["first_name"] = firstName;
      request.fields["last_name"] = lastName;
      request.fields["email"] = profile.email ?? "";
      request.fields["age"] = profile.age?.toString() ?? "";
      request.fields["gender"] = profile.gender ?? "male";
      request.fields["weight_kg"] = profile.weight?.toString() ?? "";
      request.fields["height_cm"] = profile.height?.toString() ?? "";
      request.fields["diabetes_status"] = profile.diabetesStatus ?? "none";
      request.fields["insulin_usage"] =
          (profile.insulinUsage ?? false).toString();
      request.fields["insulin_morning_units"] =
          profile.insulinMorningUnits?.toString() ?? "0";
      request.fields["insulin_night_units"] =
          profile.insulinNightUnits?.toString() ?? "0";
      request.fields["blood_glucose"] =
          profile.bloodSugar?.readingValue?.toString() ?? "";

      if (imageBytes != null && imageName != null) {
        final extension = imageName.split('.').last.toLowerCase();
        request.files.add(http.MultipartFile.fromBytes(
          'profile_picture',
          imageBytes,
          filename: imageName,
          contentType: MediaType('image', extension),
        ));
      } else if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        String fileName = p.basename(imageFile.path);
        String extension =
            p.extension(imageFile.path).replaceAll('.', '').toLowerCase();

        request.files.add(http.MultipartFile.fromBytes(
          'profile_picture',
          bytes,
          filename: fileName,
          contentType:
              MediaType('image', extension.isEmpty ? 'jpeg' : extension),
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        final current = await AuthService().getAuth();
        if (current == null || current.refreshToken != auth.refreshToken)
          return false;

        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          final updatedUser = User(
            userId: userId,
            email: profile.email ?? auth.user.email,
            firstName: firstName,
            lastName: lastName,
          );
          await AuthService().updateAuthUser(updatedUser);
        }

        final updatedProfile = ProfileModel(
          userId: profile.userId,
          treatment:
              profile.treatment.withInsulin(profile.insulinUsage ?? false),
          name: profile.name,
          email: profile.email,
          age: profile.age,
          gender: profile.gender,
          weight: profile.weight,
          height: profile.height,
          diabetesStatus: profile.diabetesStatus,
          insulinUsage: profile.insulinUsage,
          insulinMorningUnits: profile.insulinMorningUnits,
          insulinNightUnits: profile.insulinNightUnits,
          activityLevel: profile.activityLevel,
          healthGoals: profile.healthGoals,
          dietaryPreferences: profile.dietaryPreferences,
          bloodSugar: profile.bloodSugar,
          profileImagePath: data['profile_picture'],
          profileCompleted: true,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_nutrition_plan');
        await prefs.remove('cached_nutrition_plan_owner');
        await clearProfileCache();
        _cachedProfile = updatedProfile;
        _cacheTime = DateTime.now();
        await saveProfile(updatedProfile);

        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Edit profile error: $e");
      return false;
    } finally {
      _isEditing = false;
    }
  }

  static Future<bool> syncProfile() async {
    try {
      final profile = await getProfile(forceRefresh: true);
      return profile != null;
    } catch (e) {
      return false;
    }
  }
}
