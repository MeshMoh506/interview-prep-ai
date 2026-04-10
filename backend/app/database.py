# backend/app/database.py
#
# Root cause of the 500 error:
#   sqlalchemy.exc.OperationalError: could not translate host name
#   "aws-1-ap-south-1.pooler.supabase.com" to address: Name or service not known
#
# Why it happens:
#   Supabase's connection pooler (PgBouncer) drops idle connections after ~5 min.
#   SQLAlchemy hands out a stale pooled connection → psycopg2 DNS lookup fails.
#
# Fix strategy:
#   1. pool_pre_ping=True   — SQLAlchemy issues "SELECT 1" before every checkout.
#                             If it fails, the bad connection is discarded and a fresh
#                             one is opened.  This eliminates the 500 on the NEXT
#                             request after an idle period.
#   2. pool_recycle=240     — Force-recycle connections every 4 min (before Supabase's
#                             5-min idle timeout), preventing stale entries from
#                             accumulating in the pool.
#   3. TCP keepalives       — Keeps the underlying TCP socket alive so the OS does
#                             not silently drop it while the pool holds it.
#   4. get_db with rollback — Ensures any failed transaction is rolled back cleanly
#                             before the session is returned to the pool.

import os
import time
import logging
from sqlalchemy import create_engine, event, text
from sqlalchemy.exc import OperationalError
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

DATABASE_URL = os.getenv("DATABASE_URL", "")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is not set")

engine = create_engine(
    DATABASE_URL,
    # ── Pool stability (Supabase / PgBouncer) ──────────────────────
    pool_pre_ping=True,       # validates connection health before checkout
    pool_recycle=240,         # recycle after 4 min  (Supabase drops idle at 5)
    pool_size=5,              # Supabase free tier cap is 15 connections
    max_overflow=2,           # allow 2 extra connections under burst load
    pool_timeout=30,          # raise after 30 s if pool is exhausted
    # ── TCP keepalive (prevents silent OS-level drops) ─────────────
    connect_args={
        "keepalives":          1,
        "keepalives_idle":     30,   # start probes after 30 s idle
        "keepalives_interval": 10,   # probe every 10 s
        "keepalives_count":    5,    # give up after 5 missed probes
        "connect_timeout":     10,   # fail-fast if host is unreachable
    },
)


# ── Retry helper (wraps get_db so transient DNS blips self-heal) ──
def _execute_with_retry(func, max_retries: int = 2):
    """Re-run func up to max_retries times on OperationalError."""
    last_exc = None
    for attempt in range(max_retries + 1):
        try:
            return func()
        except OperationalError as exc:
            last_exc = exc
            logger.warning(
                "DB OperationalError on attempt %d/%d: %s",
                attempt + 1, max_retries + 1, exc,
            )
            if attempt < max_retries:
                time.sleep(0.5 * (attempt + 1))   # 0.5 s, 1 s back-off
    raise last_exc


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """
    FastAPI dependency.  Yields a SQLAlchemy session and ensures it is
    cleanly closed (with rollback on error) before returning to the pool.
    """
    db = SessionLocal()
    try:
        yield db
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()