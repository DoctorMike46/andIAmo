from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.message import MessageIn, MessageOut
from app.schemas.outing import AddParticipantIn, OutingCreate, OutingOut, OutingUpdate
from app.schemas.recommendation import RecommendationOut
from app.schemas.vote import LocaleVoteSummary, VoteIn
from app.services import mediation as mediation_service
from app.services import messages as messages_service
from app.services import outings as outings_service
from app.services import recommendations as rec_service
from app.services import votes as votes_service

router = APIRouter()


@router.post("", response_model=OutingOut, status_code=status.HTTP_201_CREATED)
async def create_outing(
    payload: OutingCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> OutingOut:
    try:
        return await outings_service.create_outing(
            session, owner_id=current_user.id, payload=payload
        )
    except outings_service.InvalidParticipantError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc


@router.get("", response_model=list[OutingOut])
async def list_my_outings(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[OutingOut]:
    return await outings_service.list_user_outings(session, user_id=current_user.id)


@router.get("/{outing_id}", response_model=OutingOut)
async def get_outing(
    outing_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> OutingOut:
    return await _get(session, outing_id, current_user.id)


@router.patch("/{outing_id}", response_model=OutingOut)
async def update_outing(
    outing_id: UUID,
    payload: OutingUpdate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> OutingOut:
    try:
        return await outings_service.update_outing(
            session, outing_id=outing_id, requester_id=current_user.id, payload=payload
        )
    except NoResultFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="outing not found"
        ) from exc
    except outings_service.NotAuthorizedError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)
        ) from exc
    except outings_service.OutingError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc


@router.delete("/{outing_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_outing(
    outing_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Response:
    try:
        await outings_service.delete_outing(
            session, outing_id=outing_id, requester_id=current_user.id
        )
    except NoResultFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="outing not found"
        ) from exc
    except outings_service.NotAuthorizedError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)
        ) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{outing_id}/participants", response_model=OutingOut)
async def add_participant(
    outing_id: UUID,
    payload: AddParticipantIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> OutingOut:
    try:
        return await outings_service.add_participant(
            session,
            outing_id=outing_id,
            requester_id=current_user.id,
            user_id=payload.user_id,
        )
    except NoResultFound as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except outings_service.NotAuthorizedError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except outings_service.InvalidParticipantError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.delete("/{outing_id}/participants/{user_id}", response_model=OutingOut)
async def remove_participant(
    outing_id: UUID,
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> OutingOut:
    try:
        return await outings_service.remove_participant(
            session,
            outing_id=outing_id,
            requester_id=current_user.id,
            user_id=user_id,
        )
    except NoResultFound as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except outings_service.NotAuthorizedError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except outings_service.InvalidParticipantError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/{outing_id}/recommendations", response_model=list[RecommendationOut])
async def outing_recommendations(
    outing_id: UUID,
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    when: datetime | None = Query(default=None),
    limit: int = Query(default=20, gt=0, le=50),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[RecommendationOut]:
    if (lat is None) != (lng is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="lat and lng must be provided together",
        )
    # Authorize: ensure caller is part of the outing.
    await _get(session, outing_id, current_user.id)
    user_ids = await outings_service.participant_user_ids(session, outing_id=outing_id)
    return await rec_service.recommend_for_group(
        session,
        user_ids=user_ids,
        lat=lat,
        lng=lng,
        when=when,
        limit=limit,
    )


@router.post("/{outing_id}/votes", status_code=status.HTTP_201_CREATED)
async def cast_vote(
    outing_id: UUID,
    payload: VoteIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    try:
        vote = await votes_service.cast_vote(
            session,
            outing_id=outing_id,
            user_id=current_user.id,
            locale_id=payload.locale_id,
            vote=payload.vote,
        )
    except NoResultFound as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except votes_service.VoteError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return {
        "id": str(vote.id),
        "locale_id": str(vote.locale_id),
        "vote": vote.vote,
    }


@router.delete(
    "/{outing_id}/votes/{locale_id}", status_code=status.HTTP_204_NO_CONTENT
)
async def remove_vote(
    outing_id: UUID,
    locale_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Response:
    try:
        await votes_service.remove_vote(
            session,
            outing_id=outing_id,
            user_id=current_user.id,
            locale_id=locale_id,
        )
    except NoResultFound as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{outing_id}/votes", response_model=list[LocaleVoteSummary])
async def list_votes(
    outing_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[LocaleVoteSummary]:
    # Authorize.
    await _get(session, outing_id, current_user.id)
    return await votes_service.summary_for_outing(
        session,
        outing_id=outing_id,
        requester_id=current_user.id,
    )


# ── Chat ───────────────────────────────────────────────────────────────────


@router.get("/{outing_id}/messages", response_model=list[MessageOut])
async def list_messages(
    outing_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[MessageOut]:
    await _get(session, outing_id, current_user.id)
    return await messages_service.list_messages(session, outing_id=outing_id)


@router.post(
    "/{outing_id}/messages",
    response_model=MessageOut,
    status_code=status.HTTP_201_CREATED,
)
async def post_message(
    outing_id: UUID,
    payload: MessageIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> MessageOut:
    await _get(session, outing_id, current_user.id)
    msg = await messages_service.post_message(
        session,
        outing_id=outing_id,
        user_id=current_user.id,
        body=payload.body,
        kind="text",
    )
    return MessageOut(
        id=msg.id,
        kind=msg.kind,
        body=msg.body,
        user_id=msg.user_id,
        user_name=current_user.full_name or current_user.email,
        created_at=msg.created_at,
    )


# ── AI Mediator ────────────────────────────────────────────────────────────


@router.post("/{outing_id}/mediate")
async def mediate(
    outing_id: UUID,
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    await _get(session, outing_id, current_user.id)
    result = await mediation_service.mediate_outing(
        session, outing_id=outing_id, lat=lat, lng=lng
    )
    # Persist as system message in the chat for everyone to see.
    if result.suggested_locale_id is not None:
        body = (
            f"🤖 Suggerimento AI: {result.rationale}"
            if not result.rationale.startswith("🤖")
            else result.rationale
        )
    else:
        body = result.rationale
    await messages_service.post_message(
        session, outing_id=outing_id, user_id=None, body=body, kind="ai"
    )
    return {
        "suggested_locale_id": result.suggested_locale_id,
        "rationale": result.rationale,
    }


async def _get(session: AsyncSession, outing_id: UUID, user_id: UUID) -> OutingOut:
    try:
        return await outings_service.get_outing(
            session, outing_id=outing_id, requester_id=user_id
        )
    except NoResultFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="outing not found"
        ) from exc
    except outings_service.NotAuthorizedError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)
        ) from exc
