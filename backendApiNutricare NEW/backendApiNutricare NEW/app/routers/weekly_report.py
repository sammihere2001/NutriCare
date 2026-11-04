from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_
from datetime import date, datetime, timedelta
from app.database import get_db
from app.models import DailyTracker, DailyTrackerMeals, WeeklyReport, User
from app.schemas import DailyTrackerCreate
from jose import jwt
from app.config import settings
from app.routers.notifications import create_notification

router = APIRouter(
    prefix="/weekly-reports",
    tags=["Weekly Reports"]
)

from app.auth_utils import get_current_user as get_current_user_from_token


def _calculate_report_data(records, user_id, start_date, end_date):
    """Helper function to calculate report data from records"""
    total_days = len(records)

    def avg(field):
        values = [float(getattr(r, field)) for r in records if getattr(r, field) is not None]
        if not values:
            return None
        return round(sum(values) / len(values), 1)

    avg_morning = avg("morning_glucose")
    avg_evening = avg("evening_glucose")
    avg_exercise = avg("exercise")
    avg_sleep = avg("sleep_hours")
    avg_water = avg("water_intake")
    avg_stress = avg("stress_level")
    avg_weight = avg("weight")

    # Build daily logs
    daily_logs = []
    for record in records:
        status = "Recorded" if record.morning_glucose is not None or record.evening_glucose is not None else "No glucose data"

        daily_logs.append({
            "date": record.tracker_date.strftime("%a, %b %d"),
            "morning_glucose": float(record.morning_glucose) if record.morning_glucose is not None else None,
            "evening_glucose": float(record.evening_glucose) if record.evening_glucose is not None else None,
            "exercise_minutes": float(record.exercise) if record.exercise is not None else None,
            "sleep_hours": float(record.sleep_hours) if record.sleep_hours is not None else None,
            "water": float(record.water_intake) if record.water_intake is not None else None,
            "status": status
        })

    # Describe measured change, without equating lower glucose with better health.
    trend = "INSUFFICIENT_DATA"
    for field in ("morning_glucose", "evening_glucose"):
        series = [float(getattr(r, field)) for r in records if getattr(r, field) is not None]
        if len(series) >= 2:
            delta = series[-1] - series[0]
            trend = "RISING" if delta > 0 else "FALLING" if delta < 0 else "STABLE"
            break

    # Best/Worst days
    best_day = None
    worst_day = None
    best_avg = float('inf')
    worst_avg = float('-inf')

    for record in records:
        readings = [float(value) for value in (record.morning_glucose, record.evening_glucose) if value is not None]
        avg_glucose = sum(readings) / len(readings) if readings else 0

        if avg_glucose > 0:
            if avg_glucose < best_avg:
                best_avg = avg_glucose
                best_day = record
            if avg_glucose > worst_avg:
                worst_avg = avg_glucose
                worst_day = record

    max_days = (end_date - start_date).days + 1
    compliance = round((total_days / max_days) * 100, 2)

    report_data = {
        "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "report_id": f"WR-{user_id}-{start_date}",
        "start_date": start_date.strftime("%Y-%m-%d"),
        "end_date": end_date.strftime("%Y-%m-%d"),
        "compliance": f"{compliance}% ({total_days}/{max_days} days)",
        "summary": {
            "total_days": total_days,
            "period_days": max_days,
            "glucose_reading_counts": {
                field: sum(getattr(r, field) is not None for r in records)
                for field in ("morning_glucose", "evening_glucose")
            },
            "compliance": compliance,
            "trend": trend
        },
        "clinical_metrics": [
            {
                "parameter": "Morning Glucose",
                "average_value": f"{avg_morning} mg/dL" if avg_morning is not None else "No data",
                "target_range": "80-130",
                "status": "No data" if avg_morning is None else "Optimal" if 80 <= avg_morning <= 130 else "High" if avg_morning > 130 else "Low"
            },
            {
                "parameter": "Evening Glucose",
                "average_value": f"{avg_evening} mg/dL" if avg_evening is not None else "No data",
                "target_range": "<180",
                "status": "No data" if avg_evening is None else "Optimal" if avg_evening <= 180 else "High"
            }
        ],
        "lifestyle_metrics": [
            {
                "factor": "Exercise",
                "weekly_average": f"{avg_exercise} min/day" if avg_exercise is not None else "No data",
                "recommendation": ">=30",
                "assessment": "No data" if avg_exercise is None else "Excellent" if avg_exercise is not None and avg_exercise >= 30 else "Low"
            },
            {
                "factor": "Sleep",
                "weekly_average": f"{avg_sleep} hrs" if avg_sleep is not None else "No data",
                "recommendation": "7-9",
                "assessment": "No data" if avg_sleep is None else "Optimal" if avg_sleep is not None and 7 <= avg_sleep <= 9 else "Low"
            },
            {
                "factor": "Hydration",
                "weekly_average": f"{avg_water} glasses" if avg_water is not None else "No data",
                "recommendation": ">=8",
                "assessment": "No data" if avg_water is None else "Adequate" if avg_water is not None and avg_water >= 8 else "Low"
            }
        ],
        "daily_logs": daily_logs,
        "best_day": {
            "date": best_day.tracker_date.strftime("%A, %b %d") if best_day else "N/A",
            "avg_glucose": round(best_avg, 1) if best_day else 0
        } if best_day else None,
        "worst_day": {
            "date": worst_day.tracker_date.strftime("%A, %b %d") if worst_day else "N/A",
            "avg_glucose": round(worst_avg, 1) if worst_day else 0
        } if worst_day else None,
        "achievements": [
            "[+] Excellent exercise routine!" if avg_exercise is not None and avg_exercise >= 30 else "[-] Increase physical activity" if avg_exercise is not None else "No exercise data recorded",
            "[+] Great hydration!" if avg_water is not None and avg_water >= 8 else "[-] Drink more water" if avg_water is not None else "No hydration data recorded",
            "[+] Healthy sleep pattern!" if avg_sleep is not None and 7 <= avg_sleep <= 9 else "[-] Improve sleep schedule" if avg_sleep is not None else "No sleep data recorded"
        ],
        "recommendations": "Continue monitoring and maintaining healthy habits."
    }

    return report_data


@router.post("/generate")
async def generate_weekly_report(
        start_date: date,
        end_date: date,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """Generate weekly report without AI analysis"""
    user_id = current_user.user_id

    days_diff = (end_date - start_date).days
    if days_diff > 6:
        raise HTTPException(status_code=400, detail="Max 7 days allowed")
    if days_diff < 0:
        raise HTTPException(status_code=400, detail="End date must be after start date")

    result = await db.execute(
        select(DailyTracker).where(
            DailyTracker.user_id == user_id,
            DailyTracker.tracker_date >= start_date,
            DailyTracker.tracker_date <= end_date
        ).order_by(DailyTracker.tracker_date)
    )
    records = result.scalars().all()

    if not records:
        raise HTTPException(status_code=404, detail="No data found")

    report_data = _calculate_report_data(records, user_id, start_date, end_date)

    # Save to database and create notifications (same as before)
    # ... (your existing save logic)

    return report_data


from app.services.openai_service import openai_service


@router.post("/generate-with-ai")
async def generate_weekly_report_with_ai(
        start_date: date,
        end_date: date,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """Generate weekly report with ChatGPT AI analysis"""
    user_id = current_user.user_id

    days_diff = (end_date - start_date).days
    if days_diff > 6:
        raise HTTPException(status_code=400, detail="Max 7 days allowed")
    if days_diff < 0:
        raise HTTPException(status_code=400, detail="End date must be after start date")

    # Fetch current week data
    result = await db.execute(
        select(DailyTracker).where(
            DailyTracker.user_id == user_id,
            DailyTracker.tracker_date >= start_date,
            DailyTracker.tracker_date <= end_date
        ).order_by(DailyTracker.tracker_date)
    )
    records = result.scalars().all()

    if not records:
        raise HTTPException(status_code=404, detail="No data found")

    # Calculate base report for current week
    report_data = _calculate_report_data(records, user_id, start_date, end_date)

    # Try to fetch previous week data for comparison
    prev_start = start_date - timedelta(days=days_diff + 1)
    prev_end = start_date - timedelta(days=1)

    prev_result = await db.execute(
        select(DailyTracker).where(
            DailyTracker.user_id == user_id,
            DailyTracker.tracker_date >= prev_start,
            DailyTracker.tracker_date <= prev_end
        ).order_by(DailyTracker.tracker_date)
    )
    prev_records = prev_result.scalars().all()

    previous_week_data = None
    if prev_records:
        previous_week_data = _calculate_report_data(prev_records, user_id, prev_start, prev_end)

    # Enhance with AI analysis (pass previous week data if available)
    enhanced_report = await openai_service.generate_health_insights(
        report_data,
        previous_week_data
    )

    # Save to database and create notification
    # ... (existing save logic)

    await create_notification(
        db,
        user_id,
        "🤖 AI-Enhanced Report Ready!",
        f"Your weekly report with ChatGPT analysis for {start_date} to {end_date} is ready!",
        "success"
    )

    return enhanced_report