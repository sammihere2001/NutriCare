# Data and model card

## Provenance

The owner confirmed on 2026-11-25 that the original `final_pakistani_diabetic_meal_plans.csv` contains synthetic/fictional profiles. This supersedes an earlier ambiguous answer in the project discussion. That confirmation is the basis for making the demonstration dataset public; the original generation methodology has not been independently established.

The CSV contains simulated demographics, body measurements, glucose/insulin fields, dietary categories and meal plans. It is not evidence from a prospective clinical study. Do not infer patient outcomes or medication effects from it.

The screenshots use additional fictional widget-test fixtures. No local PostgreSQL account, tracker export, `.env` or database backup is included in this repository.

## Baseline model

The included legacy Random Forest/scaler/encoders are retained for reproducibility of the engineering prototype. Any accuracy in the legacy metadata describes that stored dataset split; it is not a clinical validation result or a measure of health outcomes. Dataset labels are derived from meal composition, not adjudicated medication-specific suitability.

Serving does not silently retrain these artifacts. Explicit offline training should use an isolated model directory and documented dataset version. Never load untrusted pickle/joblib artifacts; the repository's local artifacts are executable serialized Python objects.

## Medication-aware layer

The runtime combines the original classifier with explicit dietary/nutrition constraints and context-preference rules for medication classes, appetite and symptoms. Users may record multiple medications. The rules are engineering choices requiring clinician review. They do not calculate doses or establish that a meal is appropriate for a particular patient.

`medication_dataset.py` and `medication_ranker.py` provide a separate reviewed-label workflow. Synthetic rows are excluded by default; grouped evaluation prevents the same case group from appearing on both sides of its split. Software eligibility checks are not evidence that a dataset is clinically adequate. No clinically reviewed medication model is currently installed.

## Important gaps

- Food values, portions, ingredients, allergens and category labels have not been verified for clinical use.
- Estimated energy bounds and ranking scores are engineering constraints, not individualized medical prescriptions.
- Optional narration summarizes limited recorded data and remains an unverified AI draft.
- Clinician review, external evaluation, demographic coverage and real-device testing remain incomplete.

This is a portfolio/research demonstration, not a medical device or treatment service.
