# andIAmo

App per scegliere dove uscire stasera. Composta da un backend FastAPI (Postgres + PostGIS + pgvector) e un'app Flutter per iOS e Android.

L'idea: invece di scrollare le solite recensioni, l'utente compila un breve profilo (cucine, mood, budget, dieta, raggio) e l'app gli propone i locali che davvero potrebbero piacergli. Quando si esce in gruppo, ognuno vota i candidati e un mediatore AI propone il compromesso migliore tra le preferenze di tutti.

## Cosa c'è dentro

```
backend/   FastAPI, SQLAlchemy async, Alembic, pgvector, integrazione Claude/Voyage
mobile/    Flutter (Material 3), Riverpod, go_router, flutter_map
infra/     docker-compose con Postgres+PostGIS+pgvector, Redis, MinIO, Mailpit
docs/      architettura, note GDPR, riferimento API
```

## Funzionalità principali

- Registrazione, login, JWT con refresh, secure storage lato app
- Onboarding multi-step con consensi GDPR (terms, privacy, profilazione AI)
- Catalogo locali con coordinate PostGIS, filtri per tipo, città, raggio, "aperto adesso"
- Raccomandazioni "Stasera per te" basate su geo + popolarità + orario + similarità AI (embedding utente vs locale)
- Sistema amici (ricerca, richieste, accetta/rifiuta)
- Uscite di gruppo: inviti agli amici, voting, AI mediator che suggerisce un compromesso
- Chat per uscita
- Pannello admin per CRUD locali, upload immagini su S3 (MinIO in dev)
- Geolocalizzazione iOS reale, fallback automatico a centro Roma
- Bookmark locali preferiti
- Export dati personali e cancellazione account (Art. 15/17 GDPR)

## Avviare il progetto in locale

### Cosa serve

- Docker Desktop o OrbStack
- Python 3.12 (consiglio `uv`: `brew install uv`)
- Flutter SDK 3.24 o superiore
- Per iOS: Xcode (anche senza simulatore va bene per buildare il backend, ma per testare l'app servono i simulator runtime di iOS)

### Backend

```bash
cd infra
docker compose up -d         # postgres su :5433, redis :6379, minio :9000

cd ../backend
cp .env.example .env
uv sync
uv run alembic upgrade head
uv run python -m app.cli.seed       # 10 locali di prova (Roma + Milano)
uv run python -m app.cli.embed_locales   # categorizza + embedda (mock se ANTHROPIC_API_KEY è vuota)
uv run uvicorn app.main:app --reload
```

API su `http://localhost:8000/docs` (Swagger). Postgres è esposto sulla **5433** anziché 5432 per non andare in conflitto con un eventuale Postgres installato via Homebrew.

### Mobile

```bash
cd mobile
flutter pub get
flutter run -d chrome   # oppure: flutter run (per device/emulator)
```

Per iOS: aggiungere la piattaforma se manca (`flutter create --platforms=ios .`), poi `flutter run -d ios`. Sul simulatore Apple il `localhost` del Mac è raggiungibile direttamente.

### Promuovere un utente ad admin

Dopo aver registrato un account dall'app:

```bash
cd backend
uv run python -m app.cli.set_admin <email>
```

Da quel momento, il pannello "Admin · Gestisci locali" appare nel profilo.

## Configurazione

Il file `.env` di esempio funziona out-of-the-box per dev. Le sole chiavi opzionali interessanti sono:

- `ANTHROPIC_API_KEY` — se valorizzata, l'AI mediator e la categorizzazione locali usano Claude vero. Se vuota, vengono usati fallback deterministici.
- `VOYAGE_API_KEY` — embedding reali da `voyage-3`. Se vuota, embedding mock derivati da SHA-256 (utili per validare la pipeline).

Lavorare in mock-mode è perfettamente funzionale per sviluppare e testare il flow, semplicemente la qualità del ranking AI è meno significativa.

## Stack

Backend: FastAPI, SQLAlchemy 2.0 async, asyncpg, Alembic, PostGIS, pgvector, GeoAlchemy2, Pydantic v2, Argon2, PyJWT, boto3 (per MinIO/S3), Anthropic SDK, Voyage AI SDK.

Mobile: Flutter 3.41, Riverpod, go_router, Dio, flutter_map (OSM), flutter_secure_storage, image_picker, geolocator, url_launcher, google_fonts (Inter), cached_network_image.

Infra dev: docker-compose con Postgres 16 + PostGIS 3.4 + pgvector, Redis 7, MinIO, Mailpit per le email di test.

## Documentazione

- [Architettura](docs/ARCHITECTURE.md)
- [GDPR e privacy](docs/GDPR.md)
- [API reference](docs/API.md)

## Stato

Progetto in sviluppo attivo. Il core (auth, profilazione, catalogo, raccomandazioni, amici, uscite, chat, AI mediator, GDPR) è funzionante. Da fare ancora: notifiche push, integrazione TheFork/OpenTable, eventi calendarizzati, deploy su Hetzner via Caddy.
