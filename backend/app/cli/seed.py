"""Seed the database with sample locales for development.

Run with: uv run python -m app.cli.seed
Idempotent: skips locales whose name+city already exist.
"""
import asyncio
from datetime import time
from decimal import Decimal

from geoalchemy2.functions import ST_GeomFromText
from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.locale import Locale, LocaleMedia, OpeningHours

# (lng, lat) pairs — note the order!
SAMPLE_LOCALES: list[dict] = [
    # ── Roma ────────────────────────────────────────────────────────────────
    {
        "name": "Trattoria del Cesare",
        "type": "ristorante",
        "description": "Cucina romana tradizionale, cacio e pepe e amatriciana fatte come una volta.",
        "address": "Via dei Coronari 64",
        "city": "Roma",
        "price_level": 3,
        "rating": Decimal("4.5"),
        "lng": 12.4715,
        "lat": 41.9015,
        "media": [
            "https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800",
        ],
        "hours": {0: ("12:00", "23:00"), 1: ("12:00", "23:00"), 2: ("12:00", "23:00"),
                  3: ("12:00", "23:00"), 4: ("12:00", "23:30"), 5: ("12:00", "23:30"),
                  6: None},
    },
    {
        "name": "Bar San Calisto",
        "type": "bar",
        "description": "Storico bar di Trastevere, atmosfera popolare e prezzi onesti.",
        "address": "Piazza San Calisto 3",
        "city": "Roma",
        "price_level": 1,
        "rating": Decimal("4.3"),
        "lng": 12.4694,
        "lat": 41.8881,
        "media": [
            "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=800",
        ],
        "hours": {i: ("06:00", "02:00") for i in range(7)},
    },
    {
        "name": "Pizzeria Da Remo",
        "type": "pizzeria",
        "description": "Pizza romana sottile e croccante, fila fuori ogni sera.",
        "address": "Piazza di Santa Maria Liberatrice 44",
        "city": "Roma",
        "price_level": 2,
        "rating": Decimal("4.6"),
        "lng": 12.4796,
        "lat": 41.8800,
        "media": [
            "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800",
        ],
        "hours": {0: None, 1: ("19:00", "23:30"), 2: ("19:00", "23:30"),
                  3: ("19:00", "23:30"), 4: ("19:00", "23:30"),
                  5: ("19:00", "23:30"), 6: ("19:00", "23:30")},
    },
    {
        "name": "Sant'Eustachio Il Caffè",
        "type": "caffe",
        "description": "Caffetteria storica vicino al Pantheon, una delle migliori miscele di Roma.",
        "address": "Piazza di Sant'Eustachio 82",
        "city": "Roma",
        "price_level": 2,
        "rating": Decimal("4.4"),
        "lng": 12.4756,
        "lat": 41.8985,
        "media": [
            "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800",
        ],
        "hours": {i: ("07:30", "01:00") for i in range(7)},
    },
    {
        "name": "Ex Dogana",
        "type": "club",
        "description": "Ex dogana ferroviaria riconvertita: dj set, eventi e mostre.",
        "address": "Viale dello Scalo San Lorenzo 10",
        "city": "Roma",
        "price_level": 3,
        "rating": Decimal("4.1"),
        "lng": 12.5125,
        "lat": 41.8893,
        "media": [
            "https://images.unsplash.com/photo-1571266028243-d220bc562efb?w=800",
        ],
        "hours": {0: None, 1: None, 2: None, 3: ("22:00", "04:00"),
                  4: ("22:30", "05:00"), 5: ("22:30", "05:00"), 6: None},
    },
    # ── Milano ──────────────────────────────────────────────────────────────
    {
        "name": "Bar Basso",
        "type": "bar",
        "description": "Patria del Negroni Sbagliato, icona del bere milanese.",
        "address": "Via Plinio 39",
        "city": "Milano",
        "price_level": 3,
        "rating": Decimal("4.5"),
        "lng": 9.2105,
        "lat": 45.4810,
        "media": [
            "https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?w=800",
        ],
        "hours": {0: None, 1: ("09:00", "01:30"), 2: ("09:00", "01:30"),
                  3: ("09:00", "01:30"), 4: ("09:00", "02:00"),
                  5: ("09:00", "02:00"), 6: ("09:00", "01:30")},
    },
    {
        "name": "Trippa",
        "type": "ristorante",
        "description": "Cucina italiana di ricerca con quinto quarto in primo piano.",
        "address": "Via Giorgio Vasari 1",
        "city": "Milano",
        "price_level": 4,
        "rating": Decimal("4.7"),
        "lng": 9.2050,
        "lat": 45.4520,
        "media": [
            "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800",
        ],
        "hours": {6: None, 0: ("19:30", "23:30"), 1: ("19:30", "23:30"),
                  2: ("19:30", "23:30"), 3: ("19:30", "23:30"),
                  4: ("19:30", "23:30"), 5: ("19:30", "23:30")},
    },
    {
        "name": "Spontini",
        "type": "pizzeria",
        "description": "Trancio di pizza alta come a Milano si fa, dal 1953.",
        "address": "Via Spontini 4",
        "city": "Milano",
        "price_level": 1,
        "rating": Decimal("4.2"),
        "lng": 9.2169,
        "lat": 45.4774,
        "media": [
            "https://images.unsplash.com/photo-1593504049359-74330189a345?w=800",
        ],
        "hours": {i: ("11:30", "23:30") for i in range(7)},
    },
    {
        "name": "Marchesi 1824",
        "type": "caffe",
        "description": "Pasticceria storica milanese in Galleria, oggi parte del gruppo Prada.",
        "address": "Galleria Vittorio Emanuele II 11",
        "city": "Milano",
        "price_level": 4,
        "rating": Decimal("4.4"),
        "lng": 9.1900,
        "lat": 45.4660,
        "media": [
            "https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800",
        ],
        "hours": {i: ("07:30", "21:00") for i in range(7)},
    },
    {
        "name": "Plastic",
        "type": "club",
        "description": "Storico club LGBT-friendly, serate elettroniche e d'autore.",
        "address": "Via Gargano 15",
        "city": "Milano",
        "price_level": 3,
        "rating": Decimal("4.0"),
        "lng": 9.2200,
        "lat": 45.4480,
        "media": [
            "https://images.unsplash.com/photo-1571266028243-d220bc562efb?w=800",
        ],
        "hours": {0: None, 1: None, 2: None, 3: None,
                  4: ("23:30", "05:00"), 5: ("23:30", "05:00"), 6: None},
    },
]


def _make_hours(locale_id: str | None, hours_map: dict[int, tuple[str, str] | None]) -> list[OpeningHours]:
    rows: list[OpeningHours] = []
    for weekday in range(7):
        slot = hours_map.get(weekday)
        if slot is None:
            rows.append(
                OpeningHours(
                    weekday=weekday,
                    open_time=time(0, 0),
                    close_time=time(0, 1),
                    closed_all_day=True,
                )
            )
        else:
            rows.append(
                OpeningHours(
                    weekday=weekday,
                    open_time=time.fromisoformat(slot[0]),
                    close_time=time.fromisoformat(slot[1]),
                    closed_all_day=False,
                )
            )
    return rows


async def seed() -> None:
    async with SessionLocal() as session:
        created = 0
        skipped = 0
        for entry in SAMPLE_LOCALES:
            existing = await session.scalar(
                select(Locale).where(Locale.name == entry["name"], Locale.city == entry["city"])
            )
            if existing is not None:
                skipped += 1
                continue

            locale = Locale(
                name=entry["name"],
                type=entry["type"],
                description=entry["description"],
                address=entry["address"],
                city=entry["city"],
                price_level=entry["price_level"],
                rating=entry["rating"],
                location=ST_GeomFromText(f"POINT({entry['lng']} {entry['lat']})", 4326),
                is_published=True,
                media=[
                    LocaleMedia(url=url, is_primary=(i == 0), sort_order=i)
                    for i, url in enumerate(entry["media"])
                ],
                opening_hours=_make_hours(None, entry["hours"]),
            )
            session.add(locale)
            created += 1
        await session.commit()
        print(f"Seed done. Created: {created}, skipped (already present): {skipped}")


if __name__ == "__main__":
    asyncio.run(seed())
