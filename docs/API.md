# API reference

L'API è documentata automaticamente da FastAPI tramite OpenAPI 3.

## Accesso alla documentazione interattiva

In sviluppo:
- Swagger UI: <http://localhost:8000/docs>
- OpenAPI JSON: <http://localhost:8000/openapi.json>

In produzione `/docs` è disabilitato (vedi `app/main.py`). Il JSON OpenAPI rimane scaricabile da CI per generare il client Dart per Flutter.

## Stato endpoint per fase

### Fase 0 (corrente)
- `GET /api/v1/health` → `{status, version, env}`
- `GET /api/v1/health/db` → `{status, extensions[]}` (verifica che postgis/vector/pg_trgm/pgcrypto siano installate)

### Fase 1 (auth + GDPR)
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/verify-email`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/forgot-password`
- `POST /api/v1/auth/reset-password`
- `GET /api/v1/me`
- `PATCH /api/v1/me`
- `POST /api/v1/me/consents`
- `GET /api/v1/me/export`
- `DELETE /api/v1/me`

### Fase 2 (catalogo)
- `GET /api/v1/locales/{id}`
- `GET /api/v1/events/{id}`
- `GET /api/v1/search/locales`
- `GET /api/v1/search/events`
- `POST /api/v1/admin/locales` (auth ruolo admin)
- `POST /api/v1/admin/locales/import-osm`
- `POST /api/v1/admin/events`
- `POST /api/v1/admin/locales/{id}/media`

### Fase 3 (raccomandazione)
- `GET /api/v1/recommendations/tonight`
- `GET /api/v1/recommendations/alternatives`

### Fase 4-5 (AI + polish)
- `GET /api/v1/onboarding/questions`
- `POST /api/v1/onboarding/answers`
- `POST /api/v1/favorites`
- `DELETE /api/v1/favorites/{type}/{id}`
- `GET /api/v1/favorites`
- `POST /api/v1/shares`
- `POST /api/v1/interactions`

## Convenzioni

- **Versionamento**: `/api/v1/...`. Per breaking changes, nuova `/v2/`.
- **Date/time**: ISO 8601 UTC con offset (`2026-05-07T19:30:00Z`)
- **ID**: UUID v4 in tutti i path
- **Errori**: `{detail: string | object}` standard FastAPI; codici 4xx con messaggi machine-readable nel campo `code` quando utile
- **Paginazione**: cursor-based su endpoint search/list (`?cursor=...&limit=20`)
- **Geo**: lat/lng come float WGS84 (`?lat=45.4642&lng=9.1900`); raggi in metri (`radius_m=2000`)
