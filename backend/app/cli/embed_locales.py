"""Embed all published locales that don't yet have an embedding.

Usage: uv run python -m app.cli.embed_locales [--all]
"""
import asyncio
import sys

from sqlalchemy import select

from app.ai.categorizer import embed_locale
from app.db.session import SessionLocal
from app.models.locale import Locale


async def run(refresh_all: bool) -> None:
    async with SessionLocal() as session:
        stmt = select(Locale).where(Locale.is_published.is_(True))
        if not refresh_all:
            stmt = stmt.where(Locale.embedding.is_(None))
        result = await session.execute(stmt)
        locales = list(result.scalars())
        print(f"Found {len(locales)} locales to embed.")
        for i, locale in enumerate(locales, 1):
            await embed_locale(session, locale)
            print(f"  [{i}/{len(locales)}] {locale.name} ({locale.city})")
        print("Done.")


if __name__ == "__main__":
    asyncio.run(run(refresh_all="--all" in sys.argv))
