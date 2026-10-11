"""Database migration script to add custom_system_prompts column to users table."""

import asyncio
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text
from src.services.databases.postgresql.database import engine
from src.core.settings.logging import logger


async def run_migration():
    """Run database migration to add custom_system_prompts column."""
    
    logger.info("Starting database migration for custom_system_prompts...")
    
    try:
        async with engine.begin() as conn:
            # Check if users table has custom_system_prompts column
            result = await conn.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.columns 
                    WHERE table_name = 'users' AND column_name = 'custom_system_prompts'
                );
            """))
            column_exists = result.scalar()
            
            if not column_exists:
                logger.info("Adding custom_system_prompts column to users table...")
                await conn.execute(text("""
                    ALTER TABLE users 
                    ADD COLUMN custom_system_prompts JSONB NULL;
                """))
                logger.info("Successfully added custom_system_prompts column.")
            else:
                logger.info("custom_system_prompts column already exists.")
                
    except Exception as e:
        logger.error(f"Migration failed: {e}")
        raise

if __name__ == "__main__":
    asyncio.run(run_migration())
