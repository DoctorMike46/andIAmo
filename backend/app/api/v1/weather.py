from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel

from app.api.deps import get_current_user
from app.models.user import User
from app.services import weather as weather_service

router = APIRouter()


class WeatherOut(BaseModel):
    temperature_c: float
    condition: str
    is_precipitation: bool
    is_outdoor_friendly: bool


@router.get("/now", response_model=WeatherOut | None)
async def weather_now(
    lat: float = Query(ge=-90, le=90),
    lng: float = Query(ge=-180, le=180),
    _: User = Depends(get_current_user),
) -> WeatherOut | None:
    snap = await weather_service.get_weather(lat, lng)
    if snap is None:
        return None
    return WeatherOut(
        temperature_c=snap.temperature_c,
        condition=snap.condition,
        is_precipitation=snap.is_precipitation,
        is_outdoor_friendly=snap.is_outdoor_friendly,
    )
