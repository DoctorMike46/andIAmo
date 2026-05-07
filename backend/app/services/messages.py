from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.outing_message import OutingMessage
from app.models.user import User
from app.schemas.message import MessageOut


async def list_messages(
    session: AsyncSession,
    *,
    outing_id: UUID,
    after: UUID | None = None,
    limit: int = 200,
) -> list[MessageOut]:
    """Return messages of the outing, oldest first.

    `after` is unused for now; reserved for cursor-based pagination later.
    Joins users to enrich author display name.
    """
    stmt = (
        select(OutingMessage, User)
        .outerjoin(User, User.id == OutingMessage.user_id)
        .where(OutingMessage.outing_id == outing_id)
        .order_by(OutingMessage.created_at.asc())
        .limit(limit)
    )
    rows = (await session.execute(stmt)).all()
    out: list[MessageOut] = []
    for msg, user in rows:
        out.append(
            MessageOut(
                id=msg.id,
                kind=msg.kind,
                body=msg.body,
                user_id=msg.user_id,
                user_name=(user.full_name or user.email) if user else None,
                created_at=msg.created_at,
            )
        )
    return out


async def post_message(
    session: AsyncSession,
    *,
    outing_id: UUID,
    user_id: UUID | None,
    body: str,
    kind: str = "text",
) -> OutingMessage:
    msg = OutingMessage(
        outing_id=outing_id,
        user_id=user_id,
        body=body,
        kind=kind,
    )
    session.add(msg)
    await session.commit()
    await session.refresh(msg)
    return msg
