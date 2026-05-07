from datetime import datetime, time
from uuid import UUID
from zoneinfo import ZoneInfo

from geoalchemy2 import Geography
from geoalchemy2.functions import ST_AsText, ST_Distance, ST_DWithin, ST_GeomFromText
from sqlalchemy import and_, cast, exists, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.locale import Locale, OpeningHours
from app.models.recommendation_log import RecommendationLog
from app.recommender.engine import (
    LocaleCandidate,
    ScoredLocale,
    TimeWindow,
    UserContext,
    merge_group_context,
    score_locale,
)
from app.schemas.locale import LocaleSummary
from app.schemas.recommendation import RecommendationOut
from app.services.locales import _parse_point  # reuse helper
from app.services.preferences import get_preferences

_ROME_TZ = ZoneInfo("Europe/Rome")
_DEFAULT_LIMIT = 20


def _wkt_point(lng: float, lat: float) -> str:
    return f"POINT({lng} {lat})"


async def recommend_tonight(
    session: AsyncSession,
    *,
    user_id: UUID,
    lat: float | None,
    lng: float | None,
    when: datetime | None,
    limit: int = _DEFAULT_LIMIT,
) -> list[RecommendationOut]:
    when_local = (when or datetime.now(_ROME_TZ)).astimezone(_ROME_TZ)
    weekday = when_local.weekday()
    now_time = when_local.time().replace(microsecond=0)

    prefs = await get_preferences(session, user_id=user_id)
    user_embedding = list(prefs.embedding) if prefs and prefs.embedding is not None else None
    ctx = UserContext(
        moods=prefs.moods if prefs else [],
        cuisines=prefs.cuisines if prefs else [],
        dietary=prefs.dietary if prefs else [],
        avoid_types=prefs.avoid_types if prefs else [],
        budget_max=prefs.budget_max if prefs else 4,
        max_distance_km=prefs.max_distance_km if prefs else 5.0,
        embedding=user_embedding,
    )

    point = (
        ST_GeomFromText(_wkt_point(lng, lat), 4326)
        if lat is not None and lng is not None
        else None
    )
    distance_col = (
        ST_Distance(cast(Locale.location, Geography), cast(point, Geography))
        if point is not None
        else None
    )

    stmt = (
        select(Locale, ST_AsText(Locale.location).label("wkt"))
        .options(
            selectinload(Locale.media),
            selectinload(Locale.opening_hours),
        )
        .where(Locale.is_published.is_(True))
        .where(Locale.price_level <= ctx.budget_max)
    )

    if distance_col is not None:
        stmt = stmt.add_columns(distance_col.label("distance_m"))
        stmt = stmt.where(
            ST_DWithin(
                cast(Locale.location, Geography),
                cast(point, Geography),
                ctx.max_distance_km * 1000.0,
            )
        )

    if ctx.avoid_types:
        stmt = stmt.where(Locale.type.not_in(ctx.avoid_types))

    # Hard filter "open at the requested time".
    prev_weekday = (weekday - 1) % 7
    stmt = stmt.where(
        exists().where(
            and_(
                OpeningHours.locale_id == Locale.id,
                OpeningHours.closed_all_day.is_(False),
                or_(
                    # Normal: today open before now, closes after now.
                    and_(
                        OpeningHours.weekday == weekday,
                        OpeningHours.open_time <= now_time,
                        OpeningHours.close_time > now_time,
                    ),
                    # Cross-midnight: opened yesterday with close < open (after midnight),
                    # and we're still inside the post-midnight tail.
                    and_(
                        OpeningHours.weekday == prev_weekday,
                        OpeningHours.close_time < OpeningHours.open_time,
                        OpeningHours.close_time > now_time,
                    ),
                ),
            )
        )
    )
    stmt = stmt.limit(200)  # cap candidates before scoring

    result = await session.execute(stmt)
    rows = result.all()

    scored: list[tuple[ScoredLocale, Locale, str, float | None]] = []
    for row in rows:
        locale: Locale = row[0]
        wkt = row.wkt
        distance_m = row.distance_m if distance_col is not None else None
        distance_km = (distance_m / 1000.0) if distance_m is not None else None
        locale_embedding = list(locale.embedding) if locale.embedding is not None else None
        candidate = LocaleCandidate(
            id=str(locale.id),
            name=locale.name,
            type=locale.type,
            price_level=locale.price_level,
            rating=float(locale.rating) if locale.rating is not None else None,
            distance_km=distance_km,
            embedding=locale_embedding,
        )
        window = _matching_window(locale, weekday, now_time)
        scored_locale = score_locale(candidate, ctx, window=window, now=now_time)
        scored.append((scored_locale, locale, wkt, distance_m))

    scored.sort(key=lambda x: x[0].score, reverse=True)
    top = scored[:limit]

    log = RecommendationLog(
        user_id=user_id,
        requested_lat=lat,
        requested_lng=lng,
        locale_ids=[t[1].id for t in top],
    )
    session.add(log)
    await session.commit()

    out: list[RecommendationOut] = []
    for sl, locale, wkt, distance_m in top:
        primary_url: str | None = None
        if locale.media:
            primary = next((m for m in locale.media if m.is_primary), None) or locale.media[0]
            primary_url = primary.url
        lng_, lat_ = _parse_point(wkt)
        out.append(
            RecommendationOut(
                **LocaleSummary(
                    id=locale.id,
                    name=locale.name,
                    type=locale.type,
                    city=locale.city,
                    address=locale.address,
                    price_level=locale.price_level,
                    rating=locale.rating,
                    latitude=lat_,
                    longitude=lng_,
                    distance_m=distance_m,
                    primary_media_url=primary_url,
                ).model_dump(),
                score=sl.score,
                reasons=sl.reasons,
            )
        )
    return out


async def recommend_for_group(
    session: AsyncSession,
    *,
    user_ids: list[UUID],
    lat: float | None,
    lng: float | None,
    when: datetime | None,
    limit: int = _DEFAULT_LIMIT,
) -> list[RecommendationOut]:
    """Same scoring as `recommend_tonight` but with a merged group context.

    The group context unions each user's preferences for cuisines/moods/dietary,
    takes the strictest budget/radius, and averages embeddings.
    """
    if not user_ids:
        return []

    when_local = (when or datetime.now(_ROME_TZ)).astimezone(_ROME_TZ)
    weekday = when_local.weekday()
    now_time = when_local.time().replace(microsecond=0)

    # Build per-user contexts.
    contexts: list[UserContext] = []
    for uid in user_ids:
        prefs = await get_preferences(session, user_id=uid)
        contexts.append(
            UserContext(
                moods=prefs.moods if prefs else [],
                cuisines=prefs.cuisines if prefs else [],
                dietary=prefs.dietary if prefs else [],
                avoid_types=prefs.avoid_types if prefs else [],
                budget_max=prefs.budget_max if prefs else 4,
                max_distance_km=prefs.max_distance_km if prefs else 5.0,
                embedding=list(prefs.embedding) if prefs and prefs.embedding is not None else None,
            )
        )
    ctx = merge_group_context(contexts)

    point = (
        ST_GeomFromText(_wkt_point(lng, lat), 4326)
        if lat is not None and lng is not None
        else None
    )
    distance_col = (
        ST_Distance(cast(Locale.location, Geography), cast(point, Geography))
        if point is not None
        else None
    )

    stmt = (
        select(Locale, ST_AsText(Locale.location).label("wkt"))
        .options(
            selectinload(Locale.media),
            selectinload(Locale.opening_hours),
        )
        .where(Locale.is_published.is_(True))
        .where(Locale.price_level <= ctx.budget_max)
    )
    if distance_col is not None:
        stmt = stmt.add_columns(distance_col.label("distance_m"))
        stmt = stmt.where(
            ST_DWithin(
                cast(Locale.location, Geography),
                cast(point, Geography),
                ctx.max_distance_km * 1000.0,
            )
        )
    if ctx.avoid_types:
        stmt = stmt.where(Locale.type.not_in(ctx.avoid_types))
    prev_weekday = (weekday - 1) % 7
    stmt = stmt.where(
        exists().where(
            and_(
                OpeningHours.locale_id == Locale.id,
                OpeningHours.closed_all_day.is_(False),
                or_(
                    # Normal: today open before now, closes after now.
                    and_(
                        OpeningHours.weekday == weekday,
                        OpeningHours.open_time <= now_time,
                        OpeningHours.close_time > now_time,
                    ),
                    # Cross-midnight: opened yesterday with close < open (after midnight),
                    # and we're still inside the post-midnight tail.
                    and_(
                        OpeningHours.weekday == prev_weekday,
                        OpeningHours.close_time < OpeningHours.open_time,
                        OpeningHours.close_time > now_time,
                    ),
                ),
            )
        )
    )
    stmt = stmt.limit(200)

    result = await session.execute(stmt)
    rows = result.all()

    scored: list[tuple[ScoredLocale, Locale, str, float | None]] = []
    for row in rows:
        locale: Locale = row[0]
        wkt = row.wkt
        distance_m = row.distance_m if distance_col is not None else None
        distance_km = (distance_m / 1000.0) if distance_m is not None else None
        locale_embedding = list(locale.embedding) if locale.embedding is not None else None
        candidate = LocaleCandidate(
            id=str(locale.id),
            name=locale.name,
            type=locale.type,
            price_level=locale.price_level,
            rating=float(locale.rating) if locale.rating is not None else None,
            distance_km=distance_km,
            embedding=locale_embedding,
        )
        window = _matching_window(locale, weekday, now_time)
        scored_locale = score_locale(candidate, ctx, window=window, now=now_time)
        scored.append((scored_locale, locale, wkt, distance_m))

    scored.sort(key=lambda x: x[0].score, reverse=True)
    top = scored[:limit]

    out: list[RecommendationOut] = []
    for sl, locale, wkt, distance_m in top:
        primary_url: str | None = None
        if locale.media:
            primary = next((m for m in locale.media if m.is_primary), None) or locale.media[0]
            primary_url = primary.url
        lng_, lat_ = _parse_point(wkt)
        out.append(
            RecommendationOut(
                **LocaleSummary(
                    id=locale.id,
                    name=locale.name,
                    type=locale.type,
                    city=locale.city,
                    address=locale.address,
                    price_level=locale.price_level,
                    rating=locale.rating,
                    latitude=lat_,
                    longitude=lng_,
                    distance_m=distance_m,
                    primary_media_url=primary_url,
                ).model_dump(),
                score=sl.score,
                reasons=sl.reasons,
            )
        )
    return out


def _matching_window(locale: Locale, weekday: int, now: time) -> TimeWindow | None:
    """Return the OpeningHours row that covers `now` for this locale.

    Tries today's row first, then yesterday's if it crosses midnight and
    includes the current early-morning time.
    """
    today = next(
        (h for h in locale.opening_hours if h.weekday == weekday and not h.closed_all_day),
        None,
    )
    if today is not None:
        if today.open_time <= today.close_time:
            if today.open_time <= now < today.close_time:
                return TimeWindow(open_time=today.open_time, close_time=today.close_time)
        else:
            # Cross-midnight: open today from open_time to 23:59, plus 00:00 to close_time.
            if now >= today.open_time or now < today.close_time:
                return TimeWindow(open_time=today.open_time, close_time=today.close_time)

    prev = (weekday - 1) % 7
    yesterday = next(
        (h for h in locale.opening_hours if h.weekday == prev and not h.closed_all_day),
        None,
    )
    if yesterday is not None and yesterday.close_time < yesterday.open_time:
        if now < yesterday.close_time:
            return TimeWindow(
                open_time=yesterday.open_time, close_time=yesterday.close_time
            )
    return None
