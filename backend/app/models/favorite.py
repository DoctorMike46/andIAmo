from uuid import UUID

from sqlalchemy import ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin


class Favorite(Base, UUIDPkMixin, TimestampMixin):
    """A user has bookmarked a locale. Append-only; removed by hard delete."""

    __tablename__ = "favorites"
    __table_args__ = (
        UniqueConstraint("user_id", "locale_id", name="uq_favorites_user_locale"),
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
