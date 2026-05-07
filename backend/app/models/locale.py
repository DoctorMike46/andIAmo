from datetime import time
from decimal import Decimal
from uuid import UUID

from geoalchemy2 import Geometry
from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    Time,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPkMixin

LOCALE_TYPES = ("bar", "ristorante", "pub", "pizzeria", "caffe", "club")


class Locale(Base, UUIDPkMixin, TimestampMixin):
    __tablename__ = "locales"
    __table_args__ = (
        CheckConstraint(
            f"type IN {LOCALE_TYPES!r}".replace("'", "'"),
            name="ck_locales_type",
        ),
        CheckConstraint("price_level BETWEEN 1 AND 4", name="ck_locales_price_level"),
    )

    name: Mapped[str] = mapped_column(String(160), nullable=False)
    type: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    address: Mapped[str] = mapped_column(String(255), nullable=False)
    city: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    price_level: Mapped[int] = mapped_column(Integer, nullable=False, default=2)
    rating: Mapped[Decimal | None] = mapped_column(Numeric(2, 1), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    website: Mapped[str | None] = mapped_column(String(512), nullable=True)
    location: Mapped[object] = mapped_column(
        Geometry(geometry_type="POINT", srid=4326),
        nullable=False,
    )
    embedding: Mapped[list[float] | None] = mapped_column(Vector(1024), nullable=True)
    is_published: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    media: Mapped[list["LocaleMedia"]] = relationship(
        back_populates="locale",
        cascade="all, delete-orphan",
        order_by="LocaleMedia.sort_order",
    )
    opening_hours: Mapped[list["OpeningHours"]] = relationship(
        back_populates="locale",
        cascade="all, delete-orphan",
        order_by="OpeningHours.weekday",
    )


class LocaleMedia(Base, UUIDPkMixin, TimestampMixin):
    __tablename__ = "locale_media"

    locale_id: Mapped[UUID] = mapped_column(
        ForeignKey("locales.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    url: Mapped[str] = mapped_column(String(1024), nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    locale: Mapped[Locale] = relationship(back_populates="media")


class OpeningHours(Base, UUIDPkMixin, TimestampMixin):
    """One row per (locale, weekday). Weekday 0=Monday … 6=Sunday."""

    __tablename__ = "opening_hours"
    __table_args__ = (
        UniqueConstraint("locale_id", "weekday", name="uq_opening_hours_locale_weekday"),
        CheckConstraint("weekday BETWEEN 0 AND 6", name="ck_opening_hours_weekday"),
    )

    locale_id: Mapped[UUID] = mapped_column(
        ForeignKey("locales.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    weekday: Mapped[int] = mapped_column(Integer, nullable=False)
    open_time: Mapped[time] = mapped_column(Time, nullable=False)
    close_time: Mapped[time] = mapped_column(Time, nullable=False)
    closed_all_day: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    locale: Mapped[Locale] = relationship(back_populates="opening_hours")
