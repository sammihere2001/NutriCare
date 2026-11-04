"""
Utilities for working with the Pakistani diabetic meal-plan dataset.
"""

from __future__ import annotations

import json
import re
from typing import Any

import pandas as pd

DEFAULT_DATASET_PATH = "final_pakistani_diabetic_meal_plans.csv"

GOAL_OPTIONS = [
    "weight_loss",
    "weight_gain",
    "muscle_gain",
    "maintain_weight",
    "blood_sugar_control",
    "improve_energy",
    "better_sleep",
    "general_health",
    "heart_health",
]

GOAL_LABELS = {
    "weight_loss": "Weight Loss",
    "weight_gain": "Weight Gain",
    "muscle_gain": "Muscle Gain",
    "maintain_weight": "Maintain Weight",
    "blood_sugar_control": "Blood Sugar Control",
    "improve_energy": "Improve Energy",
    "better_sleep": "Better Sleep",
    "general_health": "General Health",
    "heart_health": "Heart Health",
}

DIETARY_PREFERENCE_LABELS = {
    "balanced": "Balanced",
    "vegetarian": "Vegetarian",
    "keto": "Keto",
    "gluten_free": "Gluten-Free",
    "seafood_only": "Seafood-Only",
    "heart_healthy": "Heart-Healthy",
}

ACTIVITY_LEVEL_OPTIONS = [
    "sedentary",
    "lightly_active",
    "moderately_active",
    "very_active",
    "extremely_active",
]


def slugify_value(value: Any) -> str:
    """Normalize a free-form value to a consistent machine-friendly slug."""
    if value is None or pd.isna(value):
        return ""

    text = str(value).strip().lower()
    text = text.replace("&", " and ")
    text = re.sub(r"[\s\-/]+", "_", text)
    text = re.sub(r"[^a-z0-9_]", "", text)
    text = re.sub(r"_+", "_", text)
    return text.strip("_")


GOAL_ALIASES = {slugify_value(goal): goal for goal in GOAL_OPTIONS}
GOAL_ALIASES.update(
    {
        "blood_sugar": "blood_sugar_control",
        "heart_healthy": "heart_health",
    }
)

DIETARY_PREFERENCE_ALIASES = {
    "balanced": "balanced",
    "balanced_diet": "balanced",
    "vegetarian": "vegetarian",
    "keto": "keto",
    "gluten_free": "gluten_free",
    "glutenfree": "gluten_free",
    "seafood_only": "seafood_only",
    "seafoodonly": "seafood_only",
    "heart_healthy": "heart_healthy",
    "hearthealthy": "heart_healthy",
    "heart_health": "heart_healthy",
}

ACTIVITY_LEVEL_ALIASES = {slugify_value(level): level for level in ACTIVITY_LEVEL_OPTIONS}
GENDER_ALIASES = {
    "male": "male",
    "m": "male",
    "female": "female",
    "f": "female",
}


def normalize_goal(value: Any) -> str:
    slug = slugify_value(value)
    if not slug:
        return "general_health"
    return GOAL_ALIASES.get(slug, slug)


def normalize_dietary_preference(value: Any) -> str:
    slug = slugify_value(value)
    if not slug:
        return "balanced"
    return DIETARY_PREFERENCE_ALIASES.get(slug, slug)


def normalize_activity_level(value: Any) -> str:
    slug = slugify_value(value)
    if not slug:
        return "moderately_active"
    return ACTIVITY_LEVEL_ALIASES.get(slug, slug)


def normalize_gender(value: Any) -> str:
    slug = slugify_value(value)
    return GENDER_ALIASES.get(slug, "male")


def normalize_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None or pd.isna(value):
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "y"}


def canonical_to_display_goal(value: Any) -> str:
    canonical = normalize_goal(value)
    return GOAL_LABELS.get(canonical, canonical.replace("_", " ").title())


def canonical_to_display_preference(value: Any) -> str:
    canonical = normalize_dietary_preference(value)
    return DIETARY_PREFERENCE_LABELS.get(canonical, canonical.replace("_", " ").title())


def parse_meal_plan(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, list):
        return value
    if value is None or pd.isna(value):
        return []

    raw_text = str(value).strip()
    if not raw_text:
        return []

    try:
        parsed = json.loads(raw_text)
    except json.JSONDecodeError:
        return []

    return parsed if isinstance(parsed, list) else []


def meal_plan_totals(meal_plan: list[dict[str, Any]]) -> dict[str, float]:
    totals = {
        "calories": 0.0,
        "protein": 0.0,
        "carbs": 0.0,
        "fat": 0.0,
    }

    for item in meal_plan:
        meal = item.get("meal", {})
        for key in totals:
            totals[key] += float(meal.get(key, 0) or 0)

    return {key: round(value, 2) for key, value in totals.items()}


from typing import Any, List


def classify_meal_plan(meal_plan: List[dict[str, Any]]) -> str:
    totals = meal_plan_totals(meal_plan)

    # Initialize scores for each category
    scores = {
        "low_calorie_plan": 0,
        "high_calorie_plan": 0,
        "high_protein_plan": 0,
        "high_carb_plan": 0,
        "balanced_plan": 0
    }

    # 1. CALORIE SCORING (Strongest factor)
    if totals["calories"] < 1500:
        scores["low_calorie_plan"] += 3
    elif totals["calories"] > 2500:
        scores["high_calorie_plan"] += 3
    else:
        # If it's in the middle range (1500-2500), it's a candidate for 'balanced'
        scores["balanced_plan"] += 1

    # 2. PROTEIN SCORING
    if totals["protein"] > 100:
        scores["high_protein_plan"] += 2
    elif 60 <= totals["protein"] <= 100:
        scores["balanced_plan"] += 1

    # 3. CARB SCORING
    if totals["carbs"] > 250:
        scores["high_carb_plan"] += 2
    elif 150 <= totals["carbs"] <= 250:
        scores["balanced_plan"] += 1

    # 4. BALANCED TIE-BREAKER
    # If it's not extreme in any direction, we give an extra push to 'balanced'
    if 1600 < totals["calories"] < 2400 and scores["high_protein_plan"] < 2 and scores["high_carb_plan"] < 2:
        scores["balanced_plan"] += 2

    # Find the category with the highest score
    # If there's a tie, 'max' will pick the first one it finds (usually the calorie plans)
    winner = max(scores, key=scores.get)

    return winner


def normalize_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Normalize dataset values so training and inference share one format."""
    data = df.copy()

    if "gender" in data.columns:
        data["gender"] = data["gender"].apply(normalize_gender)
    if "activity_level" in data.columns:
        data["activity_level"] = data["activity_level"].apply(normalize_activity_level)
    if "goal" in data.columns:
        data["goal"] = data["goal"].apply(normalize_goal)
    if "dietary_preference" in data.columns:
        data["dietary_preference"] = data["dietary_preference"].apply(normalize_dietary_preference)

    for column in ["has_diabetes", "uses_insulin"]:
        if column in data.columns:
            data[column] = data[column].apply(normalize_bool)

    numeric_columns = [
        "age",
        "weight_kg",
        "height_cm",
        "bmi",
        "insulin_morning_units",
        "insulin_night_units",
        "blood_sugar_level",
        "bmr",
        "tdee",
        "target_calories",
    ]

    for column in numeric_columns:
        if column in data.columns:
            data[column] = pd.to_numeric(data[column], errors="coerce")

    if "meal_plan" in data.columns:
        data["parsed_meal_plan"] = data["meal_plan"].apply(parse_meal_plan)
        data["recommended_plan_type"] = data["parsed_meal_plan"].apply(classify_meal_plan)
        data["daily_totals"] = data["parsed_meal_plan"].apply(meal_plan_totals)
        data["meal_signature"] = data["parsed_meal_plan"].apply(
            lambda plan: " | ".join(
                f"{item.get('type', '')}:{item.get('meal', {}).get('name', '')}"
                for item in plan
            )
        )
        data["daily_calories"] = data["daily_totals"].apply(lambda totals: totals["calories"])
        data["daily_protein"] = data["daily_totals"].apply(lambda totals: totals["protein"])
        data["daily_carbs"] = data["daily_totals"].apply(lambda totals: totals["carbs"])
        data["daily_fat"] = data["daily_totals"].apply(lambda totals: totals["fat"])

    return data
