from fastapi import APIRouter, Depends, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app import __version__
from app.core.config import settings
from app.db.session import get_session

router = APIRouter()


@router.get("/health", status_code=status.HTTP_200_OK)
async def health() -> dict[str, str]:
    return {"status": "ok", "version": __version__, "env": settings.app_env}


@router.get("/health/db", status_code=status.HTTP_200_OK)
async def health_db(session: AsyncSession = Depends(get_session)) -> dict[str, object]:
    result = await session.execute(
        text(
            "SELECT extname FROM pg_extension WHERE extname IN "
            "('postgis', 'vector', 'pg_trgm', 'pgcrypto')"
        )
    )
    extensions = sorted(row[0] for row in result.all())
    return {"status": "ok", "extensions": extensions}
