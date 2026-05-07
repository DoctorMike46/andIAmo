from uuid import UUID

import jwt
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models.user import User
from app.schemas.auth import TokenPair


class AuthError(Exception):
    """Domain-level auth failure. The API layer maps this to HTTP 4xx."""


class EmailAlreadyExistsError(AuthError):
    pass


class InvalidCredentialsError(AuthError):
    pass


class InvalidTokenError(AuthError):
    pass


class InactiveUserError(AuthError):
    pass


async def register_user(
    session: AsyncSession,
    *,
    email: str,
    password: str,
    full_name: str | None,
) -> User:
    user = User(
        email=email.lower(),
        password_hash=hash_password(password),
        full_name=full_name,
    )
    session.add(user)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise EmailAlreadyExistsError("email already registered") from exc
    await session.refresh(user)
    return user


async def authenticate_user(
    session: AsyncSession,
    *,
    email: str,
    password: str,
) -> User:
    result = await session.execute(select(User).where(User.email == email.lower()))
    user = result.scalar_one_or_none()
    if user is None or not verify_password(password, user.password_hash):
        raise InvalidCredentialsError("invalid email or password")
    if not user.is_active:
        raise InactiveUserError("user is inactive")
    return user


def issue_token_pair(user_id: UUID) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
    )


async def refresh_tokens(session: AsyncSession, *, refresh_token: str) -> TokenPair:
    try:
        payload = decode_token(refresh_token, "refresh")
    except jwt.PyJWTError as exc:
        raise InvalidTokenError("invalid refresh token") from exc

    user_id = UUID(payload["sub"])
    user = await session.get(User, user_id)
    if user is None or not user.is_active:
        raise InvalidTokenError("user not found or inactive")
    return issue_token_pair(user.id)
