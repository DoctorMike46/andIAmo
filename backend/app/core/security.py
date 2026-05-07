from datetime import UTC, datetime, timedelta
from typing import Any, Literal
from uuid import UUID

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

from app.core.config import settings

TokenType = Literal["access", "refresh"]

_JWT_ALG = "HS256"
_hasher = PasswordHasher()


def hash_password(plain: str) -> str:
    return _hasher.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    try:
        _hasher.verify(hashed, plain)
        return True
    except VerifyMismatchError:
        return False


def _create_token(subject: UUID, token_type: TokenType, ttl_seconds: int) -> str:
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": str(subject),
        "type": token_type,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=ttl_seconds)).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=_JWT_ALG)


def create_access_token(subject: UUID) -> str:
    return _create_token(subject, "access", settings.jwt_access_ttl_seconds)


def create_refresh_token(subject: UUID) -> str:
    return _create_token(subject, "refresh", settings.jwt_refresh_ttl_seconds)


def decode_token(token: str, expected_type: TokenType) -> dict[str, Any]:
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[_JWT_ALG])
    if payload.get("type") != expected_type:
        raise jwt.InvalidTokenError(f"expected token type {expected_type!r}")
    return payload
