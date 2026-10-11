#!/usr/bin/env python
"""
Migration: add user profile columns to the users table.

Columns added (all idempotent — no-op if they already exist):

  Identity:
    first_name        VARCHAR(100)
    last_name         VARCHAR(100)
    date_of_birth     DATE
    phone_number      VARCHAR(30)
    country           VARCHAR(80)

  Professional context:
    job_title         VARCHAR(120)
    company           VARCHAR(150)

  AI personalisation (added in a prior migration — included here for
  completeness so a fresh install only needs to run this one script):
    industry          VARCHAR(120)
    preferred_language VARCHAR(10)

Run with:

    poetry run python scripts/add_user_profile_columns.py
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

# Make sure the project root is on the path so src imports work.
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text

from src.services.databases.postgresql.database import engine


# Each entry: (column_name, DDL_type)
COLUMNS_TO_ADD: list[tuple[str, str]] = [
    ("first_name",         "VARCHAR(100)"),
    ("last_name",          "VARCHAR(100)"),
    ("date_of_birth",      "DATE"),
    ("phone_number",       "VARCHAR(30)"),
    ("country",            "VARCHAR(80)"),
    ("job_title",          "VARCHAR(120)"),
    ("company",            "VARCHAR(150)"),
    ("industry",           "VARCHAR(120)"),
    ("preferred_language", "VARCHAR(10)"),
]


async def run_migration() -> None:
    altered = False

    async with engine.begin() as conn:
        for col_name, col_type in COLUMNS_TO_ADD:
            result = await conn.execute(text("""
                SELECT EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name = 'users'
                      AND column_name = :col
                );
            """), {"col": col_name})
            exists = result.scalar()

            if exists:
                print(f"  — already exists : users.{col_name}")
            else:
                await conn.execute(
                    text(f"ALTER TABLE users ADD COLUMN {col_name} {col_type} DEFAULT NULL;")
                )
                print(f"  ✓ added           : users.{col_name} {col_type}")
                altered = True

    if altered:
        print("\n✅ Migration committed successfully.")
    else:
        print("\nℹ️  Nothing to migrate — all columns already present.")


if __name__ == "__main__":
    print("Running user profile column migration…\n")
    asyncio.run(run_migration())

