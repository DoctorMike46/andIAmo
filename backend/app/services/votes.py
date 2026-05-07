from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError, NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.outing import OutingParticipant
from app.models.outing_vote import VOTE_VALUES, OutingVote
from app.schemas.vote import LocaleVoteSummary


class VoteError(Exception):
    pass


async def _ensure_participant(
    session: AsyncSession, *, outing_id: UUID, user_id: UUID
) -> None:
    row = (
        await session.execute(
            select(OutingParticipant).where(
                OutingParticipant.outing_id == outing_id,
                OutingParticipant.user_id == user_id,
            )
        )
    ).scalar_one_or_none()
    if row is None:
        raise NoResultFound("not a participant of this outing")


async def cast_vote(
    session: AsyncSession,
    *,
    outing_id: UUID,
    user_id: UUID,
    locale_id: UUID,
    vote: str,
) -> OutingVote:
    if vote not in VOTE_VALUES:
        raise VoteError(f"invalid vote; allowed: {', '.join(VOTE_VALUES)}")
    await _ensure_participant(session, outing_id=outing_id, user_id=user_id)

    existing = (
        await session.execute(
            select(OutingVote).where(
                OutingVote.outing_id == outing_id,
                OutingVote.user_id == user_id,
                OutingVote.locale_id == locale_id,
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        existing.vote = vote
        await session.commit()
        await session.refresh(existing)
        return existing

    row = OutingVote(
        outing_id=outing_id,
        user_id=user_id,
        locale_id=locale_id,
        vote=vote,
    )
    session.add(row)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise
    await session.refresh(row)
    return row


async def remove_vote(
    session: AsyncSession,
    *,
    outing_id: UUID,
    user_id: UUID,
    locale_id: UUID,
) -> None:
    await _ensure_participant(session, outing_id=outing_id, user_id=user_id)
    row = (
        await session.execute(
            select(OutingVote).where(
                OutingVote.outing_id == outing_id,
                OutingVote.user_id == user_id,
                OutingVote.locale_id == locale_id,
            )
        )
    ).scalar_one_or_none()
    if row is None:
        raise NoResultFound("vote not found")
    await session.delete(row)
    await session.commit()


async def summary_for_outing(
    session: AsyncSession,
    *,
    outing_id: UUID,
    requester_id: UUID,
    locale_ids: list[UUID] | None = None,
) -> list[LocaleVoteSummary]:
    """Aggregate votes per locale_id, including the requester's own vote.

    When `locale_ids` is None, returns aggregates for every locale that has at
    least one vote in this outing.
    """
    stmt = select(OutingVote).where(OutingVote.outing_id == outing_id)
    if locale_ids is not None:
        if not locale_ids:
            return []
        stmt = stmt.where(OutingVote.locale_id.in_(locale_ids))
    result = await session.execute(stmt)
    rows = list(result.scalars())

    if locale_ids is None:
        locale_ids = sorted({r.locale_id for r in rows})

    by_locale: dict[UUID, dict[str, object]] = {
        lid: {"likes": 0, "dislikes": 0, "my_vote": None} for lid in locale_ids
    }
    for r in rows:
        bucket = by_locale[r.locale_id]
        if r.vote == "like":
            bucket["likes"] = (bucket["likes"] or 0) + 1  # type: ignore[operator]
        else:
            bucket["dislikes"] = (bucket["dislikes"] or 0) + 1  # type: ignore[operator]
        if r.user_id == requester_id:
            bucket["my_vote"] = r.vote

    return [
        LocaleVoteSummary(
            locale_id=lid,
            likes=int(b["likes"]),  # type: ignore[arg-type]
            dislikes=int(b["dislikes"]),  # type: ignore[arg-type]
            score=int(b["likes"]) - int(b["dislikes"]),  # type: ignore[arg-type]
            my_vote=b["my_vote"],  # type: ignore[arg-type]
        )
        for lid, b in by_locale.items()
    ]
