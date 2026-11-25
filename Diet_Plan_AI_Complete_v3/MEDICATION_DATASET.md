# Medication-aware prototype: data and recommendation contract

This version adds medication-context preferences and explicit constraints around the existing classifier. It does not establish clinical suitability, predict medication response, recommend doses, or replace a diabetes care plan. The original model artifacts are preserved. There is no new clinically trained GLP-1 model installed by default.

## Current runtime

1. The backend retrieves the authenticated profile and treatment records. Only medication **classes**, confirmation status, appetite and symptom flags reach the ML service. Medicine names, prescription text, email and user identifiers are not forwarded.
2. The original Random Forest predicts a legacy nutrition-plan category using its original features. That prediction is one ranking signal; its old accuracy is not a clinical evaluation of this extension.
3. Invalid meal nutrition records are excluded. Dietary categories must match the selected restrictions; unsupported combinations return a descriptive 422 response rather than silently changing the diet. Multiple restrictions use intersection semantics. “Balanced” is treated as neutral when combined with a more specific preference.
4. Plans must meet optional supplied nutrition limits. Without supplied energy limits, actual meal calories must be within **20%** of the existing calculated energy estimate. This is an engineering matching tolerance, not an individualized medical calorie prescription. An infeasible request returns an error; the service does not widen the constraints or invent replacement meals.
5. GLP-1/dual-incretin context favors relative protein density within the eligible pool. Reduced appetite, nausea, reflux or early fullness favor a more even distribution of meal energy; nausea/reflux also favors relatively lower-fat individual meals. The weights (10, 15 and 10 score units) are transparent engineering preferences requiring review, not learned drug effects or guideline nutrient cutoffs. No universal low-fiber diet is applied to GLP-1 users.
6. The default method is reported as `baseline_classifier_and_context_preferences`. An optional reviewed-example ranker can add a score only for medication combinations/appetite/symptoms represented in its training coverage. Missing coverage falls back transparently to the context preferences, never outside the constraint-filtered pool.
7. Responses include planning metadata, limitations, matching bounds, reasons, stable source **plan** hashes and clinical-review status. Source-patient identifiers are not returned. Flutter preserves this metadata and displays a preview/review notice. New glucose logs and profile edits invalidate old plans; older engine caches are rejected.

Nutrition values, portions, ingredient declarations and dietary categories in the legacy CSV are not independently verified. Category matching cannot establish that a food is allergen-free, gluten-free, or appropriate for an individual condition. The app does not yet collect a full clinical history, renal function, individualized glucose targets, pregnancy history beyond recorded gestational status, or meal-by-meal insulin requirements. These are material limits before patient use.

## Conservative planning pauses

The prototype pauses routine generation for recorded glucose below 70 mg/dL, recorded vomiting, unsupported age/pregnancy profiles, and requested keto diets with recorded insulin, sulfonylureas, meglitinides or SGLT2 treatment. It asks for clinical review and gives no medication-change instructions. These product restrictions are deliberately conservative and are **not** a claim that every such dietary choice is universally contraindicated.

Clinical background checked on 4 November 2026:

- [NIDDK: low blood glucose](https://www.niddk.nih.gov/health-information/diabetes/overview/preventing-problems/low-blood-glucose-hypoglycemia): insulin and certain tablets, inadequate carbohydrate intake and missed meals can contribute to hypoglycemia; the individual threshold/care plan can differ.
- [American Society for Nutrition joint GLP-1 nutrition advisory announcement](https://nutrition.org/nutritional-priorities-to-support-glp-1-therapy-for-obesity/): individualized nutrition, gastrointestinal tolerability, nutrient adequacy, and preservation of lean mass are priorities. The advisory concerns GLP-1 therapy for obesity and does not validate this diabetes application.
- [GLP-1 gastrointestinal adverse-event expert consensus](https://pmc.ncbi.nlm.nih.gov/articles/pmid/36614945/): symptom-related food amount/frequency and composition are considerations. The app's relative energy-distribution proxy does not measure stomach-emptying rate, food volume or tolerability.
- [FDA Jardiance label, 2025](https://www.accessdata.fda.gov/drugsatfda_docs/label/2025/204629s063lbl.pdf): ketogenic diets, reduced intake, volume depletion and other factors are listed in ketoacidosis precautions. This motivates the prototype's SGLT2/keto review gate; it is not an instruction to change medication.

Engineering thresholds, score weights and CSV training eligibility are project design decisions. Clinical references do not endorse those numeric engineering choices or demonstrate improved health outcomes.

## Review CSV schema v1

Each row represents one candidate day plan for one explicitly described case. This supports positive and negative suitability judgments rather than manufacturing a different meal-class label for each medication.

| Column | Meaning |
| --- | --- |
| `schema_version` | `1` |
| `case_id` | Pseudonymous scenario ID; one profile per case |
| `group_id` | Independent patient/scenario group; repeated visits from a patient share a group |
| `plan_id` | SHA-256-derived 20-character hash of canonical meal JSON |
| `is_synthetic` | Explicit `true` or `false`; never inferred |
| `profile_json` | Validated demographics, goals, preferences, diabetes context and medication-class/symptom inputs |
| `meal_plan_json` | Food names and calorie/protein/carbohydrate/fat values for each meal; extend with measured portions, ingredients and nutrition-source evidence when collecting better data |
| `declared_preferences_json` | Source category tags; a declaration is not proof of ingredient safety |
| `suitability` | Blank until review, then `unsuitable`, `acceptable` or `preferred` |
| `review_status` | `draft`, `reviewed` or `excluded` |
| `reviewer_id` | Reviewer code, required for reviewed rows |
| `reviewed_at` | Review date in YYYY-MM-DD form, not in the future |
| `source_reference` | Dataset/recipe/nutrition provenance; retain uncertainty explicitly |
| `review_notes` | Missing information, reasons and limitations; excluded from ML features |

Do not put names, contact details, account IDs, clinical record numbers, or prescription text in `profile_json`. Its schema rejects unknown fields. IDs and notes still require careful manual de-identification. Medication names/doses are intentionally absent from training features; doses of different medicines are not comparable numerical inputs.

The generator creates **36 draft rows across six fictional scenarios**, with blank suitability labels, plus a printable HTML companion. No reviewer identity or clinical judgment is invented. Its six candidate plans span the legacy calorie distribution so the reviewer can reject unsuitable options. All cases use the same demographics to make medication-context contrasts explicit; they are not representative clinical samples or independent patients. They may also lack food/portion information needed for any suitability judgment. Leave the label blank or exclude a row when information is insufficient.

```powershell
./venv/Scripts/python.exe prepare_medication_review.py
./venv/Scripts/python.exe medication_dataset.py review_data/medication_review_draft.csv
./venv/Scripts/python.exe medication_dataset.py --template review_data/medication_review_template.csv
```

## Training a separate suitability ranker

The optional pipeline uses medication-class flags, appetite/symptoms, demographics and candidate nutrition metrics with a Random Forest regressor. It predicts reviewer scores on a 0–2 scale, not glucose response, drug efficacy or a clinical risk score.

- Draft/excluded examples never train it. Reviewed rows need a label, reviewer code, date and source reference. This is a curation check, not independent verification of a reviewer's credentials.
- Synthetic rows are excluded by default. Reviewed synthetic research requires an explicit flag and remains identified in model metadata. This flag must never be used to claim real-patient validation.
- Minimum software eligibility: 20 reviewed examples, six independent groups and two suitability labels. These small minimums are **not** sample-size justification or evidence of adequate clinical coverage.
- Groups are separated before preprocessing; the vectorizer fits only training groups. Evaluation reports held-out-group mean absolute error and a training-mean baseline. Catalog meals can recur across groups, so this is not an unseen-food evaluation.
- Metadata records treatment coverage and synthetic counts. A treatment combination outside training coverage does not get a learned score at runtime.
- Build artifacts in a separate directory. Do not overwrite the original classifier/scaler/encoder files. Only load trusted local artifacts; joblib files execute Python deserialization.

```powershell
./venv/Scripts/python.exe medication_ranker.py PATH_TO_REVIEWED.csv --output models/medication_ranker
# Explicit research-only option after genuine review of fictional cases:
./venv/Scripts/python.exe medication_ranker.py PATH_TO_REVIEWED.csv --output models/medication_ranker_research --allow-reviewed-synthetic
# Optional service configuration after evaluating the resulting artifact:
$env:MEDICATION_RANKER_PATH = 'models/medication_ranker/medication_ranker.joblib'
```

The checked-in draft must fail training eligibility. The default serving engine therefore continues to use the original classifier plus documented context preferences. Online retraining is disabled by default; `ALLOW_BASELINE_RETRAIN=true` is an explicit operator-only development override for the legacy endpoint. Serving no longer retrains or overwrites baseline artifacts automatically when a file modification time changes. A changed dataset is reported in planning metadata and needs deliberate model evaluation/retraining.

## Engineering comparison

```powershell
./venv/Scripts/python.exe evaluate_medication_engine.py
./venv/Scripts/python.exe -m unittest discover -s tests -v
```

The comparison reconstructs the inspected old filter/scoring logic, shares the unchanged classifier, fixes sampling seed 42, and compares actual meal calories against the engineering matching window for six fictional scenarios. Its report includes baseline artifact hashes. It measures constraint compliance only. It does not establish that calorie estimates, medication preferences, nutrient values or meals are clinically correct, nor that the new approach improves health outcomes.
