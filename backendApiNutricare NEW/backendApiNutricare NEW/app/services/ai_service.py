# app/services/ai_service.py
import httpx
from typing import Dict, Any
from fastapi import HTTPException
import logging
from app.config import settings
from app.treatment_schemas import TreatmentProfile

logger = logging.getLogger(__name__)


class AIService:
    def __init__(self, ai_api_url: str | None = None):
        self.ai_api_url = (ai_api_url or settings.AI_API_URL).rstrip("/")
        self.timeout = float(settings.AI_API_TIMEOUT)  # Increased timeout for AI processing

    async def retrain_model(self) -> Dict[str, Any]:
        """
        Call the AI model API to retrain from latest CSV data.
        """
        async with httpx.AsyncClient(timeout=120.0) as client:  # Longer timeout for training
            try:
                logger.info(f"Requesting AI model retrain at {self.ai_api_url}/retrain")

                response = await client.post(
                    f"{self.ai_api_url}/retrain",
                )
                response.raise_for_status()
                result = response.json()

                if result.get("status") == "success":
                    logger.info(f"Model retrained successfully. Records: {result.get('reference_records')}")
                    return result
                else:
                    raise HTTPException(
                        status_code=500,
                        detail=f"AI retrain error: {result.get('detail', 'Unknown error')}"
                    )

            except httpx.TimeoutException:
                logger.error("AI retrain timeout")
                raise HTTPException(status_code=504, detail="AI retrain timeout - try again later")
            except httpx.ConnectError:
                logger.error(f"Cannot connect to AI API at {self.ai_api_url}")
                raise HTTPException(status_code=503, detail="AI service not running")
            except HTTPException:
                raise
            except Exception as e:
                logger.error(f"Retrain error: {e}")
                raise HTTPException(status_code=500, detail=f"Retrain failed: {str(e)}")

    async def retrain_and_generate(self, user_profile: Dict[str, Any], days: int = 7) -> Dict[str, Any]:
        """
        Step 1: Retrain the AI model
        Step 2: Generate fresh diet plan for the user
        """
        # Step 1: Retrain
        logger.info("Step 1/2: Retraining AI model...")
        retrain_result = await self.retrain_model()
        logger.info(f"Retrain complete: {retrain_result.get('message')}")

        # Step 2: Generate plan
        logger.info("Step 2/2: Generating fresh diet plan...")
        return await self.generate_diet_plan(user_profile, days=days)

    async def generate_diet_plan(self, user_profile: Dict[str, Any], days: int = 7) -> Dict[str, Any]:
        """
        Call the AI model API to generate a personalized diet plan
        """
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                # Transform user profile to match AI API expectations
                ai_payload = self._prepare_ai_payload(user_profile)

                logger.info(f"Sending request to AI API at {self.ai_api_url}/generate-plan")


                response = await client.post(
                    f"{self.ai_api_url}/generate-plan",
                    json=ai_payload,
                    params={"days": days}
                )
                response.raise_for_status()
                result = response.json()

                if result.get("status") == "success":
                    # Return the complete response with health_analysis, health_conditions, etc.
                    return {
                        "planning_context": result.get("planning_context", {}),
                        "health_analysis": result.get("health_analysis", {}),
                        "health_conditions": result.get("health_conditions", {}),
                        "recommended_plan_type": result.get("recommended_plan_type", ""),
                        "meal_category": result.get("meal_category", ""),
                        "weekly_plan": result.get("weekly_plan", [])
                    }
                else:
                    raise HTTPException(
                        status_code=500,
                        detail=f"AI model error: {result.get('detail', 'Unknown error')}"
                    )

            except httpx.TimeoutException:
                logger.error("AI API timeout")
                raise HTTPException(status_code=504, detail="AI service timeout - please try again")
            except httpx.ConnectError:
                logger.error(f"Cannot connect to AI API at {self.ai_api_url}")
                raise HTTPException(status_code=503,
                                    detail="AI service is not running. Please start the AI model server.")
            except httpx.HTTPStatusError as error:
                if error.response.status_code == 422:
                    detail = error.response.json().get('detail', 'The profile cannot be used for meal planning')
                    if isinstance(detail, list):
                        detail = {'code': 'invalid_planning_profile',
                                  'message': '; '.join(str(item.get('msg', 'Invalid field')) for item in detail)}
                    raise HTTPException(status_code=422, detail=detail) from None
                raise HTTPException(status_code=503, detail="The meal-planning service could not complete the request") from None
            except httpx.RequestError as e:
                logger.error(f"AI API request error: {e}")
                raise HTTPException(status_code=503, detail=f"AI service unavailable: {str(e)}")
            except HTTPException:
                raise
            except Exception as e:
                logger.error(f"Unexpected error calling AI API: {e}")
                raise HTTPException(status_code=500, detail=f"Failed to generate diet plan: {str(e)}")

    def _prepare_ai_payload(self, user_profile: Dict[str, Any]) -> Dict[str, Any]:
        """
        Transform backend user profile to AI API format
        """
        # Extract health goals as strings (not IDs)
        # These mappings should match your database seed data
        health_goals_map = {
            1: "weight_loss",
            2: "blood_sugar_control",
            3: "muscle_gain",
            4: "maintain_weight",
            5: "improve_energy",
            6: "better_sleep",
            7: "general_health",
            8: "heart_health",
            9: "weight_gain"
        }

        # Extract dietary preferences as strings
        diet_prefs_map = {
            1: "vegetarian",
            2: "vegan",
            3: "keto",
            4: "paleo",
            5: "gluten_free",
            6: "dairy_free",
            7: "low_carb",
            8: "mediterranean",
            9: "balanced",
            10: "halal",
            11: "kosher",
            12: "no_restrictions",
            13: "heart_healthy"
        }

        diabetes_status = user_profile.get("diabetes_status", "type2" if user_profile.get("has_diabetes") else "none")
        if hasattr(diabetes_status, 'value'):
            diabetes_status = diabetes_status.value
        has_diabetes = diabetes_status not in ["none", None, ""]

        def mapped_values(values, mapping, default):
            if not values:
                return [default]
            if not isinstance(values, list):
                raise HTTPException(status_code=422, detail="Goals and preferences must be lists")
            result = []
            for value in values:
                canonical = mapping.get(value) if isinstance(value, int) else str(value).strip().lower().replace('-', '_').replace(' ', '_')
                canonical = {'balanced_diet': 'balanced', 'heart_health': 'heart_healthy'}.get(canonical, canonical) if mapping is diet_prefs_map else canonical
                if canonical not in mapping.values():
                    raise HTTPException(status_code=422, detail="An unknown health goal or dietary preference was selected")
                if canonical not in result:
                    result.append(canonical)
            return result

        goals = mapped_values(user_profile.get("health_goals", user_profile.get("goals", [])), health_goals_map, "general_health")
        dietary_preferences = mapped_values(user_profile.get("dietary_preferences", []), diet_prefs_map, "balanced")
        try:
            treatment = TreatmentProfile.model_validate(user_profile.get("treatment") or {})
        except ValueError:
            raise HTTPException(status_code=422, detail="The recorded treatment profile is invalid") from None
        # Forward classes and symptom context, not medication names or prescription text.
        treatment_payload = {
            "medications_confirmed": treatment.medications_confirmed,
            "medications": [{"medication_class": med.medication_class.value} for med in treatment.medications],
            "appetite": treatment.appetite, "symptoms": treatment.symptoms}

        # Get blood sugar from profile or latest reading
        blood_sugar = user_profile.get("blood_sugar_level", 100)
        try:
            blood_sugar = int(float(blood_sugar))
        except (ValueError, TypeError):
            blood_sugar = 100

        return {
            "treatment": treatment_payload,
            "nutrition_targets": user_profile.get("nutrition_targets") or {},
            "diabetes_status": diabetes_status,
            "age": int(user_profile.get("age", 30)),
            "gender": str(user_profile.get("gender", "male")).lower(),
            "weight_kg": float(user_profile.get("weight_kg", 70)),
            "height_cm": float(user_profile.get("height_cm", 170)),
            "activity_level": str(user_profile.get("activity_level", "moderately_active")).lower(),
            "goals": goals,
            "dietary_preferences": dietary_preferences,
            "has_diabetes": has_diabetes,
            "uses_insulin": bool(user_profile.get("insulin_usage", user_profile.get("uses_insulin", False))),
            "insulin_morning_units": float(user_profile.get("insulin_morning_units", 0.0) or 0.0),
            "insulin_night_units": float(user_profile.get("insulin_night_units", 0.0) or 0.0),
            "blood_sugar_level": blood_sugar
        }


# Singleton instance
ai_service = AIService()