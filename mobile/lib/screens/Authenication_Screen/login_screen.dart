import 'package:nutricare/services/auth_service.dart';
import 'package:nutricare/model/auth_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input_field.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../../utils/app_urls.dart';
import '../Initial_profile_setup_screen/profile_setup_screen.dart';
import 'package:nutricare/services/profile_services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      try {
        print("🔐 Attempting login for: $email");
        print("🌐 Base URL: ${AppUrls.baseUrl}");

        final url = Uri.parse("${AppUrls.baseUrl}/auth/login");
        print("📡 Request URL: $url");

        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": email,
            "password": password,
          }),
        );

        print("📡 Response status: ${response.statusCode}");

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print("✅ Login successful, saving auth data...");

          // Save to SharedPreferences
          await AuthService().saveSession(AuthResponse.fromJson(data));

          // Verify save
          final savedData = await AuthService().getAuth();
          if (savedData != null) {
            print("✅ Auth data saved successfully!");

            // ✅ Check profile status after login
            await _checkProfileAndRedirect();
          } else {
            print("❌ Failed to save auth data!");
            setState(() {
              _errorMessage = "Failed to save login data";
            });
          }
        } else {
          final data = jsonDecode(response.body);
          print("❌ Login failed: ${data['detail']}");
          setState(() {
            _errorMessage = data["detail"] ?? "Login failed";
          });
        }
      } catch (e) {
        print("❌ Login error: $e");
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

// ✅ Add this new method
  Future<void> _checkProfileAndRedirect() async {
    try {
      // Fetch profile with force refresh
      final profile = await UserProfileService.getProfile(forceRefresh: true);

      print("📱 Profile fetched: ${profile != null}");
      print("📱 Profile completed: ${profile?.profileCompleted}");

      if (!mounted) return;

      // Check if profile exists and is completed
      if (profile == null || profile.profileCompleted != true) {
        // ✅ Profile not completed - go to profile setup
        print("🔄 Redirecting to Profile Setup...");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      } else {
        // ✅ Profile completed - go to dashboard
        print("🚀 Redirecting to Dashboard...");
        Navigator.pushReplacementNamed(context, "/dashboard");
      }
    } catch (e) {
      print("❌ Error checking profile: $e");
      // If error occurs, still try to go to dashboard
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/dashboard");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: h * 0.02),
                        Text(
                          'Welcome!',
                          style: AppTextStyles.heading2.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .slideY(begin: 0.3, end: 0),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue your nutrition journey',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 400.ms)
                            .slideY(begin: 0.3, end: 0),
                        SizedBox(height: h * 0.05),
                        CustomInputField(
                          label: 'Email',
                          hintText: 'Enter your email',
                          icon: Icons.email_outlined,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        )
                            .animate()
                            .fadeIn(delay: 600.ms)
                            .slideY(begin: 0.3, end: 0),
                        const SizedBox(height: 20),
                        CustomInputField(
                          label: 'Password',
                          hintText: 'Enter your password',
                          icon: Icons.lock_outline,
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textHint,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        )
                            .animate()
                            .fadeIn(delay: 800.ms)
                            .slideY(begin: 0.3, end: 0),
                        const SizedBox(height: 16),
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().slideY(begin: -0.2, end: 0),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Forgot Password?',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 1000.ms)
                            .slideY(begin: 0.3, end: 0),
                        SizedBox(height: h * 0.05),
                        CustomButton(
                          text: _isLoading ? 'Logging in...' : 'Login',
                          onPressed: _isLoading ? null : _login,
                        )
                            .animate()
                            .fadeIn(delay: 1200.ms)
                            .slideY(begin: 0.3, end: 0),
                        SizedBox(height: h * 0.03),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation,
                                            secondaryAnimation) =>
                                        const SignupScreen(),
                                    transitionsBuilder: (context, animation,
                                        secondaryAnimation, child) {
                                      return SlideTransition(
                                        position: animation.drive(
                                          Tween(
                                                  begin: const Offset(1.0, 0.0),
                                                  end: Offset.zero)
                                              .chain(CurveTween(
                                                  curve: Curves.easeInOut)),
                                        ),
                                        child: child,
                                      );
                                    },
                                    transitionDuration:
                                        const Duration(milliseconds: 300),
                                  ),
                                );
                              },
                              child: Text(
                                'Sign Up',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(delay: 1400.ms)
                            .slideY(begin: 0.3, end: 0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
