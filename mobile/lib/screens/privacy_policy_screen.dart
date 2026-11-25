import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradient
          Container(
            height: 300,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF38ADB6), Color(0xFF4ECDC4)],
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Privacy & Security',
                                style: AppTextStyles.heading3.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'How we protect your data',
                                style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.8)),
                              ),
                            ],
                          ),
                        ),
                        // Shield icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shield, color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2, end: 0),

                  // White content area
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Trust Badge
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF38ADB6), Color(0xFF4ECDC4)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38ADB6).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.verified_user, color: Colors.white, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your Data is Safe With Us',
                                      style: AppTextStyles.heading4.copyWith(color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'We follow industry best practices for data protection',
                                      style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.8)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 24),

                        // Policy Cards
                        _buildPolicyCard(
                          icon: Icons.security,
                          title: 'Data Encryption',
                          description: 'Your personal and health data is encrypted using AES-256 encryption, the same standard used by banks and military.',
                          color: const Color(0xFF4ECDC4),
                          tag: 'Secure',
                        ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2, end: 0),

                        const SizedBox(height: 16),

                        _buildPolicyCard(
                          icon: Icons.block,
                          title: 'No Data Selling',
                          description: 'We never sell, rent, or share your personal information with third parties for marketing or any other purposes.',
                          color: const Color(0xFFFF6B6B),
                          tag: 'Private',
                        ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.2, end: 0),

                        const SizedBox(height: 16),

                        _buildPolicyCard(
                          icon: Icons.lock,
                          title: 'Secure Storage',
                          description: 'All data is stored on secure, encrypted servers with regular security audits and 24/7 monitoring.',
                          color: const Color(0xFF7C3AED),
                          tag: 'Protected',
                        ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2, end: 0),

                        const SizedBox(height: 16),

                        _buildPolicyCard(
                          icon: Icons.visibility,
                          title: 'Data Transparency',
                          description: 'You can view, export, or delete your data anytime from Settings. Full control in your hands.',
                          color: const Color(0xFFF59E0B),
                          tag: 'Control',
                        ).animate().fadeIn(delay: 700.ms).slideX(begin: 0.2, end: 0),

                        const SizedBox(height: 16),

                        _buildPolicyCard(
                          icon: Icons.gavel,
                          title: 'Your Rights',
                          description: 'Access, modify, export, or permanently delete your data at any time through your account settings.',
                          color: const Color(0xFF45B7D1),
                          tag: 'Rights',
                        ).animate().fadeIn(delay: 800.ms).slideX(begin: -0.2, end: 0),

                        const SizedBox(height: 16),

                        _buildPolicyCard(
                          icon: Icons.health_and_safety,
                          title: 'HIPAA Compliant',
                          description: 'We follow healthcare data protection standards to ensure your medical information stays confidential.',
                          color: const Color(0xFF10B981),
                          tag: 'Compliant',
                        ).animate().fadeIn(delay: 900.ms).slideX(begin: 0.2, end: 0),

                        const SizedBox(height: 24),

                        // Data Types Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4ECDC4).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.data_usage, color: Color(0xFF4ECDC4), size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Data We Collect',
                                    style: AppTextStyles.heading4.copyWith(fontSize: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildDataItem(Icons.person_outline, 'Personal Info', 'Name, email, age, gender'),
                              _buildDataItem(Icons.monitor_heart, 'Health Metrics', 'Weight, height, BMI, blood glucose'),
                              _buildDataItem(Icons.restaurant, 'Diet Data', 'Meals, calories, nutrition preferences'),
                              _buildDataItem(Icons.fitness_center, 'Activity', 'Exercise, sleep, water intake'),
                            ],
                          ),
                        ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 24),

                        // Contact
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ECDC4).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email, color: Color(0xFF4ECDC4), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Questions? Contact us at nutricareapp200@gmail.com',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 1100.ms),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required String tag,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textHint, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}