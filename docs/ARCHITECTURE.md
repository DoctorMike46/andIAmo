# Architettura

Sintesi dell'architettura andIAmo. Per il piano completo (database schema, fasi, API surface) vedi `~/.claude/plans/voglio-sviluppare-il-backend-eager-charm.md`.

## High-level

```
┌────────────────┐         ┌──────────────────────────────────┐
│  Flutter app   │ HTTPS   │  Caddy (TLS, reverse proxy)      │
│  (iOS/Android) │ ─────►  │  ↓                               │
└────────────────┘         │  FastAPI (Uvicorn, async)        │
                           │  ↓                               │
                           │  ┌──────────────┐  ┌───────────┐ │
                           │  │ PostgreSQL16 │  │  Redis    │ │
                           │  │ + PostGIS    │  │  (cache + │ │
                           │  │ + pgvector   │  │   ARQ jobs│ │
                           │  └──────────────┘  └───────────┘ │
                           │           │                      │
                           │  ┌────────▼─────────┐            │
                           │  │ ARQ workers      │            │
                           │  │ - categorize_*   │ ──► Claude │
                           │  │ - embed_user     │ ──► Voyage │
                           │  └──────────────────┘            │
                           │                                  │
                           │  S3-compatible (Hetzner Object   │
                           │  Storage / MinIO in dev)         │
                           └──────────────────────────────────┘
```

## Componenti chiave

### `app/api/v1/` — endpoint REST
Layer sottile: validazione Pydantic, dispatch a `services/`, response model. Niente logica di dominio qui.

### `app/services/` — logica di dominio
Pure functions su `AsyncSession`. Esempi futuri: `auth.register_user`, `consent.record`, `recommendations.compute`.

### `app/recommender/engine.py` — motore di matching
Funzione pura `recommend(user, context, filters) -> list[ScoredLocale]`. Testabile senza DB. Branch: rule-based o ibrido AI in base ai consensi dell'utente.

### `app/ai/` — integrazioni AI
- `claude_client.py` — wrapper su `anthropic` SDK con prompt caching attivato sul system prompt
- `embeddings.py` — wrapper Voyage AI (`voyage-3`, 1024-dim)
- `categorizer.py` — pipeline async: media → Claude vision → JSON strutturato → embedding
- `prompts/` — prompt versionati (file Markdown) per auditability

### `app/workers/` — job background (ARQ + Redis)
Trigger asincroni: categorizzazione media, embedding utente notturno, purge GDPR.

### `app/db/` — accesso DB
- `base.py` — `Base` ORM, `TimestampMixin`, `UUIDPkMixin`
- `session.py` — engine async + factory + dependency `get_session`

## Flusso raccomandazione (caldo)

```
GET /recommendations/tonight?lat&lng&time
       │
       ▼
[ require_consent("ai_profiling") | branch on consent ]
       │
       ▼
[ SQL filters: ST_DWithin, opening_hours, dietary, published ]
       │ (top 200 candidati)
       ▼
[ Score: cosine(user_emb, locale_emb) + time_fit + geo_decay + popularity ]
       │
       ▼
[ MMR diversification ]
       │
       ▼
[ recommendation_logs ]
       │
       ▼
   list[Locale] (top 20)
```

> Claude **non è chiamato** sul percorso sync. Resta al pipeline di categorizzazione async e a feature future (group consensus).

## Decisioni architetturali

- **Un solo DB** (Postgres) per relazionale + geo + vettoriale → meno operazioni, transazioni atomiche tra tutti i layer
- **Async ovunque** (asyncpg + AsyncSession) per sostenere I/O concorrente con risorse contenute
- **Embedding sync vs async**: embedding utente è async (worker dopo onboarding); embedding locale è async (worker dopo upload media)
- **No microservizi** all'MVP: monolite modulare. Decomposizione solo se justified da scaling reale
