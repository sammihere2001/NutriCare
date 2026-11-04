"""
One-time script to populate meals table from CSV file.
Run from project root: python -m app.scripts.populate_meals
"""
import asyncio
import json
import pandas as pd
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select
from app.config import settings
from app.models import Meal, Ingredient, MealIngredient, Tag, MealTag
import os

# Path to your CSV file
CSV_PATH = r"C:\Users\Dell\Desktop\Almost All done FYP\Diet_Plan_AI_Complete_v3\final_pakistani_diabetic_meal_plans.csv"

async def populate_meals():
    """Read CSV and populate meals table with unique meals"""

    if not os.path.exists(CSV_PATH):
        print(f" CSV file not found at: {CSV_PATH}")
        return

    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # Read CSV
        print(" Reading CSV file...")
        df = pd.read_csv(CSV_PATH)
        print(f" Read {len(df)} rows from CSV")

        # Extract all unique meals from meal_plan column
        unique_meals = {}  # name -> meal data

        for idx, row in df.iterrows():
            try:
                meal_plan_str = row.get('meal_plan', '[]')
                if isinstance(meal_plan_str, str):
                    meal_plan = json.loads(meal_plan_str)
                else:
                    meal_plan = meal_plan_str

                for meal_entry in meal_plan:
                    meal_type = meal_entry.get('type', 'meal')
                    meal_data = meal_entry.get('meal', {})
                    name = meal_data.get('name', '').strip()

                    if name and name not in unique_meals:
                        # Determine meal category
                        # Normalize meal categories - merge all snacks into one "Snack" category
                        if meal_type in ['snack_1', 'snack_2', 'snack']:
                            category = 'Snack'
                        else:
                            category = meal_type.capitalize()

                        unique_meals[name] = {
                            'name': name,
                            'category': category,
                            'calories': meal_data.get('calories', 0),
                            'protein_g': meal_data.get('protein', 0),
                            'carbs_g': meal_data.get('carbs', 0),
                            'fat_g': meal_data.get('fat', 0),
                            'fiber_g': meal_data.get('fiber', 0),
                            'serving_size_desc': '1 serving',
                            'glycemic_index': estimate_gi(
                                carbs=meal_data.get('carbs', 0),
                                fiber=meal_data.get('fiber', 0),
                                protein=meal_data.get('protein', 0),
                                fat=meal_data.get('fat', 0),
                                calories=meal_data.get('calories', 0) ),
                            'source': 'ML Model CSV'
                        }
            except Exception as e:
                print(f" Error processing row {idx}: {e}")
                continue

        print(f" Found {len(unique_meals)} unique meals")

        # Insert meals into database
        inserted_count = 0
        skipped_count = 0

        for meal_name, meal_data in unique_meals.items():
            # Check if meal already exists
            result = await session.execute(
                select(Meal).where(Meal.name == meal_name)
            )
            existing = result.scalar_one_or_none()

            if existing:
                skipped_count += 1
                continue

            # Create meal
            new_meal = Meal(
                name=meal_data['name'],
                category=meal_data['category'],
                serving_size_desc=meal_data['serving_size_desc'],
                calories=meal_data['calories'],
                carbs_g=meal_data['carbs_g'],
                protein_g=meal_data['protein_g'],
                fat_g=meal_data['fat_g'],
                fiber_g=meal_data['fiber_g'],
                glycemic_index=meal_data['glycemic_index'],
                source=meal_data['source']
            )
            session.add(new_meal)
            inserted_count += 1

        await session.commit()
        print(f" Inserted {inserted_count} new meals")
        print(f" Skipped {skipped_count} existing meals")

        # Add common tags
        await add_tags(session)

        print(" Done! Meal database populated successfully!")


def estimate_gi(carbs: float, fiber: float, protein: float, fat: float, calories: float) -> int:
    """
    Better GI estimation based on multiple nutritional factors.

    Factors that LOWER GI:
    - High fiber (>5g per serving)
    - High protein (>15g per serving)
    - High fat (>15g per serving)
    - Low total carbs (<30g)

    Factors that RAISE GI:
    - High carbs (>60g)
    - Low fiber (<3g)
    - Low protein (<10g)
    - Low fat (<5g)
    """
    score = 50  # Start at medium

    # Fiber lowers GI (strongest factor)
    if fiber >= 8:
        score -= 20
    elif fiber >= 5:
        score -= 12
    elif fiber >= 3:
        score -= 5
    elif fiber < 2:
        score += 10
    elif fiber < 1:
        score += 15

    # Protein lowers GI
    if protein >= 20:
        score -= 10
    elif protein >= 15:
        score -= 7
    elif protein >= 10:
        score -= 3
    elif protein < 5:
        score += 8

    # Fat lowers GI
    if fat >= 20:
        score -= 8
    elif fat >= 15:
        score -= 5
    elif fat >= 10:
        score -= 2
    elif fat < 3:
        score += 5

    # Carb content affects GI (high carbs = higher GI)
    if carbs > 80:
        score += 15
    elif carbs > 60:
        score += 10
    elif carbs > 40:
        score += 5
    elif carbs < 20:
        score -= 10
    elif carbs < 30:
        score -= 5

    # Fiber-to-carb ratio (higher ratio = lower GI)
    if carbs > 0:
        fiber_ratio = fiber / carbs
        if fiber_ratio > 0.15:
            score -= 8
        elif fiber_ratio > 0.1:
            score -= 3
        elif fiber_ratio < 0.03:
            score += 8

    # Calorie density (very high calorie meals tend to have higher GI impact)
    if calories > 800:
        score += 8
    elif calories > 600:
        score += 5
    elif calories < 200:
        score -= 5

    # Clamp score between 25-85
    score = max(25, min(85, score))

    return int(score)

if __name__ == "__main__":
    asyncio.run(populate_meals())