from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class MessageIn(BaseModel):
    body: str = Field(min_length=1, max_length=2000)


class MessageOut(BaseModel):
    id: UUID
    kind: str
    body: str
    user_id: UUID | None
    user_name: str | None
    created_at: datetime
