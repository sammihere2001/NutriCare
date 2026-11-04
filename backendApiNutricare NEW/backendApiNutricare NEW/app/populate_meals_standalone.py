"""
Standalone script to populate meals table from CSV file.
Run from project root: python populate_meals_standalone.py
"""
import asyncio
import json
import sys
import os

# Add the current directory to path so we can import app modules
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, current_dir)

import pandas as pd
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select, text, Column, Integer, String, Text, Numeric, DateTime, func, ForeignKey, BigInteger, Date
from sqlalchemy.orm import declarative_base, relationship

# Read database URL from .env file
def get_database_url():
    """Read DATABASE_URL from .env file"""
    env_path = os.path.join(current_dir, '.env')
    if os.path.exists(env_path):
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('DATABASE_URL='):
                    url = line.split('=', 1)[1].strip().strip('"').strip("'")
                    print(f" Found DATABASE_URL in .env")
                    return url

    from app.config import settings
    return settings.DATABASE_URL


DATABASE_URL = get_database_url()

# Define models directly (avoiding import issues)
Base = declarative_base()

class Meal(Base):
    __tablename__ = "meals"
    meal_id = Column(Integer, primary_key=True, index=True)
    name = Column(Text, nullable=False)
    category = Column(Text)
    serving_size_desc = Column(Text)
    calories = Column(Integer)
    carbs_g = Column(Numeric)
    protein_g = Column(Numeric)
    fat_g = Column(Numeric)
    fiber_g = Column(Numeric)
    glycemic_index = Column(Integer)
    source = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

class Ingredient(Base):
    __tablename__ = "ingredients"
    ingredient_id = Column(Integer, primary_key=True, index=True)
    name = Column(Text, nullable=False, unique=True)

class MealIngredient(Base):
    __tablename__ = "meal_ingredients"
    meal_id = Column(Integer, ForeignKey("meals.meal_id", ondelete="CASCADE"), primary_key=True)
    ingredient_id = Column(Integer, ForeignKey("ingredients.ingredient_id", ondelete="CASCADE"), primary_key=True)
    amount_desc = Column(Text)

class Tag(Base):
    __tablename__ = "tags"
    tag_id = Column(Integer, primary_key=True, index=True)
    tag_name = Column(Text, nullable=False, unique=True)

class MealTag(Base):
    __tablename__ = "meal_tags"
    meal_id = Column(Integer, ForeignKey("meals.meal_id", ondelete="CASCADE"), primary_key=True)
    tag_id = Column(Integer, ForeignKey("tags.tag_id", ondelete="CASCADE"), primary_key=True)

# Path to your CSV file
CSV_PATH = r"C:\Users\Dell\Desktop\Almost All done FYP\Diet_Plan_AI_Complete_v3\final_pakistani_diabetic_meal_plans.csv"


def estimate_gi(carbs: float, fiber: float, protein: float, fat: float, calories: float) -> int:
    """
    Better GI estimation based on multiple nutritional factors.
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

    # Carb content affects GI
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

    # Fiber-to-carb ratio
    if carbs > 0:
        fiber_ratio = fiber / carbs
        if fiber_ratio > 0.15:
            score -= 8
        elif fiber_ratio > 0.1:
            score -= 3
        elif fiber_ratio < 0.03:
            score += 8

    # Calorie density
    if calories > 800:
        score += 8
    elif calories > 600:
        score += 5
    elif calories < 200:
        score -= 5

    # Clamp score between 25-85
    score = max(25, min(85, score))

    return int(score)


async def populate_meals():
    """Read CSV and populate meals table with unique meals"""

    if not os.path.exists(CSV_PATH):
        print(f" CSV file not found at: {CSV_PATH}")
        print("Please update the CSV_PATH variable with the correct path.")
        return

    print(f" Connecting to database...")
    print(f"   URL: {DATABASE_URL.replace(DATABASE_URL.split('@')[0].split('://')[-1], '***')}")  # Hide credentials

    engine = create_async_engine(DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # Clear existing meals
        print("  Clearing existing meals...")
        try:
            await session.execute(text("DELETE FROM meal_ingredients"))
            await session.execute(text("DELETE FROM meal_tags"))
            await session.execute(text("DELETE FROM meals"))
            await session.commit()
            print(" Cleared existing meals")
        except Exception as e:
            print(f"  Could not clear tables: {e}")
            print("   Continuing anyway...")

        # Read CSV
        print(" Reading CSV file...")
        df = pd.read_csv(CSV_PATH)
        print(f" Read {len(df)} rows from CSV")

        # Extract all unique meals
        unique_meals = {}

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
                        # Merge all snacks
                        if meal_type in ['snack_1', 'snack_2', 'snack']:
                            category = 'Snack'
                        else:
                            category = meal_type.capitalize()

                        carbs = float(meal_data.get('carbs', 0))
                        fiber = float(meal_data.get('fiber', 0))
                        protein = float(meal_data.get('protein', 0))
                        fat = float(meal_data.get('fat', 0))
                        calories = int(meal_data.get('calories', 0))

                        unique_meals[name] = {
                            'name': name,
                            'category': category,
                            'calories': calories,
                            'protein_g': protein,
                            'carbs_g': carbs,
                            'fat_g': fat,
                            'fiber_g': fiber,
                            'serving_size_desc': '1 serving',
                            'glycemic_index': estimate_gi(carbs, fiber, protein, fat, calories),
                            'source': 'ML Model CSV'
                        }
            except Exception as e:
                print(f" Error processing row {idx}: {e}")
                continue

        print(f" Found {len(unique_meals)} unique meals")

        # Insert meals
        inserted_count = 0
        batch_size = 100

        for meal_name, meal_data in unique_meals.items():
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

            if inserted_count % batch_size == 0:
                await session.commit()
                print(f"  Inserted {inserted_count} meals...")

        await session.commit()
        print(f" Inserted {inserted_count} unique meals")

        # Add tags
        await add_tags(session)

        # Show GI distribution
        await show_gi_distribution(session)

        print("\n Done! Meal database populated successfully!")
        print(f"   Total unique meals: {inserted_count}")


async def add_tags(session: AsyncSession):
    """Add common tags to database"""
    common_tags = [
        'Diabetic-Friendly', 'Pakistani', 'Desi', 'High Protein',
        'Low Carb', 'Heart Healthy', 'Vegetarian', 'Vegan',
        'Gluten-Free', 'Dairy-Free', 'Keto-Friendly'
    ]

    added = 0
    for tag_name in common_tags:
        result = await session.execute(
            select(Tag).where(Tag.tag_name == tag_name)
        )
        if not result.scalar_one_or_none():
            session.add(Tag(tag_name=tag_name))
            added += 1

    await session.commit()
    print(f" Added {added} new tags")


async def show_gi_distribution(session: AsyncSession):
    """Show the distribution of GI levels"""
    result = await session.execute(
        select(Meal.glycemic_index)
    )
    all_gi = [row[0] for row in result.fetchall() if row[0] is not None]

    if not all_gi:
        print("\n  No GI data found!")
        return

    low = sum(1 for gi in all_gi if gi <= 55)
    medium = sum(1 for gi in all_gi if 56 <= gi <= 69)
    high = sum(1 for gi in all_gi if gi >= 70)

    print(f"\n GI Distribution:")
    print(f"    Low GI (55):   {low} meals ({low/len(all_gi)*100:.1f}%)")
    print(f"    Medium GI (56-69): {medium} meals ({medium/len(all_gi)*100:.1f}%)")
    print(f"    High GI (70):  {high} meals ({high/len(all_gi)*100:.1f}%)")
    print(f"   Average GI: {sum(all_gi)/len(all_gi):.1f}")


if __name__ == "__main__":
    asyncio.run(populate_meals())