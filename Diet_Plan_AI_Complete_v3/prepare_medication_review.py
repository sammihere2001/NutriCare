"""Create blank-label, explicitly fictional review cases from local reference meals."""
import argparse
from html import escape
import json
from pathlib import Path

import pandas as pd

from diet_data_utils import normalize_dataframe
from medication_dataset import SCHEMA_VERSION, ReviewProfile, plan_id, write_review_csv, load_review_csv
from medication_context import meal_metrics


def synthetic_cases():
    contexts = [
        ("metformin", ["metformin"], "normal", []),
        ("glp1_reduced_appetite", ["glp1", "metformin"], "reduced", ["early_fullness"]),
        ("insulin_glp1", ["insulin", "glp1"], "normal", []),
        ("sulfonylurea", ["sulfonylurea", "metformin"], "normal", []),
        ("sglt2", ["sglt2", "metformin"], "normal", []),
        ("dual_incretin_nausea", ["dual_gip_glp1"], "reduced", ["nausea"]),
    ]
    for name, medicines, appetite, symptoms in contexts:
        yield name, ReviewProfile(age=45, gender="male", weight_kg=85, height_cm=175,
            activity_level="moderately_active", goals=["maintain_weight"],
            dietary_preferences=["balanced"], uses_insulin="insulin" in medicines,
            blood_sugar_level=140, treatment={"medications_confirmed": True,
                "medications": [{"medication_class": medicine} for medicine in medicines],
                "appetite": appetite, "symptoms": symptoms}).model_dump(mode="json")


def prepare(dataset, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    data = normalize_dataframe(pd.read_csv(dataset))
    plans = data[data['dietary_preference'] == 'balanced'].drop_duplicates('meal_signature')
    plans = plans.sort_values('daily_calories').reset_index(drop=True)
    indices = sorted(set(round(i * (len(plans) - 1) / 5) for i in range(6)))
    rows, cards = [], []
    for case_name, profile in synthetic_cases():
        for index in indices:
            source = plans.iloc[index]
            plan = source['parsed_meal_plan']
            metrics = meal_metrics(plan)
            identifier = plan_id(plan)
            rows.append({"schema_version": SCHEMA_VERSION,
                "case_id": f"fictional_{case_name}", "group_id": f"fictional_group_{case_name}",
                "plan_id": identifier, "is_synthetic": "true",
                "profile_json": json.dumps(profile, separators=(',', ':')),
                "meal_plan_json": json.dumps(plan, separators=(',', ':')),
                "declared_preferences_json": '["balanced"]', "suitability": "",
                "review_status": "draft", "reviewer_id": "", "reviewed_at": "",
                "source_reference": f"Local legacy CSV ({Path(dataset).name}); food provenance and nutrition not independently verified; fictional patient context",
                "review_notes": ""})
            meal_rows = ''.join('<tr><td>' + escape(str(item.get('type', ''))) + '</td><td>' +
                escape(item['meal']['name']) + '</td><td>' + escape(str(item['meal']['calories'])) +
                '</td></tr>' for item in plan)
            classes = ', '.join(m['medication_class'] for m in profile['treatment']['medications'])
            cards.append(f'''<section><h2>Fictional case: {escape(case_name)}</h2>
                <p>Plan ID: {identifier} | 45 years, male, 85 kg, 175 cm; moderately active;
                maintain-weight goal; recorded glucose 140 mg/dL. No real patient is represented.</p>
                <p>Recorded classes: {escape(classes)}. Appetite: {escape(profile['treatment']['appetite'])}.
                Symptoms: {escape(', '.join(profile['treatment']['symptoms']) or 'none recorded')}.</p>
                <table><tr><th>Meal</th><th>Food</th><th>kcal</th></tr>{meal_rows}</table>
                <p>Daily totals: {metrics['calories']:.0f} kcal; protein {metrics['protein']:.1f} g;
                carbs {metrics['carbs']:.1f} g; fat {metrics['fat']:.1f} g.</p>
                <p>Review: ☐ Unsuitable ☐ Acceptable ☐ Preferred ☐ Insufficient information</p>
                <p>Portions, ingredients, source accuracy, medication context and missing information:</p>
                <div class="notes"></div><p>Reviewer ID: __________ Date: __________</p></section>''')
    csv_path = output / 'medication_review_draft.csv'
    write_review_csv(csv_path, rows)
    _, report = load_review_csv(csv_path)
    (output / 'audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    (output / 'review_packet.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8">
        <title>NutriCare fictional medication review cases</title><style>
        body{font:15px system-ui;max-width:960px;margin:32px auto;color:#172b36;padding:0 20px}
        section{border-top:2px solid #287a77;padding:20px 0;break-inside:avoid}
        table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:8px;border-bottom:1px solid #ccc}
        .notes{height:70px;border:1px solid #aaa}h1,h2{color:#246663}
        @media print{body{margin:0;font-size:11px}section{break-after:page}}
        </style><h1>NutriCare: fictional cases for clinical review</h1>
        <p><strong>Every case is synthetic, every label is blank, and every plan is unverified.</strong>
        These examples are for discussing dataset quality and suitability. They are not prescriptions.
        Compare candidate plans within a case, identify missing history or food/portion data, and leave
        the suitability blank if there is insufficient information. A review does not establish clinical efficacy.</p>
        ''' + ''.join(cards) + '</html>', encoding='utf-8')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dataset', default=str(Path(__file__).parent / 'final_pakistani_diabetic_meal_plans.csv'))
    parser.add_argument('--output', default=str(Path(__file__).parent / 'review_data'))
    args = parser.parse_args()
    print(json.dumps(prepare(args.dataset, args.output), indent=2))
