from uuid import UUID

from pydantic import BaseModel


class VoteIn(BaseModel):
    locale_id: UUID
    vote: str  # "like" or "dislike"


class LocaleVoteSummary(BaseModel):
    locale_id: UUID
    likes: int
    dislikes: int
    score: int  # likes - dislikes
    my_vote: str | None  # current user's vote, if any
