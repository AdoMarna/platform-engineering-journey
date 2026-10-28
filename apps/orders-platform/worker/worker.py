"""orders-worker: consumes orders from a Redis stream and processes them.

A consumer group is used instead of a plain list so that an order is never lost:
it stays pending until acknowledged, and orders left behind by a killed worker
are reclaimed by another one (several replicas can run side by side).
"""

import logging
import os
import signal
import socket
import time
from types import FrameType

import psycopg
import redis

STREAM = os.environ.get("ORDERS_STREAM", "orders")
GROUP = os.environ.get("ORDERS_GROUP", "workers")
CONSUMER = os.environ.get("HOSTNAME", socket.gethostname())  # pod name on Kubernetes
PROCESSING_SECONDS = float(os.environ.get("PROCESSING_SECONDS", "2"))
RECLAIM_IDLE_MS = int(os.environ.get("RECLAIM_IDLE_MS", "30000"))

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("orders-worker")

running = True


def stop(signum: int, _frame: FrameType | None) -> None:
    """Finish the current order, then exit (SIGTERM from Docker / Kubernetes)."""
    global running
    log.info("signal %s received, shutting down", signum)
    running = False


def ensure_group(queue: redis.Redis) -> None:
    try:
        queue.xgroup_create(STREAM, GROUP, id="0", mkstream=True)
    except redis.ResponseError as err:
        if "BUSYGROUP" not in str(err):
            raise


def set_status(conn: psycopg.Connection, order_id: int, status: str) -> None:
    conn.execute(
        "UPDATE orders SET status = %s, updated_at = now() WHERE id = %s",
        (status, order_id),
    )


def process(conn: psycopg.Connection, queue: redis.Redis, msg_id: bytes, fields: dict) -> None:
    order_id = int(fields[b"order_id"])
    set_status(conn, order_id, "processing")
    time.sleep(PROCESSING_SECONDS)  # stands in for real work
    set_status(conn, order_id, "completed")
    queue.xack(STREAM, GROUP, msg_id)
    log.info("order %d completed", order_id)


def next_message(queue: redis.Redis) -> tuple[bytes, dict] | None:
    # First take over orders a dead worker left unacknowledged for too long.
    _, claimed, _ = queue.xautoclaim(STREAM, GROUP, CONSUMER, RECLAIM_IDLE_MS, count=1)
    if claimed:
        log.info("reclaimed stale message %s", claimed[0][0])
        return claimed[0]
    # Short block so a shutdown signal is noticed quickly.
    batch = queue.xreadgroup(GROUP, CONSUMER, {STREAM: ">"}, count=1, block=5000)
    return batch[0][1][0] if batch else None


def main() -> None:
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    # Socket timeout must exceed the XREADGROUP block time below.
    queue = redis.Redis.from_url(os.environ["REDIS_URL"], socket_timeout=15)
    ensure_group(queue)
    with psycopg.connect(os.environ["DATABASE_URL"], autocommit=True) as conn:
        log.info("%s consuming stream %r as group %r", CONSUMER, STREAM, GROUP)
        while running:
            message = next_message(queue)
            if message is not None:
                process(conn, queue, *message)


if __name__ == "__main__":
    main()
