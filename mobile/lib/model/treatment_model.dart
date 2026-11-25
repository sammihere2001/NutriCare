const medicationClassLabels = {
  'insulin': 'Insulin',
  'glp1': 'GLP-1 receptor agonist',
  'dual_gip_glp1': 'Dual GIP/GLP-1 medication',
  'metformin': 'Metformin',
  'sglt2': 'SGLT2 inhibitor',
  'sulfonylurea': 'Sulfonylurea',
  'meglitinide': 'Meglitinide',
  'dpp4': 'DPP-4 inhibitor',
  'thiazolidinedione': 'Thiazolidinedione',
  'alpha_glucosidase': 'Alpha-glucosidase inhibitor',
  'other': 'Other / unsure of class',
};

class MedicationRecord {
  final Object editorKey;
  final String medicationClass;
  final String name;
  final String prescribedDose;
  final String schedule;
  final String? startedOn;

  MedicationRecord(
      {required this.medicationClass,
      this.name = '',
      this.prescribedDose = '',
      this.schedule = '',
      this.startedOn,
      Object? editorKey})
      : editorKey = editorKey ?? Object();

  factory MedicationRecord.fromJson(Map<String, dynamic> json) =>
      MedicationRecord(
          medicationClass: json['medication_class'] as String? ?? 'other',
          name: json['name'] as String? ?? '',
          prescribedDose: json['prescribed_dose'] as String? ?? '',
          schedule: json['schedule'] as String? ?? '',
          startedOn: json['started_on'] as String?);

  MedicationRecord copyWith(
          {String? name, String? prescribedDose, String? schedule}) =>
      MedicationRecord(
          medicationClass: medicationClass,
          name: name ?? this.name,
          prescribedDose: prescribedDose ?? this.prescribedDose,
          schedule: schedule ?? this.schedule,
          startedOn: startedOn,
          editorKey: editorKey);

  Map<String, dynamic> toJson() => {
        'medication_class': medicationClass,
        'name': name.trim(),
        'prescribed_dose': prescribedDose.trim(),
        'schedule': schedule.trim(),
        'started_on': startedOn
      };
}

class TreatmentProfile {
  final bool medicationsConfirmed;
  final List<MedicationRecord> medications;
  final String appetite;
  final List<String> symptoms;

  const TreatmentProfile(
      {this.medicationsConfirmed = false,
      this.medications = const [],
      this.appetite = 'unknown',
      this.symptoms = const []});

  factory TreatmentProfile.fromJson(Map<String, dynamic> json) =>
      TreatmentProfile(
          medicationsConfirmed: json['medications_confirmed'] == true,
          medications: (json['medications'] as List? ?? [])
              .map((item) => MedicationRecord.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList(),
          appetite: json['appetite'] as String? ?? 'unknown',
          symptoms: (json['symptoms'] as List? ?? []).cast<String>());

  TreatmentProfile copyWith(
          {bool? medicationsConfirmed,
          List<MedicationRecord>? medications,
          String? appetite,
          List<String>? symptoms}) =>
      TreatmentProfile(
          medicationsConfirmed:
              medicationsConfirmed ?? this.medicationsConfirmed,
          medications: medications ?? this.medications,
          appetite: appetite ?? this.appetite,
          symptoms: symptoms ?? this.symptoms);

  TreatmentProfile withInsulin(bool enabled) {
    final list = [...medications];
    if (!enabled) list.removeWhere((m) => m.medicationClass == 'insulin');
    if (enabled && !list.any((m) => m.medicationClass == 'insulin')) {
      list.add(MedicationRecord(medicationClass: 'insulin'));
    }
    return copyWith(medications: list);
  }

  Map<String, dynamic> toJson() => {
        'medications_confirmed': medicationsConfirmed,
        'medications': medications.map((m) => m.toJson()).toList(),
        'appetite': appetite,
        'symptoms': symptoms
      };
}
