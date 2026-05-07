"""Pure scoring logic. No DB access — easy to unit-test."""
import math
from dataclasses import dataclass
from datetime import time

from app.ai.embeddings import cosine_similarity


@dataclass(frozen=True)
class LocaleCandidate:
    id: str
    name: str
    type: str
    price_level: int
    rating: float | None
    distance_km: float | None  # None when no user point provided
    embedding: list[float] | None = None


@dataclass(frozen=True)
class UserContext:
    moods: list[str]
    cuisines: list[str]
    dietary: list[str]
    avoid_types: list[str]
    budget_max: int
    max_distance_km: float
    embedding: list[float] | None = None


@dataclass(frozen=True)
class TimeWindow:
    """The opening_hours record matched for the requested time."""
    open_time: time
    close_time: time


@dataclass(frozen=True)
class ScoredLocale:
    locale_id: str
    score: float
    reasons: list[str]


# Score weights — sum to 1.0 to keep score in [0, 1].
# When AI embeddings are absent on either side we redistribute W_AI's weight
# proportionally to the remaining components.
W_GEO = 0.30
W_AI = 0.25
W_POPULARITY = 0.20
W_TIME_FIT = 0.20
W_PREF_FIT = 0.05


def _geo_score(distance_km: float | None) -> float:
    if distance_km is None:
        return 0.5  # neutral when location not provided
    return 1.0 / (1.0 + distance_km / 5.0)


def _popularity_score(rating: float | None) -> float:
    if rating is None:
        return 0.5
    return max(0.0, min(1.0, rating / 5.0))


def _time_fit_score(window: TimeWindow | None, now: time) -> float:
    """1.0 in the middle of the open window, lower near the edges.

    Returns 0 if `now` is outside the window. Handles cross-midnight windows
    (close_time < open_time) by treating them as continuing past midnight.
    """
    if window is None:
        return 0.0
    open_min = window.open_time.hour * 60 + window.open_time.minute
    close_min = window.close_time.hour * 60 + window.close_time.minute
    now_min = now.hour * 60 + now.minute

    if close_min <= open_min:
        # Cross-midnight: open from open_min to 24:00, then 00:00 to close_min.
        if now_min >= open_min:
            distance_from_edge = min(now_min - open_min, (24 * 60 - now_min) + close_min)
        elif now_min < close_min:
            distance_from_edge = min(now_min + (24 * 60 - open_min), close_min - now_min)
        else:
            return 0.0
    else:
        if now_min < open_min or now_min >= close_min:
            return 0.0
        distance_from_edge = min(now_min - open_min, close_min - now_min)
    return min(1.0, max(distance_from_edge / 30.0, 0.4))


def _preference_score(candidate: LocaleCandidate, ctx: UserContext) -> tuple[float, list[str]]:
    score = 0.0
    reasons: list[str] = []

    if candidate.price_level <= ctx.budget_max:
        score += 0.5
        if candidate.price_level < ctx.budget_max:
            reasons.append("dentro il tuo budget")

    type_to_cuisine = {
        "ristorante": ["italiana", "carne", "pesce"],
        "pizzeria": ["pizza", "italiana"],
        "caffe": [],
        "bar": [],
        "pub": [],
        "club": [],
    }
    aligned = type_to_cuisine.get(candidate.type, [])
    if any(c in ctx.cuisines for c in aligned):
        score += 0.5
        reasons.append("in linea con i tuoi gusti")

    return min(1.0, score), reasons


def _ai_score(user_emb: list[float] | None, locale_emb: list[float] | None) -> float | None:
    """Cosine similarity mapped to [0, 1]. None when either embedding is missing."""
    if not user_emb or not locale_emb:
        return None
    sim = cosine_similarity(user_emb, locale_emb)
    return max(0.0, min(1.0, (sim + 1.0) / 2.0))


def score_locale(
    candidate: LocaleCandidate,
    ctx: UserContext,
    *,
    window: TimeWindow | None,
    now: time,
) -> ScoredLocale:
    geo = _geo_score(candidate.distance_km)
    pop = _popularity_score(candidate.rating)
    tfit = _time_fit_score(window, now)
    pref, pref_reasons = _preference_score(candidate, ctx)
    ai = _ai_score(ctx.embedding, candidate.embedding)

    if ai is None:
        # Redistribute W_AI proportionally over the remaining 4 components.
        boost = W_AI / (W_GEO + W_POPULARITY + W_TIME_FIT + W_PREF_FIT)
        score = (
            (W_GEO * (1 + boost)) * geo
            + (W_POPULARITY * (1 + boost)) * pop
            + (W_TIME_FIT * (1 + boost)) * tfit
            + (W_PREF_FIT * (1 + boost)) * pref
        )
    else:
        score = (
            W_GEO * geo
            + W_AI * ai
            + W_POPULARITY * pop
            + W_TIME_FIT * tfit
            + W_PREF_FIT * pref
        )

    reasons = list(pref_reasons)
    if candidate.distance_km is not None and candidate.distance_km < 1.0:
        reasons.append("a meno di 1 km")
    if candidate.rating is not None and candidate.rating >= 4.5:
        reasons.append(f"valutazione {candidate.rating:.1f}/5")
    if tfit >= 0.9:
        reasons.append("aperto in pieno orario")
    if ai is not None and ai >= 0.8:
        reasons.append("matcha il tuo profilo")

    return ScoredLocale(locale_id=candidate.id, score=round(score, 4), reasons=reasons)


# ── Group recommendations ────────────────────────────────────────────────────


def merge_group_context(contexts: list[UserContext]) -> UserContext:
    """Combine multiple users' preferences into a group profile.

    Strategy:
    - cuisines/moods/dietary: union (group considers everyone's tastes).
    - avoid_types: union (one veto = the whole group avoids).
    - budget_max: min (don't push someone above their cap).
    - max_distance_km: min (closest acceptable to everyone).
    - embedding: average of available vectors (re-normalized).
    """
    if not contexts:
        raise ValueError("contexts must be non-empty")

    cuisines = sorted({c for ctx in contexts for c in ctx.cuisines})
    moods = sorted({m for ctx in contexts for m in ctx.moods})
    dietary = sorted({d for ctx in contexts for d in ctx.dietary})
    avoid = sorted({a for ctx in contexts for a in ctx.avoid_types})
    budget = min(ctx.budget_max for ctx in contexts)
    radius = min(ctx.max_distance_km for ctx in contexts)

    embeddings = [ctx.embedding for ctx in contexts if ctx.embedding]
    averaged: list[float] | None = None
    if embeddings:
        dim = len(embeddings[0])
        sums = [0.0] * dim
        for emb in embeddings:
            for i, v in enumerate(emb):
                sums[i] += v
        norm = math.sqrt(sum(s * s for s in sums))
        if norm > 0:
            averaged = [s / norm for s in sums]

    return UserContext(
        moods=moods,
        cuisines=cuisines,
        dietary=dietary,
        avoid_types=avoid,
        budget_max=budget,
        max_distance_km=radius,
        embedding=averaged,
    )
