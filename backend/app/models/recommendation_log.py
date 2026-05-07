from uuid import UUID

from sqlalchemy import Float, ForeignKey
from sqlalchemy.dialects.postgresql import ARRAY, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin


class RecommendationLog(Base, UUIDPkMixin, TimestampMixin):
    """One row per /recommendations/tonight call. Audit trail for GDPR.

    Cascaded on user deletion so revoking the account removes history too.
    """

    __tablename__ = "recommendation_logs"

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    requested_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    requested_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    locale_ids: Mapped[list[UUID]] = mapped_column(
        ARRAY(PG_UUID(as_uuid=True)), nullable=False
    )
