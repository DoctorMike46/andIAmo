from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.friendship import Friendship
from app.models.user import User
from app.schemas.friendship import UserCard


class FriendError(Exception):
    pass


class SelfFriendError(FriendError):
    pass


class AlreadyFriendsError(FriendError):
    pass


class UserNotFoundError(FriendError):
    pass


class NotAuthorizedError(FriendError):
    pass


async def search_users(
    session: AsyncSession, *, query: str, current_user_id: UUID, limit: int = 10
) -> list[UserCard]:
    q = query.strip().lower()
    if not q:
        return []
    stmt = (
        select(User)
        .where(User.id != current_user_id)
        .where(User.is_active.is_(True))
        .where(
            or_(
                User.email.ilike(f"%{q}%"),
                User.full_name.ilike(f"%{q}%"),
            )
        )
        .limit(limit)
    )
    result = await session.execute(stmt)
    return [UserCard.model_validate(u) for u in result.scalars()]


async def send_request(
    session: AsyncSession, *, requester_id: UUID, target_email: str
) -> Friendship:
    target = (
        await session.execute(select(User).where(User.email == target_email.lower()))
    ).scalar_one_or_none()
    if target is None:
        raise UserNotFoundError("user not found")
    if target.id == requester_id:
        raise SelfFriendError("cannot friend yourself")

    # Check existing pair in either direction.
    existing = (
        await session.execute(
            select(Friendship).where(
                or_(
                    (Friendship.requester_id == requester_id) & (Friendship.addressee_id == target.id),
                    (Friendship.requester_id == target.id) & (Friendship.addressee_id == requester_id),
                )
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        if existing.status == "accepted":
            raise AlreadyFriendsError("already friends")
        if existing.status == "pending":
            raise AlreadyFriendsError("request already pending")
        # rejected → allow re-sending by replacing
        await session.delete(existing)
        await session.flush()

    fr = Friendship(
        requester_id=requester_id,
        addressee_id=target.id,
        status="pending",
    )
    session.add(fr)
    await session.commit()
    await session.refresh(fr)
    return fr


async def respond_to_request(
    session: AsyncSession, *, friendship_id: UUID, current_user_id: UUID, accept: bool
) -> Friendship:
    fr = await session.get(Friendship, friendship_id)
    if fr is None or fr.status != "pending":
        raise NoResultFound("request not found")
    if fr.addressee_id != current_user_id:
        raise NotAuthorizedError("only the addressee can respond")
    if accept:
        fr.status = "accepted"
        fr.accepted_at = datetime.now(UTC)
    else:
        fr.status = "rejected"
    await session.commit()
    await session.refresh(fr)
    return fr


async def remove_friend(
    session: AsyncSession, *, current_user_id: UUID, other_user_id: UUID
) -> None:
    fr = (
        await session.execute(
            select(Friendship)
            .where(Friendship.status == "accepted")
            .where(
                or_(
                    (Friendship.requester_id == current_user_id) & (Friendship.addressee_id == other_user_id),
                    (Friendship.requester_id == other_user_id) & (Friendship.addressee_id == current_user_id),
                )
            )
        )
    ).scalar_one_or_none()
    if fr is None:
        raise NoResultFound("friendship not found")
    await session.delete(fr)
    await session.commit()


async def list_friends(
    session: AsyncSession, *, user_id: UUID
) -> list[UserCard]:
    """Return accepted friends as user cards, regardless of who sent the request."""
    others_ids = await fetch_friend_user_ids(session, user_id=user_id)
    if not others_ids:
        return []
    users = (
        await session.execute(select(User).where(User.id.in_(others_ids)))
    ).scalars()
    return [UserCard.model_validate(u) for u in users]


async def list_pending_requests(
    session: AsyncSession, *, user_id: UUID, direction: str
) -> list[tuple[Friendship, User]]:
    """direction: 'incoming' (where I am addressee) or 'outgoing' (where I am requester)."""
    if direction == "incoming":
        stmt = (
            select(Friendship, User)
            .join(User, User.id == Friendship.requester_id)
            .where(Friendship.addressee_id == user_id)
            .where(Friendship.status == "pending")
        )
    else:
        stmt = (
            select(Friendship, User)
            .join(User, User.id == Friendship.addressee_id)
            .where(Friendship.requester_id == user_id)
            .where(Friendship.status == "pending")
        )
    result = await session.execute(stmt)
    return [(fr, u) for fr, u in result.all()]


async def fetch_friend_user_ids(
    session: AsyncSession, *, user_id: UUID
) -> list[UUID]:
    """Return the user ids of all accepted friends."""
    result = await session.execute(
        select(Friendship)
        .where(Friendship.status == "accepted")
        .where(
            or_(
                Friendship.requester_id == user_id,
                Friendship.addressee_id == user_id,
            )
        )
    )
    return [
        fr.addressee_id if fr.requester_id == user_id else fr.requester_id
        for fr in result.scalars()
    ]
