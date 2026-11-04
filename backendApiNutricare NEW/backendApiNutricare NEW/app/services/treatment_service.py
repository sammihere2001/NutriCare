from fastapi import HTTPException
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User, UserMedication, UserProfile, UserTreatmentContext
from app.treatment_schemas import MedicationRecord, TreatmentProfile


async def sync_legacy_insulin(db: AsyncSession, user_id: int, enabled: bool):
    """Keep older clients' insulin flag consistent without deleting other medicines."""
    await db.execute(select(User.user_id).where(User.user_id == user_id).with_for_update())
    result = await db.execute(select(UserMedication).where(
        UserMedication.user_id == user_id, UserMedication.medication_class == "insulin"))
    existing = result.scalars().first()
    if enabled and existing is None:
        db.add(UserMedication(user_id=user_id, medication_class="insulin", position=0))
    elif not enabled:
        await db.execute(delete(UserMedication).where(
            UserMedication.user_id == user_id, UserMedication.medication_class == "insulin"))


async def read_treatment(db: AsyncSession, user_id: int, legacy_insulin: bool = False) -> dict:
    context = await db.get(UserTreatmentContext, user_id)
    result = await db.execute(select(UserMedication).where(
        UserMedication.user_id == user_id).order_by(UserMedication.position))
    medications = [MedicationRecord(medication_class=row.medication_class, name=row.name,
                                   prescribed_dose=row.prescribed_dose, schedule=row.schedule,
                                   started_on=row.started_on) for row in result.scalars().all()]
    if context is None and legacy_insulin and not medications:
        medications = [MedicationRecord(medication_class="insulin")]
    return TreatmentProfile(medications=medications,
                            medications_confirmed=context.medications_confirmed if context else False,
                            appetite=context.appetite if context else "unknown",
                            symptoms=context.symptoms if context else []).model_dump(mode="json")


async def save_treatment(db: AsyncSession, user_id: int, payload: TreatmentProfile):
    """Stage updates in the caller's transaction; serialize writes for one user."""
    await db.execute(select(User.user_id).where(User.user_id == user_id).with_for_update())
    profile = await db.get(UserProfile, user_id)
    if profile is None:
        raise HTTPException(status_code=409, detail="Create your health profile before updating treatment")
    context = await db.get(UserTreatmentContext, user_id)
    if context is None:
        context = UserTreatmentContext(user_id=user_id)
        db.add(context)
    context.medications_confirmed = payload.medications_confirmed
    context.appetite = payload.appetite
    context.symptoms = payload.symptoms
    await db.execute(delete(UserMedication).where(UserMedication.user_id == user_id))
    for position, medication in enumerate(payload.medications):
        data = medication.model_dump()
        data["medication_class"] = medication.medication_class.value
        db.add(UserMedication(user_id=user_id, position=position, **data))
    uses_insulin = any(m.medication_class.value == "insulin" for m in payload.medications)
    profile.insulin_usage = uses_insulin
    if not uses_insulin:
        profile.insulin_morning_units = None
        profile.insulin_night_units = None

