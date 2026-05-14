from fastapi import APIRouter

from app.api.v1 import (
    admin,
    auth,
    concierge,
    favorites,
    friends,
    health,
    locales,
    outings,
    recommendations,
    routing,
    users,
    weather,
)

router = APIRouter()
router.include_router(health.router, tags=["health"])
router.include_router(auth.router, prefix="/auth", tags=["auth"])
router.include_router(users.router, tags=["users"])
router.include_router(locales.router, prefix="/locales", tags=["locales"])
router.include_router(
    recommendations.router, prefix="/recommendations", tags=["recommendations"]
)
router.include_router(concierge.router, prefix="/concierge", tags=["concierge"])
router.include_router(weather.router, prefix="/weather", tags=["weather"])
router.include_router(routing.router, prefix="/routing", tags=["routing"])
router.include_router(friends.router, tags=["friends"])
router.include_router(outings.router, prefix="/outings", tags=["outings"])
router.include_router(favorites.router, prefix="/me/favorites", tags=["favorites"])
router.include_router(admin.router, prefix="/admin", tags=["admin"])
