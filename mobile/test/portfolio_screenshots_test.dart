// Render real app screens with fictional, offline fixtures for the public README.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutricare/screens/Authenication_Screen/login_screen.dart';
import 'package:nutricare/screens/dashboard_screen.dart';
import 'package:nutricare/screens/diet_plan_screen/diet_plan_screen.dart';
import 'package:nutricare/model/treatment_model.dart';
import 'package:nutricare/widgets/treatment_editor.dart';
import 'package:nutricare/services/auth_service.dart';
import 'foundation_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> capture(WidgetTester tester, Widget screen, String name,
      {bool golden = true}) async {
    await tester.runAsync(() async {
      for (final entry in {
        'Poppins': 'Regular',
        'Poppins_regular': 'Regular',
        'Poppins_medium': 'Medium',
        'Poppins_semibold': 'SemiBold',
        'Poppins_bold': 'Bold'
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(rootBundle.load('assets/fonts/Poppins-${entry.value}.ttf'));
        await loader.load();
      }
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthService().saveSession(fixtures.session());
    final plan = jsonDecode(jsonEncode(fixtures.cachedPlan(DateTime.now())))
        as Map<String, dynamic>;
    plan['data']['planning_context'] = <String, dynamic>{
      'engine_version': 'medication_hybrid_v1',
      'medication_context': {
        'medication_classes': ['glp1', 'metformin']
      },
      'ranking_reasons': [
        'Fictional demo: medication and appetite context recorded.'
      ],
      'warnings': ['Prototype meal preview. Clinician review required.']
    };
    plan['data']['health_analysis'].addAll({
      'bmi_status': 'Reference calculation',
      'avg_daily_calories': 2000,
      'avg_daily_protein': 85,
      'avg_daily_carbs': 240,
      'avg_daily_fat': 65
    });
    plan['data']['weekly_plan'][0]['meals'] = [
      {
        'meal_type': 'Breakfast',
        'time': '08:00 AM',
        'food': {
          'name': 'Oats and yogurt (demo portion)',
          'calories': 400,
          'protein': 20,
          'carbs': 55,
          'fat': 11
        }
      },
      {
        'meal_type': 'Lunch',
        'time': '01:00 PM',
        'food': {
          'name': 'Lentil and rice bowl (demo portion)',
          'calories': 600,
          'protein': 24,
          'carbs': 90,
          'fat': 16
        }
      }
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cached_nutrition_plan_owner', 1);
    await prefs.setString('cached_nutrition_plan', jsonEncode(plan));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'Poppins'),
          home: RepaintBoundary(key: const Key('capture'), child: screen)));
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(tester.takeException(), isNull);
      if (golden) {
        await expectLater(find.byKey(const Key('capture')),
            matchesGoldenFile('portfolio/$name.png'));
      } else {
        expect(find.text('Weekly Diet Plan'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
        () => MockClient((request) async {
              final path = request.url.path;
              if (path.startsWith('/profile'))
                return http.Response(
                    jsonEncode({
                      'user_id': 1,
                      'first_name': 'Demo',
                      'last_name': 'User',
                      'email': 'demo@example.com',
                      'age': 35,
                      'gender': 'female',
                      'weight_kg': 68,
                      'height_cm': 165,
                      'bmi': 25,
                      'activity_level': 'moderately_active',
                      'diabetes_status': 'type2',
                      'insulin_usage': false,
                      'profile_completed': true,
                      'latest_blood_sugar': 128,
                      'treatment': {
                        'medications_confirmed': true,
                        'appetite': 'normal',
                        'symptoms': [],
                        'medications': [
                          {'medication_class': 'glp1'},
                          {'medication_class': 'metformin'}
                        ]
                      }
                    }),
                    200);
              if (path.contains('history'))
                return http.Response('{"history":[]}', 200);
              if (path.contains('daily-tracker'))
                return http.Response('{"exists":false}', 200);
              if (path.contains('diet-plan'))
                return http.Response(jsonEncode(plan), 200);
              return http.Response(
                  '{"success":true,"unread_count":0,"notifications":[]}', 200);
            }));
  }

  if (const bool.fromEnvironment('GENERATE_PORTFOLIO_SCREENSHOTS')) {
    testWidgets('capture portfolio gallery with fictional fixtures',
        (tester) async {
      await capture(tester, const LoginScreen(), 'login');
      await capture(tester, const DashboardScreen(), 'dashboard');
      await capture(tester, const DietPlanScreen(), 'meal-plan');
      await capture(
          tester,
          Scaffold(
              appBar: AppBar(title: const Text('Treatment profile')),
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: TreatmentEditor(
                    value: TreatmentProfile(
                        medicationsConfirmed: true,
                        appetite: 'reduced',
                        symptoms: const [
                          'early_fullness'
                        ],
                        medications: [
                          MedicationRecord(medicationClass: 'glp1'),
                          MedicationRecord(medicationClass: 'metformin')
                        ]),
                    onChanged: (_) {},
                  ))),
          'treatment');
    });
  } else {
    testWidgets(
        'one-day meal response renders at phone width without overflow',
        (tester) => capture(tester, const DietPlanScreen(), 'meal-plan',
            golden: false));
  }
}
