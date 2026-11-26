from uuid import UUID

from .errors import ApiError
from .ports import Call
from .postgres import one


async def lock_owner(tx, user: UUID) -> None:
    await tx.execute(
        "SELECT pg_advisory_xact_lock(hashtextextended(%s, 0))", (str(user),)
    )


async def lock_vocabulary_writes(tx) -> None:
    await tx.execute(
        "SELECT pg_advisory_xact_lock(hashtextextended('hanyu.vocab.import',0))"
    )


async def receipt(tx, call: Call, operation: str, fingerprint: str) -> UUID | None:
    row = await one(
        tx,
        """
        SELECT payload_hash, resource_id FROM app.operations
        WHERE owner_id = %s AND operation = %s AND client_key = %s
        """,
        (call.identity.user_id, operation, call.idempotency_key),
    )
    if row is None:
        return None
    if row["payload_hash"] != fingerprint:
        raise ApiError(
            409, "IDEMPOTENCY_CONFLICT", "Khóa thao tác đã dùng với dữ liệu khác."
        )
    if row["resource_id"] is None:
        raise ApiError(
            409,
            "OPERATION_IN_PROGRESS",
            "Thao tác đang được xử lý.",
            retryable=True,
        )
    return row["resource_id"]


async def write_receipt(
    tx,
    call: Call,
    operation: str,
    fingerprint: str,
    resource_id: UUID,
    resource_type: str = "job",
) -> UUID:
    row = await one(
        tx,
        """
        INSERT INTO app.operations (owner_id, operation, client_key, payload_hash, status,
                                    resource_type, resource_id, finished_at)
        VALUES (%s, %s, %s, %s, 'completed', %s, %s, transaction_timestamp())
        RETURNING id
        """,
        (
            call.identity.user_id,
            operation,
            call.idempotency_key,
            fingerprint,
            resource_type,
            resource_id,
        ),
    )
    return row["id"]
