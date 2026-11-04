from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field
from diet_recommender import DietRecommender
import uvicorn
import os
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict, Any
from medication_context import TreatmentContext, NutritionTargets, PlanRequestError

# Initialize App
app = FastAPI(
    title="Diet Plan AI API",
    description="API to generate personalized diet plans using ML",
    version="1.0.0"
)

# Add CORS Middleware to handle cross-origin requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins (change to specific domains for production)
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods (GET, POST, OPTIONS, etc.)
    allow_headers=["*"],  # Allow all headers
)

# Load Model
try:
    recommender = DietRecommender()
    print("OK Model loaded successfully API")
except Exception as e:
    print(f"[ERROR] Error loading model: {e}")
    recommender = None


# --- Data Models (Input Validation) ---

class UserProfile(BaseModel):
    treatment: TreatmentContext = Field(default_factory=TreatmentContext)
    nutrition_targets: NutritionTargets = Field(default_factory=NutritionTargets)
    diabetes_status: str = "none"
    age: int = Field(..., ge=18, le=100, description="Age of the user")
    gender: str = Field(..., pattern="^(male|female)$", description="Gender: male or female")
    weight_kg: float = Field(..., ge=30, le=300, description="Weight in KG")
    height_cm: float = Field(..., ge=100, le=250, description="Height in CM")
    activity_level: str = Field(...,
                                description="sedentary, lightly_active, moderately_active, very_active, extremely_active")
    goals: list = Field(..., description="List of health goals")
    dietary_preferences: list = Field(..., description="List of dietary preferences")
    has_diabetes: bool = Field(False, description="True if user has diabetes")
    uses_insulin: bool = Field(False, description="True if user uses insulin")
    insulin_morning_units: float = Field(0.0, ge=0, le=100, description="Morning insulin units")
    insulin_night_units: float = Field(0.0, ge=0, le=100, description="Night insulin units")
    blood_sugar_level: int = Field(100, ge=20, le=600, description="Blood sugar level in mg/dL")


# --- Response Models ---

class MealFood(BaseModel):
    name: str
    calories: float
    protein: float
    carbs: float
    fat: float


class Meal(BaseModel):
    meal_type: str
    time: str
    food: MealFood


class DailyTotals(BaseModel):
    calories: float
    protein: float
    carbs: float
    fat: float


class DayPlan(BaseModel):
    day: int
    date: str
    meals: List[Meal]
    daily_totals: DailyTotals


class HealthMetrics(BaseModel):
    bmi: float
    bmi_status: str
    bmr: float
    tdee: float
    target_calories: float


class HealthConditions(BaseModel):
    has_diabetes: bool
    uses_insulin: bool
    insulin_morning: float
    insulin_night: float
    blood_sugar_level: int


class DietPlanResponse(BaseModel):
    status: str
    health_analysis: Dict[str, Any]
    health_conditions: Dict[str, Any]
    recommended_plan_type: str
    weekly_plan: List[Dict[str, Any]]


# --- Helper Functions ---

def get_bmi_status(bmi: float) -> str:
    """Determine BMI status category"""
    if bmi < 18.5:
        return "Underweight"
    elif 18.5 <= bmi < 25:
        return "Normal"
    elif 25 <= bmi < 30:
        return "Overweight"
    else:
        return "Obese"

def calculate_daily_nutrition_totals(weekly_plan: list) -> dict:
    """Calculate average daily nutrition totals across the week"""
    total_calories = 0
    total_protein = 0
    total_carbs = 0
    total_fat = 0
    num_days = len(weekly_plan)

    for day in weekly_plan:
        daily = day.get("daily_totals", {})
        total_calories += daily.get("calories", 0)
        total_protein += daily.get("protein", 0)
        total_carbs += daily.get("carbs", 0)
        total_fat += daily.get("fat", 0)

    return {
        "avg_daily_calories": round(total_calories / num_days, 1) if num_days > 0 else 0,
        "avg_daily_protein": round(total_protein / num_days, 1) if num_days > 0 else 0,
        "avg_daily_carbs": round(total_carbs / num_days, 1) if num_days > 0 else 0,
        "avg_daily_fat": round(total_fat / num_days, 1) if num_days > 0 else 0,
    }


# --- Endpoints ---

@app.get("/")
def home():
    """Health Check Endpoint"""
    return {
        "status": "online",
        "message": "Diet Plan AI API is running! 🚀",
        "docs_url": "/docs"
    }


@app.post("/generate-plan")
def generate_diet_plan(user: UserProfile, days: int = Query(7, ge=1, le=14)):
    """
    Generate a 7-day personalized diet plan.
    Returns health analysis, conditions, and weekly meal plan.
    """
    if not recommender:
        raise HTTPException(status_code=500, detail="Model not loaded. Check server logs.")

    try:
        # Convert Pydantic model to dict
        user_dict = user.model_dump()

        # Generate plan
        plan = recommender.generate_meal_plan(user_dict, num_days=days)

        # Extract health metrics
        health_metrics = plan.get("health_metrics", {})
        bmi = health_metrics.get("bmi", 0)

        # Calculate average daily nutrition from meal plans
        weekly_plan = plan.get("weekly_plan", [])
        avg_nutrition = calculate_daily_nutrition_totals(weekly_plan)

        # Format the response for frontend
        response = {
            "status": "success",
            "planning_context": plan.get("planning_context", {}),
            "health_analysis": {
                "bmi": round(bmi, 2),
                "bmi_status": get_bmi_status(bmi),
                "bmr": round(health_metrics.get("bmr", 0), 2),
                "tdee": round(health_metrics.get("tdee", 0), 2),
                "target_calories": round(health_metrics.get("target_calories", 0), 2),
                **avg_nutrition  # Include average nutrition data
            },
            "health_conditions": plan.get("health_conditions", {}),
            "recommended_plan_type": plan.get("recommended_plan_type", ""),
            "meal_category": plan.get("meal_category", ""),
            "weekly_plan": weekly_plan
        }

        return response

    except PlanRequestError as e:
        raise HTTPException(status_code=422, detail={"code": e.code, "message": str(e)}) from None
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/generate-plan-detailed")
def generate_diet_plan_detailed(user: UserProfile, days: int = Query(7, ge=1, le=14)):
    """
    Generate a 7-day personalized diet plan with detailed nutritional breakdown.
    This endpoint provides extra detail including pie chart data for each day.
    """
    if not recommender:
        raise HTTPException(status_code=500, detail="Model not loaded. Check server logs.")

    try:
        user_dict = user.model_dump()
        plan = recommender.generate_meal_plan(user_dict, num_days=days)

        health_metrics = plan.get("health_metrics", {})
        bmi = health_metrics.get("bmi", 0)

        weekly_plan = plan.get("weekly_plan", [])
        avg_nutrition = calculate_daily_nutrition_totals(weekly_plan)

        # Add pie chart data for each day
        enhanced_weekly_plan = []
        for day in weekly_plan:
            daily_totals = day.get("daily_totals", {})
            enhanced_day = {
                **day,
                "nutrition_pie_chart": {
                    "labels": ["Protein", "Carbohydrates", "Fat"],
                    "values": [
                        daily_totals.get("protein", 0),
                        daily_totals.get("carbs", 0),
                        daily_totals.get("fat", 0)
                    ],
                    "hole": 0.3  # For donut chart
                }
            }
            enhanced_weekly_plan.append(enhanced_day)

        response = {
            "status": "success",
            "planning_context": plan.get("planning_context", {}),
            "health_analysis": {
                "bmi": round(bmi, 2),
                "bmi_status": get_bmi_status(bmi),
                "bmr": round(health_metrics.get("bmr", 0), 2),
                "tdee": round(health_metrics.get("tdee", 0), 2),
                "target_calories": round(health_metrics.get("target_calories", 0), 2),
                **avg_nutrition
            },
            "health_conditions": plan.get("health_conditions", {}),
            "recommended_plan_type": plan.get("recommended_plan_type", ""),
            "meal_category": plan.get("meal_category", ""),
            "weekly_plan": enhanced_weekly_plan
        }

        return response

    except PlanRequestError as e:
        raise HTTPException(status_code=422, detail={"code": e.code, "message": str(e)}) from None
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/retrain")
def retrain_model():
    """
    Retrain the AI model from the latest CSV dataset.
    This reloads data, retrains, and hot-reloads the model.
    """
    if os.getenv("ALLOW_BASELINE_RETRAIN", "false").lower() != "true":
        raise HTTPException(status_code=403, detail="Online retraining is disabled. Train and evaluate artifacts offline before replacing the baseline.")
    global recommender

    try:
        print("\n" + "=" * 60)
        print("[RETRAIN] Starting model retraining...")
        print("=" * 60)

        from train_model import train_from_dataset
        from pathlib import Path
        service_dir = Path(__file__).resolve().parent
        train_from_dataset(str(service_dir / 'final_pakistani_diabetic_meal_plans.csv'),
                           str(service_dir / 'models'))
        recommender = DietRecommender()

        print("\n[SUCCESS] Model retrained and reloaded successfully!")
        print("=" * 60)

        return {
            "status": "success",
            "message": "Model retrained successfully",
            "dataset_mtime": recommender.dataset_mtime,
            "reference_records": len(recommender.reference_data)
        }

    except Exception as e:
        print(f"[ERROR] Retraining failed: {e}")
        raise HTTPException(status_code=500, detail=f"Retraining failed: {str(e)}")


@app.get("/model-status")
def model_status():
    """
    Check current model status - when it was last trained, how many records, etc.
    """
    if not recommender:
        return {"status": "not_loaded"}

    try:
        metadata = recommender._read_model_metadata()
        return {
            "status": "loaded",
            "reference_records": len(recommender.reference_data),
            "dataset_mtime": recommender.dataset_mtime,
            "trained_at": metadata.get("trained_at", "unknown"),
            "accuracy": metadata.get("accuracy", "unknown"),
            "dataset_path": metadata.get("dataset_path", "unknown")
        }
    except Exception as e:
        return {"status": "loaded", "error": str(e)}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8002)
