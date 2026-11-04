from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError
from sqlalchemy import select, delete
from app.database import get_db
from app.models import User, UserProfile, DailyTracker, DailyTrackerMeals, SugarReading
from app.schemas import DailyTrackerCreate, GlucoseQuickLogSchema
from jose import jwt
from app.config import settings
from app.routers.notifications import create_notification
from datetime import date, timedelta, datetime, time, timezone
from decimal import Decimal

router = APIRouter(prefix="/daily-tracker", tags=["Daily Tracker"])


def to_float(value):
    if value is None:
        return 0.0
    return float(value)


from app.auth_utils import get_current_user as get_current_user_from_token


# CHECK ENDPOINT
@router.get("/check")
async def check_tracker_exists(
        tracker_date: date,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """Check if daily tracker already exists for given date"""
    print(f"=== CHECK ENDPOINT CALLED ===")
    print(f"User ID: {current_user.user_id}")
    print(f"Tracker Date: {tracker_date}")

    result = await db.execute(
        select(DailyTracker).where(
            DailyTracker.user_id == current_user.user_id,
            DailyTracker.tracker_date == tracker_date
        )
    )
    tracker = result.scalar_one_or_none()

    exists = tracker is not None
    print(f"Tracker exists: {exists}")
    print(f"Tracker ID: {tracker.tracker_id if tracker else None}")

    return {"exists": exists, "tracker_id": tracker.tracker_id if tracker else None}


# GET TRACKER ENDPOINT (SINGLE - DUPLICATE REMOVED)
@router.get("/get")
async def get_daily_tracker(
        tracker_date: date,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """Fetch daily tracker data for a specific date"""
    print(f"=== GET TRACKER CALLED ===")
    print(f"User ID: {current_user.user_id}")
    print(f"Tracker Date: {tracker_date}")

    result = await db.execute(
        select(DailyTracker).where(
            DailyTracker.user_id == current_user.user_id,
            DailyTracker.tracker_date == tracker_date
        )
    )
    tracker = result.scalar_one_or_none()

    if not tracker:
        return {
            "exists": False,
            "data": None
        }

    # Fetch meals
    meals_result = await db.execute(
        select(DailyTrackerMeals).where(
            DailyTrackerMeals.tracker_id == tracker.tracker_id
        )
    )
    meals = meals_result.scalars().all()

    return {
        "exists": True,
        "data": {
            "tracker_id": tracker.tracker_id,
            "tracker_date": str(tracker.tracker_date),
            "morning_glucose": to_float(tracker.morning_glucose),
            "evening_glucose": to_float(tracker.evening_glucose),
            "weight": to_float(tracker.weight),
            "exercise": to_float(tracker.exercise),
            "exercise_time": tracker.exercise_time,
            "water_intake": to_float(tracker.water_intake),
            "sleep_hours": to_float(tracker.sleep_hours),
            "stress_level": to_float(tracker.stress_level),
            "notes": tracker.notes,
            "meals": [
                {
                    "meal_name": meal.meal_name,
                    "calories": to_float(meal.calories),
                    "meal_time": str(meal.meal_time),
                    "meal_type": meal.meal_type
                }
                for meal in meals
            ]
        }
    }


@router.get("/history")
async def get_daily_tracker_history(
        days: int = 7,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """Fetch daily tracker data for the last N days"""
    print(f"=== GET HISTORY CALLED ===")
    print(f"User ID: {current_user.user_id}")
    print(f"Days: {days}")

    end_date = date.today()
    start_date = end_date - timedelta(days=days - 1)

    result = await db.execute(
        select(DailyTracker).where(
            DailyTracker.user_id == current_user.user_id,
            DailyTracker.tracker_date >= start_date,
            DailyTracker.tracker_date <= end_date
        ).order_by(DailyTracker.tracker_date)
    )
    trackers = result.scalars().all()

    history = []
    for tracker in trackers:
        history.append({
            "tracker_date": str(tracker.tracker_date),
            "morning_glucose": to_float(tracker.morning_glucose),
            "evening_glucose": to_float(tracker.evening_glucose),
            "weight": to_float(tracker.weight),
            "exercise": to_float(tracker.exercise),
            "water_intake": to_float(tracker.water_intake),
            "sleep_hours": to_float(tracker.sleep_hours),
            "stress_level": to_float(tracker.stress_level),
        })

    return {
        "history": history,
        "total_days": len(history),
        "start_date": str(start_date),
        "end_date": str(end_date)
    }


async def sync_tracker_glucose(db: AsyncSession, tracker: DailyTracker):
    """Keep profile/diet readings consistent with tracker edits in the same transaction."""
    if await db.get(UserProfile, tracker.user_id) is None:
        raise HTTPException(status_code=409, detail="Complete your profile before logging glucose")
    pakistan_tz = timezone(timedelta(hours=5))
    for slot, hour in (("morning", 8), ("evening", 20)):
        marker = f"tracker:{tracker.tracker_date.isoformat()}:{slot}"
        result = await db.execute(select(SugarReading).where(
            SugarReading.user_id == tracker.user_id,
            SugarReading.notes == marker
        ).order_by(SugarReading.reading_time.desc()))
        existing = result.scalars().first()
        value = getattr(tracker, f"{slot}_glucose")
        if value is None:
            if existing is not None:
                await db.delete(existing)
            continue
        if existing is not None:
            existing.reading_value = value
        else:
            recorded_at = datetime.combine(tracker.tracker_date, time(hour), tzinfo=pakistan_tz)
            recorded_at = min(recorded_at, datetime.now(pakistan_tz))
            db.add(SugarReading(user_id=tracker.user_id, reading_value=value,
                                reading_unit="mg/dL", notes=marker,
                                reading_time=recorded_at))


@router.post("")
async def save_daily_tracker(
        data: DailyTrackerCreate,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    print(f"=== SAVE TRACKER CALLED ===")
    print(f"User ID: {current_user.user_id}")
    print(f"Tracker Date: {data.tracker_date}")
    print(f"Is Update: {data.is_update}")

    # ✅ Pydantic automatically validates all fields here

    # Additional meal count validation
    if len(data.meals) > 10:
        raise HTTPException(status_code=400, detail="Maximum 10 meals allowed per day")

    # Check if at least one glucose reading is provided
    if data.morning_glucose is None and data.evening_glucose is None:
        raise HTTPException(status_code=400, detail="At least one glucose reading is required")

    try:
        await db.execute(select(User.user_id).where(User.user_id == current_user.user_id).with_for_update())
        result = await db.execute(
            select(DailyTracker).where(
                DailyTracker.user_id == current_user.user_id,
                DailyTracker.tracker_date == data.tracker_date
            )
        )
        existing_tracker = result.scalar_one_or_none()

        print(f"Existing tracker found: {existing_tracker is not None}")

        is_update = data.is_update or existing_tracker is not None

        if existing_tracker and is_update:
            print("UPDATING existing tracker...")
            tracker = existing_tracker
            tracker.morning_glucose = Decimal(str(data.morning_glucose)) if data.morning_glucose is not None else None
            tracker.evening_glucose = Decimal(str(data.evening_glucose)) if data.evening_glucose is not None else None
            tracker.weight = Decimal(str(data.weight)) if data.weight is not None else None
            tracker.exercise = Decimal(str(data.exercise)) if data.exercise is not None else None
            tracker.exercise_time = data.exercise_time
            tracker.water_intake = Decimal(str(data.water_intake)) if data.water_intake is not None else None
            tracker.sleep_hours = Decimal(str(data.sleep_hours)) if data.sleep_hours is not None else None
            tracker.stress_level = Decimal(str(data.stress_level)) if data.stress_level is not None else None
            tracker.notes = data.notes

            await db.execute(
                delete(DailyTrackerMeals).where(DailyTrackerMeals.tracker_id == tracker.tracker_id)
            )
        else:
            print("CREATING new tracker...")
            tracker = DailyTracker(
                user_id=current_user.user_id,
                tracker_date=data.tracker_date,
                morning_glucose=Decimal(str(data.morning_glucose)) if data.morning_glucose is not None else None,
                evening_glucose=Decimal(str(data.evening_glucose)) if data.evening_glucose is not None else None,
                weight=Decimal(str(data.weight)) if data.weight is not None else None,
                exercise=Decimal(str(data.exercise)) if data.exercise is not None else None,
                exercise_time=data.exercise_time,
                water_intake=Decimal(str(data.water_intake)) if data.water_intake is not None else None,
                sleep_hours=Decimal(str(data.sleep_hours)) if data.sleep_hours is not None else None,
                stress_level=Decimal(str(data.stress_level)) if data.stress_level is not None else None,
                notes=data.notes
            )
            db.add(tracker)
            await db.flush()

        if data.meals:
            print(f"Saving {len(data.meals)} meals...")
            for meal in data.meals:
                db_meal = DailyTrackerMeals(
                    tracker_id=tracker.tracker_id,
                    meal_name=meal.meal_name,
                    calories=Decimal(str(meal.calories)),
                    meal_time=meal.meal_time,
                    meal_type=meal.meal_type
                )
                db.add(db_meal)

        await sync_tracker_glucose(db, tracker)
        await db.commit()
        await db.refresh(tracker)

        if data.weight and data.weight > 0:
            await update_user_profile_weight(db, current_user.user_id, data.weight)

        return {
            "message": "Daily tracker saved successfully" if not is_update else "Daily tracker updated successfully",
            "tracker_id": tracker.tracker_id,
            "is_update": is_update
        }

    except HTTPException:
        await db.rollback()
        raise
    except IntegrityError as e:
        await db.rollback()
        print(f"IntegrityError: {e}")
        raise HTTPException(status_code=400, detail="Daily tracker for this date already exists")
    except ValueError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        await db.rollback()
        print(f"Exception: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to save tracker: {str(e)}")


async def update_user_profile_weight(db: AsyncSession, user_id: int, weight: float):
    from app.models import UserProfile
    from decimal import Decimal

    weight_decimal = Decimal(str(weight))

    result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == user_id)
    )
    profile = result.scalar_one_or_none()

    if profile:
        profile.weight_kg = weight_decimal
        if profile.height_cm and profile.height_cm > 0:
            height_in_meters = Decimal(str(profile.height_cm)) / Decimal('100')
            profile.bmi = weight_decimal / (height_in_meters * height_in_meters)
        await db.commit()
        print(f"Weight updated in profile for user {user_id}: {weight} kg")
        return profile
    return None


@router.get("/weekly-stats")
async def get_weekly_stats(
        user_id: int,
        start_date: date,
        end_date: date,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    if user_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="You can only access your own statistics")
    if not 0 <= (end_date - start_date).days <= 6:
        raise HTTPException(status_code=400, detail="Choose a range of 1 to 7 days")
    result = await db.execute(
        select(DailyTracker).where(
            DailyTracker.user_id == user_id,
            DailyTracker.tracker_date >= start_date,
            DailyTracker.tracker_date <= end_date
        ).order_by(DailyTracker.tracker_date)
    )
    records = result.scalars().all()

    if not records:
        return {
            "avg_morning_glucose": 0,
            "avg_evening_glucose": 0,
            "avg_exercise": 0,
            "avg_water": 0,
            "avg_sleep": 0,
            "compliance": 0
        }

    total_days = len(records)

    def avg(field):
        values = [float(getattr(r, field)) for r in records if getattr(r, field) is not None]
        if not values:
            return 0.0
        return round(sum(values) / len(values), 1)

    compliance = round((total_days / ((end_date - start_date).days + 1)) * 100, 1)

    return {
        "avg_morning_glucose": avg("morning_glucose"),
        "avg_evening_glucose": avg("evening_glucose"),
        "avg_exercise": avg("exercise"),
        "avg_water": avg("water_intake"),
        "avg_sleep": avg("sleep_hours"),
        "compliance": compliance
    }


@router.post("/quick-log-glucose")
async def quick_log_glucose(
    tracker_date: date,
    glucose_type: str,
    glucose_value: float,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user_from_token)
):
    """Quick log glucose reading without full tracker entry (accepts query parameters)"""
    print(f"=== QUICK LOG GLUCOSE CALLED ===")
    print(f"User ID: {current_user.user_id}")
    print(f"Date: {tracker_date}, Type: {glucose_type}, Value: {glucose_value}")

    # Validate
    if glucose_type not in ["morning", "evening"]:
        raise HTTPException(status_code=400, detail="glucose_type must be 'morning' or 'evening'")

    if glucose_value < 20 or glucose_value > 600:
        raise HTTPException(status_code=400, detail="Glucose value must be between 20 and 600 mg/dL")

    # Serialize creates/updates for one user, including older databases without the unique constraint.
    await db.execute(select(User.user_id).where(User.user_id == current_user.user_id).with_for_update())
    result = await db.execute(
        select(DailyTracker).where(
            DailyTracker.user_id == current_user.user_id,
            DailyTracker.tracker_date == tracker_date
        )
    )
    existing_tracker = result.scalar_one_or_none()

    if existing_tracker:
        # Update existing tracker
        if glucose_type == "morning":
            existing_tracker.morning_glucose = Decimal(str(glucose_value))
        else:
            existing_tracker.evening_glucose = Decimal(str(glucose_value))

        await sync_tracker_glucose(db, existing_tracker)
        await db.commit()
        await db.refresh(existing_tracker)

        return {
            "message": f"{glucose_type.capitalize()} glucose updated successfully",
            "tracker_id": existing_tracker.tracker_id,
            "is_new": False
        }
    else:
        # Create new tracker with minimal data
        new_tracker = DailyTracker(
            user_id=current_user.user_id,
            tracker_date=tracker_date,
            morning_glucose=Decimal(str(glucose_value)) if glucose_type == "morning" else None,
            evening_glucose=Decimal(str(glucose_value)) if glucose_type == "evening" else None,
            weight=None,
            exercise=None,
            exercise_time=None,
            water_intake=None,
            sleep_hours=None,
            stress_level=None,
            notes=None
        )
        db.add(new_tracker)
        await sync_tracker_glucose(db, new_tracker)
        await db.commit()
        await db.refresh(new_tracker)

        return {
            "message": f"New tracker created with {glucose_type} glucose",
            "tracker_id": new_tracker.tracker_id,
            "is_new": True
        }
