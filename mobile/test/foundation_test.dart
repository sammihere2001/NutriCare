import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nutricare/services/session_store.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutricare/model/auth_model.dart';
import 'package:nutricare/model/nutrition_plan_model.dart';
import 'package:nutricare/model/profile_setup_model.dart';
import 'package:nutricare/services/auth_service.dart';
import 'package:nutricare/services/mealplan_service.dart';
import 'package:nutricare/services/profile_services.dart';

String token(DateTime expiry) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({
              'exp': expiry.millisecondsSinceEpoch ~/ 1000,
            }))).replaceAll('=', '')}.signature';

AuthResponse session({int userId = 1, bool expired = false}) => AuthResponse(
      accessToken: token(DateTime.now().add(Duration(hours: expired ? -1 : 1))),
      tokenType: 'bearer',
      refreshToken: 'refresh-$userId',
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      user: User(userId: userId, email: 'user$userId@example.com'),
    );

Map<String, dynamic> cachedPlan(DateTime date) => {
      'success': true,
      'message': 'Test plan',
      'data': {
        'planning_context': <String, dynamic>{'engine_version': 'medication_hybrid_v1'},
        'health_analysis': {
          'bmi': 24,
          'bmr': 1500,
          'tdee': 2000,
          'target_calories': 2000
        },
        'health_conditions': {},
        'weekly_plan': [
          {
            'day': 1,
            'date': date.toIso8601String().split('T').first,
            'meals': [],
            'daily_totals': {
              'calories': 2000,
              'protein': 80,
              'carbs': 220,
              'fat': 60
            }
          }
        ],
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('planning evidence and source identifiers survive cache round trips',
      () {
    final json = cachedPlan(DateTime.now());
    json['data']['planning_context']['medication_context'] = {
      'medication_classes': ['glp1', 'metformin']
    };
    json['data']['weekly_plan'][0]['source_plan_id'] = 'reviewable-plan';
    final restored = NutritionPlanResponse.fromJson(
        NutritionPlanResponse.fromJson(jsonDecode(jsonEncode(json))).toJson());
    expect(
        restored.data.planningContext.medicationClasses, ['glp1', 'metformin']);
    expect(restored.data.weeklyPlan.first.sourcePlanId, 'reviewable-plan');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await UserProfileService.clearProfileCache();
  });

  test('profile accepts fractional doses and the backend glucose format', () {
    final profile = ProfileModel.fromJson({
      'user_id': 1,
      'first_name': 'Test',
      'last_name': 'User',
      'insulin_morning_units': 12.5,
      'insulin_night_units': 8.0,
      'latest_blood_sugar': 145,
      'profile_picture': 'https://example.com/photo.png',
      'email': 'test@example.com',
    });
    expect(profile.name, 'Test User');
    expect(profile.insulinMorningUnits, 12.5);
    expect(profile.bloodSugar?.readingValue, 145);
    final cached = ProfileModel.fromJson(profile.toJson());
    expect(cached.name, profile.name);
    expect(cached.email, profile.email);
    expect(cached.profileImagePath, profile.profileImagePath);
  });

  test('legacy authentication migrates into secure storage', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_data', jsonEncode(session().toJson()));
    await prefs.setString('access_token', 'legacy-token');
    expect((await AuthService().getAuth())?.user.userId, 1);
    expect(prefs.getString('auth_data'), isNull);
    expect(prefs.getString('access_token'), isNull);
    expect(await const FlutterSecureStorage().read(key: SessionStore.key),
        isNotNull);
  });

  test('new sessions never store tokens in ordinary preferences', () async {
    await AuthService().saveSession(session());
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_data'), isNull);
    expect(prefs.getString('refresh_token'), isNull);
    expect((await AuthService().getAuth())?.refreshToken, 'refresh-1');
  });

  test('parallel profile loads share the same request', () async {
    await AuthService().saveSession(session());
    final response = Completer<http.Response>();
    final started = Completer<void>();
    var requests = 0;
    await http.runWithClient(() async {
      final first = UserProfileService.getProfile(forceRefresh: true);
      final second = UserProfileService.getProfile(forceRefresh: true);
      await started.future;
      response.complete(
          http.Response(jsonEncode({'user_id': 1, 'name': 'Test User'}), 200));
      final results = await Future.wait([first, second]);
      expect(results.every((p) => p?.name == 'Test User'), isTrue);
      expect(requests, 1);
    },
        () => MockClient((request) async {
              requests++;
              if (!started.isCompleted) started.complete();
              return response.future;
            }));
  });

  test('an old profile response cannot overwrite a newer edit', () async {
    await AuthService().saveSession(session());
    final response = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      final pending = UserProfileService.getProfile(forceRefresh: true);
      await started.future;
      await UserProfileService.clearProfileCache();
      await UserProfileService.saveProfile(
          ProfileModel(userId: 1, name: 'Updated'));
      response.complete(
          http.Response(jsonEncode({'user_id': 1, 'name': 'Old'}), 200));
      expect((await pending)?.name, 'Updated');
      expect((await UserProfileService.getProfile())?.name, 'Updated');
    },
        () => MockClient((request) async {
              started.complete();
              return response.future;
            }));
  });

  test('an old account edit cannot replace the current signed-in user',
      () async {
    await AuthService().saveSession(session(userId: 2));
    await AuthService()
        .updateAuthUser(User(userId: 1, email: 'old@example.com'));
    expect((await AuthService().getAuth())?.user.userId, 2);
  });

  test('expired sessions refresh from auth_data and save the complete response',
      () async {
    await AuthService().saveSession(session(expired: true));
    final fresh = session();
    await http.runWithClient(() async {
      final result = await AuthService().getAuth();
      expect(result?.accessToken, fresh.accessToken);
      expect(jsonDecode((await SessionStore.read())!)['access_token'],
          fresh.accessToken);
    },
        () => MockClient((request) async {
              expect(request.url.path, '/auth/refresh');
              expect(jsonDecode(request.body)['refresh_token'], 'refresh-1');
              return http.Response(jsonEncode(fresh.toJson()), 200);
            }));
  });

  test('simultaneous requests share one token refresh', () async {
    await AuthService().saveSession(session(expired: true));
    var refreshes = 0;
    await http.runWithClient(() async {
      final results =
          await Future.wait(List.generate(4, (_) => AuthService().getAuth()));
      expect(results.every((value) => value != null), isTrue);
      expect(refreshes, 1);
    },
        () => MockClient((request) async {
              refreshes++;
              await Future<void>.delayed(const Duration(milliseconds: 10));
              return http.Response(jsonEncode(session().toJson()), 200);
            }));
  });

  test('logout clears private caches and revokes the refresh token', () async {
    await AuthService().saveSession(session());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_nutrition_plan', 'old-plan');
    await prefs.setInt('cached_nutrition_plan_owner', 1);
    var revoked = false;
    await http.runWithClient(
        () => AuthService().clearAuth(),
        () => MockClient((request) async {
              expect(request.url.path, '/auth/logout');
              expect(jsonDecode(request.body)['refresh_token'], 'refresh-1');
              revoked = true;
              return http.Response('{}', 200);
            }));
    expect(revoked, isTrue);
    expect(await SessionStore.read(), isNull);
    expect(prefs.getString('auth_data'), isNull);
    expect(prefs.getString('cached_nutrition_plan'), isNull);
  });

  test('a late refresh response cannot undo logout', () async {
    await AuthService().saveSession(session(expired: true));
    final started = Completer<void>();
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      final pending = AuthService().getAuth();
      await started.future;
      await AuthService().clearAuth();
      response.complete(http.Response(jsonEncode(session().toJson()), 200));
      expect(await pending, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(await SessionStore.read(), isNull);
      expect(prefs.getString('auth_data'), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path == '/auth/refresh') {
                started.complete();
                return response.future;
              }
              return http.Response('{}', 200);
            }));
  });

  test('a meal cache owned by another user is ignored', () async {
    await AuthService().saveSession(session(userId: 2));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cached_nutrition_plan_owner', 1);
    await prefs.setString('cached_nutrition_plan', '{}');
    expect(await MealPlanService.getCachedPlan(), isNull);
  });

  test('an owned current plan loads and an expired plan is ignored', () async {
    await AuthService().saveSession(session());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cached_nutrition_plan_owner', 1);
    await prefs.setString(
        'cached_nutrition_plan', jsonEncode(cachedPlan(DateTime.now())));
    expect(await MealPlanService.getCachedPlan(), isNotNull);
    await prefs.setString(
        'cached_nutrition_plan',
        jsonEncode(
            cachedPlan(DateTime.now().subtract(const Duration(days: 8)))));
    expect(await MealPlanService.getCachedPlan(), isNull);
  });

  test('failed regeneration preserves the existing meal plan', () async {
    await AuthService().saveSession(session());
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonEncode(cachedPlan(DateTime.now()));
    await prefs.setString('cached_nutrition_plan', saved);
    await prefs.setInt('cached_nutrition_plan_owner', 1);
    await http.runWithClient(() async {
      expect(await MealPlanService.generateMealPlan(ProfileModel()), isNull);
    }, () => MockClient((request) async => http.Response('{}', 503)));
    expect(prefs.getString('cached_nutrition_plan'), saved);
    expect(await MealPlanService.getCachedPlan(), isNotNull);
  });

  test('legacy plans are ignored after the medication engine upgrade',
      () async {
    await AuthService().saveSession(session());
    final prefs = await SharedPreferences.getInstance();
    final old = cachedPlan(DateTime.now());
    old['data'].remove('planning_context');
    await prefs.setInt('cached_nutrition_plan_owner', 1);
    await prefs.setString('cached_nutrition_plan', jsonEncode(old));
    expect(await MealPlanService.getCachedPlan(), isNull);
  });

  test('planning restrictions retain the actionable server explanation',
      () async {
    await AuthService().saveSession(session());
    await http.runWithClient(() async {
      await expectLater(
          MealPlanService.generateMealPlan(ProfileModel()),
          throwsA(isA<PlanGenerationException>()
              .having((e) => e.code, 'code', 'review_required')
              .having((e) => e.message, 'message',
                  'Review your current symptoms.')));
    },
        () => MockClient((request) async => http.Response(
            jsonEncode({
              'detail': {
                'code': 'review_required',
                'message': 'Review your current symptoms.'
              }
            }),
            422)));
  });
}
