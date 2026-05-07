from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.preferences import ConsentIn, ConsentOut, PreferencesIn, PreferencesOut
from app.schemas.user import UserOut
from app.services import gdpr as gdpr_service
from app.services import preferences as prefs_service

router = APIRouter()


@router.get("/me", response_model=UserOut)
async def read_me(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> UserOut:
    onboarded = await prefs_service.is_onboarded(session, user_id=current_user.id)
    return UserOut.model_validate(current_user).model_copy(update={"onboarded": onboarded})


@router.get("/me/preferences", response_model=PreferencesOut)
async def get_preferences(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> PreferencesOut:
    prefs = await prefs_service.get_preferences(session, user_id=current_user.id)
    if prefs is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="preferences not set"
        )
    return PreferencesOut.model_validate(prefs)


@router.put("/me/preferences", response_model=PreferencesOut)
async def upsert_preferences(
    payload: PreferencesIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> PreferencesOut:
    prefs = await prefs_service.upsert_preferences(
        session, user_id=current_user.id, payload=payload
    )
    return PreferencesOut.model_validate(prefs)


@router.post(
    "/me/consents",
    response_model=ConsentOut,
    status_code=status.HTTP_201_CREATED,
)
async def record_consent(
    payload: ConsentIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> ConsentOut:
    try:
        consent = await prefs_service.record_consent(
            session, user_id=current_user.id, payload=payload
        )
    except prefs_service.InvalidPurposeError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    return ConsentOut.model_validate(consent)


@router.get("/me/consents", response_model=list[ConsentOut])
async def list_consents(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[ConsentOut]:
    latest = await prefs_service.list_current_consents(session, user_id=current_user.id)
    return [ConsentOut.model_validate(c) for c in latest.values()]


@router.get("/me/export")
async def export_my_data(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    """GDPR Art. 15 — return all personal data we hold for this user."""
    return await gdpr_service.export_user_data(session, user_id=current_user.id)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_account(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Response:
    """GDPR Art. 17 — hard-delete the account. Cascade removes all linked data."""
    await gdpr_service.delete_user(session, user_id=current_user.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
