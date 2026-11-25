"""Reproducible constraint audit, not an evaluation of clinical outcomes.

The legacy selection baseline below reconstructs the inspected pre-enhancement
filter/scoring rules; the original serialized classifier is shared unchanged.
"""
import argparse
import hashlib
import json
from pathlib import Path
import random

import numpy as np

from diet_recommender import DietRecommender
from prepare_medication_review import synthetic_cases


def legacy_candidates(data, profile, predicted, target, bmi, days=7):
    selected = data.copy()
    prefs, goals = set(profile['dietary_preferences']), set(profile['goals'])
    match = selected[selected['dietary_preference'].isin(prefs)]
    if not match.empty:
        selected = match
    for column, values, minimum in [('goal', goals, 3),
            ('has_diabetes', {profile['has_diabetes']}, 3),
            ('uses_insulin', {profile['uses_insulin']}, 2)]:
        match = selected[selected[column].isin(values)]
        if len(match) >= min(days, minimum):
            selected = match
    ranked = selected.copy()
    ranked['score'] = 0.0
    for condition, weight in [
        (ranked['dietary_preference'].isin(prefs), 35),
        (ranked['dietary_preference'] == profile['dietary_preference'], 10),
        (ranked['goal'].isin(goals), 15), (ranked['goal'] == profile['goal'], 5),
        (ranked['recommended_plan_type'] == predicted, 18),
        (ranked['has_diabetes'] == profile['has_diabetes'], 12),
        (ranked['uses_insulin'] == profile['uses_insulin'], 10),
        (ranked['activity_level'] == profile['activity_level'], 8),
        (ranked['gender'] == profile['gender'], 4),
    ]:
        ranked['score'] += np.where(condition, weight, 0)
    ranked['target_calorie_gap'] = abs(ranked['target_calories'] - target)
    ranked['bmi_gap'] = abs(ranked['bmi'] - bmi)
    ranked['blood_sugar_gap'] = abs(ranked['blood_sugar_level'] - profile['blood_sugar_level'])
    for gap, maximum, divisor in [('target_calorie_gap', 25, 120),
                                  ('bmi_gap', 10, 0.4), ('blood_sugar_gap', 8, 25)]:
        ranked['score'] += np.clip(maximum - ranked[gap] / divisor, 0, None)
    ranked['score'] += np.clip(8 - abs(ranked['age'] - profile['age']) / 6, 0, None)
    if profile['blood_sugar_level'] > 200:
        ranked['score'] += np.where(ranked['recommended_plan_type'].isin(['low_calorie_plan', 'balanced_plan']), 25, 0)
    elif profile['blood_sugar_level'] > 140:
        ranked['score'] += np.where(ranked['recommended_plan_type'] == 'balanced_plan', 15, 0)
    if profile['uses_insulin']:
        ranked['score'] += np.where(ranked['daily_carbs'].between(150, 250), 20, 0)
    return ranked.sort_values(['score', 'target_calorie_gap', 'bmi_gap', 'blood_sugar_gap'],
                              ascending=[False, True, True, True])


def summarize(calories, target):
    errors = [abs(value - target) / target * 100 for value in calories]
    return {'daily_calories': calories, 'mean_absolute_energy_gap_percent': round(sum(errors) / len(errors), 2),
            'days_outside_20_percent_matching_window': sum(error > 20 + 1e-9 for error in errors)}


def evaluate(output):
    engine = DietRecommender(random_seed=42)
    results = []
    for case, source in synthetic_cases():
        profile, features, target, bmi, _, _ = engine.prepare_user_features(source)
        predicted = engine.model.predict(features)[0]
        legacy = legacy_candidates(engine.reference_data, profile, predicted, target, bmi)
        pool = legacy.drop_duplicates('meal_signature').head(14).reset_index(drop=True)
        order = list(range(len(pool)))
        random.Random(42).shuffle(order)
        legacy_calories = [float(pool.iloc[order[i % len(order)]]['daily_calories']) for i in range(7)]
        new = engine.generate_meal_plan(source)
        new_calories = [day['daily_totals']['calories'] for day in new['weekly_plan']]
        results.append({'fictional_case': case, 'target_estimate_kcal': target,
                        'legacy_selection': summarize(legacy_calories, target),
                        'medication_hybrid': summarize(new_calories, target),
                        'applied_reasons': new['planning_context']['ranking_reasons']})
    artifacts = Path(engine.model_dir)
    report = {'scope': 'engineering constraint checks on six fictional scenarios; not clinical validation',
              'baseline': 'reimplemented legacy selection rules and unchanged serialized classifier',
              'baseline_artifact_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                          for p in artifacts.iterdir() if p.suffix in {'.pkl', '.json'}},
              'clinical_validation_established': False, 'cases': results}
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    Path(output).write_text(json.dumps(report, indent=2), encoding='utf-8')
    return {'cases': len(results),
            'legacy_days_outside_window': sum(r['legacy_selection']['days_outside_20_percent_matching_window'] for r in results),
            'hybrid_days_outside_window': sum(r['medication_hybrid']['days_outside_20_percent_matching_window'] for r in results)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default=str(Path(__file__).parent / 'evaluation/medication_constraint_audit.json'))
    print(json.dumps(evaluate(parser.parse_args().output), indent=2))
