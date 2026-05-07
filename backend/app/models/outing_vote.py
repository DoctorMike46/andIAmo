from uuid import UUID

from sqlalchemy import CheckConstraint, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin

VOTE_VALUES = ("like", "dislike")


class OutingVote(Base, UUIDPkMixin, TimestampMixin):
    """One row per (outing, user, locale). The latest write wins (upsert)."""

    __tablename__ = "outing_votes"
    __table_args__ = (
        UniqueConstraint(
            "outing_id", "user_id", "locale_id", name="uq_outing_votes_unique"
        ),
        CheckConstraint(
            f"vote IN {VOTE_VALUES!r}", name="ck_outing_votes_value"
        ),
    )

    outing_id: Mapped[UUID] = mapped_column(
        ForeignKey("outings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    locale_id: Mapped[UUID] = mapped_column(
        ForeignKey("locales.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    vote: Mapped[str] = mapped_column(String(8), nullable=False)
