from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.friendship import UserCard


class OutingCreate(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    when_dt: datetime | None = None
    participant_ids: list[UUID] = Field(default_factory=list, max_length=20)


class OutingUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=120)
    when_dt: datetime | None = None
    status: str | None = None
    chosen_locale_id: UUID | None = None


class OutingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    when_dt: datetime | None
    status: str
    chosen_locale_id: UUID | None
    owner: UserCard
    participants: list[UserCard]
    created_at: datetime


class AddParticipantIn(BaseModel):
    user_id: UUID
