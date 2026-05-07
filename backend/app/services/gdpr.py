"""GDPR-related operations: data export and account deletion."""
from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.preferences import Consent, UserPreference
from app.models.recommendation_log import RecommendationLog
from app.models.user import User


def _isoformat(value: datetime | None) -> str | None:
    return value.isoformat() if value is not None else None


async def export_user_data(session: AsyncSession, *, user_id: UUID) -> dict[str, Any]:
    """Return a structured dump of all personal data we hold for this user."""
    user = await session.get(User, user_id)
    if user is None:
        return {}

    prefs_result = await session.execute(
        select(UserPreference).where(UserPreference.user_id == user_id)
    )
    prefs = prefs_result.scalar_one_or_none()

    consents_result = await session.execute(
        select(Consent).where(Consent.user_id == user_id).order_by(Consent.created_at)
    )
    consents = list(consents_result.scalars())

    logs_result = await session.execute(
        select(RecommendationLog)
        .where(RecommendationLog.user_id == user_id)
        .order_by(RecommendationLog.created_at)
    )
    logs = list(logs_result.scalars())

    return {
        "exported_at": datetime.utcnow().isoformat() + "Z",
        "format_version": "1.0",
        "user": {
            "id": str(user.id),
            "email": user.email,
            "full_name": user.full_name,
            "is_active": user.is_active,
            "is_email_verified": user.is_email_verified,
            "created_at": _isoformat(user.created_at),
            "updated_at": _isoformat(user.updated_at),
        },
        "preferences": (
            {
                "cuisines": list(prefs.cuisines),
                "moods": list(prefs.moods),
                "dietary": list(prefs.dietary),
                "avoid_types": list(prefs.avoid_types),
                "budget_max": prefs.budget_max,
                "max_distance_km": prefs.max_distance_km,
                "embedding_set": prefs.embedding is not None,
                "created_at": _isoformat(prefs.created_at),
                "updated_at": _isoformat(prefs.updated_at),
            }
            if prefs is not None
            else None
        ),
        "consents": [
            {
                "purpose": c.purpose,
                "granted": c.granted,
                "version": c.version,
                "granted_at": _isoformat(c.granted_at),
                "withdrawn_at": _isoformat(c.withdrawn_at),
                "recorded_at": _isoformat(c.created_at),
            }
            for c in consents
        ],
        "recommendation_history": [
            {
                "requested_at": _isoformat(log.created_at),
                "lat": log.requested_lat,
                "lng": log.requested_lng,
                "locale_ids": [str(lid) for lid in log.locale_ids],
            }
            for log in logs
        ],
    }


async def delete_user(session: AsyncSession, *, user_id: UUID) -> None:
    """Hard-delete a user. ON DELETE CASCADE removes preferences, consents,
    and recommendation logs automatically.
    """
    await session.execute(delete(User).where(User.id == user_id))
    await session.commit()
