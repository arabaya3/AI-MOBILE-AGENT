"""Notification service for real-time user notifications."""

import logging
from datetime import datetime
from typing import List, Optional

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from src.services.databases.postgresql.models import Notification, User

logger = logging.getLogger(__name__)


class NotificationService:
    """Service for managing user notifications."""

    async def create_notification(
        self,
        db: AsyncSession,
        *,
        user_id: str,
        type: str,
        title: str,
        message: str,
        space_id: Optional[str] = None,
        link: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> Notification:
        """Create a new notification for a user."""
        notification = Notification(
            user_id=user_id,
            space_id=space_id,
            type=type,
            title=title,
            message=message,
            link=link,
            notification_metadata=metadata or {},
            read=False,
        )
        db.add(notification)
        await db.commit()
        await db.refresh(notification)
        
        logger.info(f"Created notification {notification.id} for user {user_id}: {title}")
        return notification

    async def get_user_notifications(
        self,
        db: AsyncSession,
        *,
        user_id: str,
        unread_only: bool = False,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Notification]:
        """Get notifications for a user."""
        query = select(Notification).where(Notification.user_id == user_id)
        
        if unread_only:
            query = query.where(Notification.read == False)
        
        query = query.order_by(Notification.created_at.desc()).limit(limit).offset(offset)
        
        result = await db.execute(query)
        return list(result.scalars().all())

    async def mark_as_read(self, db: AsyncSession, *, notification_id: str, user_id: str) -> bool:
        """Mark a notification as read."""
        result = await db.execute(
            select(Notification).where(
                and_(
                    Notification.id == notification_id,
                    Notification.user_id == user_id,
                )
            )
        )
        notification = result.scalar_one_or_none()
        
        if not notification:
            return False
        
        notification.read = True
        await db.commit()
        return True

    async def mark_all_as_read(self, db: AsyncSession, *, user_id: str) -> int:
        """Mark all notifications as read for a user."""
        result = await db.execute(
            select(Notification).where(
                and_(
                    Notification.user_id == user_id,
                    Notification.read == False,
                )
            )
        )
        notifications = result.scalars().all()
        
        count = 0
        for notification in notifications:
            notification.read = True
            count += 1
        
        await db.commit()
        return count

    async def get_unread_count(self, db: AsyncSession, *, user_id: str) -> int:
        """Get count of unread notifications for a user."""
        result = await db.execute(
            select(Notification).where(
                and_(
                    Notification.user_id == user_id,
                    Notification.read == False,
                )
            )
        )
        return len(list(result.scalars().all()))

    async def delete_notification(self, db: AsyncSession, *, notification_id: str, user_id: str) -> bool:
        """Delete a notification."""
        result = await db.execute(
            select(Notification).where(
                and_(
                    Notification.id == notification_id,
                    Notification.user_id == user_id,
                )
            )
        )
        notification = result.scalar_one_or_none()
        
        if not notification:
            return False
        
        await db.delete(notification)
        await db.commit()
        return True

    # Helper methods for specific notification types

    async def notify_request_approved(
        self,
        db: AsyncSession,
        *,
        user_id: str,
        space_id: str,
        space_name: str,
        request_type: str,
    ) -> Notification:
        """Notify user that their request was approved."""
        return await self.create_notification(
            db,
            user_id=user_id,
            space_id=space_id,
            type="request_approved",
            title="Request Approved",
            message=f"Your {request_type} request for '{space_name}' has been approved.",
            link=f"/spaces/{space_id}",
        )

    async def notify_request_declined(
        self,
        db: AsyncSession,
        *,
        user_id: str,
        space_id: str,
        space_name: str,
        request_type: str,
        reason: Optional[str] = None,
    ) -> Notification:
        """Notify user that their request was declined."""
        message = f"Your {request_type} request for '{space_name}' has been declined."
        if reason:
            message += f" Reason: {reason}"
        
        return await self.create_notification(
            db,
            user_id=user_id,
            space_id=space_id,
            type="request_declined",
            title="Request Declined",
            message=message,
            link=f"/spaces/{space_id}",
        )

    async def notify_policy_updated(
        self,
        db: AsyncSession,
        *,
        user_id: str,
        space_id: str,
        space_name: str,
    ) -> Notification:
        """Notify user that space policy was updated."""
        return await self.create_notification(
            db,
            user_id=user_id,
            space_id=space_id,
            type="policy_updated",
            title="Policy Updated",
            message=f"The access policy for '{space_name}' has been updated.",
            link=f"/spaces/{space_id}",
        )

    async def notify_space_invitation(
        self,
        db: AsyncSession,
        *,
        user_id: str,
        space_id: str,
        space_name: str,
        inviter_name: Optional[str] = None,
    ) -> Notification:
        """Notify user about space invitation."""
        inviter_text = f"{inviter_name} has" if inviter_name else "You have been"
        return await self.create_notification(
            db,
            user_id=user_id,
            space_id=space_id,
            type="space_invite",
            title="Space Invitation",
            message=f"{inviter_text} invited you to join '{space_name}'.",
            link=f"/spaces/{space_id}",
        )

    async def notify_quota_warning(
        self,
        db: AsyncSession,
        *,
        user_id: str,
        space_id: str,
        space_name: str,
        quota_type: str,
        usage_percentage: float,
    ) -> Notification:
        """Notify user about approaching quota limit."""
        return await self.create_notification(
            db,
            user_id=user_id,
            space_id=space_id,
            type="quota_warning",
            title="Quota Warning",
            message=f"You have used {usage_percentage:.0f}% of your {quota_type} quota in '{space_name}'.",
            link=f"/spaces/{space_id}",
            metadata={"quota_type": quota_type, "usage_percentage": usage_percentage},
        )


# Singleton instance
notification_service = NotificationService()
