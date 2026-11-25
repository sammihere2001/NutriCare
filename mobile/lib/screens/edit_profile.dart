import 'package:nutricare/model/treatment_model.dart';
import 'package:nutricare/widgets/treatment_editor.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:nutricare/model/profile_setup_model.dart';
import 'package:nutricare/services/profile_services.dart';
import 'package:nutricare/utils/app_urls.dart';
import '../utils/image_utils.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfileModel? profile;
  const EditProfileScreen({Key? key, this.profile}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _insulinMorningController;
  late TextEditingController _insulinNightController;
  late TextEditingController _readingValueController;

  String? _diabetesStatus;
  String? _gender;
  bool _insulinUsage = false;
  bool _isSaving = false;
  TreatmentProfile _treatment = const TreatmentProfile();

  File? _pickedImageFile;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  String? _existingImageUrl;

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  final List<String> _diabetesOptions = [
    'Type1',
    'Type2',
    'None',
    'Prediabetes',
    'Gestational'
  ];
  final List<String> _genderOptions = ['male', 'female'];

  @override
  void initState() {
    super.initState();

    final String fullName = widget.profile?.name ?? '';
    final nameParts = fullName.trim().split(' ');

    _firstNameController =
        TextEditingController(text: nameParts.isNotEmpty ? nameParts[0] : '');
    _lastNameController = TextEditingController(
        text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
    _emailController = TextEditingController(text: widget.profile?.email ?? '');
    _ageController =
        TextEditingController(text: widget.profile?.age?.toString() ?? '');
    _weightController =
        TextEditingController(text: widget.profile?.weight?.toString() ?? '');
    _heightController =
        TextEditingController(text: widget.profile?.height?.toString() ?? '');
    _insulinMorningController = TextEditingController(
        text: widget.profile?.insulinMorningUnits?.toString() ?? '0');
    _insulinNightController = TextEditingController(
        text: widget.profile?.insulinNightUnits?.toString() ?? '0');
    _readingValueController = TextEditingController(
        text: widget.profile?.bloodSugar?.readingValue?.toString() ?? '');

    String rawStatus = widget.profile?.diabetesStatus ?? 'None';
    _diabetesStatus = _diabetesOptions.firstWhere(
      (opt) => opt.toLowerCase() == rawStatus.toLowerCase(),
      orElse: () => 'None',
    );

    String rawGender = widget.profile?.gender?.toLowerCase() ?? 'male';
    _gender =
        (rawGender == 'male' || rawGender == 'female') ? rawGender : 'male';
    _insulinUsage = widget.profile?.insulinUsage ?? false;
    _treatment = widget.profile?.treatment ?? const TreatmentProfile();
    _existingImageUrl = widget.profile?.profileImagePath;
  }

  // VALIDATION METHODS

  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'First name is required';
    }
    if (value.trim().length < 2) {
      return 'At least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Only letters allowed';
    }
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Last name optional
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Only letters allowed';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter valid email (e.g., user@example.com)';
    }
    return null;
  }

  String? _validateAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Age is required';
    }
    final age = int.tryParse(value.trim());
    if (age == null) {
      return 'Enter a valid number';
    }
    if (age < 18) {
      return 'Age must be at least 18';
    }
    if (age > 100) {
      return 'Age must be less than 100';
    }
    return null;
  }

  String? _validateWeight(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Weight is required';
    }
    final weight = double.tryParse(value.trim());
    if (weight == null) {
      return 'Enter a valid number';
    }
    if (weight < 30) {
      return 'Min 30 kg';
    }
    if (weight > 300) {
      return 'Max 300 kg';
    }
    return null;
  }

  String? _validateHeight(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Height is required';
    }
    final height = double.tryParse(value.trim());
    if (height == null) {
      return 'Enter a valid number';
    }
    if (height < 100) {
      return 'Min 100 cm';
    }
    if (height > 250) {
      return 'Max 250 cm';
    }
    return null;
  }

  String? _validateInsulinMorning(String? value) {
    if (!_insulinUsage) return null;
    if (value == null || value.trim().isEmpty) {
      return 'Required when using insulin';
    }
    final units = double.tryParse(value.trim());
    if (units == null) return 'Enter a number';
    if (units < 0) return 'Cannot be negative';
    if (units > 100) return 'Seems too high';
    return null;
  }

  String? _validateInsulinNight(String? value) {
    if (!_insulinUsage) return null;
    if (value == null || value.trim().isEmpty) {
      return 'Required when using insulin';
    }
    final units = double.tryParse(value.trim());
    if (units == null) return 'Enter a number';
    if (units < 0) return 'Cannot be negative';
    if (units > 100) return 'Seems too high';
    return null;
  }

  // NEW: Blood glucose validation - ONLY INTEGER allowed
  String? _validateBloodGlucose(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final trimmed = value.trim();

    // Check for decimal
    if (trimmed.contains('.')) {
      return '❌ Blood glucose must be a whole number (e.g., 120)\nDecimal points not allowed';
    }

    final glucose = int.tryParse(trimmed);
    if (glucose == null) {
      return '❌ Please enter a valid whole number (e.g., 120)';
    }

    if (glucose < 20) {
      return '❌ Blood glucose must be at least 20 mg/dL';
    }
    if (glucose > 600) {
      return '❌ Blood glucose cannot exceed 600 mg/dL';
    }

    return null;
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
          _pickedImageName = pickedFile.name;
          _pickedImageFile = null;
        });
      } else {
        setState(() {
          _pickedImageFile = File(pickedFile.path);
          _pickedImageBytes = null;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    // ✅ Validate all fields
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors before saving'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    if (mounted) {
      showDialog(
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
                  Text("Updating profile..."),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      String fName = _firstNameController.text.trim();
      String lName = _lastNameController.text.trim();
      String finalName = lName.isEmpty ? fName : "$fName $lName";

      String bloodSugarText = _readingValueController.text.trim();
      double? bloodSugarValue;
      if (bloodSugarText.isNotEmpty) {
        bloodSugarValue = double.tryParse(bloodSugarText);
      }

      final updated = ProfileModel(
        userId: widget.profile?.userId,
        treatment: _treatment.withInsulin(_insulinUsage),
        name: finalName,
        email: _emailController.text.trim(),
        age: int.tryParse(_ageController.text),
        gender: _gender,
        weight: double.tryParse(_weightController.text),
        height: double.tryParse(_heightController.text),
        diabetesStatus: _diabetesStatus?.toLowerCase(),
        insulinUsage: _insulinUsage,
        insulinMorningUnits: num.tryParse(_insulinMorningController.text),
        insulinNightUnits: num.tryParse(_insulinNightController.text),
        activityLevel: widget.profile?.activityLevel,
        healthGoals: widget.profile?.healthGoals,
        dietaryPreferences: widget.profile?.dietaryPreferences,
        bloodSugar: bloodSugarValue != null && bloodSugarValue > 0
            ? BloodSugar(
                readingValue: bloodSugarValue,
                readingUnit: "mg/dL",
              )
            : null,
        profileCompleted: true,
      );

      bool success = await UserProfileService.editProfile(
        updated,
        imageFile: _pickedImageFile,
        imageBytes: _pickedImageBytes,
        imageName: _pickedImageName,
      );

      if (mounted) Navigator.pop(context);

      if (success) {
        await UserProfileService.clearProfileCache();
        await UserProfileService.getProfile(forceRefresh: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Profile Updated Successfully!"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception("Failed to update profile");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("❌ Error: ${e.toString().replaceAll('Exception: ', '')}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAvatarSection() {
    ImageProvider? imageProvider;

    if (_pickedImageBytes != null) {
      imageProvider = MemoryImage(_pickedImageBytes!);
    } else if (_pickedImageFile != null) {
      imageProvider = FileImage(_pickedImageFile!);
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      String fullUrl = ImageUtils.getFullImageUrl(_existingImageUrl);
      fullUrl = "$fullUrl?t=${DateTime.now().millisecondsSinceEpoch}";
      imageProvider = NetworkImage(fullUrl);
    }

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: imageProvider,
            child: (imageProvider == null)
                ? const Icon(Icons.person, size: 60, color: AppColors.primary)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 22,
              child: IconButton(
                icon:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                onPressed: _pickImage,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Edit Profile",
          style: AppTextStyles.heading3.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text("Save",
                    style: AppTextStyles.button
                        .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      // ✅ Wrap body in Form
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 30),

              // First Name with validation
              TextFormField(
                controller: _firstNameController,
                keyboardType: TextInputType.name,
                validator: _validateFirstName,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Last Name
              TextFormField(
                controller: _lastNameController,
                keyboardType: TextInputType.name,
                validator: _validateLastName,
                decoration: const InputDecoration(
                  labelText: 'Last Name (Optional)',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Age & Gender Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      validator: _validateAge,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(
                        labelText: "Gender",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.wc),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _genderOptions
                          .map((g) => DropdownMenuItem(
                              value: g, child: Text(g.toUpperCase())))
                          .toList(),
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Weight & Height Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      validator: _validateWeight,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      validator: _validateHeight,
                      decoration: const InputDecoration(
                        labelText: 'Height (cm)',
                        prefixIcon: Icon(Icons.height),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 40),

              // Medical Info Header
              Row(
                children: [
                  const Icon(Icons.medical_services,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text("Medical Information",
                      style: AppTextStyles.heading4.copyWith(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 15),

              // Diabetes Status
              DropdownButtonFormField<String>(
                value: _diabetesStatus,
                decoration: const InputDecoration(
                  labelText: "Diabetes Status",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _diabetesOptions
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _diabetesStatus = v),
              ),
              const SizedBox(height: 12),

              // Insulin Toggle
              SwitchListTile(
                title: const Text("Use Insulin",
                    style: TextStyle(fontWeight: FontWeight.w500)),
                secondary: const Icon(Icons.vaccines),
                value: _insulinUsage,
                onChanged: (v) => setState(() {
                  _insulinUsage = v;
                  _treatment = _treatment
                      .withInsulin(v)
                      .copyWith(medicationsConfirmed: false);
                }),
                activeColor: AppColors.primary,
              ),

              // Insulin Units (if enabled)
              if (_insulinUsage) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _insulinMorningController,
                        keyboardType: TextInputType.number,
                        validator: _validateInsulinMorning,
                        decoration: const InputDecoration(
                          labelText: 'Morning Insulin (Units)',
                          prefixIcon: Icon(Icons.wb_sunny),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextFormField(
                        controller: _insulinNightController,
                        keyboardType: TextInputType.number,
                        validator: _validateInsulinNight,
                        decoration: const InputDecoration(
                          labelText: 'Night Insulin (Units)',
                          prefixIcon: Icon(Icons.nightlight_round),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const Divider(height: 40),

              // ✅ Blood Glucose Field - Only Integer allowed
              TextFormField(
                controller: _readingValueController,
                keyboardType: TextInputType.number,
                validator: _validateBloodGlucose,
                decoration: const InputDecoration(
                  labelText: 'Blood Glucose (mg/dL)',
                  hintText: 'Optional - Enter whole number only (e.g., 120)',
                  prefixIcon: Icon(Icons.bloodtype),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                  helperText: 'Example: 120, 95, 250 (No decimal points)',
                  helperStyle:
                      TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ),
              const SizedBox(height: 30),

              TreatmentEditor(
                  value: _treatment,
                  includeInsulin: false,
                  onChanged: (value) => setState(() => _treatment = value)),
              const SizedBox(height: 24),
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("💾 SAVE CHANGES",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _insulinMorningController.dispose();
    _insulinNightController.dispose();
    _readingValueController.dispose();
    super.dispose();
  }
}
