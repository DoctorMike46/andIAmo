"""OpenAI embeddings wrapper with deterministic mock fallback.

When OPENAI_API_KEY is empty the mock returns an L2-normalized 1024-dim vector
deterministically derived from a SHA-256 hash of the input. Same input → same
vector, so cosine similarity remains stable across runs even without real keys.

We use `text-embedding-3-small` with `dimensions=1024` so the result matches
the `Vector(1024)` column in the database without any schema migration.
OpenAI's Matryoshka-trained embeddings remain semantically meaningful when
truncated below their native 1536 dimensions.
"""
import hashlib
import math
from typing import Literal

from app.core.config import settings

EmbeddingDim: int = 1024
# Kept for backward-compatible call sites; OpenAI doesn't distinguish the two,
# so the parameter is currently informational only.
InputType = Literal["document", "query"]


class EmbeddingError(Exception):
    pass


def _l2_normalize(vec: list[float]) -> list[float]:
    norm = math.sqrt(sum(x * x for x in vec))
    if norm == 0:
        return vec
    return [x / norm for x in vec]


def _mock_embed(text: str) -> list[float]:
    """Derive a deterministic 1024-d float vector from a SHA-256 expansion.

    We salt the input with a counter and re-hash, mapping each byte to
    [-1, 1]. Distinct strings give distinct vectors; the same string always
    gives the same vector. Result is L2-normalized.
    """
    base = text.encode("utf-8")
    floats: list[float] = []
    counter = 0
    while len(floats) < EmbeddingDim:
        digest = hashlib.sha256(base + counter.to_bytes(4, "big")).digest()
        # 32 bytes → 32 floats in [-1, 1)
        floats.extend((b - 127.5) / 127.5 for b in digest)
        counter += 1
    floats = floats[:EmbeddingDim]
    return _l2_normalize(floats)


async def embed_text(text: str, *, input_type: InputType = "document") -> list[float]:
    """Return a 1024-dim embedding for the given text.

    Uses OpenAI `text-embedding-3-small` (truncated to 1024 dim) when
    OPENAI_API_KEY is set; otherwise returns a deterministic mock vector.
    Always L2-normalized.
    """
    del input_type  # accepted for API stability; OpenAI doesn't use it
    if not settings.openai_api_key:
        return _mock_embed(text)

    from openai import AsyncOpenAI

    client = AsyncOpenAI(api_key=settings.openai_api_key)
    try:
        result = await client.embeddings.create(
            model=settings.openai_embedding_model,
            input=text,
            dimensions=EmbeddingDim,
        )
    except Exception as exc:
        raise EmbeddingError(f"openai embed failed: {exc}") from exc
    return _l2_normalize(result.data[0].embedding)


def cosine_similarity(a: list[float], b: list[float]) -> float:
    """Cosine similarity in [-1, 1]. Both vectors are expected L2-normalized,
    so this reduces to a dot product, but we keep the general form for safety.
    """
    if not a or not b or len(a) != len(b):
        return 0.0
    dot = sum(x * y for x, y in zip(a, b, strict=False))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(x * x for x in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)
