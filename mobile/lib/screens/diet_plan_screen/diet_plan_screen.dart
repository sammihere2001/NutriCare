import 'package:nutricare/widgets/planning_context_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:nutricare/model/nutrition_plan_model.dart';
import 'package:nutricare/services/mealplan_service.dart';
import 'package:nutricare/services/profile_services.dart';
import 'package:nutricare/theme/colors.dart';
import 'package:nutricare/theme/text_styles.dart';
import 'package:nutricare/widgets/custom_card.dart';
import 'dart:ui' as ui;

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen>
    with TickerProviderStateMixin {
  NutritionPlanResponse? planResponse;
  bool isLoading = true;
  String? errorMessage;
  late TabController _tabController;
  int _selectedDayIndex = 0;

  // Animation controllers for number transitions
  late AnimationController _numberAnimationController;
  late Animation<double> _bmiAnimation;
  late Animation<double> _bmrAnimation;
  late Animation<double> _tdeeAnimation;
  late Animation<double> _targetAnimation;
  late Animation<double> _caloriesAnimation;
  late Animation<double> _proteinAnimation;
  late Animation<double> _carbsAnimation;
  late Animation<double> _fatAnimation;

  // Store previous values for smooth transitions
  double _previousBmi = 0;
  double _previousBmr = 0;
  double _previousTdee = 0;
  double _previousTarget = 0;
  double _previousCalories = 0;
  double _previousProtein = 0;
  double _previousCarbs = 0;
  double _previousFat = 0;

  // Meal order mapping for correct display sequence
  static const Map<String, int> _mealOrder = {
    'breakfast': 1,
    'morning snack': 2,
    'snack_1': 2,
    'lunch': 3,
    'evening snack': 4,
    'snack_2': 4,
    'dinner': 5,
  };

  @override
  void initState() {
    super.initState();
    _tabController = _createTabController(0);

    // Initialize animation controller for number transitions
    _numberAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Initialize animations with default values
    _bmiAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
          parent: _numberAnimationController, curve: Curves.easeOutCubic),
    );
    _bmrAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
          parent: _numberAnimationController, curve: Curves.easeOutCubic),
    );
    _tdeeAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
          parent: _numberAnimationController, curve: Curves.easeOutCubic),
    );
    _targetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
          parent: _numberAnimationController, curve: Curves.easeOutCubic),
    );
    _caloriesAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
          parent: _numberAnimationController, curve: Curves.easeOutCubic),
    );
    _proteinAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
          parent: _numberAnimationController, curve: Curves.easeOutCubic),
    );
    _carbsAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
          parent: _numberAnimationController, curve: Curves.easeOutCubic),
    );
    _fatAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
          parent: _numberAnimationController, curve: Curves.easeOutCubic),
    );

    _loadMealPlan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _numberAnimationController.dispose();
    super.dispose();
  }

  void _updateAnimations(NutritionPlanResponse plan) {
    final health = plan.data.healthAnalysis;

    // Update animation tweens with new values
    setState(() {
      _bmiAnimation =
          Tween<double>(begin: _previousBmi, end: health.bmi).animate(
        CurvedAnimation(
            parent: _numberAnimationController, curve: Curves.easeOutCubic),
      );
      _bmrAnimation =
          Tween<double>(begin: _previousBmr, end: health.bmr).animate(
        CurvedAnimation(
            parent: _numberAnimationController, curve: Curves.easeOutCubic),
      );
      _tdeeAnimation =
          Tween<double>(begin: _previousTdee, end: health.tdee).animate(
        CurvedAnimation(
            parent: _numberAnimationController, curve: Curves.easeOutCubic),
      );
      _targetAnimation =
          Tween<double>(begin: _previousTarget, end: health.targetCalories)
              .animate(
        CurvedAnimation(
            parent: _numberAnimationController, curve: Curves.easeOutCubic),
      );
    });

    // Store current values for next animation
    _previousBmi = health.bmi;
    _previousBmr = health.bmr;
    _previousTdee = health.tdee;
    _previousTarget = health.targetCalories;

    // Reset and forward the animation
    _numberAnimationController.reset();
    _numberAnimationController.forward();
  }

  void _updateDailyTotalsAnimation(WeeklyDayPlan day) {
    final totals = day.dailyTotals;

    setState(() {
      _caloriesAnimation =
          Tween<double>(begin: _previousCalories, end: totals.calories).animate(
        CurvedAnimation(
            parent: _numberAnimationController, curve: Curves.easeOutCubic),
      );
      _proteinAnimation =
          Tween<double>(begin: _previousProtein, end: totals.protein).animate(
        CurvedAnimation(
            parent: _numberAnimationController, curve: Curves.easeOutCubic),
      );
      _carbsAnimation =
          Tween<double>(begin: _previousCarbs, end: totals.carbs).animate(
        CurvedAnimation(
            parent: _numberAnimationController, curve: Curves.easeOutCubic),
      );
      _fatAnimation =
          Tween<double>(begin: _previousFat, end: totals.fat).animate(
        CurvedAnimation(
            parent: _numberAnimationController, curve: Curves.easeOutCubic),
      );
    });

    _previousCalories = totals.calories;
    _previousProtein = totals.protein;
    _previousCarbs = totals.carbs;
    _previousFat = totals.fat;

    _numberAnimationController.reset();
    _numberAnimationController.forward();
  }

  TabController _createTabController(int length) {
    final controller = TabController(length: length, vsync: this);
    controller.addListener(() {
      if (mounted && !controller.indexIsChanging) {
        setState(() => _selectedDayIndex = controller.index);
      }
    });
    return controller;
  }

  void _configureDayTabs(int length) {
    if (_tabController.length == length) return;
    _tabController.dispose();
    _tabController = _createTabController(length);
  }

  Future<void> _loadMealPlan() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final profile = await UserProfileService.getProfile();
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          isLoading = false;
          errorMessage = "Please complete your profile first";
        });
        return;
      }

      final plan = await MealPlanService.getCachedPlan() ??
          await MealPlanService.generateMealPlan(profile);
      if (!mounted) return;

      if (plan != null && plan.data.weeklyPlan.isNotEmpty) {
        _configureDayTabs(plan.data.weeklyPlan.length);
        final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final todayIndex = plan.data.weeklyPlan.indexWhere(
          (day) => day.date == todayDate,
        );

        setState(() {
          planResponse = plan;
          _selectedDayIndex = todayIndex >= 0 ? todayIndex : 0;
          isLoading = false;
        });

        // Trigger number animations
        _updateAnimations(plan);
        if (todayIndex >= 0) {
          _updateDailyTotalsAnimation(plan.data.weeklyPlan[todayIndex]);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && todayIndex >= 0) {
            _tabController.animateTo(todayIndex);
          }
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage =
              "No diet plan available. Tap 'Regenerate' to create one.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = "Failed to load diet plan: $e";
      });
    }
  }

  Future<void> _regenerate() async {
    final profile = await UserProfileService.getProfile();
    if (!mounted) return;
    if (profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please complete your profile first!"),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    NutritionPlanResponse? newPlan;
    try {
      newPlan = await MealPlanService.generateMealPlan(profile);
    } on PlanGenerationException catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = error.message;
      });
      return;
    }
    if (!mounted) return;

    if (newPlan != null && newPlan.data.weeklyPlan.isNotEmpty) {
      _configureDayTabs(newPlan.data.weeklyPlan.length);
      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayIndex = newPlan.data.weeklyPlan.indexWhere(
        (day) => day.date == todayDate,
      );

      setState(() {
        planResponse = newPlan;
        _selectedDayIndex = todayIndex >= 0 ? todayIndex : 0;
        isLoading = false;
      });

      // Trigger animations with new values
      _updateAnimations(newPlan);
      if (todayIndex >= 0) {
        _updateDailyTotalsAnimation(newPlan.data.weeklyPlan[todayIndex]);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && todayIndex >= 0) {
          _tabController.animateTo(todayIndex);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🔄 New meal-plan preview generated!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() {
        isLoading = false;
        errorMessage =
            "Failed to generate plan. Make sure the AI server is running.";
      });
    }
  }

  /// Sort meals in correct order: Breakfast → Morning Snack → Lunch → Evening Snack → Dinner
  List<Meal> _sortMeals(List<Meal> meals) {
    final sortedList = List<Meal>.from(meals);
    sortedList.sort((a, b) {
      final orderA = _mealOrder[a.mealType.toLowerCase()] ?? 99;
      final orderB = _mealOrder[b.mealType.toLowerCase()] ?? 99;
      return orderA.compareTo(orderB);
    });
    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_month,
                  color: AppColors.white, size: 20),
            )
                .animate()
                .scale(duration: 400.ms, curve: Curves.easeOutBack)
                .fadeIn(),
            const SizedBox(width: 12),
            Expanded(
                child: Text('Weekly Diet Plan',
                        style: AppTextStyles.heading4,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .slideX(begin: -0.2, end: 0)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _regenerate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Regenerate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
            )
                .animate(target: isLoading ? 0 : 1)
                .fadeIn(duration: 400.ms, delay: 400.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary)
                .animate(onPlay: (controller) => controller.repeat())
                .scale(
                    duration: 1000.ms,
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1))
                .fadeIn(),
            const SizedBox(height: 16),
            Text(
              'Generating your plan ...',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ).animate().fadeIn(delay: 300.ms).shimmer(duration: 2000.ms),
            const SizedBox(height: 8),
            Text(
              'This ensures fresh, personalized recommendations',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_menu,
                      size: 64, color: AppColors.textSecondary.withOpacity(0.5))
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .fadeIn(),
              const SizedBox(height: 16),
              Text(errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary))
                  .animate()
                  .fadeIn(delay: 200.ms)
                  .slideY(begin: 0.2, end: 0),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _regenerate,
                icon: const Icon(Icons.refresh),
                label: const Text('Generate Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                ),
              )
                  .animate()
                  .scale(delay: 400.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
            ],
          ),
        ),
      );
    }

    final health = planResponse!.data.healthAnalysis;
    final weeklyPlan = planResponse!.data.weeklyPlan;

    return Column(
      children: [
        // ═══════════════════════════════════════
        // 🏥 HEALTH ANALYSIS HEADER
        // ═══════════════════════════════════════
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                _getBmiColor(health.bmi).withOpacity(0.1),
                _getBmiColor(health.bmi).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // BMI Score
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BMI Score',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary, fontSize: 11))
                      .animate()
                      .fadeIn(delay: 100.ms),
                  const SizedBox(height: 2),
                  // Animated BMI value
                  AnimatedBuilder(
                    animation: _bmiAnimation,
                    builder: (context, child) {
                      return Text(
                        _bmiAnimation.value.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _getBmiColor(_bmiAnimation.value),
                        ),
                      );
                    },
                  )
                      .animate()
                      .scale(delay: 200.ms, curve: Curves.easeOutBack)
                      .fadeIn(),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getBmiColor(health.bmi).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      health.bmiStatus,
                      style: TextStyle(
                        fontSize: 10,
                        color: _getBmiColor(health.bmi),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                      .animate()
                      .slideX(begin: -0.3, end: 0, delay: 300.ms)
                      .fadeIn(),
                ],
              ),

              const Spacer(),

              // Metrics Row - BMR, TDEE, Target with animations
              _buildAnimatedMetricItem(
                  'BMR', _bmrAnimation, 'kcal', Colors.deepOrange),
              const SizedBox(width: 40),
              _buildAnimatedMetricItem(
                  'TDEE', _tdeeAnimation, 'kcal', Colors.amber),
              const SizedBox(width: 40),
              _buildAnimatedMetricItem(
                  'Target', _targetAnimation, 'kcal', AppColors.primary),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(begin: -0.3, end: 0, curve: Curves.easeOut),

        // ═══════════════════════════════════════
        // 📅 DAY TABS
        // ═══════════════════════════════════════
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            indicator: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorPadding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            onTap: (index) {
              setState(() {
                _selectedDayIndex = index;
              });
              // Update daily totals animation when tab changes
              _updateDailyTotalsAnimation(weeklyPlan[index]);
            },
            tabs: List.generate(weeklyPlan.length, (index) {
              final day = weeklyPlan[index];
              final date = DateTime.parse(day.date);
              return Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('E').format(date),
                        style: const TextStyle(fontSize: 12)),
                    Text('${date.day}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

        const SizedBox(height: 8).animate().fadeIn(delay: 500.ms),

        // ═══════════════════════════════════════
        // 📊 DAY CONTENT
        // ═══════════════════════════════════════
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: List.generate(weeklyPlan.length, (index) {
              final day = weeklyPlan[index];
              return _buildDayContent(day, health.targetCalories);
            }),
          ),
        ).animate().fadeIn(delay: 500.ms),
      ],
    );
  }

  Widget _buildDayContent(WeeklyDayPlan day, double targetCalories) {
    final totals = day.dailyTotals;
    final sortedMeals = _sortMeals(day.meals);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlanningContextCard(contextData: planResponse!.data.planningContext),
          const SizedBox(height: 12),
          // Date Header
          Text(
            DateFormat('EEEE, MMMM d').format(DateTime.parse(day.date)),
            style:
                AppTextStyles.heading4.copyWith(color: AppColors.textPrimary),
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2, end: 0),

          const SizedBox(height: 12),

          // ═══════════════════════════════════
          // 🥧 PIE CHART + NUTRITION
          // ═══════════════════════════════════
          CustomCard(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pie_chart, color: AppColors.primary, size: 18)
                        .animate()
                        .scale(delay: 200.ms, curve: Curves.easeOutBack)
                        .rotate(duration: 600.ms, begin: -0.2, end: 0),
                    const SizedBox(width: 6),
                    Text('Nutrition Breakdown',
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w600))
                        .animate()
                        .fadeIn(delay: 300.ms),
                  ],
                ),
                const SizedBox(height: 16),

                // Pie Chart + Legend in a Row
                Row(
                  children: [
                    // Pie Chart on left
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CustomPaint(
                        painter: _MacroPiePainter(
                          protein: totals.protein,
                          carbs: totals.carbs,
                          fat: totals.fat,
                        ),
                      ),
                    )
                        .animate()
                        .scale(delay: 400.ms, curve: Curves.easeOutBack)
                        .fadeIn(),
                    const SizedBox(width: 16),
                    // Legend on right with animated values
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAnimatedLegendItem('Protein', _proteinAnimation,
                                  const Color(0xFF4A90D9))
                              .animate()
                              .fadeIn(delay: 500.ms)
                              .slideX(begin: 0.3, end: 0),
                          const SizedBox(height: 12),
                          _buildAnimatedLegendItem('Carbs', _carbsAnimation,
                                  const Color(0xFFF5A623))
                              .animate()
                              .fadeIn(delay: 600.ms)
                              .slideX(begin: 0.3, end: 0),
                          const SizedBox(height: 12),
                          _buildAnimatedLegendItem(
                                  'Fat', _fatAnimation, const Color(0xFFE74C3C))
                              .animate()
                              .fadeIn(delay: 700.ms)
                              .slideX(begin: 0.3, end: 0),
                          const SizedBox(height: 12),
                          _buildAnimatedLegendItem('Calories',
                                  _caloriesAnimation, AppColors.calories)
                              .animate()
                              .fadeIn(delay: 800.ms)
                              .slideX(begin: 0.3, end: 0),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider()
                    .animate()
                    .fadeIn(delay: 900.ms)
                    .slideX(begin: -0.5, end: 0),
                const SizedBox(height: 12),

                // Calories progress with animated value
                _buildAnimatedCaloriesBar(
                        _caloriesAnimation, targetCalories.toInt())
                    .animate()
                    .fadeIn(delay: 1000.ms),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 16),

          // ═══════════════════════════════════
          // 🍽️ MEALS (Correct Order)
          // ═══════════════════════════════════
          Text('Meals',
                  style: AppTextStyles.heading4
                      .copyWith(fontWeight: FontWeight.w600))
              .animate()
              .fadeIn(delay: 300.ms)
              .slideX(begin: -0.2, end: 0),
          const SizedBox(height: 8),

          ...sortedMeals.asMap().entries.map((entry) {
            final meal = entry.value;
            final food = meal.food;
            return _buildMealCard(
              title: food.name,
              mealType: meal.mealType,
              time: meal.time,
              calories: food.calories.toInt(),
              protein: food.protein.toInt(),
              carbs: food.carbs.toInt(),
              fat: food.fat.toInt(),
              iconColor: _getMealColor(meal.mealType),
            ).animate().fadeIn(delay: (400 + (entry.key * 100)).ms).slideX(
                  begin: 0.3,
                  end: 0,
                  curve: Curves.easeOut,
                );
          }),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // ANIMATED HELPER WIDGETS
  // ═══════════════════════════════════════

  Widget _buildAnimatedMetricItem(
      String label, Animation<double> animation, String unit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Text(
              animation.value.toInt().toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            );
          },
        ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack).fadeIn(),
        const SizedBox(height: 1),
        Text(
          unit,
          style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 100.ms),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildAnimatedLegendItem(
      String label, Animation<double> animation, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        )
            .animate()
            .scale(duration: 200.ms, curve: Curves.easeOutBack)
            .shimmer(),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Text(
              '${animation.value.toInt()}g',
              style:
                  AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
            );
          },
        ).animate().fadeIn().slideX(begin: 0.2, end: 0),
      ],
    );
  }

  Widget _buildAnimatedCaloriesBar(Animation<double> animation, int target) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final current = animation.value.toInt();
        final percentage =
            target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
        final remaining = target - current;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Calories',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                Row(
                  children: [
                    Text(
                      '$current',
                      style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ).animate().scale(duration: 300.ms),
                    Text(
                      ' / $target kcal',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage > 1.0 ? Colors.red : AppColors.calories,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              remaining > 0
                  ? '$remaining kcal remaining'
                  : '${remaining.abs()} kcal over target',
              style: TextStyle(
                fontSize: 10,
                color: remaining >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricItem(
      String label, String value, String unit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack).fadeIn(),
        const SizedBox(height: 1),
        Text(
          unit,
          style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 100.ms),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildLegendItem(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        )
            .animate()
            .scale(duration: 200.ms, curve: Curves.easeOutBack)
            .shimmer(),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          '${value.toInt()}g',
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
        ).animate().fadeIn().slideX(begin: 0.2, end: 0),
      ],
    );
  }

  Widget _buildCaloriesBar(int current, int target) {
    final percentage = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final remaining = target - current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Calories',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            Row(
              children: [
                Text(
                  '$current',
                  style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ).animate().scale(duration: 300.ms),
                Text(
                  ' / $target kcal',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage > 1.0 ? Colors.red : AppColors.calories,
            ),
            minHeight: 8,
          ),
        ).animate().scaleX(duration: 1000.ms, begin: 0, end: 1).fadeIn(),
        const SizedBox(height: 4),
        Text(
          remaining > 0
              ? '$remaining kcal remaining'
              : '${remaining.abs()} kcal over target',
          style: TextStyle(
            fontSize: 10,
            color: remaining >= 0 ? Colors.green : Colors.red,
          ),
        ).animate().fadeIn(delay: 500.ms).slideY(begin: -0.1, end: 0),
      ],
    );
  }

  Widget _buildMealCard({
    required String title,
    required String mealType,
    required String time,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CustomCard(
        padding: const EdgeInsets.all(14),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(_getMealIcon(mealType), color: iconColor, size: 20),
                )
                    .animate()
                    .scale(duration: 400.ms, curve: Curves.easeOutBack)
                    .rotate(
                      begin: -0.1,
                      end: 0,
                      duration: 400.ms,
                    ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodySmall
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 2),
                      Text(
                        '$mealType • $time',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary, fontSize: 10),
                      ).animate().fadeIn(delay: 300.ms),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$calories kcal',
                    style: TextStyle(
                      fontSize: 11,
                      color: iconColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                    .animate()
                    .scale(delay: 400.ms, curve: Curves.easeOutBack)
                    .fadeIn(),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildNutrientBadge('P', '${protein}g', const Color(0xFF4A90D9))
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideX(begin: -0.2, end: 0),
                const SizedBox(width: 8),
                _buildNutrientBadge('C', '${carbs}g', const Color(0xFFF5A623))
                    .animate()
                    .fadeIn(delay: 600.ms)
                    .slideX(begin: -0.2, end: 0),
                const SizedBox(width: 8),
                _buildNutrientBadge('F', '${fat}g', const Color(0xFFE74C3C))
                    .animate()
                    .fadeIn(delay: 700.ms)
                    .slideX(begin: -0.2, end: 0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientBadge(String letter, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }

  Color _getMealColor(String mealType) {
    final lower = mealType.toLowerCase();
    if (lower.contains('breakfast')) return Colors.orange;
    if (lower.contains('lunch')) return Colors.green;
    if (lower.contains('dinner')) return Colors.blue;
    if (lower.contains('snack')) return Colors.purple;
    return AppColors.primary;
  }

  IconData _getMealIcon(String mealType) {
    final lower = mealType.toLowerCase();
    if (lower.contains('breakfast')) return Icons.free_breakfast;
    if (lower.contains('lunch')) return Icons.lunch_dining;
    if (lower.contains('dinner')) return Icons.dinner_dining;
    if (lower.contains('snack')) return Icons.cookie;
    return Icons.restaurant;
  }
}

// ═══════════════════════════════════════
// FIXED PIE CHART PAINTER
// ═══════════════════════════════════════
class _MacroPiePainter extends CustomPainter {
  final double protein;
  final double carbs;
  final double fat;

  _MacroPiePainter(
      {required this.protein, required this.carbs, required this.fat});

  @override
  void paint(Canvas canvas, Size size) {
    final total = protein + carbs + fat;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;

    // Calculate sweep angles
    final proteinSweep = (protein / total) * 2 * math.pi;
    final carbsSweep = (carbs / total) * 2 * math.pi;
    final fatSweep = (fat / total) * 2 * math.pi;

    // Colors
    final proteinPaint = Paint()
      ..color = const Color(0xFF4A90D9)
      ..style = PaintingStyle.fill;
    final carbsPaint = Paint()
      ..color = const Color(0xFFF5A623)
      ..style = PaintingStyle.fill;
    final fatPaint = Paint()
      ..color = const Color(0xFFE74C3C)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw slices
    double startAngle = -math.pi / 2;

    // Protein
    if (protein > 0) {
      canvas.drawArc(rect, startAngle, proteinSweep, true, proteinPaint);
    }
    startAngle += proteinSweep;

    // Carbs
    if (carbs > 0) {
      canvas.drawArc(rect, startAngle, carbsSweep, true, carbsPaint);
    }
    startAngle += carbsSweep;

    // Fat
    if (fat > 0) {
      canvas.drawArc(rect, startAngle, fatSweep, true, fatPaint);
    }

    // Donut hole
    final holeRadius = radius * 0.5;
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, holeRadius, holePaint);

    // Center text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${total.toInt()}g',
        style: const TextStyle(
          color: Colors.black87,
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _MacroPiePainter oldDelegate) =>
      oldDelegate.protein != protein ||
      oldDelegate.carbs != carbs ||
      oldDelegate.fat != fat;
}
