import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nutricare/screens/Authenication_Screen/login_screen.dart';
import 'package:nutricare/services/auth_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'cheat_tricks_screen/cheat_tricks_screen.dart';
import 'daily_tracker_screen/daily_tracker_screen.dart';
import 'dashboard_screen.dart';
import 'diet_plan_screen/diet_plan_screen.dart';
import 'meal_database_screen/meal_database_screen.dart';
import 'profile_screen.dart';
import 'weekly_report_screen.dart';
import 'widgets/custom_button.dart';
import '../services/profile_services.dart';
import '../utils/app_urls.dart';
import 'package:nutricare/model/profile_setup_model.dart';

// ✅ Global key for drawer - accessible from anywhere
final GlobalKey<ScaffoldState> globalScaffoldKey = GlobalKey<ScaffoldState>();

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();

  static final GlobalKey<_MainNavigationScreenState> navigatorKey =
      GlobalKey<_MainNavigationScreenState>();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _userName = 'User';
  String? _profileImagePath;
  bool _isLoading = true;
  bool _dataLoaded = false;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const DietPlanScreen(),
    const CheatTricksScreen(),
    const MealDatabaseScreen(),
    const DailyTrackerScreen(),
    const WeeklyReportScreen(),
    const ProfileScreen(),
  ];

  void setCurrentIndex(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    UserProfileService.addListener(_onProfileUpdated);
    _loadUserData();
  }

  void dispose() {
    UserProfileService.removeListener(_onProfileUpdated);
    super.dispose();
  }

  void _onProfileUpdated(ProfileModel profile) {
    if (mounted) {
      setState(() {
        if (profile.name != null && profile.name!.isNotEmpty) {
          _userName = profile.name!;
        }
        if (profile.profileImagePath != null &&
            profile.profileImagePath!.isNotEmpty) {
          _profileImagePath =
              AppUrls.getCloudinaryUrl(profile.profileImagePath);
        }
        _dataLoaded = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    if (_dataLoaded && _userName != 'User') {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = await AuthService().getAuth();
      final profileData =
          await UserProfileService.getProfile(forceRefresh: true);

      setState(() {
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

        if (profileData?.profileImagePath != null &&
            profileData!.profileImagePath!.isNotEmpty) {
          _profileImagePath =
              AppUrls.getCloudinaryUrl(profileData.profileImagePath);
        } else {
          _profileImagePath = null;
        }

        _dataLoaded = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> refreshProfileData() async {
    _dataLoaded = false;
    await _loadUserData();
    setState(() {});
  }

  String _getInitials() {
    if (_userName.isEmpty || _userName == 'User') return 'U';
    final parts = _userName.trim().split(' ');
    if (parts.length >= 2) {
      final firstInitial = parts[0].isNotEmpty ? parts[0][0] : '';
      final lastInitial = parts[1].isNotEmpty ? parts[1][0] : '';
      return '$firstInitial$lastInitial'.toUpperCase();
    } else if (_userName.isNotEmpty) {
      return _userName[0].toUpperCase();
    }
    return 'U';
  }

  Widget _buildSidebarAvatar() {
    if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: NetworkImage(_profileImagePath!),
            fit: BoxFit.cover,
            onError: (err, stack) {
              print("Sidebar image error: $err");
            },
          ),
        ),
      );
    }
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Health Dashboard',
                  style:
                      AppTextStyles.heading4.copyWith(color: AppColors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      _buildSidebarAvatar(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Welcome Back!',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(Icons.dashboard, 'Dashboard', 0),
                _buildDrawerItem(Icons.restaurant_menu, 'Diet Plan', 1),
                _buildDrawerItem(Icons.lightbulb, 'Cheat Tricks', 2),
                _buildDrawerItem(Icons.storage, 'Meal Database', 3),
                _buildDrawerItem(Icons.person, 'Profile', 6),
                _buildDrawerItem(Icons.favorite, 'Daily Tracker', 4),
                _buildDrawerItem(Icons.analytics, 'Weekly Report', 5),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomButton(
              text: 'Sign Out',
              onPressed: () async {
                await AuthService().clearAuth();
                await UserProfileService.clearProfileCache();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              backgroundColor: AppColors.error,
              icon: Icons.exit_to_app,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(title,
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
      onTap: () {
        Navigator.pop(context);
        setCurrentIndex(index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        key: globalScaffoldKey, // ✅ Use global key
        drawer: _buildNavigationDrawer(),
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textHint,
          selectedLabelStyle:
              AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTextStyles.caption,
          showUnselectedLabels: true,
          elevation: 10,
          backgroundColor: AppColors.white,
          items: [
            _buildBottomItem(Icons.dashboard_outlined, Icons.dashboard,
                'Dashboard', const Color(0xFF4ECDC4)),
            _buildBottomItem(Icons.restaurant_menu_outlined,
                Icons.restaurant_menu, 'Diet Plan', const Color(0xFFFF6B6B)),
            _buildBottomItem(Icons.lightbulb_outline, Icons.lightbulb,
                'Cheat Tricks', const Color(0xFFFFD93D)),
            _buildBottomItem(Icons.storage_outlined, Icons.storage, 'Meal DB',
                const Color(0xFF6BCB77)),
            _buildBottomItem(Icons.track_changes_outlined, Icons.track_changes,
                'Tracker', const Color(0xFF9D84B7)),
            _buildBottomItem(Icons.analytics_outlined, Icons.analytics,
                'Reports', const Color(0xFFF38181)),
            _buildBottomItem(Icons.person_outline, Icons.person, 'Profile',
                const Color(0xFF38ADB6)),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildBottomItem(
      IconData icon, IconData activeIcon, String label, Color color) {
    return BottomNavigationBarItem(
      icon: Icon(icon, color: color),
      activeIcon: Icon(activeIcon, color: AppColors.primary)
          .animate()
          .scale(duration: 200.ms),
      label: label,
    );
  }
}
