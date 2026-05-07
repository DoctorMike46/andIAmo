from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr


class UserCard(BaseModel):
    """Lightweight user representation used in friend lists / search results."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: EmailStr
    full_name: str | None


class FriendshipOut(BaseModel):
    id: UUID
    status: str
    requested_at: datetime
    accepted_at: datetime | None
    requester: UserCard
    addressee: UserCard

    @property
    def other(self) -> UserCard:  # convenience for the mobile client
        return self.addressee


class FriendRequestIn(BaseModel):
    email: EmailStr
