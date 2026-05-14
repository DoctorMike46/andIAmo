from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel

from app.api.deps import get_current_user
from app.models.user import User
from app.services import routing as routing_service

router = APIRouter()


class WalkingRouteOut(BaseModel):
    distance_m: float
    duration_s: float
    # [[lng, lat], [lng, lat], ...] in route order
    coordinates: list[list[float]]


@router.get("/walk", response_model=WalkingRouteOut | None)
async def walk_route(
    from_lat: float = Query(ge=-90, le=90),
    from_lng: float = Query(ge=-180, le=180),
    to_lat: float = Query(ge=-90, le=90),
    to_lng: float = Query(ge=-180, le=180),
    _: User = Depends(get_current_user),
) -> WalkingRouteOut | None:
    route = await routing_service.get_walking_route(
        from_lat=from_lat, from_lng=from_lng, to_lat=to_lat, to_lng=to_lng
    )
    if route is None:
        return None
    return WalkingRouteOut(
        distance_m=route.distance_m,
        duration_s=route.duration_s,
        coordinates=route.coordinates,
    )
