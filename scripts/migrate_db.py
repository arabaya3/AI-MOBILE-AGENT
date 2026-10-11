"""Database migration script to add new tables for notifications and email verification."""

import asyncio
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import text
from src.services.databases.postgresql.database import engine
from src.services.databases.postgresql.models import Base
from src.core.settings.logging import logger


async def run_migration():
    """Run database migrations to add new tables."""
    
    logger.info("Starting database migration...")
    
    try:
        async with engine.begin() as conn:
            # Check if notifications table exists
            result = await conn.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_name = 'notifications'
                );
            """))
            notifications_exists = result.scalar()
            
            # Check if email_verifications table exists
            result = await conn.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_name = 'email_verifications'
                );
            """))
            email_verifications_exists = result.scalar()
            
            # Check if users table has email_verified column
            result = await conn.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.columns 
                    WHERE table_name = 'users' AND column_name = 'email_verified'
                );
            """))
            email_verified_exists = result.scalar()
            
            # Check if users table has custom_system_prompts column
            result = await conn.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.columns 
                    WHERE table_name = 'users' AND column_name = 'custom_system_prompts'
                );
            """))
            custom_system_prompts_exists = result.scalar()

            # Check if chat_sessions table has langfuse_trace_id column
            result = await conn.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.columns 
                    WHERE table_name = 'chat_sessions' AND column_name = 'langfuse_trace_id'
                );
            """))
            langfuse_trace_id_exists = result.scalar()

            # Add email_verified column to users table if it doesn't exist
            if not email_verified_exists:
                logger.info("Adding email_verified column to users table...")
                await conn.execute(text("""
                    ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE NOT NULL;
                """))
                logger.info("✓ Added email_verified column to users table")
            else:
                logger.info("✓ email_verified column already exists in users table")
                
            # Add custom_system_prompts column to users table if it doesn't exist
            if not custom_system_prompts_exists:
                logger.info("Adding custom_system_prompts column to users table...")
                await conn.execute(text("""
                    ALTER TABLE users ADD COLUMN custom_system_prompts JSON DEFAULT '[]';
                """))
                logger.info("✓ Added custom_system_prompts column to users table")
            else:
                logger.info("✓ custom_system_prompts column already exists in users table")
            
            # Add langfuse_trace_id and langfuse_root_span_id to chat_sessions if they don't exist
            if not langfuse_trace_id_exists:
                logger.info("Adding langfuse columns to chat_sessions table...")
                await conn.execute(text("ALTER TABLE chat_sessions ADD COLUMN langfuse_trace_id VARCHAR"))
                await conn.execute(text("ALTER TABLE chat_sessions ADD COLUMN langfuse_root_span_id VARCHAR"))
                logger.info("✓ Added langfuse columns to chat_sessions table")
            else:
                logger.info("✓ langfuse columns already exist in chat_sessions table")

            # Create all tables (will skip existing ones)
            await conn.run_sync(Base.metadata.create_all)
            
            if not notifications_exists:
                logger.info("✓ Created notifications table")
            else:
                logger.info("✓ notifications table already exists")
            
            if not email_verifications_exists:
                logger.info("✓ Created email_verifications table")
            else:
                logger.info("✓ email_verifications table already exists")
            
            logger.info("✅ Database migration completed successfully!")
            
    except Exception as e:
        logger.error(f"❌ Migration failed: {str(e)}")
        raise


if __name__ == "__main__":
    asyncio.run(run_migration())
