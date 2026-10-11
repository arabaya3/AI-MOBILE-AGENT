#!/usr/bin/env python3
"""Helper to create an application `admin` user using the project's AuthService.

Usage: from the repository root run:
    python3 scripts/create_admin.py

This uses the project's settings to connect to the database and will create
the tables (if missing) and insert an admin user with a hashed password.
"""

import asyncio
import getpass

from src.core.settings.config import settings
from src.services.databases.postgresql.database import AsyncSessionLocal, init_db
from src.modules.apis.v1.auth.service import auth_service


async def main():
    print("Using database:", settings.database_url)
    await init_db()
    async with AsyncSessionLocal() as session:
        email = input("Admin email: ").strip().lower()
        password = getpass.getpass("Admin password: ")
        if not email or not password:
            print("Email and password are required.")
            return
        user = await auth_service.create_user(session, email=email, password=password, role="admin")
        await session.commit()
        print(f"Created admin user: {user.email} (id={user.id})")


if __name__ == "__main__":
    asyncio.run(main())