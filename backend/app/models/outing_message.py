from uuid import UUID

from sqlalchemy import CheckConstraint, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin

# - "text"        free message from a participant
# - "system"      auto-generated event (vote recap, status change)
# - "ai"          AI mediator suggestion
MESSAGE_KINDS = ("text", "system", "ai")


class OutingMessage(Base, UUIDPkMixin, TimestampMixin):
    """A message inside an outing chat. Author is null for system/ai messages."""

    __tablename__ = "outing_messages"
    __table_args__ = (
        CheckConstraint(
            f"kind IN {MESSAGE_KINDS!r}", name="ck_outing_messages_kind"
        ),
    )

    outing_id: Mapped[UUID] = mapped_column(
        ForeignKey("outings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    kind: Mapped[str] = mapped_column(String(16), nullable=False, default="text")
    body: Mapped[str] = mapped_column(Text, nullable=False)
