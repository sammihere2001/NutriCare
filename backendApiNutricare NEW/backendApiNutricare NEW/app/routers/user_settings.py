from fastapi import APIRouter, Depends, HTTPException, Header, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete
from typing import Optional
from pydantic import BaseModel, EmailStr, validator
from app.database import get_db
from app.models import User, UserDeviceToken, Notification, RefreshToken, PasswordResetToken
from app.auth_utils import hash_password, verify_password
from jose import jwt
from app.config import settings
from app.routers.notifications import create_notification
import hashlib
from sqlalchemy import select, update, delete, func
from datetime import datetime
from fastapi.responses import FileResponse
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image
from reportlab.lib.enums import TA_CENTER, TA_LEFT
import os
import tempfile
import re

router = APIRouter(prefix="/user-settings", tags=["User Settings"])

# ==================== MODELS ====================

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str
    confirm_password: str

    @validator('new_password')
    def validate_password_strength(cls, v):
        """Validate password meets security requirements"""

        # Check minimum length
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')

        # Check for uppercase letter
        if not re.search(r'[A-Z]', v):
            raise ValueError('Password must contain at least one uppercase letter (A-Z)')

        # Check for lowercase letter
        if not re.search(r'[a-z]', v):
            raise ValueError('Password must contain at least one lowercase letter (a-z)')

        # Check for number
        if not re.search(r'[0-9]', v):
            raise ValueError('Password must contain at least one number (0-9)')

        # Check for special character
        if not re.search(r'[!@#$%^&*(),.?":{}|<>]', v):
            raise ValueError('Password must contain at least one special character (!@#$%^&* etc.)')

        return v

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        if 'new_password' in values and v != values['new_password']:
            raise ValueError('Passwords do not match')
        return v


class ChangePasswordResponse(BaseModel):
    success: bool
    message: str


class PushNotificationToggleRequest(BaseModel):
    enabled: bool
    device_token: Optional[str] = None
    platform: Optional[str] = None  # android, ios, web


class PushNotificationToggleResponse(BaseModel):
    success: bool
    message: str
    push_enabled: bool


class DeleteAccountRequest(BaseModel):
    password: str
    confirm_delete: bool


class DeleteAccountResponse(BaseModel):
    success: bool
    message: str


class UserSettingsResponse(BaseModel):
    user_id: int
    email: str
    push_notifications_enabled: bool
    device_tokens_count: int

# ==================== DEPENDENCY ====================

from app.auth_utils import get_current_user as get_current_user_from_token


# ==================== CHANGE PASSWORD ====================

@router.post("/change-password", response_model=ChangePasswordResponse)
async def change_password(
        payload: ChangePasswordRequest,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """
    Change user password with strong validation.
    Password must contain:
    - At least 8 characters
    - One uppercase letter (A-Z)
    - One lowercase letter (a-z)
    - One number (0-9)
    - One special character (!@#$%^&* etc.)
    """

    # Verify current password
    if not verify_password(payload.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=400,
            detail="Current password is incorrect"
        )

    # Check if new password is same as current
    if verify_password(payload.new_password, current_user.password_hash):
        raise HTTPException(
            status_code=400,
            detail="New password must be different from current password"
        )

    #  Additional backend validation (double check)
    import re

    if len(payload.new_password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters")
    if not re.search(r'[A-Z]', payload.new_password):
        raise HTTPException(status_code=400, detail="Password must contain at least one uppercase letter")
    if not re.search(r'[a-z]', payload.new_password):
        raise HTTPException(status_code=400, detail="Password must contain at least one lowercase letter")
    if not re.search(r'[0-9]', payload.new_password):
        raise HTTPException(status_code=400, detail="Password must contain at least one number")
    if not re.search(r'[!@#$%^&*(),.?\":{}|<>]', payload.new_password):
        raise HTTPException(status_code=400, detail="Password must contain at least one special character")

    # Hash new password
    new_password_hash = hash_password(payload.new_password)

    # Update password
    current_user.password_hash = new_password_hash
    await db.commit()

    # Revoke all refresh tokens for security
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == current_user.user_id)
        .values(revoked=True, revoked_at=func.now())
    )
    await db.commit()

    # Create notification
    await create_notification(
        db,
        current_user.user_id,
        "🔒 Password Changed",
        "Your password has been successfully updated. All other sessions have been logged out.",
        "security"
    )

    return ChangePasswordResponse(
        success=True,
        message="Password changed successfully. Please login again with your new password."
    )
# ==================== PUSH NOTIFICATION TOGGLE ====================

@router.get("/push-notifications", response_model=UserSettingsResponse)
async def get_push_notification_settings(
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """Get current push notification settings"""

    # Get active device tokens
    result = await db.execute(
        select(UserDeviceToken)
        .where(
            UserDeviceToken.user_id == current_user.user_id,
            UserDeviceToken.is_active == True
        )
    )
    active_tokens = result.scalars().all()

    return UserSettingsResponse(
        user_id=current_user.user_id,
        email=current_user.email,
        push_notifications_enabled=len(active_tokens) > 0,
        device_tokens_count=len(active_tokens)
    )


@router.post("/push-notifications", response_model=PushNotificationToggleResponse)
async def toggle_push_notifications(
        payload: PushNotificationToggleRequest,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """
    Enable or disable push notifications.
    """

    if payload.enabled:
        # Enabling notifications
        if not payload.device_token:
            raise HTTPException(
                status_code=400,
                detail="Device token is required to enable push notifications"
            )

        if not payload.platform:
            raise HTTPException(
                status_code=400,
                detail="Platform is required (android, ios, or web)"
            )

        # Check if token already exists
        result = await db.execute(
            select(UserDeviceToken)
            .where(
                UserDeviceToken.user_id == current_user.user_id,
                UserDeviceToken.device_token == payload.device_token
            )
        )
        existing_token = result.scalar_one_or_none()

        if existing_token:
            # Reactivate existing token
            existing_token.is_active = True
            existing_token.platform = payload.platform
            existing_token.updated_at = func.now()
        else:
            # Add new device token
            new_token = UserDeviceToken(
                user_id=current_user.user_id,
                device_token=payload.device_token,
                platform=payload.platform,
                is_active=True
            )
            db.add(new_token)

        await db.commit()

        # Don't create notification when enabling - it's confusing
        # Just update the status

        return PushNotificationToggleResponse(
            success=True,
            message="Push notifications enabled successfully",
            push_enabled=True
        )

    else:
        # Disabling - deactivate ALL tokens
        await db.execute(
            update(UserDeviceToken)
            .where(
                UserDeviceToken.user_id == current_user.user_id,
                UserDeviceToken.is_active == True
            )
            .values(is_active=False, updated_at=func.now())
        )
        await db.commit()

        # Clear any existing notifications that haven't been sent
        # This is optional - you might want to keep old notifications

        return PushNotificationToggleResponse(
            success=True,
            message="Push notifications disabled. You won't receive any more notifications.",
            push_enabled=False
        )
@router.delete("/device-token/{token_id}")
async def remove_device_token(
        token_id: int,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """Remove a specific device token"""

    result = await db.execute(
        select(UserDeviceToken)
        .where(
            UserDeviceToken.token_id == token_id,
            UserDeviceToken.user_id == current_user.user_id
        )
    )
    token = result.scalar_one_or_none()

    if not token:
        raise HTTPException(status_code=404, detail="Device token not found")

    await db.delete(token)
    await db.commit()

    return {"success": True, "message": "Device token removed successfully"}


# ==================== DELETE ACCOUNT ====================

@router.delete("/delete-account", response_model=DeleteAccountResponse)
async def delete_account(
        payload: DeleteAccountRequest,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """
    Permanently delete user account.
    - Requires password verification
    - Requires explicit confirmation
    - This action is irreversible
    """

    # Verify password
    if not verify_password(payload.password, current_user.password_hash):
        raise HTTPException(
            status_code=400,
            detail="Password is incorrect"
        )

    # Verify confirmation
    if not payload.confirm_delete:
        raise HTTPException(
            status_code=400,
            detail="You must confirm account deletion by setting confirm_delete to true"
        )

    user_id = current_user.user_id
    user_email = current_user.email

    try:
        # Delete all related data (cascading will handle most, but let's be explicit)

        # 1. Delete device tokens
        await db.execute(
            delete(UserDeviceToken).where(UserDeviceToken.user_id == user_id)
        )

        # 2. Delete refresh tokens
        await db.execute(
            delete(RefreshToken).where(RefreshToken.user_id == user_id)
        )

        # 3. Delete password reset tokens
        await db.execute(
            delete(PasswordResetToken).where(PasswordResetToken.user_id == user_id)
        )

        # 4. Delete notifications
        await db.execute(
            delete(Notification).where(Notification.user_id == user_id)
        )

        # 5. Finally delete the user (this will cascade to profile, daily_tracker, etc.)
        await db.execute(
            delete(User).where(User.user_id == user_id)
        )

        await db.commit()

        # Log the deletion (optional)
        print(f"User account deleted: {user_email} (ID: {user_id})")

        return DeleteAccountResponse(
            success=True,
            message="Your account has been permanently deleted. All your data has been removed."
        )

    except Exception as e:
        await db.rollback()
        print(f"Error deleting account: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete account: {str(e)}"
        )


# ==================== GET SETTINGS SUMMARY ====================

@router.get("/settings")
async def get_user_settings_summary(
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    """Get complete user settings summary for settings page"""

    # Get active device tokens
    tokens_result = await db.execute(
        select(UserDeviceToken)
        .where(
            UserDeviceToken.user_id == current_user.user_id,
            UserDeviceToken.is_active == True
        )
    )
    active_tokens = tokens_result.scalars().all()

    # Count unread notifications
    unread_result = await db.execute(
        select(func.count(Notification.notification_id))
        .where(
            Notification.user_id == current_user.user_id,
            Notification.is_read == False
        )
    )
    unread_count = unread_result.scalar() or 0

    return {
        "success": True,
        "data": {
            "user_id": current_user.user_id,
            "email": current_user.email,
            "first_name": current_user.first_name,
            "last_name": current_user.last_name,
            "is_active": current_user.is_active,
            "created_at": current_user.created_at.isoformat() if current_user.created_at else None,
            "push_notifications": {
                "enabled": len(active_tokens) > 0,
                "active_devices": len(active_tokens),
                "devices": [
                    {
                        "token_id": t.token_id,
                        "platform": t.platform,
                        "created_at": t.created_at.isoformat() if t.created_at else None
                    }
                    for t in active_tokens
                ]
            },
            "unread_notifications": unread_count,
            "account_status": "active" if current_user.is_active else "inactive"
        }
    }


# ==================== EXPORT USER DATA (GDPR) ====================
@router.get("/export-data-pdf")
async def export_user_data_pdf(
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user_from_token)
):
    from app.models import DailyTracker, SugarReading
    from app.crud_profile import get_user_profile

    user_id = current_user.user_id

    profile = await get_user_profile(db, user_id)

    tracker_result = await db.execute(
        select(DailyTracker)
        .where(DailyTracker.user_id == user_id)
        .order_by(DailyTracker.tracker_date.desc())
        .limit(30)
    )
    trackers = tracker_result.scalars().all()

    sugar_result = await db.execute(
        select(SugarReading)
        .where(SugarReading.user_id == user_id)
        .order_by(SugarReading.reading_time.desc())
        .limit(30)
    )
    sugar_readings = sugar_result.scalars().all()

    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.pdf')
    file_path = temp_file.name

    doc = SimpleDocTemplate(
        file_path,
        pagesize=A4,
        rightMargin=40,
        leftMargin=40,
        topMargin=40,
        bottomMargin=40
    )

    styles = getSampleStyleSheet()
    elements = []

    # Custom styles
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=22,
        textColor=colors.HexColor('#4ECDC4'),
        alignment=TA_CENTER,
        spaceAfter=8
    )

    subtitle_style = ParagraphStyle(
        'Subtitle',
        parent=styles['Normal'],
        fontSize=12,
        textColor=colors.grey,
        alignment=TA_CENTER,
        spaceAfter=25
    )

    heading_style = ParagraphStyle(
        'SectionHeading',
        parent=styles['Heading2'],
        fontSize=14,
        textColor=colors.HexColor('#333333'),
        spaceBefore=18,
        spaceAfter=8,
        fontName='Helvetica-Bold'
    )

    normal_style = ParagraphStyle(
        'NormalText',
        parent=styles['Normal'],
        fontSize=10,
        textColor=colors.HexColor('#444444'),
        leading=14
    )

    small_style = ParagraphStyle(
        'SmallText',
        parent=styles['Normal'],
        fontSize=8,
        textColor=colors.grey,
    )

    # === TITLE ===
    elements.append(Paragraph("NutriCare Exported Data", title_style))
    elements.append(Paragraph(f"Generated on {datetime.now().strftime('%B %d, %Y at %I:%M %p')}", subtitle_style))

    # === PERSONAL INFO ===
    elements.append(Paragraph("📋 Personal Information", heading_style))

    user_name = f"{current_user.first_name or ''} {current_user.last_name or ''}".strip()

    user_info_data = [
        ["Name:", user_name or 'N/A'],
        ["Email:", current_user.email],
        ["Member Since:", current_user.created_at.strftime('%d %B, %Y') if current_user.created_at else 'N/A'],
    ]

    user_table = Table(user_info_data, colWidths=[120, 380])
    user_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('TEXTCOLOR', (0, 0), (0, -1), colors.HexColor('#555555')),
        ('TEXTCOLOR', (1, 0), (1, -1), colors.HexColor('#333333')),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('LINEBELOW', (0, 0), (-1, -1), 0.3, colors.HexColor('#EEEEEE')),
    ]))
    elements.append(user_table)

    # === HEALTH PROFILE ===
    if profile:
        elements.append(Paragraph("🏥 Health Profile", heading_style))

        profile_data = [
            ["Age:", str(profile.get('age', 'N/A'))],
            ["Gender:", str(profile.get('gender', 'N/A')).upper()],
            ["Weight:", f"{profile.get('weight_kg', 'N/A')} kg"],
            ["Height:", f"{profile.get('height_cm', 'N/A')} cm"],
            ["BMI:", f"{profile.get('bmi', 'N/A')}" if profile.get('bmi') else 'N/A'],
            ["Diabetes:", str(profile.get('diabetes_status', 'N/A')).upper()],
            ["Insulin:", "Yes" if profile.get('insulin_usage') else "No"],
            ["Activity:", str(profile.get('activity_level', 'N/A')).replace('_', ' ').title()],
        ]

        profile_table = Table(profile_data, colWidths=[120, 380])
        profile_table.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
            ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('TEXTCOLOR', (0, 0), (0, -1), colors.HexColor('#555555')),
            ('TEXTCOLOR', (1, 0), (1, -1), colors.HexColor('#333333')),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('LEFTPADDING', (0, 0), (-1, -1), 8),
            ('LINEBELOW', (0, 0), (-1, -1), 0.3, colors.HexColor('#EEEEEE')),
        ]))
        elements.append(profile_table)

    # === DAILY TRACKERS ===
    if trackers:
        elements.append(Paragraph("📊 Recent Health Tracking (Last 30 Days)", heading_style))
        elements.append(Paragraph("<i>All values shown are daily records</i>", small_style))
        elements.append(Spacer(1, 6))
        tracker_headers = ["Date", "Morning\n(mg/dL)", "Evening\n(mg/dL)", "Weight\n(kg)", "Exercise\n(min)",
                           "Water\n(glasses)", "Sleep\n(hrs)"]
        tracker_data = [tracker_headers]

        for t in trackers[:15]:
            # Convert Decimal to float and round properly
            morning = round(float(t.morning_glucose), 1) if t.morning_glucose else '-'
            evening = round(float(t.evening_glucose), 1) if t.evening_glucose else '-'
            weight = round(float(t.weight), 1) if t.weight else '-'
            exercise = int(float(t.exercise)) if t.exercise else '-'
            water = int(float(t.water_intake)) if t.water_intake else '-'
            sleep = round(float(t.sleep_hours), 1) if t.sleep_hours else '-'

            tracker_data.append([
                str(t.tracker_date),
                str(morning),
                str(evening),
                str(weight),
                str(exercise),
                str(water),
                str(sleep),
            ])

        tracker_table = Table(tracker_data, colWidths=[70, 62, 62, 55, 60, 58, 55])
        tracker_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#4ECDC4')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 8),
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -1), 8),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('LEFTPADDING', (0, 0), (-1, -1), 4),
            ('RIGHTPADDING', (0, 0), (-1, -1), 4),
            ('GRID', (0, 0), (-1, -1), 0.3, colors.HexColor('#DDDDDD')),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F8FAFA')]),
        ]))
        elements.append(tracker_table)

    # === BLOOD SUGAR READINGS ===
    if sugar_readings:
        elements.append(Paragraph("🩸 Blood Sugar Readings", heading_style))
        elements.append(Paragraph("<i>Recent readings in mg/dL</i>", small_style))
        elements.append(Spacer(1, 6))

        sugar_headers = ["Date & Time", "Reading", "Notes"]
        sugar_data = [sugar_headers]

        for s in sugar_readings[:15]:
            reading_time = s.reading_time.strftime('%d-%m-%Y %I:%M %p') if s.reading_time else 'N/A'
            reading_value = f"{round(float(s.reading_value), 1)} mg/dL" if s.reading_value else 'N/A'
            notes = s.notes[:40] + '...' if s.notes and len(s.notes) > 40 else (s.notes or '-')

            sugar_data.append([
                reading_time,
                reading_value,
                notes,
            ])

        sugar_table = Table(sugar_data, colWidths=[130, 95, 195])
        sugar_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#FF6B6B')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 9),
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -1), 8),
            ('ALIGN', (1, 0), (1, -1), 'CENTER'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('GRID', (0, 0), (-1, -1), 0.3, colors.HexColor('#DDDDDD')),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#FFF5F5')]),
        ]))
        elements.append(sugar_table)

    # === SUMMARY ===
    elements.append(Spacer(1, 20))
    elements.append(Paragraph("📈 Summary", heading_style))

    summary_data = [
        ["Total Trackers:", str(len(trackers))],
        ["Total Sugar Readings:", str(len(sugar_readings))],
        ["Report Generated:", datetime.now().strftime('%d %B, %Y at %I:%M %p')],
    ]

    summary_table = Table(summary_data, colWidths=[150, 350])
    summary_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
    ]))
    elements.append(summary_table)

    # === FOOTER ===
    elements.append(Spacer(1, 25))
    elements.append(Paragraph(
        "<i>This report is generated by NutriCare AI for personal use.<br/>For medical advice, please consult your healthcare provider.</i>",
        ParagraphStyle('Footer', parent=styles['Normal'], fontSize=8, textColor=colors.grey, alignment=TA_CENTER,
                       leading=12)
    ))
    elements.append(Spacer(1, 5))
    elements.append(Paragraph(
        f"<i>NutriCare © 2025 | Report ID: NC-{user_id}-{datetime.now().strftime('%Y%m%d%H%M')}</i>",
        ParagraphStyle('Footer2', parent=styles['Normal'], fontSize=7, textColor=colors.HexColor('#BBBBBB'),
                       alignment=TA_CENTER)
    ))

    # Build PDF
    doc.build(elements)

    user_name = f"{current_user.first_name or 'User'}_{current_user.last_name or ''}".strip().replace(' ', '_')
    filename = f"NutriCare_Report_{user_name}_{datetime.now().strftime('%Y%m%d')}.pdf"

    return FileResponse(
        file_path,
        media_type='application/pdf',
        filename=filename,
        headers={'Content-Disposition': f'attachment; filename="{filename}"'}
    )