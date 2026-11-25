import 'package:flutter/material.dart';
import '../model/nutrition_plan_model.dart';
import '../model/treatment_model.dart';

class PlanningContextCard extends StatelessWidget {
  final PlanningContext contextData;
  const PlanningContextCard({super.key, required this.contextData});

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.info_outline),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Medication-aware meal-plan preview',
                        style: TextStyle(fontWeight: FontWeight.bold)))
              ]),
              if (contextData.medicationClasses.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                    'Recorded treatment: ${contextData.medicationClasses.map((c) => medicationClassLabels[c] ?? c).join(', ')}'),
              ],
              ...contextData.reasons.map((reason) => Padding(
                  padding: const EdgeInsets.only(top: 8), child: Text(reason))),
              ...contextData.warnings.map((warning) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(warning))),
              const SizedBox(height: 8),
              const Text(
                  'Food categories are source-dataset labels. Ingredients and individual nutrition targets still need review.'),
            ])));
  }
}
