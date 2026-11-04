from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, distinct
from sqlalchemy.orm import selectinload
from typing import Optional, List
from app.database import get_db
from app.models import Meal, Ingredient, MealIngredient, Tag, MealTag

router = APIRouter(prefix="/meals-database", tags=["Meal Database"])


@router.get("/meals")
async def get_meals(
        meal_type: Optional[str] = Query(None, description="Filter by category (breakfast, lunch, dinner, snack)"),
        glycemic_index: Optional[str] = Query(None, description="Filter by GI level (low, medium, high)"),
        search: Optional[str] = Query(None, description="Search meal name"),
        page: int = Query(1, ge=1, description="Page number"),
        page_size: int = Query(20, ge=1, le=50, description="Items per page"),
        db: AsyncSession = Depends(get_db)
):
    """
    Get meals with optional filtering, search, and pagination.
    All meals are unique (deduplicated by name).
    """

    # Base query - select distinct meals by name
    # Using a subquery approach to get unique meals with their first occurrence
    subq = (
        select(
            Meal.name,
            func.min(Meal.meal_id).label('min_id')
        )
        .group_by(Meal.name)
        .subquery()
    )

    query = (
        select(Meal)
        .join(subq, Meal.meal_id == subq.c.min_id)
    )

    # Apply filters
    if meal_type and meal_type.lower() != 'all meals':
        # Map frontend filter names to backend categories
        category_map = {
            'breakfast': 'Breakfast',
            'lunch': 'Lunch',
            'dinner': 'Dinner',
            'snack': 'Snack',
            'morning snack': 'Snack',  # Map to unified Snack
            'evening snack': 'Snack',  # Map to unified Snack
        }
        db_category = category_map.get(meal_type.lower(), meal_type.capitalize())
        query = query.where(Meal.category == db_category)

    if glycemic_index:
        if glycemic_index.lower() == 'low':
            query = query.where(Meal.glycemic_index <= 55)
        elif glycemic_index.lower() == 'medium':
            query = query.where(Meal.glycemic_index.between(56, 69))
        elif glycemic_index.lower() == 'high':
            query = query.where(Meal.glycemic_index >= 70)

    if search:
        query = query.where(Meal.name.ilike(f"%{search}%"))

    # Get total count for pagination
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total_count = total_result.scalar() or 0

    # Apply pagination
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    meals = result.scalars().all()

    # Format response
    meals_data = []
    for meal in meals:
        # Get ingredients for this meal
        ing_result = await db.execute(
            select(Ingredient.name, MealIngredient.amount_desc)
            .join(MealIngredient, Ingredient.ingredient_id == MealIngredient.ingredient_id)
            .where(MealIngredient.meal_id == meal.meal_id)
        )
        ingredients = [{"name": row[0], "amount": row[1]} for row in ing_result.fetchall()]

        # Get tags
        tag_result = await db.execute(
            select(Tag.tag_name)
            .join(MealTag, Tag.tag_id == MealTag.tag_id)
            .where(MealTag.meal_id == meal.meal_id)
        )
        tags = [row[0] for row in tag_result.fetchall()]

        # Determine GI level
        gi_level = "GI unknown"
        gi_color = "info"
        if meal.glycemic_index is not None:
            if meal.glycemic_index <= 55:
                gi_level = "Low GI"
                gi_color = "success"
            elif meal.glycemic_index <= 69:
                gi_level = "Medium GI"
                gi_color = "warning"
            else:
                gi_level = "High GI"
                gi_color = "error"

        # Determine meal type from category or tags
        meal_type_display = meal.category or "Meal"

        meals_data.append({
            "meal_id": meal.meal_id,
            "name": meal.name,
            "serving": meal.serving_size_desc or "1 serving",
            "mealType": meal_type_display,
            "giLevel": gi_level,
            "giColor": gi_color,
            "calories": str(meal.calories or 0),
            "protein": f"{meal.protein_g or 0}g",
            "carbs": f"{meal.carbs_g or 0}g",
            "fat": f"{meal.fat_g or 0}g",
            "fiber": f"{meal.fiber_g}g" if meal.fiber_g is not None else "Not recorded",
            "glycemic_index": meal.glycemic_index,
            "ingredients": [ing["name"] for ing in ingredients] if ingredients else [],
            "tags": tags,
            "source": meal.source or "Database"
        })

    return {
        "meals": meals_data,
        "total": total_count,
        "page": page,
        "page_size": page_size,
        "has_more": (offset + page_size) < total_count
    }


@router.get("/categories")
async def get_meal_categories(db: AsyncSession = Depends(get_db)):
    """Get available meal categories"""
    result = await db.execute(
        select(distinct(Meal.category)).where(Meal.category.isnot(None))
    )
    categories = [row[0] for row in result.fetchall() if row[0]]

    return {"categories": categories}


@router.get("/meals/{meal_id}")
async def get_meal_detail(meal_id: int, db: AsyncSession = Depends(get_db)):
    """Get detailed information about a specific meal"""
    result = await db.execute(
        select(Meal).where(Meal.meal_id == meal_id)
    )
    meal = result.scalar_one_or_none()

    if not meal:
        raise HTTPException(status_code=404, detail="Meal not found")

    # Get ingredients
    ing_result = await db.execute(
        select(Ingredient.name, MealIngredient.amount_desc)
        .join(MealIngredient, Ingredient.ingredient_id == MealIngredient.ingredient_id)
        .where(MealIngredient.meal_id == meal.meal_id)
    )
    ingredients = [{"name": row[0], "amount": row[1]} for row in ing_result.fetchall()]

    return {
        "meal": {
            "meal_id": meal.meal_id,
            "name": meal.name,
            "category": meal.category,
            "serving_size_desc": meal.serving_size_desc,
            "calories": meal.calories,
            "carbs_g": float(meal.carbs_g) if meal.carbs_g else 0,
            "protein_g": float(meal.protein_g) if meal.protein_g else 0,
            "fat_g": float(meal.fat_g) if meal.fat_g else 0,
            "fiber_g": float(meal.fiber_g) if meal.fiber_g is not None else None,
            "glycemic_index": meal.glycemic_index,
            "ingredients": ingredients,
            "source": meal.source
        }
    }
