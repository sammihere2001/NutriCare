"""Add missing reference records only; never import local patient accounts."""
import asyncio
import json
import csv
import os
from pathlib import Path
from sqlalchemy import select
from app.database import engine, AsyncSessionLocal
from app.models import Base, HealthGoal, DietPreference, Meal

GOALS = ['Weight Loss', 'Blood Sugar Control', 'Muscle Gain', 'Maintain Weight',
         'Improve Energy', 'Better Sleep', 'General Health', 'Heart Health', 'Weight Gain']
DIETS = ['Vegetarian', 'Vegan', 'Keto', 'Paleo', 'Gluten Free', 'Dairy Free',
         'Low Carb', 'Mediterranean', 'Balanced', 'Halal', 'Kosher', 'No Restrictions', 'Heart Healthy']


async def seed():
    try:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with AsyncSessionLocal() as session:
            for model, key, label, values in [
                    (HealthGoal, 'goal_id', 'goal_name', GOALS),
                    (DietPreference, 'diet_id', 'diet_name', DIETS)]:
                for number, name in enumerate(values, 1):
                    if await session.get(model, number) is None:
                        session.add(model(**{key: number, label: name}))
            path = Path(os.getenv('MEAL_DATASET_PATH', '/srv/ml/final_pakistani_diabetic_meal_plans.csv'))
            if not path.is_file():
                raise RuntimeError('Reference meal CSV missing; set MEAL_DATASET_PATH')
            existing = set((await session.scalars(select(Meal.name))).all())
            added = 0
            with path.open(encoding='utf-8-sig', newline='') as source:
                for row in csv.DictReader(source):
                    for entry in json.loads(row['meal_plan']):
                        food = entry['meal']
                        name = food['name'].strip()
                        if name in existing:
                            continue
                        category = entry.get('type', 'meal')
                        if category.startswith('snack'):
                            category = 'snack'
                        session.add(Meal(name=name, category=category.capitalize(),
                            calories=int(round(food['calories'])), carbs_g=food['carbs'],
                            protein_g=food['protein'], fat_g=food['fat'],
                            fiber_g=None, glycemic_index=None,
                            serving_size_desc='Source portion unspecified',
                            source='Unverified reference CSV; clinician review required'))
                        existing.add(name)
                        added += 1
            await session.commit()
            print(f'Reference setup complete; {added} meals added. No patient records imported.')
    finally:
        await engine.dispose()


if __name__ == '__main__':
    asyncio.run(seed())
