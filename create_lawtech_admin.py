import asyncio
import sys
sys.path.insert(0, '/Users/khalidkhader/Desktop/LawTech/AI-Agents')
from src.core.settings.config import settings
from src.services.databases.postgresql.database import AsyncSessionLocal, init_db
from src.modules.apis.v1.auth.service import auth_service

EMAIL = "mkhader@bzu.com"
PASSWORD = "Mkhader@2026!"
ROLE = "super_admin"

async def main():
    print("DB URL: " + settings.database_url)
    await init_db()
    print("Tables created/verified.")
    async with AsyncSessionLocal() as session:
        existing = await auth_service.get_user_by_email(session, EMAIL)
        if existing:
            print("User already exists: " + existing.email + " role=" + existing.role)
            return
        user = await auth_service.create_user(
            session,
            email=EMAIL,
            password=PASSWORD,
            role=ROLE,
        )
        await session.commit()
        print("Created " + ROLE + ": " + user.email + " id=" + str(user.id))

asyncio.run(main())
