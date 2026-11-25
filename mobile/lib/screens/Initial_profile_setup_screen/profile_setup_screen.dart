import 'package:nutricare/model/treatment_model.dart';
import 'package:nutricare/widgets/treatment_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nutricare/model/profile_setup_model.dart';
import 'package:nutricare/services/auth_service.dart';
import 'package:nutricare/services/profile_services.dart';

import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../main_navigation_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_input_field.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 8;
  TreatmentProfile _treatment = const TreatmentProfile();

  // Form controllers
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bloodSugarController = TextEditingController();
  final _insulinMorningController = TextEditingController();
  final _insulinNightController = TextEditingController();

  // Error texts - show real-time
  String? _ageError;
  String? _weightError;
  String? _heightError;
  String? _bloodSugarError;
  String? _insulinMorningError;
  String? _insulinNightError;

  // Selected values
  String? _selectedGender;
  String? _diabetesStatus;
  String? _insulinUsage;
  String? _activityLevel;
  final List<String> _selectedGoals = [];
  final List<String> _selectedPreferences = [];

  final List<String> _diabetesStatusOptions = [
    'Type 1 Diabetes',
    'Type 2 Diabetes',
    'Pre-diabetes',
    'Gestational Diabetes',
    'No Diabetes',
  ];

  final List<String> _insulinUsageOptions = [
    'Yes, I use insulin',
    'No, I don\'t use insulin',
  ];

  final List<String> _activityLevels = [
    'Sedentary (little to no exercise)',
    'Lightly Active (light exercise 1-3 days/week)',
    'Moderately Active (moderate exercise 3-5 days/week)',
    'Very Active (hard exercise 6-7 days/week)',
    'Extremely Active (very hard exercise, physical job)',
  ];

  final List<String> _goals = [
    'Weight Loss',
    'Blood Sugar Control',
    'Muscle Gain',
    'Maintain Weight',
    'Improve Energy',
    'Better Sleep',
    'General Health',
    'Heart Health',
  ];

  final List<String> _preferences = [
    'Vegetarian',
    'Vegan',
    'Keto',
    'Paleo',
    'Gluten-Free',
    'Dairy-Free',
    'Low-Carb',
    'Mediterranean',
    'Balanced Diet',
  ];

  @override
  void initState() {
    super.initState();
    // Add listeners for real-time validation
    _ageController.addListener(() => _validateAge());
    _weightController.addListener(() => _validateWeight());
    _heightController.addListener(() => _validateHeight());
    _bloodSugarController.addListener(() => _validateBloodSugar());
    _insulinMorningController.addListener(() => _validateInsulinMorning());
    _insulinNightController.addListener(() => _validateInsulinNight());
  }

  // ==================== REAL-TIME VALIDATION METHODS ====================

  void _validateAge() {
    setState(() {
      final value = _ageController.text.trim();
      if (value.isEmpty) {
        _ageError = null;
      } else {
        final age = int.tryParse(value);
        if (age == null) {
          _ageError = 'Please enter a valid number';
        } else if (age < 18) {
          _ageError = 'Age must be at least 18 year';
        } else if (age > 100) {
          _ageError = 'Age cannot be more than 100 years';
        } else {
          _ageError = null;
        }
      }
    });
  }

  void _validateWeight() {
    setState(() {
      final value = _weightController.text.trim();
      if (value.isEmpty) {
        _weightError = null;
      } else {
        final weight = double.tryParse(value);
        if (weight == null) {
          _weightError = 'Please enter a valid number';
        } else if (weight < 10) {
          _weightError = 'Weight must be at least 10 kg';
        } else if (weight > 300) {
          _weightError = 'Weight cannot be more than 300 kg';
        } else {
          _weightError = null;
        }
      }
    });
  }

  void _validateHeight() {
    setState(() {
      final value = _heightController.text.trim();
      if (value.isEmpty) {
        _heightError = null;
      } else {
        final height = double.tryParse(value);
        if (height == null) {
          _heightError = 'Please enter a valid number';
        } else if (height < 50) {
          _heightError = 'Height must be at least 50 cm';
        } else if (height > 250) {
          _heightError = 'Height cannot be more than 250 cm';
        } else {
          _heightError = null;
        }
      }
    });
  }

  // MODIFIED: Blood sugar validation - ONLY INTEGER allowed
  void _validateBloodSugar() {
    setState(() {
      final value = _bloodSugarController.text.trim();
      if (value.isEmpty) {
        _bloodSugarError = null;
      } else {
        // Check if contains decimal point
        if (value.contains('.')) {
          _bloodSugarError =
              '❌ Decimal points not allowed. Enter whole number only (e.g., 120)';
          return;
        }

        final bs = int.tryParse(value);
        if (bs == null) {
          _bloodSugarError = 'Please enter a valid whole number';
        } else if (bs < 20) {
          _bloodSugarError = 'Blood sugar must be at least 20 mg/dL';
        } else if (bs > 600) {
          _bloodSugarError = 'Blood sugar cannot exceed 600 mg/dL';
        } else {
          _bloodSugarError = null;
        }
      }
    });
  }

  void _validateInsulinMorning() {
    setState(() {
      if (_insulinUsage == 'Yes, I use insulin') {
        final value = _insulinMorningController.text.trim();
        if (value.isEmpty) {
          _insulinMorningError = 'Morning insulin dose required';
        } else {
          final dose = int.tryParse(value);
          if (dose == null) {
            _insulinMorningError = 'Enter a valid number';
          } else if (dose < 0) {
            _insulinMorningError = 'Dose cannot be negative';
          } else if (dose > 100) {
            _insulinMorningError = 'Dose seems too high (>100 units)';
          } else {
            _insulinMorningError = null;
          }
        }
      } else {
        _insulinMorningError = null;
      }
    });
  }

  void _validateInsulinNight() {
    setState(() {
      if (_insulinUsage == 'Yes, I use insulin') {
        final value = _insulinNightController.text.trim();
        if (value.isEmpty) {
          _insulinNightError = 'Night insulin dose required';
        } else {
          final dose = int.tryParse(value);
          if (dose == null) {
            _insulinNightError = 'Enter a valid number';
          } else if (dose < 0) {
            _insulinNightError = 'Dose cannot be negative';
          } else if (dose > 100) {
            _insulinNightError = 'Dose seems too high (>100 units)';
          } else {
            _insulinNightError = null;
          }
        }
      } else {
        _insulinNightError = null;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _bloodSugarController.dispose();
    _insulinMorningController.dispose();
    _insulinNightController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // ✅ Force validate all fields before moving to next step
    if (!_validateCurrentStep()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getCurrentStepErrorMessage()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeSetup();
    }
  }

// ✅ Add this method to validate current step
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Personal Info
        // Gender
        if (_selectedGender == null) {
          _showError("Please select your gender");
          return false;
        }

        // Age
        final ageStr = _ageController.text.trim();
        if (ageStr.isEmpty) {
          _showError("Please enter your age");
          return false;
        }
        final age = int.tryParse(ageStr);
        if (age == null || age < 1 || age > 120) {
          _showError("Age must be between 1 and 120 years");
          return false;
        }

        // Weight
        final weightStr = _weightController.text.trim();
        if (weightStr.isEmpty) {
          _showError("Please enter your weight");
          return false;
        }
        final weight = double.tryParse(weightStr);
        if (weight == null || weight < 10 || weight > 300) {
          _showError("Weight must be between 10 and 300 kg");
          return false;
        }

        // Height
        final heightStr = _heightController.text.trim();
        if (heightStr.isEmpty) {
          _showError("Please enter your height");
          return false;
        }
        final height = double.tryParse(heightStr);
        if (height == null || height < 50 || height > 250) {
          _showError("Height must be between 50 and 250 cm");
          return false;
        }
        return true;

      case 1: // Diabetes Status
        if (_diabetesStatus == null) {
          _showError("Please select your diabetes status");
          return false;
        }
        return true;

      case 2: // Insulin Usage
        if (_insulinUsage == null) {
          _showError("Please select insulin usage");
          return false;
        }
        if (_insulinUsage == 'Yes, I use insulin') {
          final morningStr = _insulinMorningController.text.trim();
          if (morningStr.isEmpty) {
            _showError("Please enter morning insulin dose");
            return false;
          }
          final morning = int.tryParse(morningStr);
          if (morning == null || morning < 0 || morning > 100) {
            _showError("Morning insulin dose must be between 0-100 units");
            return false;
          }

          final nightStr = _insulinNightController.text.trim();
          if (nightStr.isEmpty) {
            _showError("Please enter night insulin dose");
            return false;
          }
          final night = int.tryParse(nightStr);
          if (night == null || night < 0 || night > 100) {
            _showError("Night insulin dose must be between 0-100 units");
            return false;
          }
        }
        return true;

      case 3: // Blood Sugar - ✅ Updated with integer validation
        final bsStr = _bloodSugarController.text.trim();
        if (bsStr.isEmpty) {
          _showError("Please enter your blood sugar reading");
          return false;
        }

        // ✅ Check for decimal
        if (bsStr.contains('.')) {
          _showError(
              "Blood sugar must be a whole number (e.g., 120), no decimal points allowed");
          return false;
        }

        final bs = int.tryParse(bsStr);
        if (bs == null) {
          _showError("Please enter a valid whole number");
          return false;
        }
        if (bs < 20) {
          _showError("Blood sugar must be at least 20 mg/dL");
          return false;
        }
        if (bs > 600) {
          _showError("Blood sugar cannot exceed 600 mg/dL");
          return false;
        }
        return true;
      case 4: // Activity Level
        if (_activityLevel == null) {
          _showError("Please select your activity level");
          return false;
        }
        return true;

      case 5: // Goals
        if (_selectedGoals.isEmpty) {
          _showError("Please select at least one health goal");
          return false;
        }
        return true;

      case 6: // Preferences
        if (_selectedPreferences.isEmpty) {
          _showError("Please select at least one dietary preference");
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getCurrentStepErrorMessage() {
    switch (_currentStep) {
      case 0:
        return "Please fill all personal information correctly (Age: 1-120, Weight: 10-300 kg, Height: 50-250 cm)";
      case 1:
        return "Please select your diabetes status";
      case 2:
        return "Please complete insulin information correctly";
      case 3:
        return "Please enter valid blood sugar reading (20-600 mg/dL)";
      case 4:
        return "Please select your activity level";
      case 5:
        return "Please select at least one health goal";
      case 6:
        return "Please select at least one dietary preference";
      default:
        return "Please complete all fields";
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  final Map<String, String> diabetesStatusMap = {
    'No Diabetes': 'none',
    'Type 1 Diabetes': 'type1',
    'Type 2 Diabetes': 'type2',
    'Pre-diabetes': 'prediabetes',
    'Gestational Diabetes': 'gestational',
  };

  final Map<String, String> activityLevelMap = {
    'Sedentary (little to no exercise)': 'sedentary',
    'Lightly Active (light exercise 1-3 days/week)': 'lightly_active',
    'Moderately Active (moderate exercise 3-5 days/week)': 'moderately_active',
    'Very Active (hard exercise 6-7 days/week)': 'very_active',
    'Extremely Active (very hard exercise, physical job)': 'extremely_active',
  };

  Future<void> _completeSetup() async {
    final userInfo = await AuthService().getAuth();

    if (userInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found. Please login again.")),
      );
      return;
    }

    // ✅ Final validation before saving
    if (!_validateAllFields()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields correctly"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // ✅ Get blood sugar as integer
    int? bloodSugarInt;
    final bsStr = _bloodSugarController.text.trim();
    if (bsStr.isNotEmpty) {
      bloodSugarInt = int.tryParse(bsStr);
    }

    ProfileModel profileModel = ProfileModel(
      userId: userInfo.user.userId,
      treatment: _treatment.withInsulin(_insulinUsage == 'Yes, I use insulin'),
      gender: _selectedGender?.toLowerCase(),
      age: int.tryParse(_ageController.text.trim()),
      weight: double.tryParse(_weightController.text.trim()),
      height: double.tryParse(_heightController.text.trim()),
      diabetesStatus: diabetesStatusMap[_diabetesStatus] ?? 'none',
      insulinUsage: _insulinUsage == 'Yes, I use insulin',
      insulinMorningUnits: _insulinUsage == 'Yes, I use insulin'
          ? int.tryParse(_insulinMorningController.text.trim())
          : null,
      insulinNightUnits: _insulinUsage == 'Yes, I use insulin'
          ? int.tryParse(_insulinNightController.text.trim())
          : null,
      activityLevel: activityLevelMap[_activityLevel] ?? 'sedentary',
      healthGoals: _selectedGoals.map((g) => _goals.indexOf(g) + 1).toList(),
      dietaryPreferences:
          _selectedPreferences.map((p) => _preferences.indexOf(p) + 1).toList(),
      bloodSugar: BloodSugar(
        readingValue: double.tryParse(_bloodSugarController.text.trim()) ?? 100,
        readingUnit: "mg/dL",
        notes: "fasting",
      ),
      profileCompleted: true,
    );

    print("🔵 Saving profile to backend...");
    final success = await UserProfileService.createProfile(profileModel);
    print("🔵 Profile creation result: $success");

    if (success) {
      await UserProfileService.saveProfile(profileModel);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainNavigationScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                      .chain(CurveTween(curve: Curves.easeInOut)),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save profile. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _validateAllFields() {
    // Age validation
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 1 || age > 120) return false;

    // Weight validation
    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight < 10 || weight > 300) return false;

    // Height validation
    final height = double.tryParse(_heightController.text.trim());
    if (height == null || height < 50 || height > 250) return false;

    // Gender
    if (_selectedGender == null) return false;

    // Diabetes status
    if (_diabetesStatus == null) return false;

    // Insulin validation
    if (_insulinUsage == null) return false;
    if (_insulinUsage == 'Yes, I use insulin') {
      final morningDose = int.tryParse(_insulinMorningController.text.trim());
      final nightDose = int.tryParse(_insulinNightController.text.trim());
      if (morningDose == null || nightDose == null) return false;
      if (morningDose < 0 || morningDose > 100) return false;
      if (nightDose < 0 || nightDose > 100) return false;
    }

    // Blood sugar validation
    final bsStr = _bloodSugarController.text.trim();
    if (bsStr.isEmpty) return false;

    // Activity level
    if (_activityLevel == null) return false;

    // Goals and Preferences
    if (_selectedGoals.isEmpty) return false;
    if (_selectedPreferences.isEmpty) return false;

    return true;
  }

  // ==================== STEP VALIDATION ====================

  bool _canProceed() {
    switch (_currentStep) {
      case 0: // Personal Info - Strict validation
        if (_selectedGender == null) return false;

        final ageStr = _ageController.text.trim();
        if (ageStr.isEmpty) return false;
        final age = int.tryParse(ageStr);
        if (age == null || age < 1 || age > 120) return false;

        final weightStr = _weightController.text.trim();
        if (weightStr.isEmpty) return false;
        final weight = double.tryParse(weightStr);
        if (weight == null || weight < 10 || weight > 300) return false;

        final heightStr = _heightController.text.trim();
        if (heightStr.isEmpty) return false;
        final height = double.tryParse(heightStr);
        if (height == null || height < 50 || height > 250) return false;

        return true;

      case 1: // Diabetes Status
        return _diabetesStatus != null;

      case 2: // Insulin Usage
        if (_insulinUsage == null) return false;
        if (_insulinUsage == 'Yes, I use insulin') {
          final morningStr = _insulinMorningController.text.trim();
          if (morningStr.isEmpty) return false;
          final morning = int.tryParse(morningStr);
          if (morning == null || morning < 0 || morning > 100) return false;

          final nightStr = _insulinNightController.text.trim();
          if (nightStr.isEmpty) return false;
          final night = int.tryParse(nightStr);
          if (night == null || night < 0 || night > 100) return false;
        }
        return true;

      case 3: // Blood Sugar
        final bsStr = _bloodSugarController.text.trim();
        if (bsStr.isEmpty) return false;
        final bs = double.tryParse(bsStr);
        if (bs == null || bs < 20 || bs > 600) return false;
        return true;

      case 4: // Activity Level
        return _activityLevel != null;

      case 5: // Goals
        return _selectedGoals.isNotEmpty;

      case 6: // Preferences
        return _selectedPreferences.isNotEmpty;
      case 7: // Treatment details can be left unconfirmed if unknown.
        return true;

      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: _previousStep,
              )
            : null,
        title: Text(
          'Profile Setup',
          style: AppTextStyles.heading4.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              children: [
                Text(
                  'Step ${_currentStep + 1} of $_totalSteps',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '${((_currentStep + 1) / _totalSteps * 100).round()}%',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: AppColors.borderLight,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                });
              },
              children: [
                _buildPersonalInfoStep(),
                _buildDiabetesStatusStep(),
                _buildInsulinUsageStep(),
                _buildBloodSugarStep(),
                _buildActivityLevelStep(),
                _buildGoalsStep(),
                _buildPreferencesStep(),
                SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: TreatmentEditor(
                        value: _treatment,
                        includeInsulin: false,
                        onChanged: (value) =>
                            setState(() => _treatment = value))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: CustomButton(
                      text: 'Back',
                      onPressed: _previousStep,
                      isOutlined: true,
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: _currentStep == _totalSteps - 1 ? 'Complete' : 'Next',
                    onPressed: _canProceed()
                        ? _nextStep
                        : null, // ✅ Disabled when validation fails
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information',
                  style: AppTextStyles.heading3
                      .copyWith(color: AppColors.textPrimary))
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 8),
          Text('Tell us about yourself to personalize your experience',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary))
              .animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 32),
          Text('Gender',
                  style: AppTextStyles.label.copyWith(color: AppColors.primary))
              .animate()
              .fadeIn(delay: 600.ms)
              .slideX(begin: -0.3, end: 0),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildGenderOption('Male', Icons.male)),
              const SizedBox(width: 16),
              Expanded(child: _buildGenderOption('Female', Icons.female)),
            ],
          ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 24),
          CustomInputField(
            label: 'Age',
            hintText: 'Enter your age (18-100 years)',
            icon: Icons.cake_outlined,
            controller: _ageController,
            keyboardType: TextInputType.number,
            errorText: _ageError,
          ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 20),
          CustomInputField(
            label: 'Weight (kg)',
            hintText: 'Enter your weight (10-300 kg)',
            icon: Icons.monitor_weight_outlined,
            controller: _weightController,
            keyboardType: TextInputType.number,
            errorText: _weightError,
          ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 20),
          CustomInputField(
            label: 'Height (cm)',
            hintText: 'Enter your height (50-250 cm)',
            icon: Icons.height_outlined,
            controller: _heightController,
            keyboardType: TextInputType.number,
            errorText: _heightError,
          ).animate().fadeIn(delay: 1400.ms).slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  Widget _buildGenderOption(String gender, IconData icon) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? AppColors.primary : AppColors.textHint,
                size: 32),
            const SizedBox(height: 8),
            Text(gender,
                style: AppTextStyles.bodyMedium.copyWith(
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDiabetesStatusStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Diabetes Status',
                  style: AppTextStyles.heading3
                      .copyWith(color: AppColors.textPrimary))
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 8),
          Text('Please select your diabetes status to help us provide personalized recommendations',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary))
              .animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 32),
          ...List.generate(_diabetesStatusOptions.length, (index) {
            final status = _diabetesStatusOptions[index];
            final isSelected = _diabetesStatus == status;
            return Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () => setState(() => _diabetesStatus = status),
                child: CustomCard(
                  backgroundColor: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.white,
                  border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.borderLight,
                      width: isSelected ? 2 : 1),
                  child: Row(
                    children: [
                      Icon(Icons.medical_services,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textHint,
                          size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Text(status,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ))),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 24),
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: (600 + index * 100).ms)
                .slideY(begin: 0.3, end: 0);
          }),
          if (_diabetesStatus == null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Please select your diabetes status',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsulinUsageStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Insulin Usage',
                  style: AppTextStyles.heading3
                      .copyWith(color: AppColors.textPrimary))
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 8),
          Text('Do you currently use insulin? This helps us understand your treatment plan',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary))
              .animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 32),
          ...List.generate(_insulinUsageOptions.length, (index) {
            final usage = _insulinUsageOptions[index];
            final isSelected = _insulinUsage == usage;
            return Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () => setState(() => _insulinUsage = usage),
                child: CustomCard(
                  backgroundColor: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.white,
                  border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.borderLight,
                      width: isSelected ? 2 : 1),
                  child: Row(
                    children: [
                      Icon(Icons.medication,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textHint,
                          size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Text(usage,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ))),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 24),
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: (600 + index * 100).ms)
                .slideY(begin: 0.3, end: 0);
          }),
          if (_insulinUsage == null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Please select your insulin usage status',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          if (_insulinUsage == 'Yes, I use insulin') ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: CustomInputField(
                    label: 'Morning Insulin (units)',
                    hintText: 'Enter morning dose (0-100)',
                    icon: Icons.wb_sunny,
                    controller: _insulinMorningController,
                    keyboardType: TextInputType.number,
                    errorText: _insulinMorningError,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomInputField(
                    label: 'Night Insulin (units)',
                    hintText: 'Enter night dose (0-100)',
                    icon: Icons.nightlight_round,
                    controller: _insulinNightController,
                    keyboardType: TextInputType.number,
                    errorText: _insulinNightError,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.3, end: 0),
          ],
        ],
      ),
    );
  }

  Widget _buildBloodSugarStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Blood Sugar Reading',
                  style: AppTextStyles.heading3
                      .copyWith(color: AppColors.textPrimary))
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 8),
          Text('Please enter your most recent blood sugar reading (mg/dL)',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary))
              .animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 32),
          CustomInputField(
            label: 'Blood Sugar Level (mg/dL)',
            hintText: 'Enter your blood sugar reading (20-600)',
            icon: Icons.bloodtype,
            controller: _bloodSugarController,
            keyboardType: TextInputType.number,
            errorText: _bloodSugarError,
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Blood Sugar Guidelines:',
                    style: AppTextStyles.label.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                    '• Normal: 70-100 mg/dL\n• Pre-diabetes: 100-125 mg/dL\n• Diabetes: 126+ mg/dL',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  Widget _buildActivityLevelStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Level',
                  style: AppTextStyles.heading3
                      .copyWith(color: AppColors.textPrimary))
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 8),
          Text('How active are you on a daily basis? This helps us calculate your calorie needs',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary))
              .animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 32),
          ...List.generate(_activityLevels.length, (index) {
            final level = _activityLevels[index];
            final isSelected = _activityLevel == level;
            return Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () => setState(() => _activityLevel = level),
                child: CustomCard(
                  backgroundColor: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.white,
                  border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.borderLight,
                      width: isSelected ? 2 : 1),
                  child: Row(
                    children: [
                      Icon(Icons.fitness_center,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textHint,
                          size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Text(level,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ))),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 24),
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: (600 + index * 100).ms)
                .slideY(begin: 0.3, end: 0);
          }),
          if (_activityLevel == null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Please select your activity level',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoalsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Goals',
                  style: AppTextStyles.heading3
                      .copyWith(color: AppColors.textPrimary))
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 8),
          Text('What are your primary health goals? Select all that apply',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary))
              .animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _goals.map((goal) {
              final isSelected = _selectedGoals.contains(goal);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedGoals.remove(goal);
                    } else {
                      _selectedGoals.add(goal);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.borderLight,
                        width: 1),
                  ),
                  child: Text(goal,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected
                            ? AppColors.white
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      )),
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0),
          if (_selectedGoals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Please select at least one health goal',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          if (_selectedGoals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '✓ ${_selectedGoals.length} goal(s) selected',
                style: TextStyle(color: AppColors.success, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreferencesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dietary Preferences',
                  style: AppTextStyles.heading3
                      .copyWith(color: AppColors.textPrimary))
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 8),
          Text('What are your dietary preferences and restrictions? Select all that apply',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary))
              .animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _preferences.map((preference) {
              final isSelected = _selectedPreferences.contains(preference);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedPreferences.remove(preference);
                    } else {
                      _selectedPreferences.add(preference);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.borderLight,
                        width: 1),
                  ),
                  child: Text(preference,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected
                            ? AppColors.white
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      )),
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0),
          if (_selectedPreferences.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Please select at least one dietary preference',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          if (_selectedPreferences.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '✓ ${_selectedPreferences.length} preference(s) selected',
                style: TextStyle(color: AppColors.success, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
