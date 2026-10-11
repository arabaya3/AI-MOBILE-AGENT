import asyncio
import sys
sys.path.insert(0, '/Users/khalidkhader/Desktop/LawTech/AI-Agents')
from src.services.databases.postgresql.database import AsyncSessionLocal, init_db
from src.modules.apis.v1.auth.service import auth_service

async def main():
    await init_db()
    async with AsyncSessionLocal() as session:
        users = await auth_service.list_users(session, limit=20)
        print("Total users: " + str(len(users)))
        for u in users:
            print("  " + str(u.email) + " | " + str(u.role) + " | active=" + str(u.is_active))
        if not users:
            print("  NO USERS FOUND - run create_admin.py first")

asyncio.run(main())
