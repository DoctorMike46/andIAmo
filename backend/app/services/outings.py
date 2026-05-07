from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.outing import OUTING_STATUSES, Outing, OutingParticipant
from app.models.user import User
from app.schemas.friendship import UserCard
from app.schemas.outing import OutingCreate, OutingOut, OutingUpdate
from app.services.friends import fetch_friend_user_ids


class OutingError(Exception):
    pass


class NotAuthorizedError(OutingError):
    pass


class InvalidParticipantError(OutingError):
    pass


async def _user_card(session: AsyncSession, user_id: UUID) -> UserCard:
    user = await session.get(User, user_id)
    if user is None:
        # Should never happen given FK cascades, but be defensive.
        return UserCard(id=user_id, email="<unknown>", full_name=None)
    return UserCard.model_validate(user)


async def _to_out(session: AsyncSession, outing: Outing) -> OutingOut:
    owner = await _user_card(session, outing.owner_id)
    participants: list[UserCard] = []
    for p in outing.participants:
        participants.append(await _user_card(session, p.user_id))
    return OutingOut(
        id=outing.id,
        title=outing.title,
        when_dt=outing.when_dt,
        status=outing.status,
        chosen_locale_id=outing.chosen_locale_id,
        owner=owner,
        participants=participants,
        created_at=outing.created_at,
    )


async def create_outing(
    session: AsyncSession, *, owner_id: UUID, payload: OutingCreate
) -> OutingOut:
    # Validate that all proposed participants are accepted friends.
    if payload.participant_ids:
        friend_ids = set(await fetch_friend_user_ids(session, user_id=owner_id))
        for pid in payload.participant_ids:
            if pid != owner_id and pid not in friend_ids:
                raise InvalidParticipantError(
                    f"user {pid} is not in your friends"
                )

    outing = Outing(
        owner_id=owner_id,
        title=payload.title,
        when_dt=payload.when_dt,
        status="planning",
    )
    session.add(outing)
    await session.flush()

    # Owner is always a participant.
    rows: dict[UUID, OutingParticipant] = {
        owner_id: OutingParticipant(outing_id=outing.id, user_id=owner_id)
    }
    for pid in payload.participant_ids:
        rows.setdefault(pid, OutingParticipant(outing_id=outing.id, user_id=pid))
    session.add_all(rows.values())
    await session.commit()

    return await get_outing(session, outing_id=outing.id, requester_id=owner_id)


async def list_user_outings(
    session: AsyncSession, *, user_id: UUID
) -> list[OutingOut]:
    """Return every outing the user owns or is invited to."""
    stmt = (
        select(Outing)
        .options(selectinload(Outing.participants))
        .join(OutingParticipant, OutingParticipant.outing_id == Outing.id)
        .where(
            or_(Outing.owner_id == user_id, OutingParticipant.user_id == user_id)
        )
        .order_by(Outing.created_at.desc())
        .distinct()
    )
    result = await session.execute(stmt)
    outings = list(result.scalars().unique())
    return [await _to_out(session, o) for o in outings]


async def get_outing(
    session: AsyncSession, *, outing_id: UUID, requester_id: UUID
) -> OutingOut:
    stmt = (
        select(Outing)
        .options(selectinload(Outing.participants))
        .where(Outing.id == outing_id)
    )
    outing = (await session.execute(stmt)).scalar_one_or_none()
    if outing is None:
        raise NoResultFound("outing not found")
    participant_ids = {p.user_id for p in outing.participants}
    if requester_id != outing.owner_id and requester_id not in participant_ids:
        raise NotAuthorizedError("you are not part of this outing")
    return await _to_out(session, outing)


async def update_outing(
    session: AsyncSession,
    *,
    outing_id: UUID,
    requester_id: UUID,
    payload: OutingUpdate,
) -> OutingOut:
    outing = await session.get(Outing, outing_id)
    if outing is None:
        raise NoResultFound("outing not found")
    if outing.owner_id != requester_id:
        raise NotAuthorizedError("only the owner can update")
    if payload.title is not None:
        outing.title = payload.title
    if payload.when_dt is not None:
        outing.when_dt = payload.when_dt
    if payload.status is not None:
        if payload.status not in OUTING_STATUSES:
            raise OutingError(
                f"invalid status; allowed: {', '.join(OUTING_STATUSES)}"
            )
        outing.status = payload.status
    if payload.chosen_locale_id is not None:
        outing.chosen_locale_id = payload.chosen_locale_id
    await session.commit()
    return await get_outing(
        session, outing_id=outing.id, requester_id=requester_id
    )


async def add_participant(
    session: AsyncSession,
    *,
    outing_id: UUID,
    requester_id: UUID,
    user_id: UUID,
) -> OutingOut:
    outing = await session.get(Outing, outing_id)
    if outing is None:
        raise NoResultFound("outing not found")
    if outing.owner_id != requester_id:
        raise NotAuthorizedError("only the owner can add participants")
    friend_ids = set(
        await fetch_friend_user_ids(session, user_id=requester_id)
    )
    if user_id != requester_id and user_id not in friend_ids:
        raise InvalidParticipantError("user is not in your friends")
    existing = (
        await session.execute(
            select(OutingParticipant).where(
                OutingParticipant.outing_id == outing_id,
                OutingParticipant.user_id == user_id,
            )
        )
    ).scalar_one_or_none()
    if existing is None:
        session.add(OutingParticipant(outing_id=outing_id, user_id=user_id))
        await session.commit()
    return await get_outing(
        session, outing_id=outing.id, requester_id=requester_id
    )


async def remove_participant(
    session: AsyncSession,
    *,
    outing_id: UUID,
    requester_id: UUID,
    user_id: UUID,
) -> OutingOut:
    outing = await session.get(Outing, outing_id)
    if outing is None:
        raise NoResultFound("outing not found")
    if outing.owner_id != requester_id:
        raise NotAuthorizedError("only the owner can remove participants")
    if user_id == outing.owner_id:
        raise InvalidParticipantError("cannot remove the owner")
    row = (
        await session.execute(
            select(OutingParticipant).where(
                OutingParticipant.outing_id == outing_id,
                OutingParticipant.user_id == user_id,
            )
        )
    ).scalar_one_or_none()
    if row is not None:
        await session.delete(row)
        await session.commit()
    return await get_outing(
        session, outing_id=outing.id, requester_id=requester_id
    )


async def delete_outing(
    session: AsyncSession, *, outing_id: UUID, requester_id: UUID
) -> None:
    outing = await session.get(Outing, outing_id)
    if outing is None:
        raise NoResultFound("outing not found")
    if outing.owner_id != requester_id:
        raise NotAuthorizedError("only the owner can delete")
    await session.delete(outing)
    await session.commit()


async def participant_user_ids(
    session: AsyncSession, *, outing_id: UUID
) -> list[UUID]:
    result = await session.execute(
        select(OutingParticipant.user_id).where(
            OutingParticipant.outing_id == outing_id
        )
    )
    return [uid for (uid,) in result.all()]
