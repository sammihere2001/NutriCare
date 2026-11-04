"""Versioned request context and transparent prototype ranking preferences.

No medication dosing or drug-effect prediction is performed here. References
and the distinction between engineering weights and clinical targets are in
MEDICATION_DATASET.md.
"""
from __future__ import annotations

from math import isfinite
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

MEDICATION_CLASSES = (
    "insulin", "glp1", "dual_gip_glp1", "metformin", "sglt2", "sulfonylurea",
    "meglitinide", "dpp4", "thiazolidinedione", "alpha_glucosidase", "other",
)
SYMPTOMS = ("nausea", "vomiting", "early_fullness", "reflux", "constipation", "diarrhea")
GLP_CLASSES = {"glp1", "dual_gip_glp1"}
HYPOGLYCEMIA_MEDICATIONS = {"insulin", "sulfonylurea", "meglitinide"}


class MedicationEntry(BaseModel):
    model_config = ConfigDict(extra="forbid")
    medication_class: Literal[MEDICATION_CLASSES]


class TreatmentContext(BaseModel):
    model_config = ConfigDict(extra="forbid")
    medications_confirmed: bool = False
    medications: list[MedicationEntry] = Field(default_factory=list, max_length=20)
    appetite: Literal["unknown", "normal", "reduced", "increased"] = "unknown"
    symptoms: list[Literal[SYMPTOMS]] = Field(default_factory=list, max_length=6)


class NutritionTargets(BaseModel):
    """Optional supplied limits; not inferred prescriptions or clinician verification."""
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
    calories_min: float | None = Field(None, ge=0)
    calories_max: float | None = Field(None, gt=0)
    protein_min_g: float | None = Field(None, ge=0)
    carbs_max_g: float | None = Field(None, ge=0)
    fat_max_g: float | None = Field(None, ge=0)
    max_meal_calories: float | None = Field(None, gt=0)

    @model_validator(mode="after")
    def ordered_energy_range(self):
        if self.calories_min is not None and self.calories_max is not None:
            if self.calories_min > self.calories_max:
                raise ValueError("calories_min must not exceed calories_max")
        return self


class PlanRequestError(ValueError):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def treatment_context(profile: dict) -> dict:
    raw = profile.get("treatment") or {}
    context = raw if isinstance(raw, TreatmentContext) else TreatmentContext.model_validate(raw)
    classes = {m.medication_class for m in context.medications}
    if profile.get("uses_insulin"):
        classes.add("insulin")
    return {"medication_classes": sorted(classes),
            "medications_confirmed": context.medications_confirmed,
            "appetite": context.appetite, "symptoms": sorted(set(context.symptoms))}


def context_features(profile: dict) -> dict:
    context = treatment_context(profile)
    features = {f"medication_{name}": int(name in context["medication_classes"])
                for name in MEDICATION_CLASSES}
    features.update({f"symptom_{name}": int(name in context["symptoms"]) for name in SYMPTOMS})
    features.update({"medications_confirmed": int(context["medications_confirmed"]),
                     "appetite": context["appetite"]})
    return features


def check_planning_context(profile: dict):
    context = treatment_context(profile)
    if not 18 <= int(profile["age"]) <= 100 or profile.get("diabetes_status") == "gestational":
        raise PlanRequestError("individual_review_required",
                               "This prototype supports adult, non-pregnancy meal-plan previews. Please review individual nutrition needs with your clinician.")
    glucose = profile.get("blood_sugar_level")
    if glucose is not None and float(glucose) < 70:
        raise PlanRequestError("low_glucose_review_required",
                               "The recorded glucose is below 70 mg/dL. Follow your prescribed low-glucose care plan; seek urgent medical help for severe symptoms. Meal planning is paused.")
    if "vomiting" in context["symptoms"]:
        raise PlanRequestError("symptom_review_required",
                               "Vomiting can affect food intake and hydration. Review this with your healthcare team before generating a routine meal plan; seek urgent care if symptoms are severe or you cannot keep fluids down.")
    preferences = set(profile.get("dietary_preferences", []))
    if "keto" in preferences and set(context["medication_classes"]) & (HYPOGLYCEMIA_MEDICATIONS | {"sglt2"}):
        raise PlanRequestError("diet_medication_review_required",
                               "A ketogenic diet with the recorded medication needs individualized clinical review. This prototype will not generate that combination automatically.")


def meal_metrics(meal_plan: list) -> dict:
    totals = {"calories": 0.0, "protein": 0.0, "carbs": 0.0, "fat": 0.0}
    meals = []
    if not isinstance(meal_plan, list) or not meal_plan:
        raise ValueError("A plan must contain meals")
    for entry in meal_plan:
        food = entry.get("meal", {})
        if not isinstance(food.get("name"), str) or not food["name"].strip():
            raise ValueError("Every meal needs a name")
        numbers = {key: float(food[key]) for key in totals}
        if any(not isfinite(v) or v < 0 for v in numbers.values()) or numbers["calories"] <= 0:
            raise ValueError("Nutrition values must be finite and nonnegative, with positive calories")
        for key in totals:
            totals[key] += numbers[key]
        meals.append(numbers)
    return {**totals, "meal_count": len(meals),
            "largest_meal_calories": max(m["calories"] for m in meals),
            "largest_meal_share": max(m["calories"] for m in meals) / totals["calories"],
            "largest_meal_fat": max(m["fat"] for m in meals),
            "protein_density": totals["protein"] / totals["calories"] * 1000}


def preference_adjustments(ranked, profile: dict):
    """Relative engineering preferences, not prescribed nutrient thresholds."""
    ranked = ranked.copy()
    context = treatment_context(profile)
    classes = set(context["medication_classes"])
    reasons = []
    ranked["medication_score"] = 0.0
    if classes & GLP_CLASSES:
        ranked["medication_score"] += ranked["protein_density"].rank(pct=True) * 10
        reasons.append("Prioritized protein density among eligible plans for recorded GLP-1-based treatment.")
    if context["appetite"] == "reduced" or set(context["symptoms"]) & {"nausea", "early_fullness", "reflux"}:
        ranked["medication_score"] += (1 - ranked["largest_meal_share"].rank(pct=True)) * 15
        reasons.append("Preferred a more even distribution of meal calories for reduced appetite or reported symptoms.")
    if set(context["symptoms"]) & {"nausea", "reflux"}:
        ranked["medication_score"] += (1 - ranked["largest_meal_fat"].rank(pct=True)) * 10
        reasons.append("Preferred lower-fat individual meals among eligible plans for reported nausea/reflux.")
    ranked["score"] += ranked["medication_score"]
    return ranked, reasons


def planning_notes(profile: dict) -> list[str]:
    context = treatment_context(profile)
    notes = ["Prototype meal-plan preview: meal suitability, ingredients and nutrition targets require clinical review."]
    if not context["medications_confirmed"]:
        notes.append("The medication list is not confirmed; missing medications cannot be taken into account.")
    if set(context["medication_classes"]) & HYPOGLYCEMIA_MEDICATIONS:
        notes.append("Recorded medications can increase low-glucose risk. Keep to your prescribed meal/medication plan; this app does not adjust doses or match insulin to carbohydrates.")
    if "sglt2" in context["medication_classes"]:
        notes.append("Recorded SGLT2 treatment requires care around reduced intake, dehydration and ketogenic diets; discuss these with your clinician.")
    if "other" in context["medication_classes"]:
        notes.append("An unclassified medication is recorded; its specific food-related considerations are not modeled.")
    return notes


def constrain_candidates(candidates, profile: dict, target_calories: float):
    targets = NutritionTargets.model_validate(profile.get("nutrition_targets") or {})
    requested = set(profile.get("dietary_preferences") or ["balanced"]) - {"no_restrictions"}
    if len(requested) > 1:
        requested.discard("balanced")
    eligible = candidates[candidates["declared_preferences"].apply(
        lambda tags: requested.issubset(set(tags)))].copy()
    if eligible.empty:
        raise PlanRequestError("unsupported_dietary_combination",
                               "No reference plans declare all of your selected dietary preferences. These restrictions will not be silently relaxed.")
    if not isfinite(target_calories) or target_calories <= 0:
        raise PlanRequestError("invalid_energy_estimate", "Your profile needs an individual nutrition-target review before a plan can be generated.")
    if targets.calories_min is not None or targets.calories_max is not None:
        lower = targets.calories_min if targets.calories_min is not None else 0
        upper = targets.calories_max if targets.calories_max is not None else float("inf")
        source = "supplied_limits_not_clinically_verified"
    else:
        # A transparent engineering matching window, not a medical intake recommendation.
        lower, upper, source = target_calories * 0.8, target_calories * 1.2, "estimated_energy_matching_window"
    eligible = eligible[eligible["daily_calories"].between(lower, upper)].copy()
    for column, limit, minimum in [
        ("daily_protein", targets.protein_min_g, True),
        ("daily_carbs", targets.carbs_max_g, False),
        ("daily_fat", targets.fat_max_g, False),
        ("largest_meal_calories", targets.max_meal_calories, False),
    ]:
        if limit is not None:
            eligible = eligible[eligible[column] >= limit if minimum else eligible[column] <= limit]
    if eligible.empty:
        raise PlanRequestError("no_matching_nutrition_plan",
                               "No reference plan meets the energy range and supplied nutrition limits. Review your profile/targets or add reviewed meal plans; constraints were not relaxed.")
    return eligible, {"calories_min": round(lower, 2),
                      "calories_max": round(upper, 2) if isfinite(upper) else None,
                      "source": source, "supplied_limits": targets.model_dump(exclude_none=True)}
