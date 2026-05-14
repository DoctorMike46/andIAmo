"""AI Concierge: conversational front-end for the recommender.

Users type free text ("siamo in 3, voglia di pesce, max 30 euro, vicino a noi")
and the LLM returns a structured intent + extracted filters. If `intent=search`
we call the existing recommender with those filters as an override on top of
the user's saved preferences.

When OPENAI_API_KEY is empty, a deterministic keyword-based fallback ensures
the endpoint still works for development.
"""
import json
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.schemas.concierge import (
    ConciergeFilters,
    ConciergeMessage,
    ConciergeResponse,
)
from app.services import recommendations as rec_service


@dataclass(frozen=True)
class _LLMOutput:
    intent: str
    reply: str
    filters: ConciergeFilters


_PROMPTS_DIR = Path(__file__).parent / "prompts"
_SYSTEM_PROMPT = (_PROMPTS_DIR / "concierge_system.md").read_text(encoding="utf-8")


def _mock_extract(message: str) -> _LLMOutput:
    """Cheap keyword-based fallback when OPENAI_API_KEY is empty.

    Just enough to keep the endpoint working in dev/CI. Real intelligence
    requires the LLM.
    """
    msg = message.lower()
    cuisines: list[str] = []
    moods: list[str] = []
    dietary: list[str] = []
    avoid: list[str] = []
    budget: int | None = None
    distance: float | None = None

    for kw, tag in (
        ("pizza", "pizza"),
        ("pesce", "pesce"),
        ("sushi", "giapponese"),
        ("giappones", "giapponese"),
        ("burger", "burger"),
        ("hambur", "burger"),
        ("cocktail", "cocktail"),
        ("aperitivo", "cocktail"),
        ("italian", "italiana"),
    ):
        if kw in msg:
            cuisines.append(tag)

    for kw, tag in (
        ("romantic", "romantico"),
        ("tranquill", "tranquillo"),
        ("viva", "vivace"),
        ("elegant", "elegante"),
        ("informal", "informale"),
    ):
        if kw in msg:
            moods.append(tag)

    for kw, tag in (
        ("vegetarian", "vegetariano"),
        ("vegan", "vegano"),
        ("senza glutine", "senza_glutine"),
        ("celiac", "senza_glutine"),
    ):
        if kw in msg:
            dietary.append(tag)

    if any(w in msg for w in ("economic", "poco", "budget bass", "low cost")):
        budget = 2
    elif any(w in msg for w in ("medio", "media")):
        budget = 3
    elif any(w in msg for w in ("lusso", "alto", "elegant")):
        budget = 4

    if "vicin" in msg or "vicino a noi" in msg:
        distance = 2.0
    elif "lontano" in msg or "in giro" in msg:
        distance = 10.0

    has_signal = bool(cuisines or moods or dietary or budget or distance)
    intent = "search" if has_signal else "clarify"
    if intent == "search":
        bits = []
        if cuisines:
            bits.append(", ".join(cuisines))
        if moods:
            bits.append(moods[0])
        joined = " · ".join(bits) or "in base alle preferenze"
        reply = f"Ecco qualche idea per voi ({joined})."
    else:
        reply = (
            "Dimmi qualcosa di più: che cucina ti va? "
            "Budget? Vuoi qualcosa di tranquillo o vivace?"
        )

    return _LLMOutput(
        intent=intent,
        reply=reply,
        filters=ConciergeFilters(
            cuisines=cuisines or None,
            moods=moods or None,
            dietary=dietary or None,
            avoid_types=avoid or None,
            budget_max=budget,
            max_distance_km=distance,
        ),
    )


async def _llm_extract(message: str, history: list[ConciergeMessage]) -> _LLMOutput:
    from openai import AsyncOpenAI

    client = AsyncOpenAI(api_key=settings.openai_api_key)

    msgs: list[dict[str, str]] = [{"role": "system", "content": _SYSTEM_PROMPT}]
    for h in history[-10:]:
        msgs.append({"role": h.role, "content": h.content})
    msgs.append({"role": "user", "content": message})

    completion = await client.chat.completions.create(
        model=settings.openai_chat_model,
        messages=msgs,  # type: ignore[arg-type]
        response_format={"type": "json_object"},
        max_tokens=500,
        temperature=0.4,
    )
    raw = (completion.choices[0].message.content or "").strip()
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        # Salvage: extract first {...} block if the model wrapped the JSON.
        match = re.search(r"\{.*\}", raw, re.DOTALL)
        if match is None:
            raise
        data = json.loads(match.group(0))

    intent = data.get("intent") or "clarify"
    if intent not in {"search", "clarify", "chitchat"}:
        intent = "clarify"

    filters_data = data.get("filters") or {}
    filters = ConciergeFilters(
        cuisines=filters_data.get("cuisines"),
        moods=filters_data.get("moods"),
        dietary=filters_data.get("dietary"),
        avoid_types=filters_data.get("avoid_types"),
        budget_max=filters_data.get("budget_max"),
        max_distance_km=filters_data.get("max_distance_km"),
    )
    return _LLMOutput(intent=intent, reply=str(data.get("reply", "")).strip(), filters=filters)


async def reply(
    session: AsyncSession,
    *,
    user_id: UUID,
    message: str,
    history: list[ConciergeMessage],
    lat: float | None,
    lng: float | None,
    when: datetime | None = None,
) -> ConciergeResponse:
    """Produce a concierge reply, optionally running the recommender."""
    if settings.openai_api_key:
        try:
            out = await _llm_extract(message, history)
        except Exception:
            out = _mock_extract(message)
    else:
        out = _mock_extract(message)

    if out.intent != "search":
        return ConciergeResponse(reply=out.reply, intent=out.intent)

    override = out.filters.model_dump(exclude_none=True)
    recs = await rec_service.recommend_tonight(
        session,
        user_id=user_id,
        lat=lat,
        lng=lng,
        when=when,
        limit=6,
        prefs_override=override if override else None,
    )

    if not recs:
        return ConciergeResponse(
            reply=(
                "Non trovo locali che corrispondano. Prova ad allargare il raggio o "
                "il budget, o dimmi qualcosa di diverso."
            ),
            intent="search",
            filters_applied=out.filters,
            recommendations=[],
        )

    return ConciergeResponse(
        reply=out.reply or f"Ecco {len(recs)} idee per stasera.",
        intent="search",
        filters_applied=out.filters,
        recommendations=recs,
    )
