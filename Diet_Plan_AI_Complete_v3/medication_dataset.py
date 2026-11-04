"""CSV contract for reviewed (profile, candidate-plan) suitability examples.

This is application data-engineering code. It never invents clinical labels.
"""
from __future__ import annotations

import argparse
import csv
from datetime import date
import hashlib
import json
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from medication_context import TreatmentContext, NutritionTargets, meal_metrics

SCHEMA_VERSION = "1"
CSV_COLUMNS = ["schema_version", "case_id", "group_id", "plan_id", "is_synthetic",
               "profile_json", "meal_plan_json", "declared_preferences_json",
               "suitability", "review_status", "reviewer_id", "reviewed_at",
               "source_reference", "review_notes"]
SUITABILITY_SCORES = {"unsuitable": 0.0, "acceptable": 1.0, "preferred": 2.0}


class ReviewProfile(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
    age: int = Field(ge=18, le=100)
    gender: Literal["male", "female"]
    weight_kg: float = Field(ge=30, le=300)
    height_cm: float = Field(ge=100, le=250)
    activity_level: Literal["sedentary", "lightly_active", "moderately_active", "very_active", "extremely_active"]
    goals: list[str] = Field(default_factory=lambda: ["general_health"], min_length=1, max_length=9)
    dietary_preferences: list[str] = Field(default_factory=lambda: ["balanced"], min_length=1, max_length=12)
    diabetes_status: Literal["none", "type1", "type2", "prediabetes", "gestational"] = "type2"
    has_diabetes: bool = True
    uses_insulin: bool = False
    insulin_morning_units: float = Field(0, ge=0, le=100)
    insulin_night_units: float = Field(0, ge=0, le=100)
    blood_sugar_level: int = Field(100, ge=20, le=600)
    treatment: TreatmentContext = Field(default_factory=TreatmentContext)
    nutrition_targets: NutritionTargets = Field(default_factory=NutritionTargets)


def plan_id(plan: list) -> str:
    canonical = json.dumps(plan, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode()).hexdigest()[:20]


def validate_record(row: dict, line: int = 0) -> dict:
    prefix = f"Row {line}: " if line else ""
    try:
        if row["schema_version"] != SCHEMA_VERSION:
            raise ValueError("unsupported schema_version")
        if not row["case_id"].strip() or not row["group_id"].strip():
            raise ValueError("case_id and group_id are required pseudonymous identifiers")
        if row["is_synthetic"].lower() not in {"true", "false"}:
            raise ValueError("is_synthetic must explicitly be true or false")
        profile = ReviewProfile.model_validate_json(row["profile_json"]).model_dump(mode="json")
        plan = json.loads(row["meal_plan_json"])
        metrics = meal_metrics(plan)
        if row["plan_id"] != plan_id(plan):
            raise ValueError("plan_id does not match meal_plan_json; regenerate its hash after editing a plan")
        preferences = json.loads(row["declared_preferences_json"])
        if not isinstance(preferences, list) or not all(isinstance(p, str) and p for p in preferences):
            raise ValueError("declared_preferences_json must be a list of category strings")
        if row["review_status"] not in {"draft", "reviewed", "excluded"}:
            raise ValueError("review_status must be draft, reviewed or excluded")
        if row["suitability"] and row["suitability"] not in SUITABILITY_SCORES:
            raise ValueError("unknown suitability label")
        if row["review_status"] == "reviewed":
            if row["suitability"] not in SUITABILITY_SCORES:
                raise ValueError("reviewed records need a suitability label")
            if not row["reviewer_id"].strip() or not row["source_reference"].strip():
                raise ValueError("reviewed records need reviewer_id and source_reference")
            reviewed_at = date.fromisoformat(row["reviewed_at"])
            if reviewed_at > date.today():
                raise ValueError("reviewed_at cannot be in the future")
        if not row["source_reference"].strip():
            raise ValueError("source_reference is required even for draft data")
        return {"raw": row, "profile": profile, "plan": plan, "metrics": metrics,
                "preferences": preferences, "synthetic": row["is_synthetic"].lower() == "true",
                "score": SUITABILITY_SCORES.get(row["suitability"])}
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        raise ValueError(prefix + str(error)) from None


def load_review_csv(path: str | Path) -> tuple[list[dict], dict]:
    records = []
    pairs = set()
    cases = {}
    with open(path, newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != CSV_COLUMNS:
            raise ValueError("CSV columns/order must match schema v1: " + ", ".join(CSV_COLUMNS))
        for line, row in enumerate(reader, 2):
            record = validate_record(row, line)
            pair = (row["case_id"], row["plan_id"])
            if pair in pairs:
                raise ValueError(f"Row {line}: duplicate case_id/plan_id pair")
            pairs.add(pair)
            case = (row["group_id"], json.dumps(record["profile"], sort_keys=True))
            if row["case_id"] in cases and cases[row["case_id"]] != case:
                raise ValueError(f"Row {line}: one case_id must describe one profile and group")
            cases[row["case_id"]] = case
            records.append(record)
    report = {"schema_version": SCHEMA_VERSION, "rows": len(records), "cases": len(cases),
              "groups": len({r["raw"]["group_id"] for r in records}),
              "reviewed_rows": sum(r["raw"]["review_status"] == "reviewed" for r in records),
              "synthetic_rows": sum(r["synthetic"] for r in records),
              "clinical_validation_established": False}
    return records, report


def write_review_csv(path: str | Path, rows: list[dict]):
    """Export a reproducible machine-data file from application records."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", nargs="?")
    parser.add_argument("--template", type=Path)
    args = parser.parse_args()
    if args.template:
        write_review_csv(args.template, [])
        print(f"Wrote schema-v1 template: {args.template}")
    elif args.csv:
        _, report = load_review_csv(args.csv)
        print(json.dumps(report, indent=2))
    else:
        parser.error("Provide a CSV to validate, or --template PATH")
