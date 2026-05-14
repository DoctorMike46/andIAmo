"""AI mediator for group outings.

Given an outing, its participants' preferences, current votes and the group
recommendations, produce a single suggestion with a human-readable rationale.

Falls back to a deterministic heuristic when OPENAI_API_KEY is empty.
"""
from dataclasses import dataclass
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.outing_vote import OutingVote
from app.schemas.recommendation import RecommendationOut
from app.services import recommendations as rec_service
from app.services import outings as outings_service
from app.services.preferences import get_preferences
from sqlalchemy import select


@dataclass(frozen=True)
class MediationResult:
    suggested_locale_id: str | None
    rationale: str


async def mediate_outing(
    session: AsyncSession, *, outing_id: UUID, lat: float | None, lng: float | None
) -> MediationResult:
    user_ids = await outings_service.participant_user_ids(session, outing_id=outing_id)
    if not user_ids:
        return MediationResult(suggested_locale_id=None, rationale="Nessun partecipante.")

    candidates = await rec_service.recommend_for_group(
        session, user_ids=user_ids, lat=lat, lng=lng, when=None, limit=10
    )
    if not candidates:
        return MediationResult(
            suggested_locale_id=None,
            rationale=(
                "Non trovo locali che soddisfino tutti i partecipanti. "
                "Provate ad allargare il raggio o il budget nelle preferenze."
            ),
        )

    votes = (
        await session.execute(
            select(OutingVote).where(OutingVote.outing_id == outing_id)
        )
    ).scalars().all()

    # Score each candidate combining engine score + group voting consensus.
    score_by_locale: dict[str, float] = {c.id: c.score for c in candidates}
    for v in votes:
        if str(v.locale_id) not in score_by_locale:
            continue
        score_by_locale[str(v.locale_id)] += 0.15 if v.vote == "like" else -0.20

    ranked = sorted(candidates, key=lambda c: score_by_locale[c.id], reverse=True)
    pick = ranked[0]

    # Build participant profile summary.
    profile_lines: list[str] = []
    for uid in user_ids:
        prefs = await get_preferences(session, user_id=uid)
        if prefs is None:
            continue
        cuisines = ", ".join(prefs.cuisines) or "—"
        moods = ", ".join(prefs.moods) or "—"
        profile_lines.append(
            f"- utente {str(uid)[:8]}: cucine [{cuisines}], mood [{moods}], budget {prefs.budget_max}"
        )

    if settings.openai_api_key:
        try:
            rationale = await _openai_rationale(
                pick=pick, candidates=candidates, votes=votes, profile=profile_lines
            )
            return MediationResult(suggested_locale_id=pick.id, rationale=rationale)
        except Exception:
            pass

    return MediationResult(
        suggested_locale_id=pick.id,
        rationale=_mock_rationale(pick=pick, candidates=candidates, votes=votes),
    )


def _mock_rationale(
    *,
    pick: RecommendationOut,
    candidates: list[RecommendationOut],
    votes: list,
) -> str:
    likes = sum(1 for v in votes if v.vote == "like" and str(v.locale_id) == pick.id)
    dislikes = sum(1 for v in votes if v.vote == "dislike" and str(v.locale_id) == pick.id)
    parts = [
        f"Proposta: **{pick.name}** ({pick.type} · {pick.city}).",
    ]
    if pick.reasons:
        parts.append("Motivi: " + ", ".join(pick.reasons) + ".")
    if likes or dislikes:
        parts.append(f"Voti finora: 👍 {likes} · 👎 {dislikes}.")
    if len(candidates) > 1:
        runner = candidates[1]
        parts.append(
            f"Alternativa: {runner.name} (score {runner.score:.2f})."
        )
    return " ".join(parts)


async def _openai_rationale(
    *,
    pick: RecommendationOut,
    candidates: list[RecommendationOut],
    votes: list,
    profile: list[str],
) -> str:
    """Ask OpenAI to write the rationale. Only invoked when API key is set."""
    from openai import AsyncOpenAI

    client = AsyncOpenAI(api_key=settings.openai_api_key)
    profile_str = "\n".join(profile) if profile else "(nessun profilo)"
    options_str = "\n".join(
        f"- {c.name} ({c.type}, {c.city}) score={c.score} reasons={c.reasons}"
        for c in candidates[:5]
    )
    votes_str = "\n".join(
        f"- locale {str(v.locale_id)[:8]}: {v.vote} da utente {str(v.user_id)[:8]}"
        for v in votes
    ) or "(nessun voto)"

    system = (
        "Sei un mediatore di gruppo per scegliere un locale dove uscire. "
        "Ricevi: profilo dei partecipanti, opzioni candidate con score, voti già espressi. "
        "Spiega perché la prima opzione è il miglior compromesso, in italiano, in 2-3 frasi calde e amichevoli, "
        "evidenziando equilibrio tra le preferenze del gruppo. Non parlare di score numerici."
    )
    user_msg = (
        f"PARTECIPANTI:\n{profile_str}\n\n"
        f"CANDIDATI:\n{options_str}\n\n"
        f"VOTI:\n{votes_str}\n\n"
        f"PROPOSTA: {pick.name} ({pick.type}, {pick.city})"
    )

    completion = await client.chat.completions.create(
        model=settings.openai_chat_model,
        max_tokens=300,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user_msg},
        ],
    )
    return (completion.choices[0].message.content or "").strip()
