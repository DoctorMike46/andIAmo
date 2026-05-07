from datetime import time
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.locale import LOCALE_TYPES


class LocaleMediaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    url: str
    is_primary: bool
    sort_order: int


class OpeningHoursOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    weekday: int = Field(ge=0, le=6, description="0=Monday … 6=Sunday")
    open_time: time
    close_time: time
    closed_all_day: bool


class LocaleSummary(BaseModel):
    """Lightweight payload for list endpoints."""

    id: UUID
    name: str
    type: str
    city: str
    address: str
    price_level: int
    rating: Decimal | None
    latitude: float
    longitude: float
    distance_m: float | None = Field(
        default=None,
        description="Distance from query point in meters; null when no point filter applied",
    )
    primary_media_url: str | None = None


class LocaleDetail(LocaleSummary):
    description: str | None
    phone: str | None = None
    website: str | None = None
    media: list[LocaleMediaOut]
    opening_hours: list[OpeningHoursOut]


class OpeningHoursIn(BaseModel):
    weekday: int = Field(ge=0, le=6)
    open_time: time
    close_time: time
    closed_all_day: bool = False


class LocaleMediaIn(BaseModel):
    url: str = Field(min_length=1, max_length=1024)
    is_primary: bool = False
    sort_order: int = 0


class LocaleWrite(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    type: str
    description: str | None = None
    address: str = Field(min_length=1, max_length=255)
    city: str = Field(min_length=1, max_length=80)
    price_level: int = Field(ge=1, le=4)
    rating: Decimal | None = Field(default=None, ge=0, le=5)
    phone: str | None = Field(default=None, max_length=32)
    website: str | None = Field(default=None, max_length=512)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    is_published: bool = True
    media: list[LocaleMediaIn] = Field(default_factory=list)
    opening_hours: list[OpeningHoursIn] = Field(default_factory=list)

    def validate_type(self) -> None:
        if self.type not in LOCALE_TYPES:
            raise ValueError(
                f"invalid type {self.type!r}; allowed: {', '.join(LOCALE_TYPES)}"
            )
