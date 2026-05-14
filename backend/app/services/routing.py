"""Walking-route lookup via OSRM (foot profile).

Uses the public FOSSGIS demo server, which exposes `routed-foot` for free
under fair-use. Results are cached in-process for an hour, keyed on
quantised coordinates (~10 m) — neighbouring requests don't repeatedly hit
the upstream service.

If OSRM is unreachable (network blip, rate-limit) we return None and the
caller falls back to a straight-line "as the crow flies" path.
"""
import asyncio
import time
from dataclasses import dataclass

import httpx

_OSRM_URL = "https://routing.openstreetmap.de/routed-foot/route/v1/foot"
_CACHE_TTL_SECONDS = 60 * 60  # 1 hour
_HTTP_TIMEOUT = 6.0


@dataclass(frozen=True)
class WalkingRoute:
    distance_m: float
    duration_s: float
    # GeoJSON-style coordinate pairs as [lng, lat] in route order, ready to
    # send to the client (which converts to LatLng for the map polyline).
    coordinates: list[list[float]]


_cache: dict[tuple[float, float, float, float], tuple[float, WalkingRoute]] = {}
_cache_lock = asyncio.Lock()


def _quantise(value: float) -> float:
    """4 decimals ≈ 11 m — fine enough not to be wrong, coarse enough to share cache."""
    return round(value, 4)


async def get_walking_route(
    *, from_lat: float, from_lng: float, to_lat: float, to_lng: float
) -> WalkingRoute | None:
    key = (
        _quantise(from_lat), _quantise(from_lng),
        _quantise(to_lat), _quantise(to_lng),
    )
    now = time.monotonic()

    async with _cache_lock:
        cached = _cache.get(key)
        if cached and (now - cached[0]) < _CACHE_TTL_SECONDS:
            return cached[1]

    coords = f"{key[1]},{key[0]};{key[3]},{key[2]}"
    url = f"{_OSRM_URL}/{coords}"
    try:
        async with httpx.AsyncClient(timeout=_HTTP_TIMEOUT) as client:
            response = await client.get(
                url,
                params={"overview": "full", "geometries": "geojson"},
            )
            response.raise_for_status()
            data = response.json()
    except (httpx.HTTPError, ValueError):
        return None

    routes = data.get("routes") or []
    if not routes:
        return None

    route = routes[0]
    geometry = route.get("geometry") or {}
    coordinates = geometry.get("coordinates") or []
    if not coordinates:
        return None

    walking = WalkingRoute(
        distance_m=float(route.get("distance") or 0.0),
        duration_s=float(route.get("duration") or 0.0),
        coordinates=[[float(c[0]), float(c[1])] for c in coordinates],
    )

    async with _cache_lock:
        _cache[key] = (now, walking)
    return walking
