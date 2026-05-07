"""Pipeline: user preferences → embedding → save on user_preferences.embedding."""
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embeddings import embed_text
from app.models.preferences import UserPreference


def _serialize_preferences(prefs: UserPreference) -> str:
    parts = [
        f"cuisine: {', '.join(prefs.cuisines) or '-'}",
        f"mood: {', '.join(prefs.moods) or '-'}",
        f"dietary: {', '.join(prefs.dietary) or '-'}",
        f"avoid: {', '.join(prefs.avoid_types) or '-'}",
        f"budget_max: {prefs.budget_max}",
    ]
    return "\n".join(parts)


async def embed_user_preferences(
    session: AsyncSession, prefs: UserPreference
) -> list[float]:
    """Embed the user's preference profile into a query-style vector."""
    vector = await embed_text(_serialize_preferences(prefs), input_type="query")
    prefs.embedding = vector
    await session.commit()
    return vector
