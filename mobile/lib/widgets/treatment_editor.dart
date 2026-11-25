import 'package:flutter/material.dart';
import '../model/treatment_model.dart';

class TreatmentEditor extends StatelessWidget {
  final TreatmentProfile value;
  final ValueChanged<TreatmentProfile> onChanged;
  final bool includeInsulin;

  const TreatmentEditor(
      {super.key,
      required this.value,
      required this.onChanged,
      this.includeInsulin = true});

  void _replace(int index, MedicationRecord medicine) {
    final list = [...value.medications];
    list[index] = medicine;
    onChanged(value.copyWith(medications: list, medicationsConfirmed: false));
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Medications and appetite',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(includeInsulin
          ? 'Record all medications you currently take. You can add more than one.'
          : 'Add GLP-1 or tablet medications here. Your insulin selection is recorded in the earlier step.'),
      const SizedBox(height: 8),
      const Text(
          'Copy medication details from your prescription. NutriCare does not recommend medication doses.'),
      const SizedBox(height: 12),
      ...value.medications
          .asMap()
          .entries
          .where((entry) =>
              includeInsulin || entry.value.medicationClass != 'insulin')
          .map((entry) {
        final index = entry.key;
        final medicine = entry.value;
        return Card(
            key: ObjectKey(medicine.editorKey),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                            medicationClassLabels[medicine.medicationClass] ??
                                medicine.medicationClass,
                            style: Theme.of(context).textTheme.titleMedium)),
                    IconButton(
                        tooltip: 'Remove medication',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          final list = [...value.medications]..removeAt(index);
                          onChanged(value.copyWith(
                              medications: list, medicationsConfirmed: false));
                        }),
                  ]),
                  TextFormField(
                      initialValue: medicine.name,
                      maxLength: 100,
                      decoration: const InputDecoration(
                          labelText: 'Medication name (optional)'),
                      onChanged: (text) =>
                          _replace(index, medicine.copyWith(name: text))),
                  TextFormField(
                      initialValue: medicine.prescribedDose,
                      maxLength: 100,
                      decoration: const InputDecoration(
                          labelText: 'Prescribed dose (optional)'),
                      onChanged: (text) => _replace(
                          index, medicine.copyWith(prescribedDose: text))),
                  TextFormField(
                      initialValue: medicine.schedule,
                      maxLength: 150,
                      decoration: const InputDecoration(
                          labelText: 'Prescribed schedule (optional)'),
                      onChanged: (text) =>
                          _replace(index, medicine.copyWith(schedule: text))),
                ])));
      }),
      if (value.medications.length < 20)
        PopupMenuButton<String>(
            tooltip: 'Choose a medication class',
            onSelected: (type) => onChanged(value.copyWith(medications: [
                  ...value.medications,
                  MedicationRecord(medicationClass: type)
                ], medicationsConfirmed: false)),
            itemBuilder: (_) => medicationClassLabels.entries
                .where((entry) => includeInsulin || entry.key != 'insulin')
                .map((entry) =>
                    PopupMenuItem(value: entry.key, child: Text(entry.value)))
                .toList(),
            child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_circle_outline),
                  SizedBox(width: 8),
                  Text('Add medication')
                ]))),
      CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
              'I have checked this list against my current prescription'),
          subtitle: const Text(
              'An empty list can mean no medications. Leave unchecked if you are unsure.'),
          value: value.medicationsConfirmed,
          onChanged: (checked) => onChanged(
              value.copyWith(medicationsConfirmed: checked ?? false))),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
          initialValue: value.appetite,
          decoration: const InputDecoration(labelText: 'Current appetite'),
          items: const [
            DropdownMenuItem(value: 'unknown', child: Text('Not recorded')),
            DropdownMenuItem(value: 'normal', child: Text('Usual appetite')),
            DropdownMenuItem(value: 'reduced', child: Text('Reduced appetite')),
            DropdownMenuItem(
                value: 'increased', child: Text('Increased appetite'))
          ],
          onChanged: (appetite) =>
              onChanged(value.copyWith(appetite: appetite))),
      const SizedBox(height: 16),
      const Text('Current symptoms (optional)'),
      Wrap(
          spacing: 8,
          children: const {
            'nausea': 'Nausea',
            'vomiting': 'Vomiting',
            'early_fullness': 'Feeling full quickly',
            'reflux': 'Reflux',
            'constipation': 'Constipation',
            'diarrhea': 'Diarrhea'
          }
              .entries
              .map((entry) => FilterChip(
                  label: Text(entry.value),
                  selected: value.symptoms.contains(entry.key),
                  onSelected: (selected) {
                    final symptoms = [...value.symptoms]..remove(entry.key);
                    if (selected) symptoms.add(entry.key);
                    onChanged(value.copyWith(symptoms: symptoms));
                  }))
              .toList()),
    ]);
  }
}
