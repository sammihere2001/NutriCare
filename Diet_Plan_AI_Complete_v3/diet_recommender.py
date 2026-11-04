"""
Diet plan recommendation engine backed by the Pakistani meal-plan dataset.
"""

from __future__ import annotations

from datetime import datetime, timedelta
import json
import os
import random
import hashlib
from pathlib import Path
from datetime import timezone

import joblib
import numpy as np
import pandas as pd

from diet_data_utils import (
    DEFAULT_DATASET_PATH,
    canonical_to_display_preference,
    classify_meal_plan,
    meal_plan_totals,
    normalize_activity_level,
    normalize_bool,
    normalize_dataframe,
    normalize_dietary_preference,
    normalize_gender,
    normalize_goal,
)
from train_model import MODEL_METADATA_FILENAME, train_from_dataset
from medication_context import (treatment_context, check_planning_context, constrain_candidates,
                                meal_metrics, preference_adjustments, planning_notes, PlanRequestError)


class DietRecommender:
    def __init__(self, model_dir="models", dataset_path=DEFAULT_DATASET_PATH, random_seed=None):
        service_dir = Path(__file__).resolve().parent
        self.model_dir = str(Path(model_dir) if Path(model_dir).is_absolute() else service_dir / model_dir)
        self.dataset_path = str(Path(dataset_path) if Path(dataset_path).is_absolute() else service_dir / dataset_path)
        self.random_seed = random_seed
        self.model = None
        self.scaler = None
        self.label_encoders = {}
        self.feature_columns = []
        self.reference_data = pd.DataFrame()
        self.dataset_mtime = None

        self.ensure_fresh_state(force_reload=True)
        self.medication_ranker = None
        ranker_path = os.getenv('MEDICATION_RANKER_PATH')
        if ranker_path:
            from medication_ranker import MedicationRanker
            path = Path(ranker_path)
            if not path.is_absolute():
                path = service_dir / path
            self.medication_ranker = MedicationRanker(path)

    def _get_dataset_mtime(self) -> float:
        if not os.path.exists(self.dataset_path):
            raise RuntimeError(f"Dataset not found: {self.dataset_path}")
        return os.path.getmtime(self.dataset_path)

    def _get_model_metadata_path(self) -> str:
        return os.path.join(self.model_dir, MODEL_METADATA_FILENAME)

    def _read_model_metadata(self) -> dict:
        metadata_path = self._get_model_metadata_path()
        if not os.path.exists(metadata_path):
            return {}

        try:
            with open(metadata_path, "r", encoding="utf-8") as metadata_file:
                return json.load(metadata_file)
        except Exception:
            return {}

    def _has_model_artifacts(self) -> bool:
        required_artifacts = [
            os.path.join(self.model_dir, "diet_model.pkl"),
            os.path.join(self.model_dir, "scaler.pkl"),
            os.path.join(self.model_dir, "label_encoders.pkl"),
            os.path.join(self.model_dir, "feature_columns.pkl"),
        ]
        return all(os.path.exists(path) for path in required_artifacts)

    def _model_is_stale(self, dataset_mtime: float) -> bool:
        if not self._has_model_artifacts():
            return True

        metadata = self._read_model_metadata()
        metadata_dataset_mtime = metadata.get("dataset_mtime")
        if metadata_dataset_mtime is not None:
            return float(metadata_dataset_mtime) != float(dataset_mtime)

        artifact_paths = [
            os.path.join(self.model_dir, "diet_model.pkl"),
            os.path.join(self.model_dir, "scaler.pkl"),
            os.path.join(self.model_dir, "label_encoders.pkl"),
            os.path.join(self.model_dir, "feature_columns.pkl"),
        ]
        newest_artifact_mtime = min(os.path.getmtime(path) for path in artifact_paths)
        return newest_artifact_mtime < dataset_mtime

    def ensure_fresh_state(self, force_reload=False):
        dataset_mtime = self._get_dataset_mtime()
        dataset_changed = self.dataset_mtime is None or self.dataset_mtime != dataset_mtime
        should_retrain = self._model_is_stale(dataset_mtime)

        # Serving must not silently overwrite the baseline model artifacts.
        if not self._has_model_artifacts():
            raise RuntimeError("Baseline model artifacts are missing. Train them explicitly before starting the service.")
        self.baseline_dataset_changed = should_retrain

        if force_reload or dataset_changed or self.model is None or self.reference_data.empty:
            self._load_model_artifacts(self.model_dir)
            self.reference_data = self._load_reference_data(self.dataset_path)
            self.dataset_mtime = dataset_mtime

    def _load_model_artifacts(self, model_dir: str):
        try:
            self.model = joblib.load(f"{model_dir}/diet_model.pkl")
            self.scaler = joblib.load(f"{model_dir}/scaler.pkl")
            self.label_encoders = joblib.load(f"{model_dir}/label_encoders.pkl")
            self.feature_columns = joblib.load(f"{model_dir}/feature_columns.pkl")

            if hasattr(self.model, "n_jobs"):
                self.model.n_jobs = 1

            print("Model loaded successfully.")
        except Exception as exc:
            print(f"Error loading model: {exc}")
            raise

    def _load_reference_data(self, dataset_path: str) -> pd.DataFrame:
        try:
            raw_df = pd.read_csv(dataset_path)
        except Exception as exc:
            raise RuntimeError(f"Unable to load recommendation dataset: {exc}") from exc

        data = normalize_dataframe(raw_df)
        if data.empty:
            raise RuntimeError("Recommendation dataset is empty.")

        valid_indices = []
        metrics = []
        for index, row in data.iterrows():
            try:
                facts = meal_metrics(row['parsed_meal_plan'])
            except (ValueError, TypeError, KeyError):
                continue
            valid_indices.append(index)
            metrics.append(facts)
        data = data.loc[valid_indices].copy()
        if data.empty:
            raise RuntimeError("No valid reference plans remain after nutrition validation")
        for key in ('largest_meal_calories', 'largest_meal_share', 'largest_meal_fat', 'protein_density', 'meal_count'):
            data[key] = [facts[key] for facts in metrics]
        data['declared_preferences'] = data['dietary_preference'].apply(lambda tag: [tag])
        data['source_plan_id'] = data['parsed_meal_plan'].apply(lambda plan: hashlib.sha256(
            json.dumps(plan, sort_keys=True, separators=(',', ':')).encode()).hexdigest()[:20])
        print(f"Loaded {len(data)} validated reference meal plans from dataset.")
        return data

    def calculate_bmr(self, weight, height, age, gender):
        if gender == "male":
            return 10 * weight + 6.25 * height - 5 * age + 5
        return 10 * weight + 6.25 * height - 5 * age - 161

    def calculate_tdee(self, bmr, activity_level):
        activity_multipliers = {
            "sedentary": 1.2,
            "lightly_active": 1.375,
            "moderately_active": 1.55,
            "very_active": 1.725,
            "extremely_active": 1.9,
        }
        return bmr * activity_multipliers.get(activity_level, 1.2)

    def calculate_target_calories(self, tdee, goal):
        if goal == "weight_loss":
            return tdee - 500
        if goal in {"weight_gain", "muscle_gain"}:
            return tdee + 500
        return tdee

    def _normalize_user_profile(self, user_profile):
        profile = dict(user_profile)

        raw_goals = profile.get("goals", profile.get("goal", "general_health"))
        if not isinstance(raw_goals, list):
            raw_goals = [raw_goals]
        normalized_goals = []
        for goal in raw_goals:
            normalized_goal = normalize_goal(goal)
            if normalized_goal and normalized_goal not in normalized_goals:
                normalized_goals.append(normalized_goal)
        if not normalized_goals:
            normalized_goals = ["general_health"]
        primary_goal = normalized_goals[0]

        raw_dietary_prefs = profile.get(
            "dietary_preferences",
            profile.get("dietary_preference", "balanced"),
        )
        if not isinstance(raw_dietary_prefs, list):
            raw_dietary_prefs = [raw_dietary_prefs]
        normalized_dietary_prefs = []
        for pref in raw_dietary_prefs:
            normalized_pref = normalize_dietary_preference(pref)
            if normalized_pref and normalized_pref not in normalized_dietary_prefs:
                normalized_dietary_prefs.append(normalized_pref)
        if not normalized_dietary_prefs:
            normalized_dietary_prefs = ["balanced"]
        primary_pref = normalized_dietary_prefs[0]

        profile["age"] = int(profile.get("age", 25))
        profile["gender"] = normalize_gender(profile.get("gender", "male"))
        profile["weight_kg"] = float(profile.get("weight_kg", 70))
        profile["height_cm"] = float(profile.get("height_cm", 170))
        profile["activity_level"] = normalize_activity_level(profile.get("activity_level", "moderately_active"))
        profile["goal"] = normalize_goal(primary_goal)
        profile["goals"] = normalized_goals
        profile["dietary_preference"] = normalize_dietary_preference(primary_pref)
        profile["dietary_preferences"] = normalized_dietary_prefs
        profile["has_diabetes"] = normalize_bool(profile.get("has_diabetes", False))
        profile["uses_insulin"] = normalize_bool(profile.get("uses_insulin", False))
        profile["insulin_morning_units"] = float(profile.get("insulin_morning_units", 0.0) or 0.0)
        profile["insulin_night_units"] = float(profile.get("insulin_night_units", 0.0) or 0.0)
        profile["blood_sugar_level"] = int(float(profile.get("blood_sugar_level", 100) or 100))

        context = treatment_context(profile)
        if 'insulin' in context['medication_classes']:
            profile['uses_insulin'] = True
        if profile["uses_insulin"]:
            profile["has_diabetes"] = True
        else:
            profile["insulin_morning_units"] = 0.0
            profile["insulin_night_units"] = 0.0

        context = treatment_context(profile)
        if 'insulin' in context['medication_classes']:
            profile['uses_insulin'] = True
            profile['has_diabetes'] = True
        return profile

    def _encode_value(self, encoder_name: str, value: str) -> int:
        encoder = self.label_encoders[encoder_name]
        classes = list(encoder.classes_)

        if value not in classes:
            value = classes[0]

        return int(encoder.transform([value])[0])

    def prepare_user_features(self, user_profile):
        profile = self._normalize_user_profile(user_profile)

        bmi = profile["weight_kg"] / ((profile["height_cm"] / 100) ** 2)
        bmr = self.calculate_bmr(
            profile["weight_kg"],
            profile["height_cm"],
            profile["age"],
            profile["gender"],
        )
        tdee = self.calculate_tdee(bmr, profile["activity_level"])
        target_calories = self.calculate_target_calories(tdee, profile["goal"])

        # Calculate derived features to match training
        insulin_total = profile["insulin_morning_units"] + profile["insulin_night_units"]
        insulin_blood_sugar_ratio = insulin_total / (profile["blood_sugar_level"] + 1)
        blood_sugar_risk = 2 if profile["blood_sugar_level"] > 200 else (1 if profile["blood_sugar_level"] > 140 else 0)
        bmi_risk = 1 if bmi > 30 else 0
        diabetes_insulin_interaction = int(profile["has_diabetes"]) * insulin_total
        age_bmi_risk = profile["age"] * bmi_risk

        features = {
            "age": profile["age"],
            "weight_kg": profile["weight_kg"],
            "height_cm": profile["height_cm"],
            "bmi": bmi,
            "gender_encoded": self._encode_value("gender", profile["gender"]),
            "activity_level_encoded": self._encode_value("activity_level", profile["activity_level"]),
            "goal_encoded": self._encode_value("goal", profile["goal"]),
            "dietary_preference_encoded": self._encode_value(
                "dietary_preference",
                profile["dietary_preference"],
            ),
            "has_diabetes_int": int(profile["has_diabetes"]),
            "uses_insulin_int": int(profile["uses_insulin"]),
            "insulin_morning_units": profile["insulin_morning_units"],
            "insulin_night_units": profile["insulin_night_units"],
            "blood_sugar_level": profile["blood_sugar_level"],
            "bmr": bmr,
            "tdee": tdee,
            "target_calories": target_calories,
            "insulin_total": insulin_total,
            "insulin_blood_sugar_ratio": insulin_blood_sugar_ratio,
            "blood_sugar_risk": blood_sugar_risk,
            "diabetes_insulin_interaction": diabetes_insulin_interaction,
            "age_bmi_risk": age_bmi_risk,
        }

        X = pd.DataFrame([features])[self.feature_columns].fillna(0)
        X_scaled = self.scaler.transform(X)

        return profile, X_scaled, target_calories, bmi, bmr, tdee

    def _filter_candidates(self, profile: dict, num_days: int) -> pd.DataFrame:
        # Never broaden an empty result to plans that violate user constraints.
        _, _, target, _, _, _ = self.prepare_user_features(profile)
        candidates, bounds = constrain_candidates(self.reference_data, profile, target)
        candidates.attrs['nutrition_bounds'] = bounds
        return candidates

    def _rank_candidates(
        self,
        candidates: pd.DataFrame,
        profile: dict,
        predicted_plan_type: str,
        target_calories: float,
        bmi: float,
    ) -> pd.DataFrame:
        ranked = candidates.copy()
        selected_preferences = set(profile["dietary_preferences"])
        selected_goals = set(profile["goals"])

        ranked["target_calorie_gap"] = (ranked["daily_calories"] - target_calories).abs()
        ranked["bmi_gap"] = (ranked["bmi"] - bmi).abs()
        ranked["blood_sugar_gap"] = (
            ranked["blood_sugar_level"] - profile["blood_sugar_level"]
        ).abs()
        ranked["age_gap"] = (ranked["age"] - profile["age"]).abs()

        ranked["score"] = 0.0
        ranked["score"] += np.where(
            ranked["dietary_preference"].isin(selected_preferences), 35, 0
        )
        ranked["score"] += np.where(
            ranked["dietary_preference"] == profile["dietary_preference"], 10, 0
        )
        ranked["score"] += np.where(ranked["goal"].isin(selected_goals), 15, 0)
        ranked["score"] += np.where(ranked["goal"] == profile["goal"], 5, 0)
        ranked["score"] += np.where(
            ranked["recommended_plan_type"] == predicted_plan_type, 18, 0
        )
        ranked["score"] += np.where(
            ranked["has_diabetes"] == profile["has_diabetes"], 12, 0
        )
        ranked["score"] += np.where(
            ranked["uses_insulin"] == profile["uses_insulin"], 10, 0
        )
        ranked["score"] += np.where(
            ranked["activity_level"] == profile["activity_level"], 8, 0
        )
        ranked["score"] += np.where(ranked["gender"] == profile["gender"], 4, 0)
        ranked["score"] += np.clip(25 - (ranked["target_calorie_gap"] / 120), 0, None)
        ranked["score"] += np.clip(10 - (ranked["bmi_gap"] * 2.5), 0, None)
        ranked["score"] += np.clip(8 - (ranked["age_gap"] / 6), 0, None)
        ranked["score"] += np.clip(8 - (ranked["blood_sugar_gap"] / 25), 0, None)

        # Medication context affects ranking independently of the baseline classifier.
        # These documented engineering weights are not learned clinical effects.
        ranked, reasons = preference_adjustments(ranked, profile)
        ranker = getattr(self, 'medication_ranker', None)
        ranked.attrs['learned_ranker_applied'] = bool(ranker and ranker.supports(profile))
        if ranker is not None and ranker.supports(profile):
            ranked['learned_suitability'] = self.medication_ranker.score(profile, ranked['parsed_meal_plan'].tolist())
            ranked['score'] += ranked['learned_suitability'] * 10
            reasons.append('Applied the configured reviewed-example suitability ranker; this remains a prototype.')
        elif ranker is not None:
            reasons.append('The optional learned ranker has no training coverage for this treatment context; documented context preferences were used.')
        ranked.attrs['ranking_reasons'] = reasons

        return ranked.sort_values(
            by=["score", "target_calorie_gap", "bmi_gap", "blood_sugar_gap"],
            ascending=[False, True, True, True],
        )

    def _meal_type_label(self, meal_type: str) -> str:
        labels = {
            "breakfast": "Breakfast",
            "lunch": "Lunch",
            "dinner": "Dinner",
            "snack_1": "Morning Snack",
            "snack_2": "Evening Snack",
        }
        return labels.get(meal_type, meal_type.replace("_", " ").title())

    def _meal_time(self, meal_type: str) -> str:
        times = {
            "breakfast": "08:00 AM",
            "snack_1": "11:00 AM",
            "lunch": "01:00 PM",
            "snack_2": "05:00 PM",
            "dinner": "08:00 PM",
        }
        return times.get(meal_type, "09:00 AM")

    def _build_weekly_plan(self, ranked_candidates: pd.DataFrame, num_days: int):
        unique_candidates = ranked_candidates.drop_duplicates("meal_signature")

        if unique_candidates.empty:
            raise PlanRequestError("no_matching_nutrition_plan", "No eligible meal plans are available")

        # Get more candidates for variety
        available_plans = unique_candidates.head(min(len(unique_candidates), max(num_days * 2, 14))).reset_index(drop=True)

        # Keep the top-ranked plan first; vary remaining eligible plans without
        # mutating global random state or ever reaching outside the filtered pool.
        rng = random.Random(self.random_seed)
        available_indices = list(range(1, len(available_plans)))
        rng.shuffle(available_indices)
        cycle = [0] + available_indices
        selected_indices = [cycle[day % len(cycle)] for day in range(num_days)]

        weekly_plan = []
        for day in range(num_days):
            source_idx = selected_indices[day] if day < len(selected_indices) else day % len(available_plans)
            source_row = available_plans.iloc[source_idx]
            parsed_meal_plan = source_row["parsed_meal_plan"]

            meals = []
            for item in parsed_meal_plan:
                meal_type = item.get("type", "meal")
                meals.append({
                    "meal_type": self._meal_type_label(meal_type),
                    "time": self._meal_time(meal_type),
                    "food": item.get("meal", {}),
                })

            weekly_plan.append({
                "day": day + 1,
                "date": (datetime.now(timezone(timedelta(hours=5))) + timedelta(days=day)).strftime("%Y-%m-%d"),
                "meals": meals,
                "daily_totals": meal_plan_totals(parsed_meal_plan),
                "source_plan_id": source_row.get("source_plan_id", ""),
            })

        return weekly_plan

    def get_alternative_for_day(self, user_profile, current_day_plan):
        """Generate an alternative meal plan for a specific day."""
        # Get a fresh set of candidates
        profile, X_scaled, target_calories, bmi, bmr, tdee = self.prepare_user_features(user_profile)
        check_planning_context(profile)
        predicted_plan_type = self.model.predict(X_scaled)[0]

        candidates = self._filter_candidates(profile, 7)
        ranked_candidates = self._rank_candidates(candidates, profile, predicted_plan_type, target_calories, bmi)

        # Exclude the current day's meal signature
        current_signature = None
        for meal in current_day_plan.get("meals", []):
            if current_signature is None:
                current_signature = f"{meal['meal_type']}:{meal['food']['name']}"
            else:
                current_signature += f" | {meal['meal_type']}:{meal['food']['name']}"

        if current_signature:
            ranked_candidates = ranked_candidates[ranked_candidates["meal_signature"] != current_signature]

        # Get a top candidate that's different
        if not ranked_candidates.empty:
            alternative = ranked_candidates.iloc[0]
            parsed_meal_plan = alternative["parsed_meal_plan"]

            meals = []
            for item in parsed_meal_plan:
                meal_type = item.get("type", "meal")
                meals.append({
                    "meal_type": self._meal_type_label(meal_type),
                    "time": self._meal_time(meal_type),
                    "food": item.get("meal", {}),
                })

            return {
                "meals": meals,
                "daily_totals": meal_plan_totals(parsed_meal_plan),
            }

        return current_day_plan

    def generate_meal_plan(self, user_profile, num_days=7):
        if not 1 <= num_days <= 14:
            raise PlanRequestError("invalid_plan_length", "Choose between 1 and 14 days")
        self.ensure_fresh_state()
        profile, X_scaled, target_calories, bmi, bmr, tdee = self.prepare_user_features(
            user_profile
        )
        check_planning_context(profile)
        predicted_plan_type = self.model.predict(X_scaled)[0]

        candidates = self._filter_candidates(profile, num_days)
        ranked_candidates = self._rank_candidates(
            candidates,
            profile,
            predicted_plan_type,
            target_calories,
            bmi,
        )
        weekly_plan = self._build_weekly_plan(ranked_candidates, num_days)

        return {
            "user_profile": profile,
            "planning_context": {
                "engine_version": "medication_hybrid_v1",
                "ranking_method": "baseline_classifier_context_and_reviewed_ranker" if ranked_candidates.attrs.get('learned_ranker_applied') else "baseline_classifier_and_context_preferences",
                "learned_medication_ranker_loaded": bool(self.medication_ranker),
                "learned_medication_ranker_applied": ranked_candidates.attrs.get('learned_ranker_applied', False),
                "clinical_validation_established": False,
                "baseline_dataset_changed": self.baseline_dataset_changed,
                "medication_context": treatment_context(profile),
                "ranking_reasons": ranked_candidates.attrs.get("ranking_reasons", []),
                "nutrition_bounds": candidates.attrs.get("nutrition_bounds", {}),
                "eligible_plans": len(candidates),
                "unique_plans_used": len({day['source_plan_id'] for day in weekly_plan}),
                "dietary_evidence": "dataset_category_labels_not_ingredient_verification",
                "review_status": "requires_clinician_review",
                "warnings": planning_notes(profile),
            },
            "health_metrics": {
                "bmi": round(bmi, 2),
                "bmr": round(bmr, 2),
                "tdee": round(tdee, 2),
                "target_calories": round(target_calories, 2),
            },
            "health_conditions": {
                "has_diabetes": profile["has_diabetes"],
                "uses_insulin": profile["uses_insulin"],
                "insulin_morning": profile["insulin_morning_units"],
                "insulin_night": profile["insulin_night_units"],
                "blood_sugar_level": profile["blood_sugar_level"],
            },
            "recommended_plan_type": predicted_plan_type,
            "meal_category": ", ".join(
                canonical_to_display_preference(pref)
                for pref in profile["dietary_preferences"]
            ),
            "weekly_plan": weekly_plan,
        }

    def print_meal_plan(self, recommendation):
        print("\n" + "=" * 80)
        print("PAKISTANI PERSONALIZED DIET PLAN")
        print("=" * 80)

        profile = recommendation["user_profile"]
        print(f"Goal: {profile['goal']}")
        print(f"Dietary preference: {profile['dietary_preference']}")
        print(f"Recommended plan type: {recommendation['recommended_plan_type']}")

        for day_plan in recommendation["weekly_plan"]:
            print(f"\nDay {day_plan['day']} - {day_plan['date']}")
            print("-" * 80)
            for meal in day_plan["meals"]:
                food = meal["food"]
                print(
                    f"{meal['meal_type']} ({meal['time']}): {food.get('name', 'Meal')} "
                    f"| Calories: {food.get('calories', 0)} "
                    f"| Protein: {food.get('protein', 0)}g "
                    f"| Carbs: {food.get('carbs', 0)}g "
                    f"| Fat: {food.get('fat', 0)}g"
                )
            print(f"Daily totals: {day_plan['daily_totals']}")


if __name__ == "__main__":
    recommender = DietRecommender()

    sample_user = {
        "age": 30,
        "gender": "male",
        "weight_kg": 80,
        "height_cm": 175,
        "activity_level": "moderately_active",
        "goals": ["blood_sugar_control"],
        "dietary_preferences": ["heart_healthy"],
        "has_diabetes": True,
        "uses_insulin": True,
        "insulin_morning_units": 20,
        "insulin_night_units": 12,
        "blood_sugar_level": 145,
    }

    recommendation = recommender.generate_meal_plan(sample_user, num_days=3)
    recommender.print_meal_plan(recommendation)