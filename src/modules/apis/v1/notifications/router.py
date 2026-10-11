"""Notification API router."""

import asyncio
import json
import logging
from typing import List

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.apis.dependencies import get_current_user, get_db
from src.services.databases.postgresql.models import User
from src.services.notifications.service import notification_service
from src.services.notifications.broadcaster import broadcaster
from src.modules.apis.v1.notifications.schemas import (
    NotificationResponse,
    UnreadCountResponse,
    MarkAsReadRequest,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/", response_model=List[NotificationResponse])
async def get_notifications(
    unread_only: bool = Query(default=False),
    limit: int = Query(default=50, le=100),
    offset: int = Query(default=0),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get notifications for the current user."""
    notifications = await notification_service.get_user_notifications(
        db,
        user_id=current_user.id,
        unread_only=unread_only,
        limit=limit,
        offset=offset,
    )
    return [NotificationResponse.model_validate(n) for n in notifications]


@router.get("/unread-count", response_model=UnreadCountResponse)
async def get_unread_count(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get count of unread notifications."""
    count = await notification_service.get_unread_count(db, user_id=current_user.id)
    return UnreadCountResponse(count=count)


@router.post("/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark a notification as read."""
    success = await notification_service.mark_as_read(
        db,
        notification_id=notification_id,
        user_id=current_user.id,
    )
    return {"success": success}


@router.post("/mark-all-read")
async def mark_all_read(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark all notifications as read."""
    count = await notification_service.mark_all_as_read(db, user_id=current_user.id)
    return {"count": count}


@router.delete("/{notification_id}")
async def delete_notification(
    notification_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a notification."""
    success = await notification_service.delete_notification(
        db,
        notification_id=notification_id,
        user_id=current_user.id,
    )
    return {"success": success}


@router.get("/stream")
async def notification_stream(
    token: str = Query(default=None),
    current_user: User = Depends(get_current_user),
):
    """Server-Sent Events stream for real-time notifications.
    
    Note: EventSource doesn't support custom headers, so auth token
    can be passed via query parameter as a fallback.
    """
    
    async def event_generator():
        queue = await broadcaster.connect(current_user.id)
        try:
            # Send initial connection confirmation
            yield f"event: connected\ndata: {json.dumps({'user_id': current_user.id})}\n\n"
            
            while True:
                try:
                    # Wait for notification with timeout
                    message = await asyncio.wait_for(queue.get(), timeout=30.0)
                    event_data = json.dumps(message["data"])
                    yield f"event: {message['type']}\ndata: {event_data}\n\n"
                except asyncio.TimeoutError:
                    # Send keepalive ping
                    yield f": keepalive\n\n"
                except Exception as e:
                    logger.error(f"Error in notification stream for user {current_user.id}: {e}")
                    break
        finally:
            await broadcaster.disconnect(current_user.id, queue)
    
    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
