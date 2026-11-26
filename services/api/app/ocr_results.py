from uuid import UUID

from psycopg.types.json import Jsonb

from .postgres import Database, many


async def insert_tokens(tx, owner: UUID, revision: UUID, tokens: list[dict]) -> None:
    await tx.execute(
        """
        INSERT INTO app.ocr_tokens (owner_id, revision_id, position, hanzi, pinyin)
        SELECT %s, %s, (i - 1)::integer, token ->> 'hanzi', token ->> 'pinyin'
        FROM jsonb_array_elements(%s) WITH ORDINALITY AS entries(token, i)
        """,
        (owner, revision, Jsonb(tokens)),
    )


async def token_page(
    tx,
    db: Database,
    owner: UUID,
    scan: UUID,
    revision: dict,
    limit: int = 100,
    cursor: str | None = None,
) -> dict:
    scope = f"ocr-tokens:{owner}:{scan}:{revision['revision']}"
    position = db.read_position(scope, cursor)
    rows = await many(
        tx,
        """
        SELECT t.id,t.position,t.hanzi,t.pinyin,t.vietnamese,t.confidence,t.entry_id,t.lookup_state,
               coalesce(t.saved_item_id,i.id) AS saved_item_id
        FROM app.ocr_tokens t LEFT JOIN app.learning_items i
          ON i.owner_id=t.owner_id AND i.entry_id=t.entry_id AND i.status='active'
        WHERE t.owner_id = %s AND t.revision_id = %s AND t.position > %s
        ORDER BY t.position LIMIT %s
        """,
        (owner, revision["id"], position, limit + 1),
    )
    page = rows[:limit]
    for row in page:
        for name in ("id", "entry_id", "saved_item_id"):
            row[name] = str(row[name]) if row[name] is not None else None
        if row["confidence"] is not None:
            row["confidence"] = float(row["confidence"])
    return {
        "items": page,
        "next_cursor": db.position_cursor(scope, page[-1]["position"])
        if len(rows) > limit
        else None,
    }
