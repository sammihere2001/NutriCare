from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, Boolean, TIMESTAMP, func, ForeignKey, DateTime, Enum, Numeric, \
    BigInteger, Date, Time
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
import uuid
from app.schemas import ActivityLevelEnum, DiabetesStatusEnum
from app.database import Base
from sqlalchemy import Column, Integer, String, Text, Boolean, TIMESTAMP, func, ForeignKey, DateTime, Enum, Numeric, BigInteger, Date, Time, UniqueConstraint
from typing import Optional
from pydantic import validator


class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, index=True)
    first_name = Column(Text)
    last_name = Column(Text)
    email = Column(Text, unique=True, nullable=False, index=True)
    password_hash = Column(Text, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

    refresh_tokens = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")
    password_reset_tokens = relationship("PasswordResetToken", back_populates="user", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    daily_trackers = relationship("DailyTracker", back_populates="user", cascade="all, delete-orphan")
    user_profile = relationship("UserProfile", back_populates="user", uselist=False, cascade="all, delete-orphan")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    token_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    token_hash = Column(Text, nullable=False)
    issued_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    expires_at = Column(TIMESTAMP(timezone=True), nullable=False)
    revoked = Column(Boolean, default=False)
    revoked_at = Column(TIMESTAMP(timezone=True), nullable=True)

    user = relationship("User", back_populates="refresh_tokens")


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    token_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    token_hash = Column(Text, nullable=False)
    issued_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    expires_at = Column(TIMESTAMP(timezone=True), nullable=False)
    used = Column(Boolean, default=False)

    user = relationship("User", back_populates="password_reset_tokens")


class UserProfile(Base):
    __tablename__ = "user_profiles"

    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), primary_key=True)
    age = Column(Integer)
    gender = Column(Text)
    weight_kg = Column(Numeric)
    height_cm = Column(Numeric)
    bmi = Column(Numeric)
    activity_level = Column(Enum(ActivityLevelEnum, name="activity_level_enum"), nullable=False)
    diabetes_status = Column(Enum(DiabetesStatusEnum, name="diabetes_status_enum"), nullable=False)
    insulin_usage = Column(Boolean, default=False)
    insulin_morning_units = Column(Numeric, nullable=True)
    insulin_night_units = Column(Numeric, nullable=True)
    profile_picture = Column(Text, nullable=True)
    profile_completed = Column(Boolean, default=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="user_profile")
    blood_sugar_readings = relationship("SugarReading", back_populates="user_profile", cascade="all, delete-orphan")
    health_goals = relationship("UserHealthGoals", back_populates="user_profile", cascade="all, delete-orphan")
    dietary_preferences = relationship("UserDietPreferences", back_populates="user_profile", cascade="all, delete-orphan")


class HealthGoal(Base):
    __tablename__ = "health_goals"
    goal_id = Column(Integer, primary_key=True)
    goal_name = Column(String, nullable=False)


class UserHealthGoals(Base):
    __tablename__ = "user_health_goals"
    user_id = Column(Integer, ForeignKey("user_profiles.user_id", ondelete="CASCADE"), primary_key=True)
    goal_id = Column(Integer, ForeignKey("health_goals.goal_id", ondelete="CASCADE"), primary_key=True)

    user_profile = relationship("UserProfile", back_populates="health_goals")
    health_goal = relationship("HealthGoal")


class DietPreference(Base):
    __tablename__ = "dietary_preferences"
    diet_id = Column(Integer, primary_key=True)
    diet_name = Column(String, nullable=False)


class UserDietPreferences(Base):
    __tablename__ = "user_diet_preferences"
    user_id = Column(Integer, ForeignKey("user_profiles.user_id", ondelete="CASCADE"), primary_key=True)
    diet_id = Column(Integer, ForeignKey("dietary_preferences.diet_id", ondelete="CASCADE"), primary_key=True)

    user_profile = relationship("UserProfile", back_populates="dietary_preferences")
    diet_preference = relationship("DietPreference")


class SugarReading(Base):
    __tablename__ = "sugar_readings"

    reading_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("user_profiles.user_id", ondelete="CASCADE"), nullable=False)
    reading_value = Column(Numeric, nullable=False)
    reading_unit = Column(Text, nullable=False)
    notes = Column(Text, nullable=True)
    reading_time = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    user_profile = relationship("UserProfile", back_populates="blood_sugar_readings")


class DailyTracker(Base):
    __tablename__ = "daily_tracker"
    __table_args__ = (UniqueConstraint("user_id", "tracker_date", name="uq_daily_tracker_user_date"),)

    tracker_id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    tracker_date = Column(Date, nullable=False)

    morning_glucose = Column(Numeric)
    evening_glucose = Column(Numeric)
    weight = Column(Numeric)
    exercise = Column(Numeric)
    exercise_time = Column(String(10))
    water_intake = Column(Numeric)
    sleep_hours = Column(Numeric)
    stress_level = Column(Numeric)
    notes = Column(Text)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="daily_trackers")
    meals = relationship("DailyTrackerMeals", back_populates="tracker", cascade="all, delete-orphan")


class UserMedication(Base):
    __tablename__ = "user_medications"

    medication_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, index=True)
    medication_class = Column(String(40), nullable=False)
    name = Column(String(100), nullable=False, default="")
    prescribed_dose = Column(String(100), nullable=False, default="")
    schedule = Column(String(150), nullable=False, default="")
    started_on = Column(Date, nullable=True)
    position = Column(Integer, nullable=False, default=0)


class UserTreatmentContext(Base):
    __tablename__ = "user_treatment_context"

    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), primary_key=True)
    medications_confirmed = Column(Boolean, nullable=False, default=False)
    appetite = Column(String(20), nullable=False, default="unknown")
    symptoms = Column(JSONB, nullable=False, default=list)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class DailyTrackerMeals(Base):
    __tablename__ = "daily_tracker_meals"

    meal_entry_id = Column(BigInteger, primary_key=True, index=True)
    tracker_id = Column(BigInteger, ForeignKey("daily_tracker.tracker_id", ondelete="CASCADE"), nullable=False)
    meal_name = Column(Text, nullable=False)
    calories = Column(Numeric)
    meal_time = Column(Time, nullable=False)
    meal_type = Column(String(50), default="Breakfast")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    tracker = relationship("DailyTracker", back_populates="meals")


class WeeklyReport(Base):
    __tablename__ = "weekly_reports"

    report_id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    week_start = Column(Date, nullable=False)
    week_end = Column(Date, nullable=False)
    report_generated_at = Column(DateTime(timezone=True), server_default=func.now())
    avg_morning_glucose = Column(Numeric)
    avg_evening_glucose = Column(Numeric)
    avg_exercise = Column(Numeric)
    avg_sleep = Column(Numeric)
    avg_water = Column(Numeric)
    avg_stress = Column(Numeric)
    avg_weight = Column(Numeric)
    total_calories = Column(Numeric)
    avg_daily_calories = Column(Numeric)
    compliance_percentage = Column(Numeric)
    total_days_recorded = Column(Integer)
    weekly_trend = Column(Text)


class Notification(Base):
    __tablename__ = "notifications"

    notification_id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    title = Column(Text, nullable=False)
    message = Column(Text, nullable=False)
    notification_type = Column(Text)
    is_read = Column(Boolean, default=False)
    sent_at = Column(DateTime(timezone=True), server_default=func.now())
    read_at = Column(DateTime(timezone=True), nullable=True)
    extra_data = Column(JSONB, nullable=True)

    user = relationship("User", back_populates="notifications")


class UserDeviceToken(Base):
    __tablename__ = "user_device_tokens"

    token_id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    device_token = Column(Text, nullable=False)
    platform = Column(Text)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

# ============================================
# MEAL DATABASE MODELS
# ============================================

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

    # Relationships
    meal_ingredients = relationship("MealIngredient", back_populates="meal", cascade="all, delete-orphan")
    meal_tags = relationship("MealTag", back_populates="meal", cascade="all, delete-orphan")


class Ingredient(Base):
    __tablename__ = "ingredients"

    ingredient_id = Column(Integer, primary_key=True, index=True)
    name = Column(Text, nullable=False, unique=True)

    # Relationships
    meal_ingredients = relationship("MealIngredient", back_populates="ingredient", cascade="all, delete-orphan")


class MealIngredient(Base):
    __tablename__ = "meal_ingredients"

    meal_id = Column(Integer, ForeignKey("meals.meal_id", ondelete="CASCADE"), primary_key=True)
    ingredient_id = Column(Integer, ForeignKey("ingredients.ingredient_id", ondelete="CASCADE"), primary_key=True)
    amount_desc = Column(Text)

    # Relationships
    meal = relationship("Meal", back_populates="meal_ingredients")
    ingredient = relationship("Ingredient", back_populates="meal_ingredients")


class Tag(Base):
    __tablename__ = "tags"

    tag_id = Column(Integer, primary_key=True, index=True)
    tag_name = Column(Text, nullable=False, unique=True)

    # Relationships
    meal_tags = relationship("MealTag", back_populates="tag", cascade="all, delete-orphan")


class MealTag(Base):
    __tablename__ = "meal_tags"

    meal_id = Column(Integer, ForeignKey("meals.meal_id", ondelete="CASCADE"), primary_key=True)
    tag_id = Column(Integer, ForeignKey("tags.tag_id", ondelete="CASCADE"), primary_key=True)

    # Relationships
    meal = relationship("Meal", back_populates="meal_tags")
    tag = relationship("Tag", back_populates="meal_tags")


class DietPlan(Base):
    __tablename__ = "diet_plans"

    plan_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    plan_name = Column(Text, nullable=False)
    start_date = Column(Date)
    end_date = Column(Date)
    notes = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class PlanMeal(Base):
    __tablename__ = "plan_meals"

    plan_id = Column(Integer, ForeignKey("diet_plans.plan_id", ondelete="CASCADE"), primary_key=True)
    meal_id = Column(Integer, ForeignKey("meals.meal_id", ondelete="CASCADE"), primary_key=True)
    day_index = Column(Integer, primary_key=True)
    meal_time = Column(Text)


class AiGeneratedMeal(Base):
    __tablename__ = "ai_generated_meals"

    ai_meal_id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    meal_id = Column(Integer, ForeignKey("meals.meal_id", ondelete="CASCADE"), nullable=False)
    generated_for_week = Column(Date)
    model_version = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class WeeklyHealthProgress(Base):
    __tablename__ = "weekly_health_progress"

    progress_id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    week_start = Column(Date, nullable=False)
    avg_sugar = Column(Numeric)
    avg_calories = Column(Numeric)
    weight_kg = Column(Numeric)
    bmi = Column(Numeric)
    notes = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

