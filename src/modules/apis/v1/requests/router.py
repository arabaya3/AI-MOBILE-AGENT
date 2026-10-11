from typing import List, Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from src.modules.apis.dependencies import get_current_user
from src.services.databases.postgresql.database import get_db
from src.services.databases.postgresql.models import User, UserRequest

router = APIRouter(prefix="/requests", tags=["Requests"])

class CreateRequestPayload(BaseModel):
    request_type: str
    payload: dict

class UpdateRequestStatus(BaseModel):
    status: str
    admin_response: Optional[str] = None

class RequestResponse(BaseModel):
    id: str
    user_id: str
    request_type: str
    status: str
    payload: dict
    admin_response: Optional[str]
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

@router.post("/", response_model=RequestResponse)
async def create_user_request(
    body: CreateRequestPayload,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    try:
        new_request = UserRequest(
            user_id=current_user.id,
            request_type=body.request_type,
            payload=body.payload,
            status="pending"
        )
        db.add(new_request)
        await db.commit()
        await db.refresh(new_request)
        return new_request
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/", response_model=List[RequestResponse])
async def list_requests(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role in ["admin", "super_admin"]:
        # Admin sees all, could join with User to get email
        result = await db.execute(select(UserRequest).order_by(UserRequest.created_at.desc()))
        return result.scalars().all()
    else:
        # User sees own
        result = await db.execute(select(UserRequest).where(UserRequest.user_id == current_user.id).order_by(UserRequest.created_at.desc()))
        return result.scalars().all()

@router.put("/{request_id}", response_model=RequestResponse)
async def update_request_status(
    request_id: str,
    body: UpdateRequestStatus,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role not in ["admin", "super_admin"]:
         raise HTTPException(status_code=403, detail="Not authorized")
         
    result = await db.execute(select(UserRequest).where(UserRequest.id == request_id))
    req = result.scalar_one_or_none()
    
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
        
    req.status = body.status
    if body.admin_response:
        req.admin_response = body.admin_response
        
    await db.commit()
    await db.refresh(req)
    return req
