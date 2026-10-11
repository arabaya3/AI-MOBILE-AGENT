"""Notification API schemas."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class NotificationResponse(BaseModel):
    id: str
    user_id: str
    space_id: Optional[str] = None
    type: str
    title: str
    message: str
    link: Optional[str] = None
    metadata: dict = Field(default_factory=dict, alias="notification_metadata")
    read: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UnreadCountResponse(BaseModel):
    count: int


class MarkAsReadRequest(BaseModel):
    notification_ids: list[str] = Field(default_factory=list)
