from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.concierge import ConciergeRequest, ConciergeResponse
from app.services import concierge as concierge_service

router = APIRouter()


@router.post("/chat", response_model=ConciergeResponse)
async def concierge_chat(
    payload: ConciergeRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> ConciergeResponse:
    return await concierge_service.reply(
        session,
        user_id=current_user.id,
        message=payload.message,
        history=payload.history,
        lat=payload.lat,
        lng=payload.lng,
    )
