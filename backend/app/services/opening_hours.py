"""SQL helper for the "open at a given moment" predicate.

A naive `open_time <= now AND close_time > now` works only for windows that
both open and close on the same calendar day. The catalogue contains a lot of
bars/clubs whose hours cross midnight (e.g. 20:00-05:00, or 05:00-00:00
which we model with `close_time = 00:00` to mean "end of the same day").

This helper returns a SQLAlchemy boolean expression that's true if there is
at least one matching `opening_hours` row for the given Python `weekday`
(0=Mon … 6=Sun) and `time`. It handles three cases:

1. Standard same-day window (open < close) — `open ≤ now < close`.
2. Cross-midnight window evaluated on the day it opens — `close ≤ open` and
   `open ≤ now` (we're past the open time today, the window extends into
   tomorrow). This is what makes 20:00-05:00 still count at 21:57.
3. Cross-midnight window evaluated on the next day — `close ≤ open` and
   `now < close`, looking at *yesterday's* row.

Note: `close_time = 00:00` is a common convention for "until midnight" and
naturally satisfies `close ≤ open`, so case 2 catches it.
"""
from datetime import time

from sqlalchemy import and_, exists, or_
from sqlalchemy.sql.elements import ColumnElement

from app.models.locale import Locale, OpeningHours


def is_open_at_clause(weekday: int, now_time: time) -> ColumnElement[bool]:
    prev_weekday = (weekday - 1) % 7
    return exists().where(
        and_(
            OpeningHours.locale_id == Locale.id,
            OpeningHours.closed_all_day.is_(False),
            or_(
                # Case 1: same-day window (open < close), `now` inside it.
                and_(
                    OpeningHours.weekday == weekday,
                    OpeningHours.open_time < OpeningHours.close_time,
                    OpeningHours.open_time <= now_time,
                    OpeningHours.close_time > now_time,
                ),
                # Case 2: cross-midnight window, currently in the evening
                # portion of today (we're past `open_time`).
                and_(
                    OpeningHours.weekday == weekday,
                    OpeningHours.close_time <= OpeningHours.open_time,
                    OpeningHours.open_time <= now_time,
                ),
                # Case 3: cross-midnight window from yesterday, still in
                # the post-midnight tail before `close_time`.
                and_(
                    OpeningHours.weekday == prev_weekday,
                    OpeningHours.close_time <= OpeningHours.open_time,
                    OpeningHours.close_time > now_time,
                ),
            ),
        )
    )
