from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth_utils import get_current_user
from app.database import get_db
from app.models import User, UserProfile
from app.services.treatment_service import read_treatment, save_treatment
from app.treatment_schemas import TreatmentProfile

router = APIRouter(prefix="/treatment", tags=["Treatment profile"])


@router.get("/me", response_model=TreatmentProfile)
async def get_treatment(current_user: User = Depends(get_current_user),
                        db: AsyncSession = Depends(get_db)):
    profile = await db.get(UserProfile, current_user.user_id)
    return await read_treatment(db, current_user.user_id, bool(profile and profile.insulin_usage))


@router.put("/me", response_model=TreatmentProfile)
async def update_treatment(payload: TreatmentProfile,
                           current_user: User = Depends(get_current_user),
                           db: AsyncSession = Depends(get_db)):
    await save_treatment(db, current_user.user_id, payload)
    await db.commit()
    return payload
