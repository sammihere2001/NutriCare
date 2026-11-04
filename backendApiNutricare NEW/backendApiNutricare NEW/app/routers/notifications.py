from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update
from datetime import datetime
from app.database import get_db
from app.models import User, Notification, UserDeviceToken
from jose import jwt
from app.config import settings

router = APIRouter(
    prefix="/notifications",
    tags=["Notifications"]
)


from app.auth_utils import get_current_user as get_current_user_from_token


# Create notification (internal function, not API endpoint)
async def create_notification(db: AsyncSession, user_id: int, title: str, message: str, notification_type: str = None,
                              extra_data: dict = None):
    """
    Create a notification for a user - BUT only if they have push notifications enabled.
    Also checks for active device tokens.
    """

    # ✅ Check if user has any active device tokens (push enabled)
    tokens_result = await db.execute(
        select(UserDeviceToken)
        .where(
            UserDeviceToken.user_id == user_id,
            UserDeviceToken.is_active == True
        )
    )
    active_tokens = tokens_result.scalars().all()

    # ✅ If no active tokens, skip notification creation
    if not active_tokens:
        print(f" Skipping notification for user {user_id} - Push disabled or no active devices")
        return None

    # ✅ Create the notification in database
    notification = Notification(
        user_id=user_id,
        title=title,
        message=message,
        notification_type=notification_type,
        extra_data=extra_data
    )
    db.add(notification)
    await db.commit()
    await db.refresh(notification)

    # ✅ Here you would send actual push notification via FCM/APNS
    # This is where you'd integrate Firebase Cloud Messaging
    # await send_push_notification(active_tokens, title, message)

    print(f" Notification created for user {user_id} with {len(active_tokens)} active devices")
    return notification

# Get all notifications for current user
@router.get("/get")
async def get_notifications(
        current_user: User = Depends(get_current_user_from_token),
        db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == current_user.user_id)
        .order_by(Notification.sent_at.desc())
    )
    notifications = result.scalars().all()
    return notifications


# Get unread count
@router.get("/unread-count")
async def get_unread_count(
        current_user: User = Depends(get_current_user_from_token),
        db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(func.count(Notification.notification_id))
        .where(Notification.user_id == current_user.user_id)
        .where(Notification.is_read == False)
    )
    count = result.scalar() or 0
    return {"count": count}


# Mark notification as read
@router.post("/mark-read/{notification_id}")
async def mark_as_read(
        notification_id: int,
        current_user: User = Depends(get_current_user_from_token),
        db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Notification).where(
            Notification.notification_id == notification_id,
            Notification.user_id == current_user.user_id
        )
    )
    notification = result.scalar_one_or_none()

    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")

    notification.is_read = True
    notification.read_at = datetime.utcnow()
    await db.commit()

    return {"message": "Notification marked as read"}


# Mark all as read
@router.post("/mark-all-read")
async def mark_all_as_read(
        current_user: User = Depends(get_current_user_from_token),
        db: AsyncSession = Depends(get_db)
):
    await db.execute(
        update(Notification)
        .where(Notification.user_id == current_user.user_id)
        .where(Notification.is_read == False)
        .values(is_read=True, read_at=datetime.utcnow())
    )
    await db.commit()

    return {"message": "All notifications marked as read"}


@router.delete("/delete/{notification_id}")
async def delete_notification(
        notification_id: int,
        current_user: User = Depends(get_current_user_from_token),
        db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Notification).where(
            Notification.notification_id == notification_id,
            Notification.user_id == current_user.user_id
        )
    )
    notification = result.scalar_one_or_none()

    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")

    await db.delete(notification)
    await db.commit()

    return {"message": "Notification deleted successfully"}


# Delete all notifications for current user
@router.delete("/delete-all")
async def delete_all_notifications(
        current_user: User = Depends(get_current_user_from_token),
        db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Notification).where(Notification.user_id == current_user.user_id)
    )
    notifications = result.scalars().all()

    for notification in notifications:
        await db.delete(notification)

    await db.commit()

    return {"message": "All notifications deleted successfully"}