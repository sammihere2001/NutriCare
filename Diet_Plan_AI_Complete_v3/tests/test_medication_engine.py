import hashlib
import json
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import httpx
import pandas as pd
from pydantic import ValidationError

from medication_context import (TreatmentContext, NutritionTargets, PlanRequestError,
    check_planning_context, context_features, preference_adjustments)
from medication_dataset import (CSV_COLUMNS, ReviewProfile, load_review_csv, plan_id,
                                validate_record, write_review_csv)
from medication_ranker import MedicationRanker, train_ranker
from prepare_medication_review import synthetic_cases
from diet_recommender import DietRecommender
import api

ROOT = Path(__file__).resolve().parents[1]


def profile(classes=('glp1',), **changes):
    data = next(synthetic_cases())[1]
    data['treatment']['medications'] = [{'medication_class': name} for name in classes]
    data['uses_insulin'] = 'insulin' in classes
    data.update(changes)
    return data


def review_row(case=0, candidate=0, reviewed=False):
    context = list(synthetic_cases())[case % 6][1]
    plan = [{'type': 'breakfast', 'meal': {'name': f'Fixture meal {candidate}',
            'calories': 400 + candidate * 100, 'protein': 20 + candidate,
            'carbs': 40, 'fat': 10}}]
    return dict(zip(CSV_COLUMNS, ['1', f'fixture_case_{case}', f'fixture_group_{case}',
        plan_id(plan), 'true', json.dumps(context), json.dumps(plan), '["balanced"]',
        ['unsuitable', 'acceptable', 'preferred'][candidate % 3] if reviewed else '',
        'reviewed' if reviewed else 'draft', 'fixture_reviewer' if reviewed else '',
        date.today().isoformat() if reviewed else '',
        'Synthetic software-test fixture, not a clinical assessment', '']))


class ContextTests(unittest.TestCase):
    def test_combination_features_preserve_both_classes(self):
        values = context_features(profile(('insulin', 'glp1', 'metformin')))
        self.assertEqual(values['medication_insulin'], 1)
        self.assertEqual(values['medication_glp1'], 1)
        self.assertEqual(values['medication_metformin'], 1)

    def test_unknown_classes_and_prescription_text_are_rejected_by_ml_contract(self):
        for medication in [{'medication_class': 'unknown'},
                           {'medication_class': 'glp1', 'prescribed_dose': 'private text'}]:
            with self.assertRaises(ValidationError):
                TreatmentContext(medications=[medication])

    def test_invalid_nutrition_bounds_are_rejected(self):
        for data in [{'calories_min': 2000, 'calories_max': 1000}, {'protein_min_g': float('nan')}]:
            with self.assertRaises(ValidationError):
                NutritionTargets(**data)

    def test_keto_risk_combinations_pause_planning(self):
        for medication in ['insulin', 'sulfonylurea', 'meglitinide', 'sglt2']:
            with self.assertRaises(PlanRequestError) as caught:
                check_planning_context(profile((medication,), dietary_preferences=['keto']))
            self.assertEqual(caught.exception.code, 'diet_medication_review_required')

    def test_low_glucose_vomiting_and_gestational_profiles_pause_planning(self):
        cases = [profile(blood_sugar_level=60), profile(diabetes_status='gestational'), profile()]
        cases[-1]['treatment']['symptoms'] = ['vomiting']
        for case in cases:
            with self.assertRaises(PlanRequestError):
                check_planning_context(case)

    def test_glp1_context_changes_protein_density_ranking(self):
        candidates = pd.DataFrame({'score': [0., 0.], 'protein_density': [20., 80.],
            'largest_meal_share': [.5, .5], 'largest_meal_fat': [10., 10.]})
        ranked, reasons = preference_adjustments(candidates, profile())
        self.assertGreater(ranked['score'].iloc[1], ranked['score'].iloc[0])
        self.assertTrue(reasons)

    def test_reduced_appetite_prefers_more_even_meal_energy(self):
        case = profile(('metformin',))
        case['treatment']['appetite'] = 'reduced'
        candidates = pd.DataFrame({'score': [0., 0.], 'protein_density': [50., 50.],
            'largest_meal_share': [.8, .3], 'largest_meal_fat': [10., 10.]})
        ranked, _ = preference_adjustments(candidates, case)
        self.assertGreater(ranked['score'].iloc[1], ranked['score'].iloc[0])


class EngineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.artifacts = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in (ROOT / 'models').iterdir() if p.suffix in {'.pkl', '.json'}}
        with patch.dict(os.environ, {'MEDICATION_RANKER_PATH': ''}):
            cls.engine = DietRecommender(random_seed=42)

    def test_full_plan_honors_actual_energy_bounds_and_combination_context(self):
        result = self.engine.generate_meal_plan(profile(('insulin', 'glp1')))
        self.assertEqual(len(result['weekly_plan']), 7)
        bounds = result['planning_context']['nutrition_bounds']
        for day in result['weekly_plan']:
            self.assertGreaterEqual(day['daily_totals']['calories'], bounds['calories_min'] - .01)
            self.assertLessEqual(day['daily_totals']['calories'], bounds['calories_max'] + .01)
            self.assertIn('source_plan_id', day)
            self.assertNotIn('source_user_id', day)
        self.assertEqual(result['planning_context']['medication_context']['medication_classes'], ['glp1', 'insulin'])
        self.assertFalse(result['planning_context']['learned_medication_ranker_loaded'])

    def test_unsupported_preferences_never_fall_back_to_unrestricted_food(self):
        for preferences in [['vegan'], ['vegetarian', 'gluten_free']]:
            with self.assertRaises(PlanRequestError) as caught:
                self.engine.generate_meal_plan(profile(dietary_preferences=preferences))
            self.assertEqual(caught.exception.code, 'unsupported_dietary_combination')

    def test_infeasible_nutrition_limits_never_fall_back(self):
        with self.assertRaises(PlanRequestError) as caught:
            self.engine.generate_meal_plan(profile(nutrition_targets={'max_meal_calories': 1}))
        self.assertEqual(caught.exception.code, 'no_matching_nutrition_plan')

    def test_requested_plan_length_is_used(self):
        self.assertEqual(len(self.engine.generate_meal_plan(profile(), num_days=3)['weekly_plan']), 3)

    def test_concurrent_contexts_do_not_leak_ranking_reasons(self):
        with ThreadPoolExecutor(max_workers=2) as executor:
            first, second = list(executor.map(self.engine.generate_meal_plan,
                                              [profile(('glp1',)), profile(('metformin',))]))
        self.assertTrue(first['planning_context']['ranking_reasons'])
        self.assertEqual(second['planning_context']['ranking_reasons'], [])

    def test_baseline_artifacts_are_not_overwritten(self):
        self.engine.generate_meal_plan(profile())
        after = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in (ROOT / 'models').iterdir() if p.name in self.artifacts}
        self.assertEqual(after, self.artifacts)


class DatasetAndTrainingTests(unittest.TestCase):
    def test_unreviewed_rows_cannot_train_or_create_an_artifact(self):
        with tempfile.TemporaryDirectory() as directory:
            path, output = Path(directory) / 'draft.csv', Path(directory) / 'artifacts'
            write_review_csv(path, [review_row()])
            with self.assertRaises(ValueError):
                train_ranker(path, output)
            self.assertFalse(output.exists())

    def test_profile_personal_identifiers_are_not_accepted(self):
        row = review_row()
        data = json.loads(row['profile_json'])
        data['email'] = 'private@example.invalid'
        row['profile_json'] = json.dumps(data)
        with self.assertRaises(ValueError):
            validate_record(row)

    def test_duplicate_pairs_and_changed_plan_hashes_are_rejected(self):
        row = review_row()
        row['plan_id'] = 'wrong-hash'
        with self.assertRaises(ValueError):
            validate_record(row)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'duplicates.csv'
            write_review_csv(path, [review_row(), review_row()])
            with self.assertRaises(ValueError):
                load_review_csv(path)

    def test_reviewed_synthetic_training_is_opt_in_with_group_separation(self):
        rows = [review_row(case, candidate, reviewed=True) for case in range(8) for candidate in range(4)]
        with tempfile.TemporaryDirectory() as directory:
            path, output = Path(directory) / 'fixtures.csv', Path(directory) / 'model'
            write_review_csv(path, rows)
            with self.assertRaises(ValueError):
                train_ranker(path, output)
            metadata = train_ranker(path, output, allow_reviewed_synthetic=True)
            self.assertFalse(set(metadata['training_groups']) & set(metadata['test_groups']))
            self.assertEqual(metadata['synthetic_training_rows'], 32)
            self.assertFalse(metadata['clinical_validation_established'])
            ranker = MedicationRanker(output / 'medication_ranker.joblib')
            self.assertEqual(len(ranker.score(profile(), [json.loads(rows[0]['meal_plan_json'])])), 1)
            self.assertFalse(ranker.supports(profile(('other',))))


class ApiTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.client = httpx.AsyncClient(transport=httpx.ASGITransport(app=api.app), base_url='http://test')

    async def asyncTearDown(self):
        await self.client.aclose()

    async def test_generation_endpoints_include_context_and_requested_length(self):
        for route in ['/generate-plan', '/generate-plan-detailed']:
            result = await self.client.post(route, json=profile(), params={'days': 3})
            self.assertEqual(result.status_code, 200, result.text)
            self.assertEqual(len(result.json()['weekly_plan']), 3)
            self.assertIn('planning_context', result.json())

    async def test_treatment_conflict_returns_actionable_422(self):
        result = await self.client.post('/generate-plan', json=profile(('sglt2',), dietary_preferences=['keto']))
        self.assertEqual(result.status_code, 422)
        self.assertEqual(result.json()['detail']['code'], 'diet_medication_review_required')

    async def test_online_retraining_is_disabled_by_default(self):
        with patch.dict(os.environ, {'ALLOW_BASELINE_RETRAIN': 'false'}):
            self.assertEqual((await self.client.post('/retrain')).status_code, 403)


if __name__ == '__main__':
    unittest.main()
