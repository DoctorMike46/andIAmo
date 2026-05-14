"""Open-Meteo weather lookup with a small in-process cache.

We use the current-conditions endpoint with WMO weather codes. The result is
used by:
- the recommender, to nudge indoor venues when it's raining and outdoor venues
  when it's sunny;
- the mobile UI, to show a weather chip on the Esplora screen.

Cache key quantises lat/lng to ~1km so close requests hit the same entry.
"""
import asyncio
import time
from dataclasses import dataclass
from typing import Literal

import httpx

WeatherCondition = Literal[
    "clear", "partly_cloudy", "cloudy", "fog", "rain", "snow", "thunder", "unknown"
]

_OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
_CACHE_TTL_SECONDS = 30 * 60  # 30 minutes
_HTTP_TIMEOUT = 5.0


@dataclass(frozen=True)
class WeatherSnapshot:
    temperature_c: float
    condition: WeatherCondition
    is_precipitation: bool
    is_outdoor_friendly: bool  # warm + no rain/snow/fog → terrace weather


def _decode_wmo(code: int) -> WeatherCondition:
    """WMO weather codes from Open-Meteo. See https://open-meteo.com/en/docs"""
    if code == 0:
        return "clear"
    if code in {1, 2}:
        return "partly_cloudy"
    if code == 3:
        return "cloudy"
    if code in {45, 48}:
        return "fog"
    if code in range(51, 68) or code in {80, 81, 82}:
        return "rain"
    if code in range(71, 78) or code in {85, 86}:
        return "snow"
    if code in {95, 96, 99}:
        return "thunder"
    return "unknown"


def _is_precip(condition: WeatherCondition) -> bool:
    return condition in {"rain", "snow", "thunder"}


def _is_outdoor_friendly(condition: WeatherCondition, temperature_c: float) -> bool:
    """Heuristic: terrace weather = no precip/fog AND 15 °C ≤ T ≤ 30 °C."""
    if condition in {"rain", "snow", "thunder", "fog"}:
        return False
    return 15.0 <= temperature_c <= 30.0


# ── Cache ────────────────────────────────────────────────────────────────────

_cache: dict[tuple[float, float], tuple[float, WeatherSnapshot]] = {}
_cache_lock = asyncio.Lock()


def _quantise(value: float) -> float:
    """Round to 2 decimals ≈ ~1.1 km — neighbours share the cache entry."""
    return round(value, 2)


async def get_weather(lat: float, lng: float) -> WeatherSnapshot | None:
    """Fetch current weather for the given point.

    Returns None if Open-Meteo is unreachable; callers should treat this as
    "no weather signal" and skip the boost rather than failing.
    """
    key = (_quantise(lat), _quantise(lng))
    now = time.monotonic()

    async with _cache_lock:
        cached = _cache.get(key)
        if cached and (now - cached[0]) < _CACHE_TTL_SECONDS:
            return cached[1]

    try:
        async with httpx.AsyncClient(timeout=_HTTP_TIMEOUT) as client:
            response = await client.get(
                _OPEN_METEO_URL,
                params={
                    "latitude": key[0],
                    "longitude": key[1],
                    "current": "temperature_2m,weather_code",
                },
            )
            response.raise_for_status()
            data = response.json()
    except (httpx.HTTPError, ValueError):
        return None

    current = data.get("current") or {}
    code = int(current.get("weather_code") or 0)
    temp = float(current.get("temperature_2m") or 0.0)
    condition = _decode_wmo(code)
    snapshot = WeatherSnapshot(
        temperature_c=temp,
        condition=condition,
        is_precipitation=_is_precip(condition),
        is_outdoor_friendly=_is_outdoor_friendly(condition, temp),
    )

    async with _cache_lock:
        _cache[key] = (now, snapshot)
    return snapshot


# ── Outdoor hint heuristic ───────────────────────────────────────────────────

_OUTDOOR_KEYWORDS = (
    "terrazz", "giardin", "outdoor", "all'aperto", "dehor", "tetto", "rooftop",
    "veranda", "patio",
)


def has_outdoor_hint(*texts: str | None) -> bool:
    """Return True if any of the texts mentions outdoor seating."""
    for t in texts:
        if not t:
            continue
        low = t.lower()
        if any(kw in low for kw in _OUTDOOR_KEYWORDS):
            return True
    return False


def weather_boost(snapshot: WeatherSnapshot | None, outdoor_hint: bool) -> tuple[float, str | None]:
    """Return (multiplicative boost, optional reason).

    Boost is small (±10%) so it nudges ranking without flipping it.
    """
    if snapshot is None:
        return 0.0, None
    if snapshot.is_precipitation and not outdoor_hint:
        return 0.10, "perfetto per ripararsi dal maltempo"
    if snapshot.is_precipitation and outdoor_hint:
        return -0.08, None
    if snapshot.is_outdoor_friendly and outdoor_hint:
        return 0.10, "perfetto per stare all'aperto"
    return 0.0, None
