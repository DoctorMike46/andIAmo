"""Schemas for the AI Concierge conversational endpoint.

The client sends a free-text message plus the (optional) conversation history.
We ask the LLM to return a structured intent: either ask a clarifying question,
extract search filters and we'll run the recommender, or just chat.
"""
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.recommendation import RecommendationOut

ConciergeRole = Literal["user", "assistant"]


class ConciergeMessage(BaseModel):
    role: ConciergeRole
    content: str


class ConciergeRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    history: list[ConciergeMessage] = Field(default_factory=list, max_length=20)
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)


class ConciergeFilters(BaseModel):
    """Filters the LLM extracted from the user's message. All optional —
    missing fields fall back to the user's saved preferences."""

    cuisines: list[str] | None = None
    moods: list[str] | None = None
    dietary: list[str] | None = None
    avoid_types: list[str] | None = None
    budget_max: int | None = Field(default=None, ge=1, le=4)
    max_distance_km: float | None = Field(default=None, gt=0, le=50)


class ConciergeResponse(BaseModel):
    reply: str
    intent: Literal["search", "clarify", "chitchat"]
    filters_applied: ConciergeFilters | None = None
    recommendations: list[RecommendationOut] = Field(default_factory=list)
