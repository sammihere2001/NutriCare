import 'package:nutricare/widgets/planning_context_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:nutricare/model/auth_model.dart';
import 'package:nutricare/model/nutrition_plan_model.dart';
import 'package:nutricare/model/profile_setup_model.dart';
import 'package:nutricare/services/auth_service.dart';
import 'package:nutricare/services/mealplan_service.dart';
import 'package:nutricare/services/profile_services.dart';
import 'package:nutricare/services/notification_service.dart';
import 'package:nutricare/services/daily_tracker_service.dart';
import 'package:nutricare/widgets/bell_icon.dart';
import 'package:nutricare/widgets/notification_panel.dart';
import 'package:nutricare/widgets/glucose_quick_log_dialog.dart';
import 'package:nutricare/screens/Authenication_Screen/login_screen.dart';
import 'package:nutricare/screens/main_navigation_screen.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'widgets/custom_card.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _userName = 'User';
  String _greeting = 'Good Morning!';
  ProfileModel? _profileData;
  AuthResponse? authData;
  String? _profileImagePath;

  NutritionPlanResponse? _nutritionPlan;
  WeeklyDayPlan? _todayPlan;
  DailyTrackerData? _todayTracker;
  List<GlucoseHistoryData> _glucoseHistory = [];
  bool _isLoadingPlan = true;
  bool _isLoadingUser = true;
  bool _isLoadingTracker = true;
  bool _dataLoaded = false;
  bool _isLoading = true;

  static const Map<String, String> _activityLevelMap = {
    'sedentary': 'Sedentary',
    'lightly_active': 'Lightly Active',
    'moderately_active': 'Moderately Active',
    'very_active': 'Very Active',
    'extra_active': 'Extra Active',
  };

  @override
  void initState() {
    super.initState();
    UserProfileService.addListener(_onProfileUpdated);

    // ✅ ONLY load user and tracker data (NO meal plan auto-generation)
    _loadUserData();
    _loadDailyTracker();
    _loadGlucoseHistory();
    _loadCachedMealPlanOnly(); // Sirf cache se load karega

    NotificationService.addUnreadCountListener(_onNotificationCountChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    UserProfileService.removeListener(_onProfileUpdated);
    NotificationService.removeUnreadCountListener(_onNotificationCountChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _onProfileUpdated(ProfileModel profile) {
    if (mounted) {
      setState(() {
        _profileData = profile;
        _profileImagePath = profile.profileImagePath;
        if (profile.name != null && profile.name!.isNotEmpty) {
          _userName = profile.name!;
        }
      });
    }
  }

  void _onNotificationCountChanged(int count) {
    if (mounted) {
      setState(() {});
    }
  }

  // ✅ NEW: Sirf cache se meal plan load karega - kabhi generate nahi karega
  Future<void> _loadCachedMealPlanOnly() async {
    setState(() => _isLoadingPlan = true);

    try {
      final cachedPlan = await MealPlanService.getCachedPlan();

      if (cachedPlan != null && mounted) {
        final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final today = cachedPlan.data.weeklyPlan.firstWhere(
          (day) => day.date == todayDate,
          orElse: () => cachedPlan.data.weeklyPlan.first,
        );
        setState(() {
          _nutritionPlan = cachedPlan;
          _todayPlan = today;
          _isLoadingPlan = false;
        });
        print('📦 Loaded meal plan from cache');
      } else {
        if (mounted) {
          setState(() {
            _nutritionPlan = null;
            _todayPlan = null;
            _isLoadingPlan = false;
          });
        }
        print('⚠️ No cached meal plan found');
      }
    } catch (e) {
      print('Error loading cached plan: $e');
      if (mounted) {
        setState(() => _isLoadingPlan = false);
      }
    }
  }

  // ✅ Public method for generating new meal plan (call from button only)
  Future<void> generateNewMealPlan() async {
    setState(() => _isLoadingPlan = true);

    try {
      final profile = await UserProfileService.getProfile();
      if (profile == null) {
        throw Exception('Profile not found');
      }

      final plan = await MealPlanService.generateMealPlan(profile);

      if (plan != null && mounted) {
        final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final today = plan.data.weeklyPlan.firstWhere(
          (day) => day.date == todayDate,
          orElse: () => plan.data.weeklyPlan.first,
        );
        setState(() {
          _nutritionPlan = plan;
          _todayPlan = today;
          _isLoadingPlan = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ New meal plan generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() => _isLoadingPlan = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to generate meal plan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingPlan = false);
      print('Error generating plan: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ Refresh only tracker data and cached meals (no generation)
  Future<void> _refreshData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingTracker = true;
    });

    await Future.wait([
      _loadDailyTracker(),
      _loadGlucoseHistory(),
      _loadCachedMealPlanOnly(), // Sirf cache se reload
    ]);

    if (mounted) {
      setState(() {
        _isLoadingTracker = false;
      });
    }
  }

  Future<void> _loadDailyTracker() async {
    if (!mounted) return;
    setState(() => _isLoadingTracker = true);
    final tracker = await DailyTrackerService().getTodayTracker();
    if (mounted) {
      setState(() {
        _todayTracker = tracker;
        _isLoadingTracker = false;
      });
    }
  }

  Future<void> _loadGlucoseHistory() async {
    final history = await DailyTrackerService().getGlucoseHistory(days: 7);
    if (mounted) {
      setState(() {
        _glucoseHistory = history;
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoadingUser = true);
    try {
      final profileData =
          await UserProfileService.getProfile(forceRefresh: true);
      final userData = await AuthService().getAuth();
      final hour = DateTime.now().hour;

      setState(() {
        _profileData = profileData;
        authData = userData;
        _profileImagePath = profileData?.profileImagePath;

        if (profileData?.name != null && profileData!.name!.isNotEmpty) {
          _userName = profileData!.name!;
        } else if (userData?.user?.firstName != null) {
          _userName =
              "${userData!.user!.firstName} ${userData!.user!.lastName ?? ''}"
                  .trim();
        } else if (userData?.user?.email != null) {
          _userName = userData!.user!.email!.split('@').first;
        } else {
          _userName = 'User';
        }

        if (hour < 12) {
          _greeting = 'Good Morning!';
        } else if (hour < 17) {
          _greeting = 'Good Afternoon!';
        } else {
          _greeting = 'Good Evening!';
        }

        _isLoadingUser = false;
      });
    } catch (e) {
      setState(() => _isLoadingUser = false);
    }
  }

  String _getInsulinText() {
    if (_profileData?.insulinUsage != true) return 'No Insulin';
    final morning = _profileData?.insulinMorningUnits ?? 0;
    final night = _profileData?.insulinNightUnits ?? 0;
    if (morning > 0 && night > 0) {
      return 'Morning: $morning units, Night: $night units';
    } else if (morning > 0) {
      return 'Morning: $morning units';
    } else if (night > 0) {
      return 'Night: $night units';
    }
    return 'Daily';
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.local_dining;
    }
  }

  String _getInitials() {
    if (_userName.isEmpty || _userName == 'User') return 'U';
    final parts = _userName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _userName[0].toUpperCase();
  }

  void _showQuickGlucoseLog() {
    showDialog(
      context: context,
      builder: (context) => GlucoseQuickLogDialog(
        onLogged: _refreshData,
      ),
    );
  }

  void _navigateToTracker() {
    final mainNav =
        context.findAncestorStateOfType<State<MainNavigationScreen>>();
    if (mainNav != null && mainNav is dynamic) {
      (mainNav as dynamic).setCurrentIndex(4);
    }
  }

  Color _getGlucoseColor(String status) {
    switch (status) {
      case 'Low':
        return Colors.red;
      case 'Normal':
        return Colors.green;
      case 'High':
        return Colors.orange;
      case 'Very High':
        return Colors.red;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getGlucoseIcon(String status) {
    switch (status) {
      case 'Low':
        return Icons.arrow_downward;
      case 'Normal':
        return Icons.check_circle;
      case 'High':
        return Icons.arrow_upward;
      case 'Very High':
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }

  List<Map<String, dynamic>> _generateInsights() {
    final List<Map<String, dynamic>> insights = [];

    if (_todayTracker == null || !_todayTracker!.exists) {
      insights.add({
        'icon': Icons.info_outline,
        'color': AppColors.primary,
        'title': 'Welcome!',
        'message':
            'Start tracking your health metrics today to get personalized insights.',
      });
      return insights;
    }

    if (_glucoseHistory.length >= 3) {
      final recentGlucose =
          _glucoseHistory.where((g) => g.morningGlucose > 0).toList();

      if (recentGlucose.length >= 3) {
        final avgMorning =
            recentGlucose.map((g) => g.morningGlucose).reduce((a, b) => a + b) /
                recentGlucose.length;

        if (avgMorning <= 130 && avgMorning >= 70) {
          insights.add({
            'icon': Icons.trending_up,
            'color': Colors.green,
            'title': 'Great Glucose Control!',
            'message':
                'Your average morning glucose is ${avgMorning.toInt()} mg/dL - within target range.',
          });
        } else if (avgMorning > 130) {
          insights.add({
            'icon': Icons.trending_down,
            'color': Colors.orange,
            'title': 'Glucose Needs Attention',
            'message':
                'Morning glucose averaging ${avgMorning.toInt()} mg/dL. Consider reviewing evening meals.',
          });
        }
      }
    }

    if (_todayTracker!.exercise > 0 && _todayTracker!.sleepHours > 0) {
      if (_todayTracker!.exercise >= 30) {
        insights.add({
          'icon': Icons.fitness_center,
          'color': AppColors.steps,
          'title': 'Active Lifestyle!',
          'message':
              'Great job completing ${_todayTracker!.exercise.toInt()} minutes of exercise today.',
        });
      }

      if (_todayTracker!.sleepHours >= 7 && _todayTracker!.sleepHours <= 9) {
        insights.add({
          'icon': Icons.bedtime,
          'color': AppColors.sleep,
          'title': 'Optimal Sleep',
          'message':
              '${_todayTracker!.sleepHours.toStringAsFixed(1)} hours of sleep supports healthy glucose levels.',
        });
      } else if (_todayTracker!.sleepHours > 0 &&
          _todayTracker!.sleepHours < 7) {
        insights.add({
          'icon': Icons.bedtime,
          'color': Colors.orange,
          'title': 'Sleep Deprivation',
          'message':
              'Less than 7 hours sleep can affect glucose regulation. Aim for 7-9 hours.',
        });
      }
    }

    if (_todayTracker!.waterIntake > 0) {
      if (_todayTracker!.waterIntake >= 8) {
        insights.add({
          'icon': Icons.water_drop,
          'color': AppColors.water,
          'title': 'Well Hydrated!',
          'message':
              'Excellent water intake - ${_todayTracker!.waterIntake.toInt()} glasses today.',
        });
      } else if (_todayTracker!.waterIntake < 6) {
        insights.add({
          'icon': Icons.water_drop,
          'color': Colors.orange,
          'title': 'Stay Hydrated',
          'message':
              'Only ${_todayTracker!.waterIntake.toInt()} glasses today. Aim for 8-10 glasses.',
        });
      }
    }

    if (_todayTracker!.stressLevel > 0) {
      if (_todayTracker!.stressLevel <= 30) {
        insights.add({
          'icon': Icons.psychology,
          'color': Colors.green,
          'title': 'Low Stress',
          'message': 'Your stress level is well managed today. Keep it up!',
        });
      } else if (_todayTracker!.stressLevel > 70) {
        insights.add({
          'icon': Icons.psychology,
          'color': Colors.red,
          'title': 'High Stress Alert',
          'message':
              'High stress can affect blood sugar. Consider relaxation techniques.',
        });
      }
    }

    if (_glucoseHistory.length >= 5) {
      final daysWithData =
          _glucoseHistory.where((g) => g.morningGlucose > 0).length;
      if (daysWithData >= 5) {
        insights.add({
          'icon': Icons.star,
          'color': AppColors.primary,
          'title': 'Consistent Tracker!',
          'message':
              "You've logged glucose $daysWithData out of last 7 days. Great consistency!",
        });
      }
    }

    if (insights.isEmpty) {
      insights.add({
        'icon': Icons.tips_and_updates,
        'color': AppColors.primary,
        'title': 'Keep Tracking!',
        'message':
            'Continue logging your daily metrics for personalized health insights.',
      });
    }

    return insights.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dailyTotals = _todayPlan?.dailyTotals;
    final targetCalories =
        _nutritionPlan?.data.healthAnalysis.targetCalories.toInt() ?? 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: NotificationPanel(
        onClose: () {
          Navigator.pop(context);
        },
      ),
      endDrawerEnableOpenDragGesture: true,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader()
                  .animate()
                  .fadeIn(delay: 200.ms)
                  .slideY(begin: -0.3, end: 0),
              const SizedBox(height: 24),
              _buildGlucoseCard()
                  .animate()
                  .fadeIn(delay: 400.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 20),
              _buildQuickActions()
                  .animate()
                  .fadeIn(delay: 600.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 24),
              _buildHealthProfileCard(dailyTotals, targetCalories)
                  .animate()
                  .fadeIn(delay: 800.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 24),
              _buildComplianceSummary()
                  .animate()
                  .fadeIn(delay: 1000.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 32),
              Text("Today's Overview",
                      style: AppTextStyles.heading3
                          .copyWith(color: AppColors.textPrimary))
                  .animate()
                  .fadeIn(delay: 1200.ms)
                  .slideX(begin: -0.3, end: 0),
              const SizedBox(height: 20),
              _buildStatsRow()
                  .animate()
                  .fadeIn(delay: 1400.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 32),
              if (_nutritionPlan != null)
                PlanningContextCard(contextData: _nutritionPlan!.data.planningContext),
              _buildMealsSection()
                  .animate()
                  .fadeIn(delay: 1600.ms)
                  .slideX(begin: -0.3, end: 0),
              const SizedBox(height: 32),
              _buildHealthInsights()
                  .animate()
                  .fadeIn(delay: 1800.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Builder(
      builder: (context) => Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () {
              globalScaffoldKey.currentState?.openDrawer();
            },
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/images/Logo.png',
            height: 100,
            width: 100,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => const SizedBox(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
                Text(_userName,
                    style: AppTextStyles.heading4
                        .copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          BellIcon(scaffoldKey: _scaffoldKey),
        ],
      ),
    );
  }

  Widget _buildGlucoseCard() {
    if (_todayTracker == null ||
        !_todayTracker!.exists ||
        (!_todayTracker!.hasMorningGlucose &&
            !_todayTracker!.hasEveningGlucose)) {
      return _buildEmptyGlucoseState();
    }

    return CustomCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bloodtype,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Blood Glucose',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _showQuickGlucoseLog,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.add, color: AppColors.primary, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildGlucoseReading(
                  'Morning (Fasting)',
                  _todayTracker!.hasMorningGlucose
                      ? '${_todayTracker!.morningGlucose.toInt()}'
                      : '--',
                  _todayTracker!.getMorningGlucoseStatus(),
                  Icons.wb_sunny,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGlucoseReading(
                  'Evening',
                  _todayTracker!.hasEveningGlucose
                      ? '${_todayTracker!.eveningGlucose.toInt()}'
                      : '--',
                  _todayTracker!.getEveningGlucoseStatus(),
                  Icons.nightlight_round,
                ),
              ),
            ],
          ),
          if (_glucoseHistory.length >= 2) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: _buildGlucoseGraph(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyGlucoseState() {
    return CustomCard(
      padding: const EdgeInsets.all(32),
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      backgroundColor: AppColors.primary.withOpacity(0.05),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bloodtype_outlined,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Glucose Data Today',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _glucoseHistory.isNotEmpty
                ? 'Log your glucose reading to track your daily trends'
                : 'Start monitoring your blood glucose levels',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showQuickGlucoseLog,
            icon: const Icon(Icons.add),
            label: const Text('Log Glucose Reading'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlucoseReading(
      String label, String value, String status, IconData icon) {
    final statusColor = _getGlucoseColor(status);
    final statusIcon = _getGlucoseIcon(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'mg/dL',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlucoseGraph() {
    return CustomPaint(
      painter: _GlucoseGraphPainter(
        glucoseHistory: _glucoseHistory,
      ),
      size: const Size(double.infinity, 150),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            'Log Glucose',
            Icons.bloodtype,
            AppColors.primary,
            _showQuickGlucoseLog,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionButton(
            'Track Day',
            Icons.track_changes,
            AppColors.steps,
            _navigateToTracker,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionButton(
            'Diet Plan',
            Icons.restaurant_menu,
            AppColors.calories,
            () {
              final mainNav = context
                  .findAncestorStateOfType<State<MainNavigationScreen>>();
              if (mainNav != null && mainNav is dynamic) {
                (mainNav as dynamic).setCurrentIndex(1);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthProfileCard(dailyTotals, int targetCalories) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Health Profile',
                  style: AppTextStyles.heading4
                      .copyWith(color: AppColors.textPrimary)),
              IconButton(
                  icon: const Icon(Icons.lightbulb_outline,
                      color: AppColors.primary),
                  onPressed: () {}),
            ],
          ),
          const SizedBox(height: 16),
          _buildProfileRow('Type', _profileData?.diabetesStatus ?? 'Not Set'),
          _buildProfileRow('Insulin', _getInsulinText()),
          _buildProfileRow(
              'Activity',
              _activityLevelMap[
                      _profileData?.activityLevel ?? 'moderately_active'] ??
                  'Moderately Active'),
          if (_todayTracker?.weight != null && _todayTracker!.weight > 0)
            _buildProfileRow(
                'Weight', '${_todayTracker!.weight.toStringAsFixed(1)} kg'),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          if (_isLoadingPlan)
            const Center(child: CircularProgressIndicator())
          else if (dailyTotals != null) ...[
            _buildNutritionRow('Calories', '${dailyTotals.calories.toInt()}',
                '$targetCalories'),
            _buildNutritionRow(
                'Protein', '${dailyTotals.protein.toInt()}g', ''),
            _buildNutritionRow('Carbs', '${dailyTotals.carbs.toInt()}g', ''),
            _buildNutritionRow('Fat', '${dailyTotals.fat.toInt()}g', ''),
          ] else
            const Text('No nutrition plan available'),
        ],
      ),
    );
  }

  Widget _buildComplianceSummary() {
    if (_todayTracker == null ||
        !_todayTracker!.exists ||
        !_todayTracker!.hasPartialData) {
      return const SizedBox.shrink();
    }

    return CustomCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.checklist,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                "Today's Compliance",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildComplianceItem(
            'Morning Glucose',
            _todayTracker!.hasMorningGlucose,
            _todayTracker!.isMorningNormal ? 'In Range' : 'Out of Range',
            _todayTracker!.isMorningNormal ? Colors.green : Colors.orange,
          ),
          _buildComplianceItem(
            'Evening Glucose',
            _todayTracker!.hasEveningGlucose,
            _todayTracker!.isEveningNormal ? 'In Range' : 'Out of Range',
            _todayTracker!.isEveningNormal ? Colors.green : Colors.orange,
          ),
          _buildComplianceItem(
            'Water Intake',
            _todayTracker!.waterIntake >= 8,
            '${_todayTracker!.waterIntake.toInt()}/8 glasses',
            _todayTracker!.waterIntake >= 8 ? Colors.green : Colors.orange,
          ),
          _buildComplianceItem(
            'Exercise',
            _todayTracker!.exercise >= 30,
            '${_todayTracker!.exercise.toInt()}/30 min',
            _todayTracker!.exercise >= 30 ? Colors.green : Colors.orange,
          ),
          _buildComplianceItem(
            'Sleep',
            _todayTracker!.sleepHours >= 7 && _todayTracker!.sleepHours <= 9,
            '${_todayTracker!.sleepHours.toStringAsFixed(1)}/7-9 hrs',
            (_todayTracker!.sleepHours >= 7 && _todayTracker!.sleepHours <= 9)
                ? Colors.green
                : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceItem(
      String label, bool completed, String detail, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed
                  ? color.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
            ),
            child: Icon(
              completed ? Icons.check : Icons.close,
              size: 16,
              color: completed ? color : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            detail,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    'Calories',
                    _isLoadingPlan
                        ? '...'
                        : '${_todayPlan?.dailyTotals.calories.toInt() ?? '0'}',
                    'kcal',
                    Icons.local_fire_department,
                    AppColors.calories)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildStatCard(
                    'Water',
                    _todayTracker?.waterIntake.toInt().toString() ?? '0',
                    'glasses',
                    Icons.water_drop,
                    AppColors.water)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    'Stress',
                    _todayTracker?.stressLevel.toInt().toString() ?? '--',
                    'level',
                    Icons.psychology,
                    AppColors.steps)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildStatCard(
                    'Sleep',
                    _todayTracker?.sleepHours.toStringAsFixed(1) ?? '--',
                    'hours',
                    Icons.bedtime,
                    AppColors.sleep)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, String unit, IconData icon, Color color) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.0)),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(unit,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: AppTextStyles.heading3
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(title,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Meals',
                style: AppTextStyles.heading3
                    .copyWith(color: AppColors.textPrimary)),
            TextButton(
              onPressed: () {
                final mainNav = context
                    .findAncestorStateOfType<State<MainNavigationScreen>>();
                if (mainNav != null && mainNav is dynamic) {
                  (mainNav as dynamic).setCurrentIndex(1);
                }
              },
              child: Text('View All',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingPlan)
          const Center(child: CircularProgressIndicator())
        else if (_todayPlan != null && _todayPlan!.meals.isNotEmpty)
          Column(
            children: _todayPlan!.meals.map((meal) {
              final food = meal.food;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMealCard(
                    meal.mealType,
                    food.name,
                    '${food.calories.toInt()} kcal',
                    meal.time,
                    _getMealIcon(meal.mealType)),
              );
            }).toList(),
          )
        else
          const Text('No meals available for today'),
      ],
    );
  }

  Widget _buildMealCard(String mealType, String description, String calories,
      String time, IconData icon) {
    return CustomCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0)),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mealType,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                Text(description,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(calories,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
              Text(time,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthInsights() {
    final insights = _generateInsights();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Health Insights',
                style: AppTextStyles.heading3
                    .copyWith(color: AppColors.textPrimary))
            .animate()
            .fadeIn(delay: 100.ms)
            .slideX(begin: -0.3, end: 0),
        const SizedBox(height: 16),
        ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CustomCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                          color: (insight['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10.0)),
                      child: Icon(insight['icon'] as IconData,
                          color: insight['color'] as Color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(insight['title'] as String,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(insight['message'] as String,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          Text(value,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, String current, String target) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          Text(target.isNotEmpty ? '$current / $target' : current,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GlucoseGraphPainter extends CustomPainter {
  final List<GlucoseHistoryData> glucoseHistory;

  _GlucoseGraphPainter({required this.glucoseHistory});

  @override
  void paint(Canvas canvas, Size size) {
    if (glucoseHistory.isEmpty) return;

    final validMorning =
        glucoseHistory.where((g) => g.morningGlucose > 0).toList();
    final validEvening =
        glucoseHistory.where((g) => g.eveningGlucose > 0).toList();

    if (validMorning.isEmpty && validEvening.isEmpty) return;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 0.5;

    final normalZonePaint = Paint()
      ..color = Colors.green.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final normalTop = _yPosition(70, size.height);
    final normalBottom = _yPosition(130, size.height);
    canvas.drawRect(
      Rect.fromLTRB(0, normalTop, size.width, normalBottom),
      normalZonePaint,
    );

    for (int i = 0; i < glucoseHistory.length; i++) {
      final date = DateTime.tryParse(glucoseHistory[i].date);
      if (date != null) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: DateFormat('E').format(date),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();
        final x = _xPosition(i, glucoseHistory.length, size.width);
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, size.height - 16),
        );
      }
    }

    if (validMorning.length >= 2) {
      final morningPaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final morningPath = Path();
      bool firstPoint = true;

      for (int i = 0; i < glucoseHistory.length; i++) {
        if (glucoseHistory[i].morningGlucose > 0) {
          final x = _xPosition(i, glucoseHistory.length, size.width);
          final y = _yPosition(glucoseHistory[i].morningGlucose, size.height);

          if (firstPoint) {
            morningPath.moveTo(x, y);
            firstPoint = false;
          } else {
            morningPath.lineTo(x, y);
          }

          canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.blue);
        }
      }

      canvas.drawPath(morningPath, morningPaint);
    }

    if (validEvening.length >= 2) {
      final eveningPaint = Paint()
        ..color = Colors.purple
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final eveningPath = Path();
      bool firstPoint = true;

      for (int i = 0; i < glucoseHistory.length; i++) {
        if (glucoseHistory[i].eveningGlucose > 0) {
          final x = _xPosition(i, glucoseHistory.length, size.width);
          final y = _yPosition(glucoseHistory[i].eveningGlucose, size.height);

          if (firstPoint) {
            eveningPath.moveTo(x, y);
            firstPoint = false;
          } else {
            eveningPath.lineTo(x, y);
          }

          canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.purple);
        }
      }

      canvas.drawPath(eveningPath, eveningPaint);
    }

    _drawLegend(canvas, 'Morning', Colors.blue, Offset(size.width - 150, 10));
    _drawLegend(canvas, 'Evening', Colors.purple, Offset(size.width - 150, 30));
  }

  void _drawLegend(Canvas canvas, String label, Color color, Offset position) {
    canvas.drawLine(
      position,
      Offset(position.dx + 20, position.dy),
      Paint()
        ..color = color
        ..strokeWidth = 2.5,
    );

    canvas.drawCircle(
      Offset(position.dx + 10, position.dy),
      3,
      Paint()..color = color,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: color, fontSize: 10),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(position.dx + 26, position.dy - 6));
  }

  double _xPosition(int index, int total, double width) {
    if (total <= 1) return width / 2;
    final padding = 20.0;
    final availableWidth = width - (padding * 2);
    return padding + (index / (total - 1)) * availableWidth;
  }

  double _yPosition(double glucose, double height) {
    final minGlucose = 0.0;
    final maxGlucose = 400.0;
    final padding = 20.0;
    final availableHeight = height - (padding * 2);
    final ratio = (glucose - minGlucose) / (maxGlucose - minGlucose);
    return height - padding - (ratio * availableHeight);
  }

  @override
  bool shouldRepaint(covariant _GlucoseGraphPainter oldDelegate) {
    return oldDelegate.glucoseHistory != glucoseHistory;
  }
}
