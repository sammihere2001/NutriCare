import 'package:nutricare/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../../utils/app_urls.dart';
import '../widgets/custom_card.dart';

class MealDatabaseScreen extends StatefulWidget {
  const MealDatabaseScreen({super.key});

  @override
  State<MealDatabaseScreen> createState() => _MealDatabaseScreenState();
}

class _MealDatabaseScreenState extends State<MealDatabaseScreen>
    with TickerProviderStateMixin {
  String _selectedMealType = 'All Meals';
  String _selectedGIFilter = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _meals = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  final int _pageSize = 15;
  int _totalMeals = 0;

  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  final List<String> _mealTypes = [
    'All Meals',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack'
  ];
  final List<String> _giFilters = ['Low GI', 'Medium GI', 'High GI'];

  // Meal type icons mapping
  final Map<String, IconData> _mealIcons = {
    'All Meals': Icons.restaurant,
    'Breakfast': Icons.free_breakfast,
    'Lunch': Icons.lunch_dining,
    'Dinner': Icons.dinner_dining,
    'Snack': Icons.cookie,
    'Morning Snack': Icons.coffee,
    'Evening Snack': Icons.nightlight_round,
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _fetchMeals();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreMeals();
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _fetchMeals();
    });
  }

  Future<String?> _getToken() async {
    final currentAuth = await AuthService().getAuth();
    final authDataString =
        currentAuth == null ? null : jsonEncode(currentAuth.toJson());
    if (authDataString == null) return null;
    final Map<String, dynamic> authData = jsonDecode(authDataString);
    return authData['access_token'];
  }

  Future<void> _fetchMeals({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _meals = [];
      });
    }

    final token = await _getToken();
    if (token == null) return;

    String url =
        '${AppUrls.baseUrl}/meals-database/meals?page=$_currentPage&page_size=$_pageSize';

    if (_selectedMealType != 'All Meals') {
      url += '&meal_type=${Uri.encodeComponent(_selectedMealType)}';
    }
    if (_selectedGIFilter.isNotEmpty) {
      url +=
          '&glycemic_index=${Uri.encodeComponent(_selectedGIFilter.replaceAll(' GI', '').toLowerCase())}';
    }
    if (_searchController.text.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(_searchController.text)}';
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (reset) {
            _meals = List<Map<String, dynamic>>.from(data['meals']);
          } else {
            _meals.addAll(List<Map<String, dynamic>>.from(data['meals']));
          }
          _totalMeals = data['total'] ?? _meals.length;
          _hasMore = data['has_more'] ?? false;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreMeals() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await _fetchMeals(reset: false);
  }

  Future<void> _onRefresh() async {
    await _fetchMeals();
  }

  void _onFilterChanged() {
    _fetchMeals();
  }

  Color _getGiColor(dynamic giColor) {
    if (giColor == 'warning') return AppColors.warning;
    if (giColor == 'error') return AppColors.error;
    return AppColors.success;
  }

  IconData _getMealIcon(String mealType) {
    return _mealIcons[mealType] ?? Icons.restaurant;
  }

  Widget _buildShimmerCard() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return CustomCard(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _shimmerBox(60, 60, 16),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(double.infinity, 20, 8),
                        const SizedBox(height: 8),
                        _shimmerBox(150, 14, 8),
                      ],
                    ),
                  ),
                  _shimmerBox(70, 28, 14),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _shimmerBox(double.infinity, 50, 12)),
                  const SizedBox(width: 10),
                  Expanded(child: _shimmerBox(double.infinity, 50, 12)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _shimmerBox(double.infinity, 50, 12)),
                  const SizedBox(width: 10),
                  Expanded(child: _shimmerBox(double.infinity, 50, 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(double width, double height, double radius) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            Colors.grey.withOpacity(0.1),
            Colors.grey.withOpacity(0.25),
            Colors.grey.withOpacity(0.1),
          ],
          stops: [
            _shimmerController.value - 0.2,
            _shimmerController.value,
            _shimmerController.value + 0.2,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal, int index) {
    final giColor = _getGiColor(meal['giColor']);
    final mealIcon = _getMealIcon(meal['mealType'] ?? '');
    final mealType = meal['mealType'] ?? 'Meal';
    final ingredients = meal['ingredients'] as List? ?? [];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index % 5) * 80),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: CustomCard(
        margin: const EdgeInsets.only(bottom: 20),
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(24),
        elevation: 4,
        boxShadow: [
          BoxShadow(
            color: giColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        child: Column(
          children: [
            // Top Section with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    giColor.withOpacity(0.08),
                    AppColors.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meal Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          giColor.withOpacity(0.3),
                          giColor.withOpacity(0.1)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: giColor.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(mealIcon, color: giColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal['name'] ?? '',
                          style: AppTextStyles.heading4.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          meal['serving'] ?? '1 serving',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badges Column
                  Column(
                    children: [
                      // GI Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: giColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: giColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.speed,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              meal['giLevel'] ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Meal Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          mealType,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Nutritional Grid
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // First Row
                  Row(
                    children: [
                      Expanded(
                          child: _buildNutritionBox(
                              '🔥 Calories',
                              meal['calories'] ?? '0',
                              'kcal',
                              AppColors.calories)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildNutritionBox(
                              '💪 Protein',
                              meal['protein'] ?? '0g',
                              '',
                              const Color(0xFF4A90D9))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Second Row
                  Row(
                    children: [
                      Expanded(
                          child: _buildNutritionBox(
                              '🍞 Carbs',
                              meal['carbs'] ?? '0g',
                              '',
                              const Color(0xFFF5A623))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildNutritionBox(
                              '🥑 Fat',
                              meal['fat'] ?? '0g',
                              '',
                              const Color(0xFFE74C3C))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Third Row
                  Row(
                    children: [
                      Expanded(
                          child: _buildNutritionBox(
                              '📊 GI Score',
                              '${meal['glycemic_index'] ?? 'N/A'}',
                              '',
                              Colors.purple)),
                      const SizedBox(width: 12),
                    ],
                  ),
                ],
              ),
            ),

            // Ingredients Section
            if (ingredients.isNotEmpty) ...[
              Container(
                width: double.infinity,
                height: 1,
                color: AppColors.borderLight.withOpacity(0.5),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shopping_basket,
                              color: AppColors.primary, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Ingredients',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ingredients.map((ingredient) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.amber.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('•',
                                  style: TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              Text(
                                ingredient.toString(),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            // Source Footer
            if (meal['source'] != null &&
                meal['source'].toString().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.03),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.textHint),
                    const SizedBox(width: 6),
                    Text(
                      'Source: ${meal['source']}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionBox(
      String label, String value, String suffix, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.replaceAll(RegExp(r'[^\d.]'), ''),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              if (suffix.isNotEmpty) ...[
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    suffix,
                    style: TextStyle(
                      color: color.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label, IconData icon, bool isSelected, VoidCallback onTap,
      {Color? selectedColor}) {
    final color = selectedColor ?? AppColors.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(colors: [color, color.withOpacity(0.8)])
                  : null,
              color: isSelected ? null : AppColors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isSelected ? color : AppColors.borderLight,
                width: isSelected ? 0 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : color.withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF38ADB6)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.restaurant_menu,
                  color: AppColors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meal Database',
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_totalMeals > 0)
                  Text(
                    '$_totalMeals meals available',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success
                      .withOpacity(0.1 + (_pulseController.value * 0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.verified,
                  color: AppColors.success
                      .withOpacity(0.7 + (_pulseController.value * 0.3)),
                  size: 22,
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search meals by name...',
                            hintStyle: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textHint,
                              fontSize: 15,
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.search_rounded,
                                  color: AppColors.primary, size: 22),
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        color: AppColors.textHint),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                          ),
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.2, end: 0),
                  ),

                  // Filter Chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter by Meal Type',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 44,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: _mealTypes.map((type) {
                                final isSelected = _selectedMealType == type;
                                return _buildFilterChip(
                                  type,
                                  _mealIcons[type] ?? Icons.restaurant,
                                  isSelected,
                                  () {
                                    setState(() => _selectedMealType = type);
                                    _onFilterChanged();
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 100.ms)
                        .slideX(begin: -0.2, end: 0),
                  ),

                  // GI Filters & Count
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              '${_meals.length} meal${_meals.length != 1 ? 's' : ''}',
                              key: ValueKey(_meals.length),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Row(
                            children: _giFilters.map((filter) {
                              final isSelected = _selectedGIFilter == filter;
                              Color filterColor;
                              switch (filter) {
                                case 'Low GI':
                                  filterColor = AppColors.success;
                                  break;
                                case 'Medium GI':
                                  filterColor = AppColors.warning;
                                  break;
                                case 'High GI':
                                  filterColor = AppColors.error;
                                  break;
                                default:
                                  filterColor = AppColors.textSecondary;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _buildGIFilterChip(
                                    filter, isSelected, filterColor),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                  ),

                  // Meal Cards
                  if (_meals.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == _meals.length) {
                              return _isLoadingMore
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            color: AppColors.primary),
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            }
                            return _buildMealCard(_meals[index], index);
                          },
                          childCount: _meals.length + (_isLoadingMore ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildGIFilterChip(String filter, bool isSelected, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGIFilter = isSelected ? '' : filter;
        });
        _onFilterChanged();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          filter,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          // Search bar skeleton
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ).animate().shimmer(duration: 1500.ms),

          const SizedBox(height: 24),

          // Filter chips skeleton
          Row(
            children: List.generate(
                4,
                (index) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Container(
                        height: 40,
                        width: 80 + (index * 20).toDouble(),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                        ),
                      )
                          .animate()
                          .shimmer(duration: 1500.ms, delay: (index * 100).ms),
                    )),
          ),

          const SizedBox(height: 24),

          // Meal card skeletons
          ...List.generate(4, (index) => _buildShimmerCard()),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: 64,
              color: AppColors.primary.withOpacity(0.6),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            'No meals found',
            style: AppTextStyles.heading4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search terms',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedMealType = 'All Meals';
                _selectedGIFilter = '';
                _searchController.clear();
              });
              _onFilterChanged();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 400.ms)
              .scale(delay: 400.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}
