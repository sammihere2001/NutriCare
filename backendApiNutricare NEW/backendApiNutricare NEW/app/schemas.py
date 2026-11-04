from app.treatment_schemas import TreatmentProfile
from pydantic import BaseModel, EmailStr, validator, Field, field_validator
from typing import Optional, List
from datetime import datetime, date, time
from enum import Enum


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    first_name: Optional[str] = None
    last_name: Optional[str] = None


class UserResponse(BaseModel):
    user_id: int
    email: EmailStr
    first_name: Optional[str] = None
    last_name: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    refresh_token: Optional[str] = None
    expires_at: Optional[datetime] = None
    user: Optional[UserResponse] = None


class RefreshRequest(BaseModel):
    refresh_token: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

    @validator('new_password')
    def validate_password_length(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        return v


class ResetPasswordResponse(BaseModel):
    message: str
    success: bool


class PasswordResetTokenResponse(BaseModel):
    message: str
    token_sent: bool


class BloodSugarReading(BaseModel):
    reading_value: float
    reading_unit: str
    notes: Optional[str]


class DiabetesStatusEnum(str, Enum):
    none = "none"
    type1 = "type1"
    type2 = "type2"
    prediabetes = "prediabetes"
    gestational = "gestational"


class ActivityLevelEnum(str, Enum):
    sedentary = "sedentary"
    lightly_active = "lightly_active"
    moderately_active = "moderately_active"
    very_active = "very_active"
    extremely_active = "extremely_active"


class UserProfileRequest(BaseModel):
    treatment: Optional[TreatmentProfile] = None
    user_id: int
    age: int = Field(..., ge=1, le=120)
    gender: str = Field(..., pattern="^(male|female|other)$")
    weight_kg: float = Field(..., ge=10, le=500)
    height_cm: float = Field(..., ge=50, le=300)
    diabetes_status: DiabetesStatusEnum
    insulin_usage: bool
    insulin_morning_units: Optional[float] = Field(None, ge=0, le=100)
    insulin_night_units: Optional[float] = Field(None, ge=0, le=100)
    activity_level: ActivityLevelEnum
    health_goals: List[int] = []
    dietary_preferences: List[int] = []
    blood_sugar: Optional[BloodSugarReading]


class UserProfileUpdateRequest(BaseModel):
    treatment: Optional[TreatmentProfile] = None
    user_id: int
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    age: Optional[int] = Field(None, ge=1, le=120)
    gender: Optional[str] = Field(None, pattern="^(male|female|other)$")
    weight_kg: Optional[float] = Field(None, ge=10, le=500)
    height_cm: Optional[float] = Field(None, ge=50, le=300)
    diabetes_status: Optional[DiabetesStatusEnum] = None
    insulin_usage: Optional[bool] = None
    insulin_morning_units: Optional[float] = Field(None, ge=0, le=100)
    insulin_night_units: Optional[float] = Field(None, ge=0, le=100)
    blood_glucose: Optional[float] = Field(None, ge=20, le=600)
    blood_sugar: Optional[BloodSugarReading] = None

    @validator("diabetes_status", pre=True)
    def normalize_diabetes_status(cls, v):
        if isinstance(v, str):
            return v.lower()
        return v


class UserProfileResponse(BaseModel):
    message: str
    profile_completed: bool = True


class MealEntry(BaseModel):
    meal_name: str = Field(..., min_length=1, max_length=100)
    calories: float = Field(..., ge=0, le=2000)
    meal_time: time
    meal_type: str = Field("Breakfast", pattern="^(Breakfast|Lunch|Dinner|Snack)$")

    @validator("calories")
    def validate_calories(cls, v):
        if v < 0:
            raise ValueError("Calories must be positive")
        if v > 2000:
            raise ValueError("Calories per meal cannot exceed 2000")
        return v

    @validator("meal_name")
    def validate_meal_name(cls, v):
        if not v or not v.strip():
            raise ValueError("Meal name cannot be empty")
        return v.strip()


class DailyTrackerCreate(BaseModel):
    tracker_date: date
    morning_glucose: Optional[float] = Field(None, ge=20, le=600)
    evening_glucose: Optional[float] = Field(None, ge=20, le=600)
    weight: Optional[float] = Field(None, ge=10, le=300)
    exercise: Optional[float] = Field(None, ge=0, le=300)
    water_intake: Optional[float] = Field(None, ge=0, le=25)
    sleep_hours: Optional[float] = Field(None, ge=0, le=24)
    stress_level: Optional[int] = Field(None, ge=1, le=100)
    notes: Optional[str] = Field(None, max_length=500)
    meals: List[MealEntry] = Field(default_factory=list, max_length=10)
    is_update: bool = False
    exercise_time: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")

    @field_validator('morning_glucose', 'evening_glucose')
    @classmethod
    def validate_glucose(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if v < 20:
                raise ValueError('Glucose value cannot be below 20 mg/dL')
            if v > 600:
                raise ValueError('Glucose value cannot exceed 600 mg/dL')
        return v

    @field_validator('weight')
    @classmethod
    def validate_weight(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if v < 10:
                raise ValueError('Weight cannot be below 10 kg')
            if v > 300:
                raise ValueError('Weight cannot exceed 300 kg')
        return v

    @field_validator('stress_level')
    @classmethod
    def validate_stress(cls, v: Optional[int]) -> Optional[int]:
        if v is not None:
            if v < 1:
                raise ValueError('Stress level cannot be below 1')
            if v > 100:
                raise ValueError('Stress level cannot exceed 100')
        return v

    @field_validator('sleep_hours')
    @classmethod
    def validate_sleep(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if v < 0:
                raise ValueError('Sleep hours cannot be negative')
            if v > 24:
                raise ValueError('Sleep hours cannot exceed 24')
        return v

    @field_validator('exercise')
    @classmethod
    def validate_exercise(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if v < 0:
                raise ValueError('Exercise minutes cannot be negative')
            if v > 300:
                raise ValueError('Exercise minutes cannot exceed 300')
        return v

    @field_validator('water_intake')
    @classmethod
    def validate_water(cls, v: Optional[float]) -> Optional[float]:
        if v is not None:
            if v < 0:
                raise ValueError('Water intake cannot be negative')
            if v > 25:
                raise ValueError('Water intake cannot exceed 25 glasses')
        return v


class GlucoseQuickLogSchema(BaseModel):
    tracker_date: date
    glucose_type: str = Field(..., pattern="^(morning|evening)$")
    glucose_value: float = Field(..., ge=20, le=600)


class DailyTrackerRead(BaseModel):
    tracker_id: int
    user_id: int
    tracker_date: date
    morning_glucose: float
    evening_glucose: float
    weight: float
    exercise: float
    water_intake: float
    sleep_hours: float
    stress_level: float
    notes: Optional[str]
    meals: List[MealEntry]

    class Config:
        from_attributes = True


class WeeklyReportCreate(BaseModel):
    avg_morning_glucose: float
    avg_evening_glucose: float
    avg_exercise: float
    avg_sleep: float
    avg_water: float
    avg_stress: float
    avg_weight: float
    compliance_percentage: float
    total_days_recorded: int
    weekly_trend: str
    week_start: date
    week_end: date


class WeeklyReportResponse(BaseModel):
    report_id: int
    message: str

    class Config:
        from_attributes = True

class MealResponse(BaseModel):
    meal_id: int
    name: str
    serving: str
    mealType: str
    giLevel: str
    giColor: str
    calories: str
    protein: str
    carbs: str
    fat: str
    fiber: str
    glycemic_index: Optional[int] = None
    ingredients: List[str] = []
    tags: List[str] = []
    source: Optional[str] = None

class MealListResponse(BaseModel):
    meals: List[MealResponse]
    total: int
    page: int
    page_size: int
    has_more: bool