from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.locale import LOCALE_TYPES
from app.models.user import User
from app.schemas.locale import LocaleDetail, LocaleSummary
from app.services import locales as locales_service

router = APIRouter()


@router.get("", response_model=list[LocaleSummary])
async def list_locales(
    locale_type: str | None = Query(default=None, alias="type", description=f"One of: {', '.join(LOCALE_TYPES)}"),
    city: str | None = Query(default=None, description="Filter by city (case-insensitive exact)"),
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    radius_km: float | None = Query(default=None, gt=0, le=50),
    open_now: bool = Query(default=False),
    limit: int = Query(default=50, gt=0, le=200),
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> list[LocaleSummary]:
    if (lat is None) != (lng is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="lat and lng must be provided together",
        )
    if radius_km is not None and (lat is None or lng is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="radius_km requires lat and lng",
        )
    if locale_type is not None and locale_type not in LOCALE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"invalid type; allowed: {', '.join(LOCALE_TYPES)}",
        )
    return await locales_service.list_locales(
        session,
        locale_type=locale_type,
        city=city,
        lat=lat,
        lng=lng,
        radius_km=radius_km,
        open_now=open_now,
        limit=limit,
    )


@router.get("/{locale_id}", response_model=LocaleDetail)
async def get_locale(
    locale_id: UUID,
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    session: AsyncSession = Depends(get_session),
    _user: User = Depends(get_current_user),
) -> LocaleDetail:
    if (lat is None) != (lng is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="lat and lng must be provided together",
        )
    try:
        return await locales_service.get_locale(
            session, locale_id=locale_id, lat=lat, lng=lng
        )
    except NoResultFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="locale not found"
        ) from exc
