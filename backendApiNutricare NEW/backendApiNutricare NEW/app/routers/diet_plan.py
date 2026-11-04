# app/routers/diet_plan.py
from fastapi import APIRouter, Depends, HTTPException, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Dict, Any, Optional
from app.services.ai_service import ai_service
from app.database import get_db
from app.models import User, SugarReading
from app.crud_profile import get_user_profile
from app.routers.notifications import create_notification
from jose import jwt, JWTError
from app.config import settings
from sqlalchemy import select, desc

router = APIRouter(prefix="/diet-plan", tags=["Diet Plan"])


from app.auth_utils import get_current_user as get_current_user_from_token


@router.post("/generate")
async def generate_diet_plan(
        days: int = Query(7, ge=1, le=14),
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """
    Generate a personalized diet plan using AI model based on user's profile.
    Uses the user's saved profile data automatically.
    """
    # Get user profile from database
    profile_data = await get_user_profile(db, current_user.user_id)

    if not profile_data:
        raise HTTPException(
            status_code=404,
            detail="User profile not found. Please complete your profile first."
        )

    # Get latest blood sugar reading if available
    sugar_result = await db.execute(
        select(SugarReading)
        .where(SugarReading.user_id == current_user.user_id)
        .order_by(desc(SugarReading.reading_time))
        .limit(1)
    )
    latest_sugar = sugar_result.scalar_one_or_none()

    # Add blood sugar to profile data
    if latest_sugar:
        profile_data["blood_sugar_level"] = float(latest_sugar.reading_value)
    else:
        profile_data["blood_sugar_level"] = 100  # Default value

    try:
        # Call AI service to generate diet plan
        diet_plan = await ai_service.generate_diet_plan(profile_data, days=days)

        # Create notification for user
        await create_notification(
            db,
            current_user.user_id,
            "🥗 Diet Plan Generated",
            f"Your personalized {days}-day diet plan is ready! View your meal recommendations now.",
            "success",
            {
                "days": days,
                "plan_type": diet_plan.get("recommended_plan_type", "balanced"),
                "target_calories": diet_plan.get("health_analysis", {}).get("target_calories", 0)
            }
        )

        return {
            "success": True,
            "message": f"{days}-day diet plan generated successfully",
            "data": diet_plan
        }

    except HTTPException:
        raise
    except Exception as e:
        # Create error notification
        await create_notification(
            db,
            current_user.user_id,
            "❌ Diet Plan Generation Failed",
            f"We couldn't generate your diet plan. Please try again later.",
            "error"
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate diet plan: {str(e)}"
        )


@router.post("/generate-custom")
async def generate_custom_diet_plan(
        user_profile: Dict[str, Any],
        days: int = Query(7, ge=1, le=14),
        current_user: User = Depends(get_current_user_from_token)
):
    """
    Generate a diet plan with custom profile data (without saving to database).
    Useful for "what-if" scenarios or testing different parameters.
    """
    try:
        diet_plan = await ai_service.generate_diet_plan(user_profile, days=days)

        return {
            "success": True,
            "message": f"{days}-day custom diet plan generated successfully",
            "data": diet_plan
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate diet plan: {str(e)}"
        )


@router.get("/health-analysis")
async def get_health_analysis(
        current_user: User = Depends(get_current_user_from_token),
        db: AsyncSession = Depends(get_db)
):
    """
    Get user's health analysis from their profile and latest readings.
    Returns BMI, BMR, TDEE calculations without calling AI model.
    """
    profile_data = await get_user_profile(db, current_user.user_id)

    if not profile_data:
        raise HTTPException(
            status_code=404,
            detail="User profile not found. Please complete your profile first."
        )

    # Calculate basic health metrics
    weight = float(profile_data.get("weight_kg", 70))
    height = float(profile_data.get("height_cm", 170))
    age = int(profile_data.get("age", 30))
    gender = str(profile_data.get("gender", "male")).lower()
    activity = str(profile_data.get("activity_level", "moderately_active")).lower()

    # BMI Calculation
    height_m = height / 100
    bmi = weight / (height_m ** 2)

    # BMR Calculation (Mifflin-St Jeor)
    if gender == "male":
        bmr = 10 * weight + 6.25 * height - 5 * age + 5
    else:
        bmr = 10 * weight + 6.25 * height - 5 * age - 161

    # TDEE Calculation
    activity_multipliers = {
        "sedentary": 1.2,
        "lightly_active": 1.375,
        "moderately_active": 1.55,
        "very_active": 1.725,
        "extremely_active": 1.9,
    }
    tdee = bmr * activity_multipliers.get(activity, 1.55)

    # BMI Status
    if bmi < 18.5:
        bmi_status = "Underweight"
    elif bmi < 25:
        bmi_status = "Normal"
    elif bmi < 30:
        bmi_status = "Overweight"
    else:
        bmi_status = "Obese"

    return {
        "success": True,
        "health_analysis": {
            "bmi": round(bmi, 2),
            "bmi_status": bmi_status,
            "bmr": round(bmr, 2),
            "tdee": round(tdee, 2),
            "target_calories": round(tdee, 2)
        },
        "profile": {
            "age": age,
            "gender": gender,
            "weight_kg": weight,
            "height_cm": height,
            "activity_level": activity,
            "diabetes_status": profile_data.get("diabetes_status", "none"),
            "insulin_usage": profile_data.get("insulin_usage", False)
        }
    }

@router.post("/retrain-and-generate")
async def retrain_and_generate_diet_plan(
        days: int = Query(7, ge=1, le=14),
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """
    🔄 Retrain the AI model from latest CSV data, then generate a fresh diet plan.
    This ensures completely new meal recommendations based on the latest data.
    """
    # Get user profile from database
    profile_data = await get_user_profile(db, current_user.user_id)

    if not profile_data:
        raise HTTPException(
            status_code=404,
            detail="User profile not found. Please complete your profile first."
        )

    # Get latest blood sugar reading
    sugar_result = await db.execute(
        select(SugarReading)
        .where(SugarReading.user_id == current_user.user_id)
        .order_by(desc(SugarReading.reading_time))
        .limit(1)
    )
    latest_sugar = sugar_result.scalar_one_or_none()

    if latest_sugar:
        profile_data["blood_sugar_level"] = float(latest_sugar.reading_value)
    else:
        profile_data["blood_sugar_level"] = 100

    try:
        # Step 1+2: Retrain model THEN generate plan
        diet_plan = await ai_service.retrain_and_generate(profile_data, days=days)

        # Create success notification
        await create_notification(
            db,
            current_user.user_id,
            "🔄 Fresh Diet Plan Generated!",
            f"AI model has been retrained and your new {days}-day personalized diet plan is ready!",
            "success",
            {
                "days": days,
                "plan_type": diet_plan.get("recommended_plan_type", "balanced"),
                "target_calories": diet_plan.get("health_analysis", {}).get("target_calories", 0)
            }
        )

        return {
            "success": True,
            "message": f"Model retrained and {days}-day diet plan generated successfully",
            "data": diet_plan
        }

    except HTTPException:
        raise
    except Exception as e:
        await create_notification(
            db,
            current_user.user_id,
            "❌ Plan Generation Failed",
            f"Could not generate diet plan after retraining. Please try again.",
            "error"
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to retrain and generate: {str(e)}"
        )