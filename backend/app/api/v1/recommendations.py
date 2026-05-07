from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.recommendation import RecommendationOut
from app.services import recommendations as rec_service

router = APIRouter()


@router.get("/tonight", response_model=list[RecommendationOut])
async def recommendations_tonight(
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    when: datetime | None = Query(
        default=None,
        description="ISO-8601 timestamp; defaults to current time in Europe/Rome",
    ),
    limit: int = Query(default=20, gt=0, le=50),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[RecommendationOut]:
    if (lat is None) != (lng is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="lat and lng must be provided together",
        )
    return await rec_service.recommend_tonight(
        session,
        user_id=current_user.id,
        lat=lat,
        lng=lng,
        when=when,
        limit=limit,
    )
