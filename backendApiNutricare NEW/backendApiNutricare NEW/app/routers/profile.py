from app.treatment_schemas import TreatmentProfile
from fastapi.concurrency import run_in_threadpool
from app.services.profile_images import normalize_profile_image, MAX_UPLOAD_BYTES
from datetime import datetime
from fastapi import APIRouter, Depends, UploadFile, File, Form, Header, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from app.database import get_db
from app.crud_profile import create_or_update_profile, get_user_profile
from app.schemas import UserProfileRequest, UserProfileResponse
from app.schemas import UserProfileUpdateRequest
from app.crud_profile import update_profile
from app.models import User, SugarReading
from jose import jwt
from app.config import settings
from app.routers.notifications import create_notification
import cloudinary
import cloudinary.uploader
import os
from urllib.parse import urlparse, unquote
from pydantic import ValidationError

router = APIRouter(prefix="/profile", tags=["Profile"])

if settings.CLOUDINARY_CLOUD_NAME:
    cloudinary.config(cloud_name=settings.CLOUDINARY_CLOUD_NAME,
                      api_key=settings.CLOUDINARY_API_KEY,
                      api_secret=settings.CLOUDINARY_API_SECRET)
elif settings.CLOUDINARY_URL:
    cloud_url = urlparse(settings.CLOUDINARY_URL)
    cloudinary.config(cloud_name=cloud_url.hostname,
                      api_key=unquote(cloud_url.username or ""),
                      api_secret=unquote(cloud_url.password or ""))


from app.auth_utils import get_current_user as get_current_user_from_token


@router.get("/me")
async def get_my_profile(
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    profile_data = await get_user_profile(db, current_user.user_id)
    if not profile_data:
        return {"success": False, "message": "Profile not found"}
    return profile_data


@router.get("/get")
async def get_profile(user_id: int, db: AsyncSession = Depends(get_db),
                      current_user: User = Depends(get_current_user_from_token)):
    if user_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="You can only access your own profile")
    profile_data = await get_user_profile(db, user_id)
    if not profile_data:
        return {"success": False, "message": "Profile not found"}
    return profile_data


@router.post("/create", response_model=UserProfileResponse)
async def create_profile(payload: UserProfileRequest, db: AsyncSession = Depends(get_db),
                         current_user: User = Depends(get_current_user_from_token)):
    if payload.user_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="You can only create your own profile")
    await create_or_update_profile(db, payload)
    await create_notification(
        db, payload.user_id,
        "Profile Created",
        "Your health profile has been created successfully!",
        "success"
    )
    return {"success": True, "message": "Profile created successfully"}


@router.put("/edit")
async def edit_profile(
        user_id: int = Form(...),
        first_name: str = Form(None),
        last_name: str = Form(None),
        email: str = Form(None),
        age: int = Form(None),
        gender: str = Form(None),
        weight_kg: float = Form(None),
        height_cm: float = Form(None),
        diabetes_status: str = Form(None),
        insulin_usage: bool = Form(None),
        insulin_morning_units: float = Form(None),
        insulin_night_units: float = Form(None),
        blood_glucose: float = Form(None),
        profile_picture: UploadFile = File(None),
        treatment: str = Form(None),
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    if user_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="You can only edit your own profile")
    # ADD BLOOD GLUCOSE VALIDATION HERE
    if blood_glucose is not None:
        if blood_glucose < 20:
            raise HTTPException(
                status_code=400,
                detail="Blood glucose must be at least 20 mg/dL"
            )
        if blood_glucose > 600:
            raise HTTPException(
                status_code=400,
                detail="Blood glucose cannot exceed 600 mg/dL"
            )
        # Optional: Check for decimal in string?
        # Frontend already handles this, but you can add:
        if isinstance(blood_glucose, float) and blood_glucose != int(blood_glucose):
            # Allow decimals? Most glucose meters give whole numbers
            # But if you want to allow decimals, remove this check
            pass

    try:
        payload = UserProfileUpdateRequest(
            user_id=user_id,
            first_name=first_name,
            last_name=last_name,
            email=email,
            age=age,
            gender=gender,
            weight_kg=weight_kg,
            height_cm=height_cm,
            diabetes_status=diabetes_status,
            insulin_usage=insulin_usage,
            insulin_morning_units=insulin_morning_units, 
            insulin_night_units=insulin_night_units,
            blood_glucose=blood_glucose,
            treatment=TreatmentProfile.model_validate_json(treatment) if treatment is not None else None
        )
    except ValidationError as error:
        raise HTTPException(status_code=422, detail=error.errors(include_input=False, include_context=False)) from None




    image_url = None
    if profile_picture:
        raw_image = await profile_picture.read(MAX_UPLOAD_BYTES + 1)
        normalized_image = await run_in_threadpool(normalize_profile_image, raw_image)
        upload_result = await run_in_threadpool(
            cloudinary.uploader.upload,
            normalized_image,
            folder="nutricare_profiles",
            public_id=f"user_{user_id}_profile",
            resource_type="image",
            overwrite=True
        )
        image_url = upload_result.get("secure_url")

    try:
        profile = await update_profile(db, payload, image_url)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Profile could not be saved; check that your email is not already registered") from None

    await create_notification(
        db, user_id,
        "Profile Updated",
        "Your health profile has been updated successfully! Keep tracking your daily metrics for better health insights.",
        "success"
    )

    return {
        "success": True,
        "message": "Profile updated successfully",
        "profile_picture": profile.profile_picture if profile else None
    }
