import 'package:nutricare/model/treatment_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Add this for kIsWeb
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nutricare/model/auth_model.dart';
import 'package:nutricare/model/profile_setup_model.dart';
import 'package:nutricare/services/auth_service.dart';
import 'package:nutricare/services/profile_services.dart';
import 'package:nutricare/services/user_service_settings.dart';
import 'package:nutricare/services/notification_service.dart';
import 'package:nutricare/utils/app_urls.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'widgets/custom_card.dart';
import '../screens/edit_profile.dart';
import 'package:nutricare/screens/main_navigation_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../widgets/notification_panel.dart';
import '../screens/Authenication_Screen/login_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
// Conditional import for web-only functionality
import '../screens/terms_conditions.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProfileTab = true;
  ProfileModel? _profileData;
  AuthResponse? _authData;
  bool _isLoading = true;
  bool _dataLoaded = false;
  bool _pushNotificationsEnabled = false;
  bool _isSaving = false;
  int _unreadNotifications = 0;
  int _activeDevices = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _isProfileTab = _tabController.index == 0);
    });
    UserProfileService.addListener(_onProfileUpdated);
    _loadProfileData();
    _loadNotificationSettings();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final profileData = await UserProfileService.getProfile(forceRefresh: true);
    final authData = await AuthService().getAuth();
    setState(() {
      _profileData = profileData;
      _authData = authData;
      _isLoading = false;
      _dataLoaded = true;
    });
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final settings = await UserSettingsService.getSettings();
      if (settings != null && settings['success'] == true) {
        final data = settings['data'];
        setState(() {
          _pushNotificationsEnabled =
              data['push_notifications']['enabled'] ?? false;
          _activeDevices = data['push_notifications']['active_devices'] ?? 0;
          _unreadNotifications = data['unread_notifications'] ?? 0;
        });
      }
    } catch (e) {
      print("Error loading notification settings: $e");
    }
  }

  Future<void> _togglePushNotifications(bool value) async {
    setState(() => _isSaving = true);

    try {
      Map<String, dynamic> result;

      if (value) {
        result = await UserSettingsService.togglePushNotifications(
          enabled: true,
          deviceToken: 'flutter_device_token',
          platform: Theme.of(context).platform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        );
      } else {
        result =
            await UserSettingsService.togglePushNotifications(enabled: false);
      }

      if (result['success'] == true) {
        setState(() {
          _pushNotificationsEnabled = result['push_enabled'] ?? value;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Settings updated'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        await NotificationService.refreshUnreadCount();
      } else {
        setState(() => _pushNotificationsEnabled = !value);
        _showErrorSnackBar(result['message'] ?? 'Failed to update');
      }
    } catch (e) {
      setState(() => _pushNotificationsEnabled = !value);
      _showErrorSnackBar('Connection error: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool isChanging = false;

    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.primary),
              SizedBox(width: 12),
              Text('Change Password',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password must contain:',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildPasswordRequirement(
                    'At least 8 characters', Icons.check_circle_outline),
                _buildPasswordRequirement(
                    'One uppercase letter (A-Z)', Icons.text_fields),
                _buildPasswordRequirement(
                    'One lowercase letter (a-z)', Icons.text_format),
                _buildPasswordRequirement('One number (0-9)', Icons.pin),
                _buildPasswordRequirement(
                    'One special character (!@#\$%^&*)', Icons.star),

                const SizedBox(height: 20),

                // Current Password
                TextField(
                  controller: currentController,
                  obscureText: !showCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(showCurrent
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setDialogState(() => showCurrent = !showCurrent),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // New Password
                TextField(
                  controller: newController,
                  obscureText: !showNew,
                  onChanged: (val) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Min 8 chars, A-Z, a-z, 0-9, !@#',
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: IconButton(
                      icon: Icon(
                          showNew ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => showNew = !showNew),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    errorText: newController.text.isNotEmpty
                        ? _validatePassword(newController.text)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextField(
                  controller: confirmController,
                  obscureText: !showConfirm,
                  onChanged: (val) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: IconButton(
                      icon: Icon(showConfirm
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setDialogState(() => showConfirm = !showConfirm),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    errorText: confirmController.text.isNotEmpty &&
                            confirmController.text != newController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                ),

                // Password strength indicator
                if (newController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildPasswordStrengthIndicator(newController.text),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isChanging ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isChanging
                  ? null
                  : () async {
                      if (currentController.text.isEmpty) {
                        _showErrorSnackBar(
                            'Please enter your current password');
                        return;
                      }

                      final passwordError =
                          _validatePassword(newController.text);
                      if (passwordError != null) {
                        _showErrorSnackBar(passwordError);
                        return;
                      }

                      if (newController.text != confirmController.text) {
                        _showErrorSnackBar('Passwords do not match');
                        return;
                      }

                      setDialogState(() => isChanging = true);

                      try {
                        final result = await UserSettingsService.changePassword(
                          currentPassword: currentController.text,
                          newPassword: newController.text,
                          confirmPassword: confirmController.text,
                        );

                        if (result['success'] == true) {
                          Navigator.pop(dialogContext);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['message'] ??
                                    'Password changed successfully'),
                                backgroundColor: AppColors.success,
                              ),
                            );

                            // ✅ Show loading
                            final loader = showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text("Logging out..."),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );

                            await AuthService().clearAuth();
                            await UserProfileService.clearProfileCache();

                            if (mounted) {
                              Navigator.pop(context); // Close loader
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          }
                        } else {
                          _showErrorSnackBar(
                              result['message'] ?? 'Failed to change password');
                        }
                      } catch (e) {
                        _showErrorSnackBar('Error: $e');
                      } finally {
                        setDialogState(() => isChanging = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isChanging
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

// Helper methods
  String? _validatePassword(String password) {
    if (password.isEmpty) return null;
    if (password.length < 8) return 'At least 8 characters required';
    if (!RegExp(r'[A-Z]').hasMatch(password)) return 'Add one uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(password)) return 'Add one lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Add one number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password))
      return 'Add one special character';
    return null;
  }

  Widget _buildPasswordRequirement(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textHint),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(String password) {
    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    String label;
    Color color;
    switch (strength) {
      case 1:
        label = 'Weak';
        color = AppColors.error;
        break;
      case 2:
        label = 'Fair';
        color = AppColors.warning;
        break;
      case 3:
        label = 'Good';
        color = Colors.orange;
        break;
      case 4:
        label = 'Strong';
        color = AppColors.success;
        break;
      case 5:
        label = 'Very Strong';
        color = Colors.green;
        break;
      default:
        label = 'Very Weak';
        color = AppColors.error;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Strength: ',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textHint)),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: strength / 5,
            backgroundColor: const Color.fromRGBO(238, 238, 238, 1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    bool confirmed = false;
    bool isDeleting = false;
    bool _obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.delete_forever, color: AppColors.error),
              SizedBox(width: 12),
              Text('Delete Account',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: AppColors.error, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This action is permanent and cannot be undone! All your data will be deleted.',
                          style:
                              TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ✅ Password Field with show/hide icon
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Enter your password to confirm',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.textHint,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I understand, delete my account',
                      style: TextStyle(fontSize: 14)),
                  value: confirmed,
                  onChanged: (val) => setDialogState(() => confirmed = val!),
                  activeColor: AppColors.error,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (isDeleting ||
                      !confirmed ||
                      passwordController.text.isEmpty)
                  ? null
                  : () async {
                      setDialogState(() => isDeleting = true);

                      try {
                        final result = await UserSettingsService.deleteAccount(
                          password: passwordController.text,
                          confirmDelete: confirmed,
                        );

                        if (result['success'] == true) {
                          Navigator.pop(dialogContext);

                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    result['message'] ?? 'Account deleted'),
                                backgroundColor: AppColors.error,
                              ),
                            );

                            await AuthService().clearAuth();
                            await UserProfileService.clearProfileCache();

                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                this.context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          }
                        } else {
                          _showErrorSnackBar(
                              result['message'] ?? 'Failed to delete account');
                        }
                      } catch (e) {
                        _showErrorSnackBar('Error: $e');
                      } finally {
                        setDialogState(() => isDeleting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExportData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating your PDF report...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final currentAuth = await AuthService().getAuth();
      if (currentAuth == null)
        throw Exception('Session expired. Please log in again.');
      final token = currentAuth.accessToken;

      final response = await http.get(
        Uri.parse(AppUrls.exportDataPdf),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        // Mobile platform (Android/iOS)
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'NutriCare_Report_${DateTime.now().toString().split(' ')[0]}.pdf';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  Text('PDF Report Ready!', style: AppTextStyles.heading4),
                ],
              ),
              content: Text(
                'Your health report has been generated.\n\nFile: $fileName',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    OpenFile.open(file.path);
                  },
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                  label: const Text('Open PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Share.shareXFiles(
                      [XFile(file.path)],
                      text: '📊 My NutriCare Health Report',
                    );
                  },
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text('Share PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        _showErrorSnackBar(
            'Failed to generate PDF. Status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().clearAuth();
      await UserProfileService.clearProfileCache();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  String _getInitials() {
    final name = _profileData?.name ?? _authData?.user.firstName ?? 'User';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _getInsulinDisplay() {
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
    return 'Yes';
  }

  Widget _buildAvatar() {
    final imagePath = _profileData?.profileImagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      String fullUrl = AppUrls.getCloudinaryUrl(imagePath);
      fullUrl = "$fullUrl?t=${DateTime.now().millisecondsSinceEpoch}";
      return CircleAvatar(
        radius: 40,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        backgroundImage: NetworkImage(fullUrl),
        onBackgroundImageError: (err, stack) {
          print("Image load error: $err");
          setState(() {});
        },
      );
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      child: Text(
        _getInitials(),
        style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary),
      ),
    );
  }

  double? _calculateBMI() {
    final weight = _profileData?.weight;
    final height = _profileData?.height;
    if (weight == null || height == null || height <= 0) return null;
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [_buildProfileTab(), _buildSecurityTab()],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Profile',
              style: AppTextStyles.heading3
                  .copyWith(color: AppColors.textPrimary)),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: [
          Tab(child: _buildTabHeader('Profile', Icons.person, _isProfileTab)),
          Tab(
              child: _buildTabHeader(
                  'Settings', Icons.manage_accounts, !_isProfileTab)),
        ],
      ),
    );
  }

  Widget _buildTabHeader(String label, IconData icon, bool isActive) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon,
            size: 20,
            color: isActive ? AppColors.primary : AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Widget _buildProfileTab() {
    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CustomCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_profileData?.name ?? 'User Name',
                            style: AppTextStyles.heading4),
                        Text(
                            _profileData?.email ??
                                _authData?.user.email ??
                                'No email',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                EditProfileScreen(profile: _profileData)),
                      );
                      if (updated == true) {
                        await _loadProfileData();
                        MainNavigationScreen.navigatorKey.currentState
                            ?.refreshProfileData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Profile updated successfully!")),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.edit_note,
                        color: AppColors.primary, size: 28),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1),
            const SizedBox(height: 24),
            _buildSectionHeader(Icons.person, "Personal Information"),
            CustomCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow('Full Name', _profileData?.name ?? 'Not set',
                      Icons.person_outline),
                  _buildInfoRow('Age', '${_profileData?.age ?? 'Not set'}',
                      Icons.cake_outlined),
                  _buildInfoRow(
                      'Gender',
                      (_profileData?.gender ?? 'Not set').toUpperCase(),
                      Icons.wc),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(Icons.favorite, "Physical Metrics"),
            CustomCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildMetricRow('Weight', '${_profileData?.weight ?? 0} Kg',
                      Icons.monitor_weight,
                      iconColor: Colors.purple),
                  _buildMetricRow(
                      'Height', '${_profileData?.height ?? 0} cm', Icons.height,
                      iconColor: Colors.red),
                  _buildMetricRow(
                    'BMI',
                    _calculateBMI()?.toStringAsFixed(1) ?? 'N/A',
                    Icons.speed,
                    iconColor: Colors.green,
                    status: _calculateBMI() != null
                        ? _getBMICategory(_calculateBMI()!)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(Icons.bloodtype, "Diabetes Status"),
            CustomCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatusBadge(
                          'Condition',
                          (_profileData?.diabetesStatus ?? 'None')
                              .toUpperCase(),
                          Colors.pink),
                      const SizedBox(width: 12),
                      _buildStatusBadge(
                          'Insulin',
                          _profileData?.insulinUsage == true ? 'Yes' : 'No',
                          Colors.green),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildInfoRow(
                      'Medications',
                      _profileData?.treatment.medications.isNotEmpty == true
                          ? _profileData!.treatment.medications
                              .map((m) => m.name.isNotEmpty
                                  ? m.name
                                  : (medicationClassLabels[m.medicationClass] ??
                                      m.medicationClass))
                              .join(', ')
                          : (_profileData?.treatment.medicationsConfirmed ==
                                  true
                              ? 'None reported'
                              : 'Not confirmed'),
                      Icons.medication_outlined),
                  if (_profileData?.insulinUsage == true) ...[
                    const Divider(height: 32),
                    _buildInfoRow('Insulin Details', _getInsulinDisplay(),
                        Icons.medication_liquid,
                        iconColor: Colors.orange),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.lock_outline, 'Security'),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.lock_reset,
            title: 'Change Password',
            subtitle: 'Update your account password',
            iconColor: AppColors.primary,
            onTap: _showChangePasswordDialog,
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2, end: 0),
          const SizedBox(height: 24),
          _buildSectionHeader(Icons.notifications_active, 'Notifications'),
          const SizedBox(height: 12),
          _buildSwitchTile(
            icon: Icons.notifications_active,
            title: 'Push Notifications',
            subtitle: _pushNotificationsEnabled
                ? 'Enabled ($_activeDevices active devices)'
                : 'Disabled',
            value: _pushNotificationsEnabled,
            iconColor: AppColors.primary,
            isLoading: _isSaving,
            onChanged: _togglePushNotifications,
          ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2, end: 0),
          const SizedBox(height: 24),
          _buildSectionHeader(Icons.privacy_tip, 'Data & Privacy'),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.download,
            title: 'Export Your Data',
            subtitle: 'Download all your personal information',
            iconColor: Colors.green,
            onTap: _handleExportData,
          ).animate().fadeIn(delay: 800.ms).slideX(begin: -0.2, end: 0),
          _buildSettingsTile(
            icon: Icons.policy,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
            iconColor: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ).animate().fadeIn(delay: 1000.ms).slideX(begin: -0.2, end: 0),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Terms And Conditions',
            subtitle: 'How you should use our app',
            iconColor: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TermsConditionsScreen()),
              );
            },
          ).animate().fadeIn(delay: 1000.ms).slideX(begin: -0.2, end: 0),
          const SizedBox(height: 32),
          _buildDangerZoneHeader(),
          const SizedBox(height: 12),
          _buildDangerTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and all data',
            onTap: _showDeleteAccountDialog,
          ).animate().fadeIn(delay: 1200.ms).slideX(begin: -0.2, end: 0),
          _buildDangerTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out from your account',
            onTap: _handleLogout,
          ).animate().fadeIn(delay: 1400.ms).slideX(begin: -0.2, end: 0),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.heading4.copyWith(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon,
      {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon,
      {Color? iconColor, String? status}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: (iconColor ?? AppColors.primary).withOpacity(0.1),
            child: Icon(icon, color: iconColor ?? AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodyMedium),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.bold)),
              if (status != null)
                Text(status,
                    style: AppTextStyles.caption.copyWith(
                        color: iconColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Center(
              child: Text(value,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color iconColor,
      required VoidCallback onTap}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile(
      {required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required Color iconColor,
      required bool isLoading,
      required ValueChanged<bool> onChanged}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        value: value,
        activeColor: AppColors.primary,
        onChanged: isLoading ? null : onChanged,
      ),
    );
  }

  Widget _buildDangerTile(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Card(
      elevation: 1,
      color: AppColors.error.withOpacity(0.03),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.error.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.error, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.error)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.error),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDangerZoneHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.warning, color: AppColors.error, size: 20),
        ),
        const SizedBox(width: 12),
        Text('Danger Zone',
            style: AppTextStyles.heading4.copyWith(color: AppColors.error)),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    UserProfileService.removeListener(_onProfileUpdated);
    super.dispose();
  }

  void _onProfileUpdated(ProfileModel profile) {
    if (mounted) {
      setState(() {
        _profileData = profile;
      });
    }
  }
}
