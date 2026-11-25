import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../widgets/custom_card.dart';

class CheatTricksScreen extends StatefulWidget {
  const CheatTricksScreen({super.key});

  @override
  State<CheatTricksScreen> createState() => _CheatTricksScreenState();
}

class _CheatTricksScreenState extends State<CheatTricksScreen> with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All';
  int? _expandedCardIndex;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _filters = ['All', 'Before', 'During', 'After', 'General'];

  // Complete list of 8 reliable, science-backed cheat tricks
  final List<Map<String, dynamic>> _tricks = [
    {
      'title': 'Eat Vegetables First',
      'category': 'Before',
      'icon': Icons.access_time,
      'iconColor': Colors.green,
      'gradientColors': [Colors.green.shade400, Colors.green.shade700],
      'description': 'Start your meal with a salad or cooked vegetables. This creates a "veggie wall" in your stomach that slows down the absorption of glucose from carbs eaten later.',
      'scientificBasis': 'Studies show eating vegetables first can reduce glucose spikes by up to 75%',
      'effectiveness': '⭐⭐⭐⭐⭐',
      'timeRequired': '2-3 minutes before meal',
    },
    {
      'title': 'Apple Cider Vinegar Before Meals',
      'category': 'Before',
      'icon': Icons.science,
      'iconColor': Colors.amber,
      'gradientColors': [Colors.amber.shade400, Colors.orange.shade700],
      'description': 'Mix 1-2 tablespoons of apple cider vinegar in a large glass of water and drink 10-20 minutes before a carb-rich meal. This reduces glucose spike by slowing carb digestion.',
      'scientificBasis': 'Multiple studies show ACV improves insulin sensitivity by 19-34% and reduces post-meal glucose by up to 30%',
      'effectiveness': '⭐⭐⭐⭐',
      'timeRequired': '10-20 min before meal',
    },
    {
      'title': 'Eat Protein & Fat Before Carbs',
      'category': 'During',
      'icon': Icons.restaurant,
      'iconColor': Colors.orange,
      'gradientColors': [Colors.orange.shade400, Colors.deepOrange.shade700],
      'description': 'When eating your meal, follow this order: vegetables → protein → fats → carbs. This sequence dramatically reduces glucose spikes.',
      'scientificBasis': 'The order of food consumption impacts glucose response significantly - protein first reduces post-meal glucose by 40%',
      'effectiveness': '⭐⭐⭐⭐⭐',
      'timeRequired': 'During entire meal',
    },
    {
      'title': '10-Minute Walk After Eating',
      'category': 'After',
      'icon': Icons.directions_walk,
      'iconColor': Colors.blue,
      'gradientColors': [Colors.blue.shade400, Colors.indigo.shade700],
      'description': 'Take a short 10-15 minute walk after meals. This helps your muscles use up the glucose from your food, preventing spikes.',
      'scientificBasis': 'Light physical activity immediately after eating can reduce post-meal glucose by 30%',
      'effectiveness': '⭐⭐⭐⭐⭐',
      'timeRequired': '10-15 min after meal',
    },
    {
      'title': 'Don\'t Eat Carbs Alone',
      'category': 'General',
      'icon': Icons.lightbulb,
      'iconColor': Colors.purple,
      'gradientColors': [Colors.purple.shade400, Colors.deepPurple.shade700],
      'description': 'Never eat carbohydrates (roti, rice, bread, sweets) by themselves. Always pair them with protein, healthy fats, or fiber-rich vegetables.',
      'scientificBasis': 'Combining carbs with protein/fat slows digestion from 30 min to 2-3 hours, preventing rapid glucose spikes',
      'effectiveness': '⭐⭐⭐⭐⭐',
      'timeRequired': 'Meal planning',
    },
    {
      'title': 'Fiber "Pre-Load" Before Meals',
      'category': 'Before',
      'icon': Icons.grass,
      'iconColor': Colors.teal,
      'gradientColors': [Colors.teal.shade400, Colors.green.shade700],
      'description': 'Eat 10-15g of viscous fiber (ground flaxseed, psyllium husk, or beans) 15 minutes before your main meal to trap glucose and slow absorption.',
      'scientificBasis': 'Viscous fiber forms a gel in the stomach that delays glucose absorption by 50-70%',
      'effectiveness': '⭐⭐⭐⭐',
      'timeRequired': '15 min before meal',
    },
    {
      'title': 'Cinnamon with Carbs',
      'category': 'During',
      'icon': Icons.spa,
      'iconColor': Colors.brown,
      'gradientColors': [Colors.brown.shade400, Colors.amber.shade800],
      'description': 'Add 1-2g (about 1/2 tsp) of cinnamon to your carb-heavy meals - on oatmeal, in coffee, or on toast. Cinnamon improves insulin sensitivity temporarily.',
      'scientificBasis': 'Meta-analysis of 10 studies shows cinnamon reduces fasting glucose by 10-29 mg/dL',
      'effectiveness': '⭐⭐⭐',
      'timeRequired': 'During meal prep',
    },
    {
      'title': 'Cold Exposure for Sensitivity',
      'category': 'General',
      'icon': Icons.ac_unit,
      'iconColor': Colors.cyan,
      'gradientColors': [Colors.cyan.shade400, Colors.blue.shade700],
      'description': 'Brief cold exposure (30-60 sec cold shower or splashing cold water on face/neck) can activate brown fat and improve insulin sensitivity for hours.',
      'scientificBasis': 'Cold exposure increases glucose uptake by brown adipose tissue by up to 15-20%',
      'effectiveness': '⭐⭐⭐',
      'timeRequired': '30-60 seconds',
    },
  ];

  List<Map<String, dynamic>> get _filteredTricks {
    if (_selectedFilter == 'All') {
      return _tricks;
    }
    return _tricks.where((trick) => trick['category'] == _selectedFilter).toList();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildTrickCard(Map<String, dynamic> trick, int index) {
    final isExpanded = _expandedCardIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedCardIndex = null;
          } else {
            _expandedCardIndex = index;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        child: CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(20),
          elevation: isExpanded ? 6 : 3,
          boxShadow: [
            BoxShadow(
              color: (trick['gradientColors'][0] as Color).withOpacity(0.15),
              blurRadius: isExpanded ? 15 : 8,
              offset: const Offset(0, 4),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon, title, and category tag
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: trick['gradientColors'],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (trick['gradientColors'][0] as Color).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      trick['icon'],
                      color: AppColors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trick['title'],
                          style: AppTextStyles.heading4.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.timer, size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              trick['timeRequired'],
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getCategoryColor(trick['category']).withOpacity(0.15),
                          _getCategoryColor(trick['category']).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getCategoryColor(trick['category']).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${trick['category']} Meal',
                      style: AppTextStyles.caption.copyWith(
                        color: _getCategoryColor(trick['category']),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Description
              Text(
                trick['description'],
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Effectiveness Rating
              Row(
                children: [
                  const Icon(Icons.trending_up, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Effectiveness: ',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    trick['effectiveness'],
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              
              // Expand/Collapse indicator
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    isExpanded ? 'Show less ▲' : 'Show scientific basis ▼',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              // Expanded scientific basis section
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      color: AppColors.borderLight,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.science,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Scientific Basis',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        trick['scientificBasis'],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Before':
        return Colors.green;
      case 'During':
        return Colors.orange;
      case 'After':
        return Colors.blue;
      case 'General':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.background,
                AppColors.primary.withOpacity(0.05),
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Smart Glucose Hacks',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Introduction Card with animation
              CustomCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.bolt,
                        color: AppColors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Science-Backed Glucose Hacks',
                            style: AppTextStyles.heading4.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Simple, proven strategies to keep your blood sugar stable without medication',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 24),
              
              // Stats row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(Icons.check_circle, '8', 'Verified Hacks'),
                    _buildStatItem(Icons.science, '100%', 'Science-Backed'),
                    _buildStatItem(Icons.timer, '5-15 min', 'Effort Needed'),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 24),
              
              // Filter Buttons with animation
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter;
                          _expandedCardIndex = null;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.borderLight,
                            width: 1.5,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ] : [],
                        ),
                        child: Text(
                          filter,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 28),
              
              // Trick Cards
              ..._filteredTricks.asMap().entries.map((entry) {
                final index = entry.key;
                final trick = entry.value;
                return _buildTrickCard(trick, index)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: (300 + index * 80).ms)
                    .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
              }).toList(),
              
              const SizedBox(height: 24),
              
              // Enhanced Pro Tips Section
              CustomCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderLight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.psychology,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Pro Strategies for Best Results',
                          style: AppTextStyles.heading4.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._getProTips().map((tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tip,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 800.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 20),
              
              // Disclaimer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.health_and_safety, size: 18, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ These are complementary strategies, not medical advice. Consult your doctor before making significant changes, especially if on medication.',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.amber.shade900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 900.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.heading4.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  List<String> _getProTips() {
    return [
      'Combine multiple tricks for synergistic effect (e.g., ACV + fiber pre-load + walk after)',
      'Track which hacks work best for YOUR unique glucose response using a log or CGM',
      'Consistency > intensity - small daily habits beat occasional perfect compliance',
      'Start with the highest-impact hacks (meal sequencing, post-meal walks, veggie-first)',
    ];
  }
}