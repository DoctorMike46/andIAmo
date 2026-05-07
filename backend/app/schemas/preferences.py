from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class PreferencesIn(BaseModel):
    cuisines: list[str] = Field(default_factory=list)
    moods: list[str] = Field(default_factory=list)
    dietary: list[str] = Field(default_factory=list)
    avoid_types: list[str] = Field(default_factory=list)
    budget_max: int = Field(default=4, ge=1, le=4)
    max_distance_km: float = Field(default=5.0, gt=0, le=50)


class PreferencesOut(PreferencesIn):
    model_config = ConfigDict(from_attributes=True)


class ConsentIn(BaseModel):
    purpose: str
    granted: bool
    version: str = "1.0"


class ConsentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    purpose: str
    granted: bool
    version: str
    granted_at: datetime
    withdrawn_at: datetime | None
