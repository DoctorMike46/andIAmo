from datetime import datetime
from uuid import UUID

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin

# Friend request lifecycle:
#   pending → accepted   (target user clicks accept)
#   pending → rejected   (target user clicks reject)
# Once accepted/rejected the row stays for audit; sending another request after
# rejection is allowed only if the previous record is removed first.
FRIENDSHIP_STATUSES = ("pending", "accepted", "rejected")


class Friendship(Base, UUIDPkMixin, TimestampMixin):
    """A directed friend request from `requester` to `addressee`.

    To enforce uniqueness regardless of direction, a separate index is created
    in the migration on (least(requester, addressee), greatest(...)).
    """

    __tablename__ = "friendships"
    __table_args__ = (
        CheckConstraint(
            f"status IN {FRIENDSHIP_STATUSES!r}",
            name="ck_friendships_status",
        ),
        CheckConstraint(
            "requester_id <> addressee_id",
            name="ck_friendships_no_self",
        ),
        UniqueConstraint(
            "requester_id", "addressee_id", name="uq_friendships_pair"
        ),
    )

    requester_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    addressee_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="pending")
    accepted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
