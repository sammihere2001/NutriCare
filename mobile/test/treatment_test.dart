import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricare/model/profile_setup_model.dart';
import 'package:nutricare/model/treatment_model.dart';
import 'package:nutricare/widgets/treatment_editor.dart';

class EditorHarness extends StatefulWidget {
  const EditorHarness({super.key});
  @override
  State<EditorHarness> createState() => EditorHarnessState();
}

class EditorHarnessState extends State<EditorHarness> {
  TreatmentProfile value = const TreatmentProfile();
  @override
  Widget build(BuildContext context) => MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: TreatmentEditor(
                  value: value,
                  onChanged: (next) => setState(() => value = next)))));
}

void main() {
  test('treatment combinations survive profile JSON round trips', () {
    final profile = ProfileModel.fromJson({
      'user_id': 1,
      'insulin_usage': true,
      'treatment': {
        'medications_confirmed': true,
        'appetite': 'reduced',
        'symptoms': ['early_fullness'],
        'medications': [
          {'medication_class': 'insulin'},
          {'medication_class': 'glp1', 'name': 'Recorded medicine'},
          {'medication_class': 'metformin'}
        ]
      }
    });
    final restored = ProfileModel.fromJson(profile.toJson());
    expect(restored.treatment.medications.length, 3);
    expect(restored.treatment.appetite, 'reduced');
    expect(restored.treatment.medicationsConfirmed, isTrue);
    expect(restored.treatment.medications[1].name, 'Recorded medicine');
  });

  test('changing legacy insulin preserves other medications', () {
    final treatment = TreatmentProfile(
        medications: [MedicationRecord(medicationClass: 'glp1')]);
    final combined = treatment.withInsulin(true);
    expect(combined.medications.map((m) => m.medicationClass),
        ['glp1', 'insulin']);
    expect(
        combined.withInsulin(false).medications.single.medicationClass, 'glp1');
  });

  testWidgets(
      'editor can add combination medications without losing typed details',
      (tester) async {
    await tester.pumpWidget(const EditorHarness());
    await tester.tap(find.text('Add medication'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GLP-1 receptor agonist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Recorded GLP-1');
    await tester.pump();
    await tester.ensureVisible(find.text('Add medication'));
    await tester.tap(find.text('Add medication'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Metformin'));
    await tester.pumpAndSettle();
    final state = tester.state<EditorHarnessState>(find.byType(EditorHarness));
    expect(state.value.medications.length, 2);
    expect(state.value.medications.first.name, 'Recorded GLP-1');
    expect(state.value.medications.last.medicationClass, 'metformin');
    expect(state.value.medicationsConfirmed, isFalse);
  });
}
