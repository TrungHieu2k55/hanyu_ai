from datetime import UTC, timedelta
from decimal import ROUND_HALF_UP, Decimal


def next_schedule(row: dict, quality: int, accepted_at) -> dict:
    ease = row["ease_factor"]
    old_repetitions = row["repetitions"]
    if quality == 0:
        repetitions, interval = 0, 1
    elif old_repetitions == 0:
        repetitions, interval = 1, 1
    elif old_repetitions == 1:
        repetitions, interval = 2, 6
    else:
        repetitions = old_repetitions + 1
        interval = max(
            1,
            int(
                (row["interval_days"] * ease).quantize(
                    Decimal(1), rounding=ROUND_HALF_UP
                )
            ),
        )
    difference = 5 - quality
    updated_ease = max(
        Decimal("1.3"),
        ease
        + Decimal("0.1")
        - difference * (Decimal("0.08") + difference * Decimal("0.02")),
    )
    return {
        "ease_factor": updated_ease,
        "interval_days": interval,
        "repetitions": repetitions,
        "due_at": accepted_at.astimezone(UTC) + timedelta(days=interval),
        "last_quality": quality,
        "version": row["version"] + 1,
        "algorithm_version": row["algorithm_version"],
    }


def schedule_dto(row: dict) -> dict:
    return {
        "ease_factor": float(row["ease_factor"]),
        "interval_days": row["interval_days"],
        "repetitions": row["repetitions"],
        "due_at": row["due_at"].isoformat(),
        "last_quality": row["last_quality"],
        "version": row["version"],
        "algorithm_version": row["algorithm_version"],
    }
