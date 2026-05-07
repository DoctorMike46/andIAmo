from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.preferences import CONSENT_PURPOSES, Consent, UserPreference
from app.schemas.preferences import ConsentIn, PreferencesIn

REQUIRED_CONSENTS = ("terms_of_service", "privacy_policy")


class InvalidPurposeError(Exception):
    pass


async def get_preferences(session: AsyncSession, *, user_id: UUID) -> UserPreference | None:
    result = await session.execute(
        select(UserPreference).where(UserPreference.user_id == user_id)
    )
    return result.scalar_one_or_none()


async def upsert_preferences(
    session: AsyncSession, *, user_id: UUID, payload: PreferencesIn
) -> UserPreference:
    existing = await get_preferences(session, user_id=user_id)
    if existing is None:
        existing = UserPreference(user_id=user_id, **payload.model_dump())
        session.add(existing)
    else:
        for field, value in payload.model_dump().items():
            setattr(existing, field, value)
    await session.commit()
    await session.refresh(existing)

    # Refresh AI profile vector. With mock embeddings this is instantaneous;
    # with real Voyage it adds ~200-500ms. Acceptable for onboarding/update flows.
    from app.ai.user_profile import embed_user_preferences

    await embed_user_preferences(session, existing)
    return existing


async def record_consent(
    session: AsyncSession, *, user_id: UUID, payload: ConsentIn
) -> Consent:
    if payload.purpose not in CONSENT_PURPOSES:
        raise InvalidPurposeError(
            f"unknown purpose; allowed: {', '.join(CONSENT_PURPOSES)}"
        )
    now = datetime.now(UTC)
    consent = Consent(
        user_id=user_id,
        purpose=payload.purpose,
        version=payload.version,
        granted=payload.granted,
        granted_at=now,
        withdrawn_at=None if payload.granted else now,
    )
    session.add(consent)
    await session.commit()
    await session.refresh(consent)
    return consent


async def list_current_consents(
    session: AsyncSession, *, user_id: UUID
) -> dict[str, Consent]:
    """Return the latest consent record per purpose for a user."""
    result = await session.execute(
        select(Consent)
        .where(Consent.user_id == user_id)
        .order_by(Consent.purpose, Consent.created_at.desc())
    )
    latest: dict[str, Consent] = {}
    for consent in result.scalars():
        if consent.purpose not in latest:
            latest[consent.purpose] = consent
    return latest


async def is_onboarded(session: AsyncSession, *, user_id: UUID) -> bool:
    """Onboarded = has UserPreference + has all REQUIRED_CONSENTS granted."""
    prefs = await get_preferences(session, user_id=user_id)
    if prefs is None:
        return False
    consents = await list_current_consents(session, user_id=user_id)
    return all(
        purpose in consents and consents[purpose].granted
        for purpose in REQUIRED_CONSENTS
    )
