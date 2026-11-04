from app.services.treatment_service import read_treatment, save_treatment, sync_legacy_insulin
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text
from app.models import UserProfile, SugarReading, HealthGoal, DietPreference, User
from app.schemas import UserProfileRequest, UserProfileUpdateRequest
from datetime import datetime
from datetime import timezone, timedelta


async def create_or_update_profile(db: AsyncSession, payload: UserProfileRequest):
    bmi = payload.weight_kg / ((payload.height_cm / 100) ** 2)

    result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == payload.user_id)
    )
    existing_profile = result.scalar_one_or_none()

    if existing_profile:
        existing_profile.age = payload.age
        existing_profile.gender = payload.gender.lower()
        existing_profile.weight_kg = payload.weight_kg
        existing_profile.height_cm = payload.height_cm
        existing_profile.bmi = bmi
        existing_profile.diabetes_status = payload.diabetes_status
        existing_profile.insulin_usage = payload.insulin_usage
        existing_profile.insulin_morning_units = getattr(payload, 'insulin_morning_units', None)
        existing_profile.insulin_night_units = getattr(payload, 'insulin_night_units', None)
        existing_profile.activity_level = payload.activity_level
        existing_profile.profile_completed = True
        profile = existing_profile
    else:
        profile = UserProfile(
            user_id=payload.user_id,
            age=payload.age,
            gender=payload.gender.lower(),
            weight_kg=payload.weight_kg,
            height_cm=payload.height_cm,
            bmi=bmi,
            diabetes_status=payload.diabetes_status,
            insulin_usage=payload.insulin_usage,
            insulin_morning_units=getattr(payload, 'insulin_morning_units', None),
            insulin_night_units=getattr(payload, 'insulin_night_units', None),
            activity_level=payload.activity_level,
            profile_completed=True
        )
        db.add(profile)

    if payload.blood_sugar:
        sugar = SugarReading(
            user_id=payload.user_id,
            reading_value=payload.blood_sugar.reading_value,
            reading_unit=payload.blood_sugar.reading_unit,
            notes=payload.blood_sugar.notes,
            reading_time=datetime.utcnow()
        )
        db.add(sugar)

    await db.execute(
        text("DELETE FROM user_health_goals WHERE user_id = :user_id"),
        {"user_id": payload.user_id}
    )

    for goal_id in payload.health_goals:
        result = await db.execute(
            select(HealthGoal).where(HealthGoal.goal_id == goal_id)
        )
        if result.scalar_one_or_none():
            await db.execute(
                text("INSERT INTO user_health_goals (user_id, goal_id) VALUES (:u, :g)"),
                {"u": payload.user_id, "g": goal_id}
            )

    await db.execute(
        text("DELETE FROM user_diet_preferences WHERE user_id = :user_id"),
        {"user_id": payload.user_id}
    )

    for diet_id in payload.dietary_preferences:
        result = await db.execute(
            select(DietPreference).where(DietPreference.diet_id == diet_id)
        )
        if result.scalar_one_or_none():
            await db.execute(
                text("INSERT INTO user_diet_preferences (user_id, diet_id) VALUES (:u, :d)"),
                {"u": payload.user_id, "d": diet_id}
            )

    if payload.treatment is not None:
        await db.flush()
        await save_treatment(db, payload.user_id, payload.treatment)
    elif payload.insulin_usage is not None:
        await sync_legacy_insulin(db, payload.user_id, payload.insulin_usage)
    await db.commit()
    await db.refresh(profile)
    return profile


async def update_profile(db: AsyncSession, payload: UserProfileUpdateRequest, image_url: Optional[str] = None):
    """
    Update user profile with validation.
    """

    # BLOOD GLUCOSE VALIDATION - Safety check before saving
    if payload.blood_glucose is not None:
        if payload.blood_glucose < 20:
            raise ValueError(f"Invalid blood glucose value: {payload.blood_glucose} mg/dL. Must be at least 20 mg/dL")
        if payload.blood_glucose > 600:
            raise ValueError(f"Invalid blood glucose value: {payload.blood_glucose} mg/dL. Cannot exceed 600 mg/dL")

    # WEIGHT VALIDATION
    if payload.weight_kg is not None:
        if payload.weight_kg < 10:
            raise ValueError(f"Invalid weight: {payload.weight_kg} kg. Must be at least 10 kg")
        if payload.weight_kg > 500:
            raise ValueError(f"Invalid weight: {payload.weight_kg} kg. Cannot exceed 500 kg")

    # HEIGHT VALIDATION
    if payload.height_cm is not None:
        if payload.height_cm < 50:
            raise ValueError(f"Invalid height: {payload.height_cm} cm. Must be at least 50 cm")
        if payload.height_cm > 300:
            raise ValueError(f"Invalid height: {payload.height_cm} cm. Cannot exceed 300 cm")

    # AGE VALIDATION
    if payload.age is not None:
        if payload.age < 1:
            raise ValueError(f"Invalid age: {payload.age}. Must be at least 1 year")
        if payload.age > 120:
            raise ValueError(f"Invalid age: {payload.age}. Cannot exceed 120 years")

    # INSULIN VALIDATIONS
    if payload.insulin_morning_units is not None:
        if payload.insulin_morning_units < 0:
            raise ValueError(f"Invalid morning insulin: {payload.insulin_morning_units} units. Cannot be negative")
        if payload.insulin_morning_units > 100:
            raise ValueError(f"Invalid morning insulin: {payload.insulin_morning_units} units. Cannot exceed 100 units")

    if payload.insulin_night_units is not None:
        if payload.insulin_night_units < 0:
            raise ValueError(f"Invalid night insulin: {payload.insulin_night_units} units. Cannot be negative")
        if payload.insulin_night_units > 100:
            raise ValueError(f"Invalid night insulin: {payload.insulin_night_units} units. Cannot exceed 100 units")

    # Update User table
    user_result = await db.execute(
        select(User).where(User.user_id == payload.user_id)
    )
    user = user_result.scalar_one_or_none()
    if user:
        if payload.first_name:
            user.first_name = payload.first_name
        if payload.last_name:
            user.last_name = payload.last_name
        if payload.email:
            user.email = payload.email

    # Update UserProfile table
    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == payload.user_id)
    )
    profile = profile_result.scalar_one_or_none()

    if not profile:
        profile = UserProfile(user_id=payload.user_id)
        db.add(profile)

    if payload.age is not None:
        profile.age = payload.age
    if payload.gender is not None:
        profile.gender = payload.gender.lower()
    if payload.weight_kg is not None:
        profile.weight_kg = payload.weight_kg
    if payload.height_cm is not None:
        profile.height_cm = payload.height_cm
    if payload.diabetes_status is not None:
        profile.diabetes_status = payload.diabetes_status
    if payload.insulin_usage is not None:
        profile.insulin_usage = payload.insulin_usage
    if hasattr(payload, 'insulin_morning_units') and payload.insulin_morning_units is not None:
        profile.insulin_morning_units = payload.insulin_morning_units
    if hasattr(payload, 'insulin_night_units') and payload.insulin_night_units is not None:
        profile.insulin_night_units = payload.insulin_night_units

    # Recalculate BMI if weight or height changed
    if profile.weight_kg and profile.height_cm:
        try:
            profile.bmi = float(profile.weight_kg) / ((float(profile.height_cm) / 100) ** 2)
        except Exception:
            profile.bmi = None  # Invalid calculation

    if image_url:
        profile.profile_picture = image_url

    # Save blood glucose reading with validation (already validated above)
    if payload.blood_glucose is not None and payload.blood_glucose > 0:
        pakistan_time = datetime.now(timezone.utc)
        new_reading = SugarReading(
            user_id=payload.user_id,
            reading_value=payload.blood_glucose,
            reading_unit="mg/dL",
            notes="Updated via Profile",
            reading_time=pakistan_time,
        )
        db.add(new_reading)
        await db.flush()

    profile.profile_completed = True

    if payload.treatment is not None:
        await db.flush()
        await save_treatment(db, payload.user_id, payload.treatment)
    elif payload.insulin_usage is not None:
        await sync_legacy_insulin(db, payload.user_id, payload.insulin_usage)
    await db.commit()
    await db.refresh(profile)
    return profile


async def get_user_profile(db: AsyncSession, user_id: int):
    """
    Get user profile with all related data.
    """
    query = (
        select(User, UserProfile)
        .join(UserProfile, User.user_id == UserProfile.user_id)
        .where(User.user_id == user_id)
    )

    result = await db.execute(query)
    data = result.first()

    if not data:
        return None

    user, profile = data

    health_goals_result = await db.execute(
        text("SELECT goal_id FROM user_health_goals WHERE user_id = :user_id"),
        {"user_id": user_id}
    )
    health_goals = [row[0] for row in health_goals_result.fetchall()]

    diet_prefs_result = await db.execute(
        text("SELECT diet_id FROM user_diet_preferences WHERE user_id = :user_id"),
        {"user_id": user_id}
    )
    dietary_preferences = [row[0] for row in diet_prefs_result.fetchall()]

    # Get latest blood sugar reading (optional - for dashboard)
    latest_sugar_result = await db.execute(
        text("""
            SELECT reading_value, reading_time 
            FROM sugar_readings 
            WHERE user_id = :user_id 
            ORDER BY reading_time DESC 
            LIMIT 1
        """),
        {"user_id": user_id}
    )
    latest_sugar = latest_sugar_result.first()
    latest_blood_sugar = float(latest_sugar[0]) if latest_sugar else None
    latest_blood_sugar_time = latest_sugar[1] if latest_sugar else None

    treatment = await read_treatment(db, user_id, bool(profile.insulin_usage))
    return {
        "treatment": treatment,
        "user_id": user.user_id,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "name": f"{user.first_name or ''} {user.last_name or ''}".strip(),
        "email": user.email,
        "age": profile.age,
        "gender": profile.gender,
        "weight_kg": float(profile.weight_kg) if profile.weight_kg else None,
        "height_cm": float(profile.height_cm) if profile.height_cm else None,
        "bmi": float(profile.bmi) if profile.bmi else None,
        "diabetes_status": profile.diabetes_status.value if hasattr(profile.diabetes_status,
                                                                    'value') else profile.diabetes_status,
        "insulin_usage": profile.insulin_usage,
        "insulin_morning_units": float(profile.insulin_morning_units) if profile.insulin_morning_units else 0,
        "insulin_night_units": float(profile.insulin_night_units) if profile.insulin_night_units else 0,
        "activity_level": profile.activity_level.value if hasattr(profile.activity_level,
                                                                  'value') else profile.activity_level,
        "profile_picture": profile.profile_picture,
        "profile_completed": profile.profile_completed,
        "health_goals": health_goals,
        "dietary_preferences": dietary_preferences,
        "latest_blood_sugar": latest_blood_sugar,
        "latest_blood_sugar_time": latest_blood_sugar_time.isoformat() if latest_blood_sugar_time else None,
    }