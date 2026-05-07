"""Voyage AI embeddings wrapper with deterministic mock fallback.

When VOYAGE_API_KEY is empty the mock returns an L2-normalized 1024-dim vector
deterministically derived from a SHA-256 hash of the input. Same input → same
vector, so cosine similarity remains stable across runs even without real keys.
"""
import hashlib
import math
from typing import Literal

from app.core.config import settings

EmbeddingDim: int = 1024
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

    Uses Voyage `voyage-3` when VOYAGE_API_KEY is set; otherwise returns a
    deterministic mock vector. Always L2-normalized.
    """
    if not settings.voyage_api_key:
        return _mock_embed(text)

    import voyageai  # local import: only required when running with real keys

    client = voyageai.AsyncClient(api_key=settings.voyage_api_key)
    try:
        result = await client.embed(
            texts=[text],
            model="voyage-3",
            input_type=input_type,
            output_dimension=EmbeddingDim,
        )
    except Exception as exc:  # noqa: BLE001 — surface as EmbeddingError
        raise EmbeddingError(f"voyage embed failed: {exc}") from exc
    return _l2_normalize(result.embeddings[0])


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
