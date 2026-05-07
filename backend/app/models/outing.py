from datetime import datetime
from uuid import UUID

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPkMixin

OUTING_STATUSES = ("planning", "decided", "done", "cancelled")


class Outing(Base, UUIDPkMixin, TimestampMixin):
    """A planned night-out among friends.

    The owner is also added as a participant via a trigger in service code,
    so the participants table always reflects the full guest list.
    """

    __tablename__ = "outings"
    __table_args__ = (
        CheckConstraint(
            f"status IN {OUTING_STATUSES!r}",
            name="ck_outings_status",
        ),
    )

    owner_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    when_dt: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="planning"
    )
    chosen_locale_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("locales.id", ondelete="SET NULL"), nullable=True
    )

    participants: Mapped[list["OutingParticipant"]] = relationship(
        back_populates="outing", cascade="all, delete-orphan"
    )


class OutingParticipant(Base, UUIDPkMixin, TimestampMixin):
    __tablename__ = "outing_participants"
    __table_args__ = (
        UniqueConstraint("outing_id", "user_id", name="uq_outing_participants"),
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

    outing: Mapped[Outing] = relationship(back_populates="participants")
