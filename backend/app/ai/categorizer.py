"""Pipeline: locale → LLM descriptor → embedding → save on locale.embedding."""
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.embeddings import embed_text
from app.ai.llm_client import describe_locale
from app.models.locale import Locale


async def embed_locale(session: AsyncSession, locale: Locale) -> list[float]:
    """Categorize and embed a single locale, persist the vector."""
    descriptor = await describe_locale(
        {
            "name": locale.name,
            "type": locale.type,
            "description": locale.description,
            "address": locale.address,
            "city": locale.city,
        }
    )
    vector = await embed_text(descriptor.to_embedding_text(), input_type="document")
    locale.embedding = vector
    await session.commit()
    return vector
