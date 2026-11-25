import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

Future<void> _launchEmail(String email) async {
  // ✅ For Web - Open Gmail compose directly
  final gmailUrl = 'https://mail.google.com/mail/?view=cm&fs=1&to=$email';
  final emailUri = Uri.parse(gmailUrl);
  
  if (await canLaunchUrl(emailUri)) {
    await launchUrl(emailUri, mode: LaunchMode.externalApplication);
  } else {
    // Fallback to normal mailto
    final mailtoUri = Uri.parse('mailto:$email');
    await launchUrl(mailtoUri);
  }
}

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradient with animation
          Container(
            height: 320,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
            ),
          ).animate().fadeIn(duration: 600.ms).then().shimmer(duration: 1500.ms),
          
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                          ).animate().scale(delay: 100.ms, duration: 300.ms),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Terms & Conditions',
                              style: AppTextStyles.heading2.copyWith(color: Colors.white, fontSize: 24),
                            ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.2, end: 0),
                            Text(
                              'Last updated: May 2025',
                              style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.8)),
                            ).animate().fadeIn(delay: 200.ms),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // White content area
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(35),
                        topRight: Radius.circular(35),
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Card
                        _buildInfoCard(
                          icon: Icons.waving_hand,
                          color: AppColors.primary,
                          title: 'Welcome to NutriCareAI! 👋',
                          subtitle: 'By using our app, you agree to these terms. Please read them carefully.',
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0),

                        const SizedBox(height: 24),

                        // Medical Disclaimer
                        _buildSectionCard(
                          icon: Icons.medical_services,
                          color: AppColors.error,
                          title: 'Medical Disclaimer',
                          content: 'NutriCareAI provides health tracking tools for informational purposes only. This is NOT medical advice. Always consult your doctor before making health decisions.',
                        ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2, end: 0),

                        const SizedBox(height: 16),

                        // User Accounts
                        _buildSectionCard(
                          icon: Icons.person,
                          color: AppColors.primary,
                          title: 'User Accounts',
                          content: '• Keep your login credentials safe\n• You\'re responsible for all account activity\n• Provide accurate information\n• Must be 13+ years old to use',
                        ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.2, end: 0),

                        const SizedBox(height: 16),

                        // Privacy & Data
                        _buildSectionCard(
                          icon: Icons.privacy_tip,
                          color: Colors.purple,
                          title: 'Privacy & Data',
                          content: 'We collect health metrics, diet data, and personal information to provide our services. Your data is encrypted and never sold to third parties.',
                        ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2, end: 0),

                        const SizedBox(height: 16),

                        // AI Content
                        _buildSectionCard(
                          icon: Icons.smart_toy,
                          color: Colors.orange,
                          title: 'AI-Generated Content',
                          content: 'Diet plans are AI-generated and may not be 100% accurate. Review recommendations with your healthcare provider before following them.',
                        ).animate().fadeIn(delay: 700.ms).slideX(begin: 0.2, end: 0),

                        const SizedBox(height: 16),

                        // Liability
                        _buildSectionCard(
                          icon: Icons.shield,
                          color: Colors.indigo,
                          title: 'Limitation of Liability',
                          content: 'We are not liable for health complications, data loss, or decisions made based on app recommendations. Use at your own discretion.',
                        ).animate().fadeIn(delay: 800.ms).slideX(begin: -0.2, end: 0),

                        const SizedBox(height: 16),

                        // Termination
                        _buildSectionCard(
                          icon: Icons.block,
                          color: AppColors.error,
                          title: 'Termination',
                          content: 'We may suspend accounts for violations. You can delete your account anytime from Settings > Danger Zone > Delete Account.',
                        ).animate().fadeIn(delay: 900.ms).slideX(begin: 0.2, end: 0),

                        const SizedBox(height: 16),

                        // Changes to Terms
                        _buildSectionCard(
                          icon: Icons.update,
                          color: Colors.teal,
                          title: 'Changes to Terms',
                          content: 'We may update these terms periodically. Continued use means you accept the changes.',
                        ).animate().fadeIn(delay: 1000.ms).slideX(begin: -0.2, end: 0),

                        const SizedBox(height: 24),

                        // Contact Card - CLICKABLE EMAIL
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
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
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.headset_mic, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Contact Support',
                                    style: AppTextStyles.heading4.copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              // ✅ Email - Clickable (Opens Gmail)
                              InkWell(
                                onTap: () => _launchEmail('nutricareapp200@gmail.com'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.email, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Email Us',
                                              style: AppTextStyles.bodySmall.copyWith(
                                                color: Colors.white.withOpacity(0.7),
                                              ),
                                            ),
                                            Text(
                                              'nutricareapp200@gmail.com',
                                              style: AppTextStyles.bodyMedium.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.open_in_new, color: Colors.white, size: 18),
                                    ],
                                  ),
                                ),
                              ).animate().scale(delay: 300.ms).then().shimmer(),
                              
                              const SizedBox(height: 12),
                              
                              // Location - Not clickable
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Office Location',
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: Colors.white.withOpacity(0.7),
                                            ),
                                          ),
                                          Text(
                                            'Karachi, Pakistan',
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 1100.ms).slideY(begin: 0.3, end: 0),

                        const SizedBox(height: 24),

                        // Website Link
                        InkWell(
                          onTap: () => _launchUrl('https://nutricareai.com'),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.language, color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Visit our Website',
                                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        'www.nutricareai.com',
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.open_in_new, color: AppColors.primary, size: 18),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 1200.ms).slideX(begin: -0.2, end: 0),

                        const SizedBox(height: 24),

                        // Agreement Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.success.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.check_circle, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'By using NutriCareAI, you agree to these Terms & Conditions.',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 1300.ms).scale(delay: 300.ms),

                        const SizedBox(height: 20),
                        
                        // Footer
                        Center(
                          child: Text(
                            '© 2025 NutriCareAI. All rights reserved.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ).animate().fadeIn(delay: 1400.ms),

                        const SizedBox(height: 20),
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

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 6),
                Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Text(title, style: AppTextStyles.heading4.copyWith(fontSize: 16, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            content,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}