"""Optional learned suitability ranker. Does not replace clinical judgment."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path

import joblib
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.feature_extraction import DictVectorizer
from sklearn.metrics import mean_absolute_error
from sklearn.model_selection import GroupShuffleSplit
from sklearn.pipeline import Pipeline

from medication_context import context_features, meal_metrics, treatment_context
from medication_dataset import load_review_csv

ARTIFACT_VERSION = 1


def ranker_features(profile: dict, plan: list) -> dict:
    metrics = meal_metrics(plan)
    features = context_features(profile)
    for key in ("age", "weight_kg", "height_cm", "blood_sugar_level"):
        features[key] = float(profile.get(key, 0))
    features.update({"gender": profile.get("gender", "unknown"),
                     "activity_level": profile.get("activity_level", "unknown"),
                     "diabetes_status": profile.get("diabetes_status", "unknown")})
    for goal in profile.get("goals", []):
        features[f"goal_{goal}"] = 1
    for preference in profile.get("dietary_preferences", []):
        features[f"preference_{preference}"] = 1
    features.update({f"plan_{key}": value for key, value in metrics.items()})
    return features


def train_ranker(csv_path, output_dir, allow_reviewed_synthetic=False):
    records, audit = load_review_csv(csv_path)
    rows = [r for r in records if r['raw']['review_status'] == 'reviewed'
            and (allow_reviewed_synthetic or not r['synthetic'])]
    groups = np.array([r['raw']['group_id'] for r in rows])
    labels = np.array([r['score'] for r in rows], dtype=float)
    if len(rows) < 20 or len(set(groups)) < 6 or len(set(labels)) < 2:
        raise ValueError("Training requires >=20 eligible reviewed rows, >=6 independent groups and >=2 suitability labels. Draft or unreviewed examples cannot train this ranker.")
    features = [ranker_features(r['profile'], r['plan']) for r in rows]
    train_indices, test_indices = next(GroupShuffleSplit(
        n_splits=1, test_size=0.25, random_state=42).split(features, labels, groups))
    if len(set(labels[train_indices])) < 2:
        raise ValueError("The training split has insufficient label diversity; collect more independent reviewed cases")
    pipeline = Pipeline([('features', DictVectorizer(sparse=False)),
                         ('ranker', RandomForestRegressor(n_estimators=200, max_depth=10,
                            min_samples_leaf=2, random_state=42, n_jobs=1))])
    pipeline.fit([features[i] for i in train_indices], labels[train_indices])
    predictions = pipeline.predict([features[i] for i in test_indices])
    metadata = {'artifact_version': ARTIFACT_VERSION,
        'trained_at': datetime.now(timezone.utc).isoformat(), 'dataset_audit': audit,
        'eligible_rows': len(rows), 'synthetic_training_rows': sum(r['synthetic'] for r in rows),
        'training_groups': sorted(set(groups[train_indices])),
        'test_groups': sorted(set(groups[test_indices])),
        'medication_combinations_seen': sorted({tuple(treatment_context(rows[i]['profile'])['medication_classes'])
                                                for i in train_indices}),
        'appetite_values_seen': sorted({treatment_context(rows[i]['profile'])['appetite'] for i in train_indices}),
        'symptoms_seen': sorted({symptom for i in train_indices
                                for symptom in treatment_context(rows[i]['profile'])['symptoms']}),
        'evaluation': {'mae_on_0_to_2_suitability': float(mean_absolute_error(labels[test_indices], predictions)),
                       'baseline_mae': float(mean_absolute_error(labels[test_indices],
                           np.repeat(labels[train_indices].mean(), len(test_indices)))),
                       'test_rows': len(test_indices)},
        'split_scope': 'held_out_case_groups; catalog meal plans may recur across groups',
        'clinical_validation_established': False,
        'intended_use': 'clinician_reviewed_prototype_ranking_not_treatment_or_dosing'}
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    joblib.dump({'pipeline': pipeline, 'metadata': metadata}, output_dir / 'medication_ranker.joblib')
    (output_dir / 'metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    return metadata


class MedicationRanker:
    def __init__(self, path):
        artifact = joblib.load(path)
        self.metadata = artifact['metadata']
        if self.metadata.get('artifact_version') != ARTIFACT_VERSION:
            raise ValueError("Unsupported medication ranker artifact")
        self.pipeline = artifact['pipeline']

    def score(self, profile, plans):
        return self.pipeline.predict([ranker_features(profile, plan) for plan in plans])

    def supports(self, profile):
        context = treatment_context(profile)
        combinations = [list(c) for c in self.metadata.get('medication_combinations_seen', [])]
        return (context['medication_classes'] in combinations
                and context['appetite'] in self.metadata.get('appetite_values_seen', [])
                and set(context['symptoms']).issubset(self.metadata.get('symptoms_seen', [])))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv')
    parser.add_argument('--output', default='models/medication_ranker')
    parser.add_argument('--allow-reviewed-synthetic', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(train_ranker(args.csv, args.output, args.allow_reviewed_synthetic), indent=2))
    except ValueError as error:
        parser.exit(2, f"Training refused: {error}\n")
