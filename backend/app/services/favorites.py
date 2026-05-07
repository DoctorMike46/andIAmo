from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError, NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.favorite import Favorite
from app.models.locale import Locale


async def add_favorite(
    session: AsyncSession, *, user_id: UUID, locale_id: UUID
) -> Favorite:
    locale = await session.get(Locale, locale_id)
    if locale is None:
        raise NoResultFound("locale not found")
    fav = Favorite(user_id=user_id, locale_id=locale_id)
    session.add(fav)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        # Already favorited — return existing row.
        existing = (
            await session.execute(
                select(Favorite).where(
                    Favorite.user_id == user_id,
                    Favorite.locale_id == locale_id,
                )
            )
        ).scalar_one()
        return existing
    await session.refresh(fav)
    return fav


async def remove_favorite(
    session: AsyncSession, *, user_id: UUID, locale_id: UUID
) -> None:
    fav = (
        await session.execute(
            select(Favorite).where(
                Favorite.user_id == user_id,
                Favorite.locale_id == locale_id,
            )
        )
    ).scalar_one_or_none()
    if fav is None:
        raise NoResultFound("favorite not found")
    await session.delete(fav)
    await session.commit()


async def list_favorite_locale_ids(
    session: AsyncSession, *, user_id: UUID
) -> list[UUID]:
    result = await session.execute(
        select(Favorite.locale_id)
        .where(Favorite.user_id == user_id)
        .order_by(Favorite.created_at.desc())
    )
    return [lid for (lid,) in result.all()]
