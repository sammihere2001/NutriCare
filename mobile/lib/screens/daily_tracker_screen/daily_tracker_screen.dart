import 'package:nutricare/services/mealplan_service.dart';
import 'package:nutricare/utils/app_urls.dart';
import 'package:nutricare/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_button.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nutricare/services/profile_services.dart';

class DailyTrackerScreen extends StatefulWidget {
  const DailyTrackerScreen({super.key});

  @override
  State<DailyTrackerScreen> createState() => _DailyTrackerScreenState();
}

class _DailyTrackerScreenState extends State<DailyTrackerScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  final TextEditingController _morningGlucoseController =
      TextEditingController();
  final TextEditingController _eveningGlucoseController =
      TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _exerciseController = TextEditingController();
  final TextEditingController _exerciseTimeController = TextEditingController();
  final TextEditingController _waterController = TextEditingController();
  final TextEditingController _sleepController = TextEditingController();
  final TextEditingController _stressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isSaving = false;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _meals = [];

  String? _exerciseTime;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();

    // Add real-time validation listeners
    _morningGlucoseController.addListener(_validateMorningGlucose);
    _eveningGlucoseController.addListener(_validateEveningGlucose);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _morningGlucoseController.dispose();
    _eveningGlucoseController.dispose();
    _weightController.dispose();
    _exerciseController.dispose();
    _exerciseTimeController.dispose();
    _waterController.dispose();
    _sleepController.dispose();
    _stressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Real-time validation methods
  void _validateMorningGlucose() {
    final value = _morningGlucoseController.text.trim();
    if (value.isNotEmpty && value.contains('.')) {
      _morningGlucoseController.value = TextEditingValue(
        text: value.replaceAll('.', ''),
        selection: TextSelection.collapsed(offset: value.length - 1),
      );
      _showMessage('Only whole numbers allowed', isError: true);
    }
  }

  void _validateEveningGlucose() {
    final value = _eveningGlucoseController.text.trim();
    if (value.isNotEmpty && value.contains('.')) {
      _eveningGlucoseController.value = TextEditingValue(
        text: value.replaceAll('.', ''),
        selection: TextSelection.collapsed(offset: value.length - 1),
      );
      _showMessage('Only whole numbers allowed', isError: true);
    }
  }

  void _addMeal() {
    if (_meals.length >= 5) {
      _showMessage('Maximum 5 meals can be added per day.', isError: true);
      return;
    }

    setState(() {
      _meals.insert(0, {
        'name': '',
        'nameController': TextEditingController(),
        'calories': '',
        'caloriesController': TextEditingController(),
        'mealType': 'Breakfast',
        'time': '',
      });
    });
  }

  void _removeMeal(int index) {
    _meals[index]['nameController'].dispose();
    _meals[index]['caloriesController'].dispose();

    setState(() {
      _meals.removeAt(index);
    });
  }

  void _clearForm() {
    _morningGlucoseController.clear();
    _eveningGlucoseController.clear();
    _weightController.clear();
    _exerciseController.clear();
    _exerciseTimeController.clear();
    _waterController.clear();
    _sleepController.clear();
    _stressController.clear();
    _notesController.clear();
    _exerciseTime = null;

    for (var meal in _meals) {
      meal['nameController']?.dispose();
      meal['caloriesController']?.dispose();
    }
    setState(() {
      _meals.clear();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _selectExerciseTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted =
          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      setState(() {
        _exerciseTime = formatted;
        _exerciseTimeController.text = formatted;
      });
    }
  }

  Future<void> _selectMealTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted =
          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      setState(() {
        _meals[index]['time'] = formatted;
      });
    }
  }

  bool _isValidNumber(String text) {
    if (text.isEmpty) return false;
    return RegExp(r'^\d+$').hasMatch(text);
  }

  bool _isValidDecimal(String text) {
    if (text.isEmpty) return false;
    return RegExp(r'^\d+(\.\d+)?$').hasMatch(text);
  }

  void _showEmergencyDialog(BuildContext context, String type, int value) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emergency, color: AppColors.error, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Medical Emergency Alert',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Your $type glucose level is $value mg/dL which is extremely high and considered a medical emergency.\n\nPlease seek medical attention immediately!',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child:
                const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showUpdateConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tracker Already Exists',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'You have already saved data for ${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}.\n\nDo you want to replace it with the new data?',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              print("User clicked NO - cancelling update");
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child:
                const Text('No', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              print("User clicked YES - updating tracker");
              Navigator.pop(context);
              _saveData(isUpdate: true);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, Replace',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  bool _validateAllFields() {
    // Morning Glucose - Required
    final morningGlucoseStr = _morningGlucoseController.text.trim();
    if (morningGlucoseStr.isEmpty) {
      _showMessage('Morning glucose reading is required.', isError: true);
      return false;
    }

    if (morningGlucoseStr.contains('.')) {
      _showMessage(
          '❌ Morning glucose must be a whole number (e.g., 120). Decimal points are not allowed.',
          isError: true);
      return false;
    }

    if (!_isValidNumber(morningGlucoseStr)) {
      _showMessage('Morning glucose must be a valid number.', isError: true);
      return false;
    }
    final morningGlucose = int.parse(morningGlucoseStr);
    if (morningGlucose > 600) {
      _showEmergencyDialog(context, 'Morning', morningGlucose);
      return false;
    }
    if (morningGlucose < 20) {
      _showMessage('Morning glucose cannot be below 20 mg/dL.', isError: true);
      return false;
    }

    // Evening Glucose - Required
    final eveningGlucoseStr = _eveningGlucoseController.text.trim();
    if (eveningGlucoseStr.isEmpty) {
      _showMessage('Evening glucose reading is required.', isError: true);
      return false;
    }

    if (eveningGlucoseStr.contains('.')) {
      _showMessage(
          '❌ Evening glucose must be a whole number (e.g., 140). Decimal points are not allowed.',
          isError: true);
      return false;
    }

    if (!_isValidNumber(eveningGlucoseStr)) {
      _showMessage('Evening glucose must be a valid number.', isError: true);
      return false;
    }
    final eveningGlucose = int.parse(eveningGlucoseStr);
    if (eveningGlucose > 600) {
      _showEmergencyDialog(context, 'Evening', eveningGlucose);
      return false;
    }
    if (eveningGlucose < 20) {
      _showMessage('Evening glucose cannot be below 20 mg/dL.', isError: true);
      return false;
    }

    // Weight - Required
    final weightStr = _weightController.text.trim();
    if (weightStr.isEmpty) {
      _showMessage('Weight is required.', isError: true);
      return false;
    }
    if (!_isValidDecimal(weightStr)) {
      _showMessage('Weight must be a valid number.', isError: true);
      return false;
    }
    final weight = double.parse(weightStr);
    if (weight < 10 || weight > 300) {
      _showMessage('Weight must be between 10 kg and 300 kg.', isError: true);
      return false;
    }

    // Exercise - Required
    final exerciseStr = _exerciseController.text.trim();
    if (exerciseStr.isEmpty) {
      _showMessage('Exercise minutes is required.', isError: true);
      return false;
    }
    if (!_isValidNumber(exerciseStr)) {
      _showMessage('Exercise minutes must be a valid number.', isError: true);
      return false;
    }
    final exercise = int.parse(exerciseStr);
    if (exercise < 0 || exercise > 300) {
      _showMessage('Exercise minutes must be between 0 and 300.',
          isError: true);
      return false;
    }

    // Exercise Time - Required
    if (_exerciseTime == null || _exerciseTime!.isEmpty) {
      _showMessage('Please select exercise time.', isError: true);
      return false;
    }

    // Water Intake - Required
    final waterStr = _waterController.text.trim();
    if (waterStr.isEmpty) {
      _showMessage('Water intake is required.', isError: true);
      return false;
    }
    if (!_isValidNumber(waterStr)) {
      _showMessage('Water intake must be a valid number.', isError: true);
      return false;
    }
    final water = int.parse(waterStr);
    if (water < 0 || water > 25) {
      _showMessage('Water intake must be between 0 and 25 glasses.',
          isError: true);
      return false;
    }

    // Sleep - Required
    final sleepStr = _sleepController.text.trim();
    if (sleepStr.isEmpty) {
      _showMessage('Sleep hours is required.', isError: true);
      return false;
    }
    if (!_isValidDecimal(sleepStr)) {
      _showMessage('Sleep hours must be a valid number.', isError: true);
      return false;
    }
    final sleep = double.parse(sleepStr);
    if (sleep < 0 || sleep > 12) {
      _showMessage('Sleep hours must be between 0 and 12.', isError: true);
      return false;
    }

    // Stress Level - Required
    final stressStr = _stressController.text.trim();
    if (stressStr.isEmpty) {
      _showMessage('Stress level is required.', isError: true);
      return false;
    }
    if (!_isValidNumber(stressStr)) {
      _showMessage('Stress level must be a valid number.', isError: true);
      return false;
    }
    final stress = int.parse(stressStr);
    if (stress < 1 || stress > 100) {
      _showMessage('Stress level must be between 1 and 100.', isError: true);
      return false;
    }

    // Meals - At least one meal required
    if (_meals.isEmpty) {
      _showMessage('Please add at least one meal.', isError: true);
      return false;
    }

    // Validate each meal
    for (int i = 0; i < _meals.length; i++) {
      final meal = _meals[i];
      if (meal['name'].toString().trim().isEmpty) {
        _showMessage('Please enter name for Meal ${i + 1}.', isError: true);
        return false;
      }
      final caloriesStr = meal['calories'].toString().trim();
      if (caloriesStr.isEmpty) {
        _showMessage('Please enter calories for Meal ${i + 1}.', isError: true);
        return false;
      }
      if (!_isValidDecimal(caloriesStr)) {
        _showMessage('Calories for Meal ${i + 1} must be a valid number.',
            isError: true);
        return false;
      }
      final calories = double.parse(caloriesStr);
      if (calories < 0 || calories > 2000) {
        _showMessage('Calories for Meal ${i + 1} must be between 0 and 2000.',
            isError: true);
        return false;
      }
      if (meal['time'] == null || meal['time'].toString().isEmpty) {
        _showMessage('Please select time for Meal ${i + 1}.', isError: true);
        return false;
      }
    }

    return true;
  }

  Future<void> _checkExistingAndSave() async {
    print("=== CHECK EXISTING AND SAVE CALLED ===");

    if (!_validateAllFields()) {
      print("Validation failed, not saving");
      return;
    }

    final currentAuth = await AuthService().getAuth();
    final authDataString =
        currentAuth == null ? null : jsonEncode(currentAuth.toJson());
    if (authDataString == null) {
      _showMessage("User not logged in. Please login again.", isError: true);
      return;
    }

    final Map<String, dynamic> authData = jsonDecode(authDataString);
    final String? token = authData['access_token'];
    if (token == null || token.isEmpty) {
      _showMessage("Invalid session. Please login again.", isError: true);
      return;
    }

    final dateStr =
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    final checkUrl = Uri.parse(
        '${AppUrls.baseUrl}/daily-tracker/check?tracker_date=$dateStr');

    try {
      print("Calling: $checkUrl");
      final checkResponse = await http.get(
        checkUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 5));

      print("Status: ${checkResponse.statusCode}");
      print("Body: ${checkResponse.body}");

      if (checkResponse.statusCode == 200) {
        final result = jsonDecode(checkResponse.body);
        if (result['exists'] == true) {
          print("Exists! Showing dialog");
          _showUpdateConfirmationDialog();
          return;
        }
      } else if (checkResponse.statusCode == 401) {
        print("Unauthorized - token issue");
        _showMessage("Session expired. Please login again.", isError: true);
        return;
      }
    } catch (e) {
      print("Error: $e");
      _showMessage("Network error. Please try again.", isError: true);
      return;
    }

    print("No existing tracker found, saving directly");
    await _saveData(isUpdate: false);
  }

  Future<void> _saveData({bool isUpdate = false}) async {
    print("=== SAVE DATA CALLED ===");
    print("isUpdate: $isUpdate");

    if (_isSaving) return;
    if (!_validateAllFields()) return;

    setState(() => _isSaving = true);

    final currentAuth = await AuthService().getAuth();
    final authDataString =
        currentAuth == null ? null : jsonEncode(currentAuth.toJson());
    if (authDataString == null) {
      setState(() => _isSaving = false);
      _showMessage("User not logged in. Please login again.", isError: true);
      return;
    }

    final Map<String, dynamic> authData = jsonDecode(authDataString);
    final String? token = authData['access_token'];

    final url = Uri.parse('${AppUrls.baseUrl}/daily-tracker');

    final dateStr =
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    final morningGlucose = int.parse(_morningGlucoseController.text.trim());
    final eveningGlucose = int.parse(_eveningGlucoseController.text.trim());
    final weight = double.parse(_weightController.text.trim());
    final exercise = int.parse(_exerciseController.text.trim());
    final water = int.parse(_waterController.text.trim());
    final sleep = double.parse(_sleepController.text.trim());
    final stress = int.parse(_stressController.text.trim());

    final List<Map<String, dynamic>> mealsData = [];
    for (var meal in _meals) {
      mealsData.add({
        "meal_name": meal["name"].toString(),
        "meal_type": meal["mealType"] ?? "Breakfast",
        "calories": double.parse(meal["calories"].toString()),
        "meal_time": meal["time"].toString()
      });
    }

    final data = {
      "tracker_date": dateStr,
      "morning_glucose": morningGlucose,
      "evening_glucose": eveningGlucose,
      "weight": weight,
      "exercise": exercise,
      "exercise_time": _exerciseTime ?? "",
      "water_intake": water,
      "sleep_hours": sleep,
      "stress_level": stress,
      "notes": _notesController.text,
      "is_update": isUpdate,
      "meals": mealsData
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      setState(() => _isSaving = false);

      print("Save response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        await MealPlanService.clearCachedPlan();
        print("Save successful, isUpdate: $isUpdate");

        if (weight > 0) {
          print("Syncing weight: $weight");
          await _syncWeightWithProfile(weight, token!);

          final updatedProfile =
              await UserProfileService.getProfile(forceRefresh: true);
          print("Profile after sync: ${updatedProfile?.weight}");

          UserProfileService.notifyListeners();
        }

        _showMessage(isUpdate ? 'Updated Successfully' : 'Saved Successfully');
        _clearForm();
      } else {
        final errorData = jsonDecode(response.body);
        _showMessage(errorData['detail'] ?? response.body, isError: true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      print("Save error: $e");
      _showMessage("Error: $e", isError: true);
    }
  }

  Future<void> _syncWeightWithProfile(double weight, String token) async {
    try {
      print("=== SYNCING WEIGHT TO PROFILE ===");
      print("Weight: $weight kg");

      final currentAuth = await AuthService().getAuth();
      final authDataString =
          currentAuth == null ? null : jsonEncode(currentAuth.toJson());
      if (authDataString == null) return;

      final authData = jsonDecode(authDataString);
      final userId = authData['user']['user_id'];
      print("User ID: $userId");

      final url = Uri.parse('${AppUrls.baseUrl}/profile/edit');

      final request = http.MultipartRequest('PUT', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['user_id'] = userId.toString();
      request.fields['weight_kg'] = weight.toString();

      final response = await request.send();
      await response.stream.drain<void>();
      print("Weight sync response status: ${response.statusCode}");
    } catch (e) {
      print("Error syncing weight: $e");
    }
  }

  Widget _buildGlucoseField({
    required String label,
    required String hintText,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textHint,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (value) {
            // Real-time validation
            if (value.contains('.')) {
              controller.value = TextEditingValue(
                text: value.replaceAll('.', ''),
                selection: TextSelection.collapsed(offset: value.length - 1),
              );
              _showMessage('Only whole numbers allowed', isError: true);
            }
          },
        ),
      ],
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.track_changes,
                  color: AppColors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Daily Tracker',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track Your Health',
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monitor your daily metrics to manage diabetes better',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 24),

            // Date Selection Card
            CustomCard(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(24),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.calendar_today,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Select Date',
                        style: AppTextStyles.heading4.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _selectedDate =
                            _selectedDate.subtract(const Duration(days: 1))),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.chevron_left,
                              color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.08),
                                AppColors.primary.withOpacity(0.02)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: Text(
                            '${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          DateTime nextDate =
                              _selectedDate.add(const Duration(days: 1));
                          if (nextDate.isAfter(_today())) {
                            _showMessage("Future dates are not allowed",
                                isError: true);
                          } else {
                            setState(() => _selectedDate = nextDate);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.chevron_right,
                              color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _selectedDate = DateTime.now()),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        'Jump To Today',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 200.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 20),

            // Blood Glucose Card
            CustomCard(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(24),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.bloodtype,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Blood Glucose (mg/dL)',
                        style: AppTextStyles.heading4.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGlucoseField(
                          label: 'Morning (Fasting)',
                          hintText: 'e.g., 110',
                          icon: Icons.wb_sunny,
                          controller: _morningGlucoseController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildGlucoseField(
                          label: 'Evening (Before Dinner)',
                          hintText: 'e.g., 140',
                          icon: Icons.nightlight_round,
                          controller: _eveningGlucoseController,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 400.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 20),

            // Physical Metrics Card
            CustomCard(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(24),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.fitness_center,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Physical Metrics',
                        style: AppTextStyles.heading4.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: CustomInputField(
                          label: 'Weight (Kg)',
                          hintText: 'e.g., 68.5',
                          icon: Icons.monitor_weight,
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomInputField(
                          label: 'Exercise (Minutes)',
                          hintText: 'e.g., 30',
                          icon: Icons.directions_run,
                          controller: _exerciseController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exercise Time',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _selectExerciseTime,
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            border: Border.all(
                                color: AppColors.borderLight, width: 1.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _exerciseTime == null
                                    ? "Select Time"
                                    : _exerciseTime!,
                                style: TextStyle(
                                  color: _exerciseTime == null
                                      ? AppColors.textHint
                                      : AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: _exerciseTime == null
                                      ? FontWeight.normal
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 600.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 20),

            // Meals Card
            CustomCard(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(24),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.restaurant,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Meals & Food',
                          style: AppTextStyles.heading4.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addMeal,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Meal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.08),
                          AppColors.primary.withOpacity(0.03)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.info_outline,
                              color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ideal day includes 4-5 small meals. Eating too much at once can spike blood sugar levels.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._meals.asMap().entries.map((entry) {
                    final index = entry.key;
                    final meal = entry.value;
                    final mealNumber = _meals.length - index;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '$mealNumber',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Meal $mealNumber',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _removeMeal(index),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.delete_outline,
                                      color: AppColors.error, size: 20),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: CustomInputField(
                                  label: 'Meal Name',
                                  hintText: 'e.g., Chicken Biryani',
                                  icon: Icons.restaurant_menu,
                                  controller: meal['nameController'],
                                  onChanged: (value) => meal['name'] = value,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomInputField(
                                  label: 'Calories',
                                  hintText: 'e.g., 450',
                                  icon: Icons.local_fire_department,
                                  controller: meal['caloriesController'],
                                  onChanged: (value) =>
                                      meal['calories'] = value,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppColors.borderLight),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    value: meal['mealType'] ?? 'Breakfast',
                                    decoration: const InputDecoration(
                                      labelText: 'Meal Type',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                    ),
                                    items: _mealTypes
                                        .map((type) => DropdownMenuItem(
                                              value: type,
                                              child: Text(type,
                                                  style: TextStyle(
                                                      color: AppColors
                                                          .textPrimary)),
                                            ))
                                        .toList(),
                                    onChanged: (value) => setState(
                                        () => meal['mealType'] = value),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Meal Time',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () => _selectMealTime(index),
                                      child: Container(
                                        height: 54,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: AppColors.white,
                                          border: Border.all(
                                              color: AppColors.borderLight,
                                              width: 1.5),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.access_time,
                                                color: AppColors.primary,
                                                size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              meal['time'].isEmpty
                                                  ? "Select Time"
                                                  : meal['time'],
                                              style: TextStyle(
                                                color: meal['time'].isEmpty
                                                    ? AppColors.textHint
                                                    : AppColors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: meal['time'].isEmpty
                                                    ? FontWeight.normal
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (_meals.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.restaurant_outlined,
                              size: 56, color: AppColors.textHint),
                          const SizedBox(height: 12),
                          Text(
                            'No meals added yet',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click "Add Meal" to start logging',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 800.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 20),

            // Lifestyle & Wellness Card
            CustomCard(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(24),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.self_improvement,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Lifestyle & Wellness',
                        style: AppTextStyles.heading4.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: CustomInputField(
                          label: 'Water Intake (glasses)',
                          hintText: '8-10 recommended',
                          icon: Icons.water_drop,
                          controller: _waterController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomInputField(
                          label: 'Sleep (hours)',
                          hintText: '7-9 recommended',
                          icon: Icons.bedtime,
                          controller: _sleepController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomInputField(
                          label: 'Stress Level',
                          hintText: '1-100',
                          icon: Icons.psychology,
                          controller: _stressController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: AppColors.textHint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'People with diabetes should aim for 8 to 10 glasses (roughly 2-2.5 liters) of water daily.',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textHint, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 1000.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 20),

            // Notes Card (Optional)
            CustomCard(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(24),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.note_add,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Notes (Optional)',
                        style: AppTextStyles.heading4.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppColors.borderLight, width: 1.5),
                    ),
                    child: TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter any additional notes here...',
                        hintStyle: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textHint),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 1200.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 28),

            // Save Button
            CustomButton(
              text: _isSaving ? 'Saving...' : 'Save Data',
              onPressed: _isSaving ? null : _checkExistingAndSave,
              icon: Icons.save_alt,
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 1400.ms)
                .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}
