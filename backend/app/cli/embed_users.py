"""Embed all user_preferences rows that don't yet have an embedding.

Usage: uv run python -m app.cli.embed_users [--all]
"""
import asyncio
import sys

from sqlalchemy import select

from app.ai.user_profile import embed_user_preferences
from app.db.session import SessionLocal
from app.models.preferences import UserPreference


async def run(refresh_all: bool) -> None:
    async with SessionLocal() as session:
        stmt = select(UserPreference)
        if not refresh_all:
            stmt = stmt.where(UserPreference.embedding.is_(None))
        result = await session.execute(stmt)
        prefs = list(result.scalars())
        print(f"Found {len(prefs)} user_preferences to embed.")
        for i, p in enumerate(prefs, 1):
            await embed_user_preferences(session, p)
            print(f"  [{i}/{len(prefs)}] user={p.user_id}")
        print("Done.")


if __name__ == "__main__":
    asyncio.run(run(refresh_all="--all" in sys.argv))
