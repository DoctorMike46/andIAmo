"""Promote/demote a user to/from admin.

Usage:
  uv run python -m app.cli.set_admin <email>           # grant admin
  uv run python -m app.cli.set_admin <email> --revoke  # revoke
"""
import asyncio
import sys

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.user import User


async def run(email: str, revoke: bool) -> None:
    async with SessionLocal() as session:
        user = (
            await session.execute(select(User).where(User.email == email.lower()))
        ).scalar_one_or_none()
        if user is None:
            print(f"No user with email {email!r}")
            sys.exit(1)
        user.is_admin = not revoke
        await session.commit()
        print(f"{user.email} is_admin = {user.is_admin}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    asyncio.run(run(sys.argv[1], "--revoke" in sys.argv))
