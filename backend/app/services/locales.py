from datetime import datetime
from uuid import UUID
from zoneinfo import ZoneInfo

from geoalchemy2 import Geography
from geoalchemy2.functions import ST_AsText, ST_Distance, ST_DWithin, ST_GeomFromText
from sqlalchemy import cast, delete, select
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.locale import Locale, LocaleMedia, OpeningHours
from app.schemas.locale import (
    LocaleDetail,
    LocaleMediaOut,
    LocaleSummary,
    LocaleWrite,
    OpeningHoursOut,
)
from app.services.opening_hours import is_open_at_clause

_ROME_TZ = ZoneInfo("Europe/Rome")


def _wkt_point(lng: float, lat: float) -> str:
    return f"POINT({lng} {lat})"


def _to_summary(
    locale: Locale,
    *,
    distance_m: float | None,
    point_wkt: str | None,
) -> LocaleSummary:
    primary_url: str | None = None
    if locale.media:
        primary = next((m for m in locale.media if m.is_primary), None) or locale.media[0]
        primary_url = primary.url

    longitude, latitude = _parse_point(point_wkt)
    return LocaleSummary(
        id=locale.id,
        name=locale.name,
        type=locale.type,
        city=locale.city,
        address=locale.address,
        price_level=locale.price_level,
        rating=locale.rating,
        latitude=latitude,
        longitude=longitude,
        distance_m=distance_m,
        primary_media_url=primary_url,
    )


def _parse_point(wkt: str | None) -> tuple[float, float]:
    """Parse 'POINT(lng lat)' into (lng, lat). Returns (0,0) on failure."""
    if not wkt:
        return 0.0, 0.0
    inner = wkt[wkt.find("(") + 1 : wkt.find(")")]
    parts = inner.split()
    return float(parts[0]), float(parts[1])


async def list_locales(
    session: AsyncSession,
    *,
    locale_type: str | None,
    city: str | None,
    lat: float | None,
    lng: float | None,
    radius_km: float | None,
    open_now: bool,
    limit: int,
) -> list[LocaleSummary]:
    point = (
        ST_GeomFromText(_wkt_point(lng, lat), 4326)
        if lat is not None and lng is not None
        else None
    )

    distance_col = (
        ST_Distance(
            cast(Locale.location, Geography),
            cast(point, Geography),
        )
        if point is not None
        else None
    )

    stmt = select(Locale, ST_AsText(Locale.location).label("wkt"))
    if distance_col is not None:
        stmt = stmt.add_columns(distance_col.label("distance_m"))

    stmt = stmt.options(selectinload(Locale.media)).where(Locale.is_published.is_(True))

    if locale_type is not None:
        stmt = stmt.where(Locale.type == locale_type)
    if city is not None:
        stmt = stmt.where(Locale.city.ilike(city))

    if point is not None and radius_km is not None:
        stmt = stmt.where(
            ST_DWithin(
                cast(Locale.location, Geography),
                cast(point, Geography),
                radius_km * 1000.0,
            )
        )

    if open_now:
        now_local = datetime.now(_ROME_TZ)
        now_time = now_local.time().replace(microsecond=0)
        stmt = stmt.where(is_open_at_clause(now_local.weekday(), now_time))

    if distance_col is not None:
        stmt = stmt.order_by(distance_col)
    else:
        stmt = stmt.order_by(Locale.name)
    stmt = stmt.limit(limit)

    result = await session.execute(stmt)
    rows = result.all()

    summaries: list[LocaleSummary] = []
    for row in rows:
        locale = row[0]
        wkt = row.wkt
        distance_m = row.distance_m if distance_col is not None else None
        summaries.append(_to_summary(locale, distance_m=distance_m, point_wkt=wkt))
    return summaries


async def get_locale(
    session: AsyncSession,
    *,
    locale_id: UUID,
    lat: float | None,
    lng: float | None,
) -> LocaleDetail:
    stmt = (
        select(Locale, ST_AsText(Locale.location).label("wkt"))
        .options(
            selectinload(Locale.media),
            selectinload(Locale.opening_hours),
        )
        .where(Locale.id == locale_id, Locale.is_published.is_(True))
    )
    if lat is not None and lng is not None:
        point = ST_GeomFromText(_wkt_point(lng, lat), 4326)
        stmt = stmt.add_columns(
            ST_Distance(
                cast(Locale.location, Geography),
                cast(point, Geography),
            ).label("distance_m"),
        )

    result = await session.execute(stmt)
    row = result.one_or_none()
    if row is None:
        raise NoResultFound(f"locale {locale_id} not found")

    locale: Locale = row[0]
    distance_m = row.distance_m if "distance_m" in row._mapping else None
    summary = _to_summary(locale, distance_m=distance_m, point_wkt=row.wkt)

    return LocaleDetail(
        **summary.model_dump(),
        description=locale.description,
        phone=locale.phone,
        website=locale.website,
        media=[LocaleMediaOut.model_validate(m) for m in locale.media],
        opening_hours=[OpeningHoursOut.model_validate(h) for h in locale.opening_hours],
    )


# ── Admin write operations ──────────────────────────────────────────────────


def _apply_write_payload(locale: Locale, payload: LocaleWrite) -> None:
    locale.name = payload.name
    locale.type = payload.type
    locale.description = payload.description
    locale.address = payload.address
    locale.city = payload.city
    locale.price_level = payload.price_level
    locale.rating = payload.rating
    locale.phone = payload.phone
    locale.website = payload.website
    locale.location = ST_GeomFromText(
        _wkt_point(payload.longitude, payload.latitude), 4326
    )
    locale.is_published = payload.is_published


async def create_locale(session: AsyncSession, *, payload: LocaleWrite) -> Locale:
    payload.validate_type()
    locale = Locale()
    _apply_write_payload(locale, payload)
    locale.media = [
        LocaleMedia(url=m.url, is_primary=m.is_primary, sort_order=m.sort_order)
        for m in payload.media
    ]
    locale.opening_hours = [
        OpeningHours(
            weekday=h.weekday,
            open_time=h.open_time,
            close_time=h.close_time,
            closed_all_day=h.closed_all_day,
        )
        for h in payload.opening_hours
    ]
    session.add(locale)
    await session.commit()
    await session.refresh(locale)
    return locale


async def update_locale(
    session: AsyncSession, *, locale_id: UUID, payload: LocaleWrite
) -> Locale:
    payload.validate_type()
    stmt = (
        select(Locale)
        .options(selectinload(Locale.media), selectinload(Locale.opening_hours))
        .where(Locale.id == locale_id)
    )
    locale = (await session.execute(stmt)).scalar_one_or_none()
    if locale is None:
        raise NoResultFound(f"locale {locale_id} not found")

    _apply_write_payload(locale, payload)

    # Replace nested collections wholesale — simpler than diff/merge for MVP.
    await session.execute(
        delete(LocaleMedia).where(LocaleMedia.locale_id == locale_id)
    )
    await session.execute(
        delete(OpeningHours).where(OpeningHours.locale_id == locale_id)
    )
    locale.media = [
        LocaleMedia(url=m.url, is_primary=m.is_primary, sort_order=m.sort_order)
        for m in payload.media
    ]
    locale.opening_hours = [
        OpeningHours(
            weekday=h.weekday,
            open_time=h.open_time,
            close_time=h.close_time,
            closed_all_day=h.closed_all_day,
        )
        for h in payload.opening_hours
    ]
    locale.embedding = None  # invalidate; will be re-generated by categorizer
    await session.commit()
    await session.refresh(locale)
    return locale


async def delete_locale(session: AsyncSession, *, locale_id: UUID) -> None:
    result = await session.execute(delete(Locale).where(Locale.id == locale_id))
    if result.rowcount == 0:
        raise NoResultFound(f"locale {locale_id} not found")
    await session.commit()
