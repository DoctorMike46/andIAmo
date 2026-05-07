"""Claude (Anthropic) wrapper with deterministic mock fallback.

When ANTHROPIC_API_KEY is empty the mock returns a structured descriptor
derived from the locale type/name — enough to drive the rest of the pipeline
during development without spending API credits.
"""
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from app.core.config import settings

_PROMPT_VERSION = "v1.0"
_PROMPTS_DIR = Path(__file__).parent / "prompts"

_MODEL = "claude-sonnet-4-6"


@dataclass(frozen=True)
class LocaleDescriptor:
    cuisine_tags: list[str]
    ambiance: list[str]
    target_audience: list[str]
    occasion: list[str]
    noise_level: str
    summary: str

    def to_embedding_text(self) -> str:
        """Serialize the descriptor into a single string suitable for embedding."""
        parts = [
            f"summary: {self.summary}",
            f"cuisine: {', '.join(self.cuisine_tags)}",
            f"ambiance: {', '.join(self.ambiance)}",
            f"target: {', '.join(self.target_audience)}",
            f"occasion: {', '.join(self.occasion)}",
            f"noise: {self.noise_level}",
        ]
        return "\n".join(parts)


class ClaudeError(Exception):
    pass


def _load_system_prompt() -> str:
    return (_PROMPTS_DIR / "locale_descriptor.md").read_text(encoding="utf-8")


def _mock_descriptor(locale_meta: dict[str, Any]) -> LocaleDescriptor:
    """Cheap deterministic mock keyed on locale.type and name.

    Good enough to validate the pipeline; embeddings will still differ between
    locales because the resulting descriptor texts differ.
    """
    t = (locale_meta.get("type") or "").lower()
    name = locale_meta.get("name") or ""
    description = (locale_meta.get("description") or "").lower()

    presets: dict[str, dict[str, Any]] = {
        "ristorante": {
            "cuisine_tags": ["italiana"],
            "ambiance": ["accogliente", "tradizionale"],
            "target_audience": ["coppie", "famiglie"],
            "occasion": ["cena", "pranzo"],
            "noise_level": "medio",
        },
        "pizzeria": {
            "cuisine_tags": ["pizza", "italiana"],
            "ambiance": ["informale", "vivace"],
            "target_audience": ["famiglie", "gruppi", "studenti"],
            "occasion": ["cena", "dopo_lavoro"],
            "noise_level": "vivace",
        },
        "bar": {
            "cuisine_tags": ["cocktail", "aperitivo"],
            "ambiance": ["sociale", "vivace"],
            "target_audience": ["coppie", "gruppi", "professionisti"],
            "occasion": ["aperitivo", "dopo_lavoro", "serata"],
            "noise_level": "vivace",
        },
        "pub": {
            "cuisine_tags": ["birra", "cocktail"],
            "ambiance": ["informale", "amichevole"],
            "target_audience": ["gruppi", "studenti"],
            "occasion": ["aperitivo", "serata"],
            "noise_level": "vivace",
        },
        "caffe": {
            "cuisine_tags": ["caffè", "pasticceria"],
            "ambiance": ["rilassante", "classico"],
            "target_audience": ["professionisti", "coppie"],
            "occasion": ["colazione", "pranzo_veloce", "pomeriggio"],
            "noise_level": "silenzioso",
        },
        "club": {
            "cuisine_tags": ["cocktail"],
            "ambiance": ["festivo", "chiassoso", "underground"],
            "target_audience": ["giovani", "amanti-musica"],
            "occasion": ["serata", "dopocena", "ballare"],
            "noise_level": "alto",
        },
    }
    base = presets.get(t, presets["bar"])

    # Add descriptive cues from description text so two locales of the same
    # type still differ.
    extra_ambiance: list[str] = []
    for keyword, tag in (
        ("storic", "storico"),
        ("tradizional", "tradizionale"),
        ("element", "moderno"),
        ("elettron", "elettronica"),
        ("lgbt", "lgbt-friendly"),
        ("ricerca", "ricerca"),
        ("sottil", "croccante"),
    ):
        if keyword in description:
            extra_ambiance.append(tag)

    return LocaleDescriptor(
        cuisine_tags=list(base["cuisine_tags"]),
        ambiance=list(base["ambiance"]) + extra_ambiance,
        target_audience=list(base["target_audience"]),
        occasion=list(base["occasion"]),
        noise_level=str(base["noise_level"]),
        summary=f"{name}: locale {t} a {locale_meta.get('city', 'Italia')}.",
    )


async def describe_locale(locale_meta: dict[str, Any]) -> LocaleDescriptor:
    """Produce a structured LocaleDescriptor for the given locale metadata.

    Falls back to a deterministic mock when ANTHROPIC_API_KEY is empty.
    """
    if not settings.anthropic_api_key:
        return _mock_descriptor(locale_meta)

    import json

    from anthropic import AsyncAnthropic

    client = AsyncAnthropic(api_key=settings.anthropic_api_key)
    system_prompt = _load_system_prompt()
    user_payload = json.dumps(locale_meta, ensure_ascii=False)

    try:
        message = await client.messages.create(
            model=_MODEL,
            max_tokens=600,
            system=[
                {
                    "type": "text",
                    "text": system_prompt,
                    "cache_control": {"type": "ephemeral"},
                }
            ],
            messages=[{"role": "user", "content": user_payload}],
        )
    except Exception as exc:  # noqa: BLE001
        raise ClaudeError(f"anthropic call failed: {exc}") from exc

    text = "".join(
        block.text for block in message.content if getattr(block, "type", "") == "text"
    ).strip()
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ClaudeError(f"claude returned non-JSON: {text[:200]}") from exc

    return LocaleDescriptor(
        cuisine_tags=list(data.get("cuisine_tags", [])),
        ambiance=list(data.get("ambiance", [])),
        target_audience=list(data.get("target_audience", [])),
        occasion=list(data.get("occasion", [])),
        noise_level=str(data.get("noise_level", "medio")),
        summary=str(data.get("summary", "")),
    )


def prompt_version() -> str:
    return _PROMPT_VERSION
