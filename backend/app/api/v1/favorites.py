from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.locale import Locale
from app.models.user import User
from app.schemas.locale import LocaleSummary
from app.services import favorites as favs_service
from sqlalchemy import select
from geoalchemy2.functions import ST_AsText

router = APIRouter()


@router.post("/{locale_id}", status_code=status.HTTP_201_CREATED)
async def add_favorite(
    locale_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    try:
        fav = await favs_service.add_favorite(
            session, user_id=current_user.id, locale_id=locale_id
        )
    except NoResultFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="locale not found"
        ) from exc
    return {"id": str(fav.id), "locale_id": str(fav.locale_id)}


@router.delete("/{locale_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_favorite(
    locale_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Response:
    try:
        await favs_service.remove_favorite(
            session, user_id=current_user.id, locale_id=locale_id
        )
    except NoResultFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="favorite not found"
        ) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("", response_model=list[LocaleSummary])
async def list_favorites(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[LocaleSummary]:
    locale_ids = await favs_service.list_favorite_locale_ids(
        session, user_id=current_user.id
    )
    if not locale_ids:
        return []
    stmt = (
        select(Locale, ST_AsText(Locale.location).label("wkt"))
        .options(selectinload(Locale.media))
        .where(Locale.id.in_(locale_ids))
        .where(Locale.is_published.is_(True))
    )
    rows = (await session.execute(stmt)).all()
    # Preserve favorite-creation order.
    by_id = {row[0].id: row for row in rows}
    out: list[LocaleSummary] = []
    for lid in locale_ids:
        row = by_id.get(lid)
        if row is None:
            continue
        locale = row[0]
        wkt = row.wkt
        primary_url: str | None = None
        if locale.media:
            primary = next((m for m in locale.media if m.is_primary), None) or locale.media[0]
            primary_url = primary.url
        # Parse "POINT(lng lat)".
        inner = wkt[wkt.find("(") + 1 : wkt.find(")")]
        parts = inner.split()
        out.append(
            LocaleSummary(
                id=locale.id,
                name=locale.name,
                type=locale.type,
                city=locale.city,
                address=locale.address,
                price_level=locale.price_level,
                rating=locale.rating,
                latitude=float(parts[1]),
                longitude=float(parts[0]),
                distance_m=None,
                primary_media_url=primary_url,
            )
        )
    return out
