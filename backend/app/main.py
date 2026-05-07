from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import __version__
from app.api.v1 import router as api_v1_router
from app.core.config import settings
from app.core.logging import configure_logging
from app.db.session import engine

log = structlog.get_logger()


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    configure_logging()
    log.info("app.startup", env=settings.app_env, version=__version__)
    yield
    await engine.dispose()
    log.info("app.shutdown")


app = FastAPI(
    title="andIAmo API",
    version=__version__,
    description="Backend per l'app andIAmo — catalogo locali/eventi e raccomandazioni AI.",
    lifespan=lifespan,
    docs_url="/docs" if settings.app_debug else None,
    redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allow_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_v1_router, prefix="/api/v1")
