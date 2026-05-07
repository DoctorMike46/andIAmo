from datetime import datetime
from uuid import UUID

from pgvector.sqlalchemy import Vector
from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin

# Legal purposes the user may grant/withdraw consent for. Onboarding requires
# at least 'terms_of_service' and 'privacy_policy' to be granted.
CONSENT_PURPOSES = (
    "terms_of_service",
    "privacy_policy",
    "ai_profiling",
    "marketing_emails",
    "analytics",
)


class UserPreference(Base, UUIDPkMixin, TimestampMixin):
    """One-to-one with users. Created the first time the user finishes onboarding."""

    __tablename__ = "user_preferences"
    __table_args__ = (
        CheckConstraint("budget_max BETWEEN 1 AND 4", name="ck_user_preferences_budget_max"),
        CheckConstraint(
            "max_distance_km > 0 AND max_distance_km <= 50",
            name="ck_user_preferences_max_distance_km",
        ),
    )

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    cuisines: Mapped[list[str]] = mapped_column(
        ARRAY(String(40)), nullable=False, default=list
    )
    moods: Mapped[list[str]] = mapped_column(
        ARRAY(String(40)), nullable=False, default=list
    )
    dietary: Mapped[list[str]] = mapped_column(
        ARRAY(String(40)), nullable=False, default=list
    )
    avoid_types: Mapped[list[str]] = mapped_column(
        ARRAY(String(40)), nullable=False, default=list
    )
    budget_max: Mapped[int] = mapped_column(Integer, nullable=False, default=4)
    max_distance_km: Mapped[float] = mapped_column(nullable=False, default=5.0)
    embedding: Mapped[list[float] | None] = mapped_column(Vector(1024), nullable=True)


class Consent(Base, UUIDPkMixin, TimestampMixin):
    """Append-only audit log of consent grants and withdrawals.

    Latest record per (user_id, purpose) determines the current state.
    A row with withdrawn_at != null indicates that purpose has been revoked.
    """

    __tablename__ = "consents"

    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    purpose: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    version: Mapped[str] = mapped_column(String(16), nullable=False, default="1.0")
    granted: Mapped[bool] = mapped_column(Boolean, nullable=False)
    granted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    withdrawn_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
