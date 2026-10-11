"""Real-time notification broadcasting via Server-Sent Events (SSE)."""

import asyncio
import json
import logging
from typing import Dict, Set
from collections import defaultdict

logger = logging.getLogger(__name__)


class NotificationBroadcaster:
    """Broadcast notifications to connected clients via SSE."""

    def __init__(self):
        # user_id -> set of queues
        self._connections: Dict[str, Set[asyncio.Queue]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, user_id: str) -> asyncio.Queue:
        """Register a new SSE connection for a user."""
        queue = asyncio.Queue(maxsize=100)
        async with self._lock:
            self._connections[user_id].add(queue)
        logger.info(f"User {user_id} connected to notification stream. Total connections: {len(self._connections[user_id])}")
        return queue

    async def disconnect(self, user_id: str, queue: asyncio.Queue):
        """Unregister an SSE connection."""
        async with self._lock:
            if user_id in self._connections:
                self._connections[user_id].discard(queue)
                if not self._connections[user_id]:
                    del self._connections[user_id]
        logger.info(f"User {user_id} disconnected from notification stream")

    async def broadcast_to_user(self, user_id: str, event_type: str, data: dict):
        """Broadcast a notification to all connections for a specific user."""
        async with self._lock:
            queues = self._connections.get(user_id, set()).copy()
        
        if not queues:
            logger.debug(f"No active connections for user {user_id}")
            return

        message = {
            "type": event_type,
            "data": data,
            "timestamp": data.get("created_at") or "",
        }
        
        dead_queues = []
        for queue in queues:
            try:
                queue.put_nowait(message)
            except asyncio.QueueFull:
                logger.warning(f"Queue full for user {user_id}, dropping message")
                dead_queues.append(queue)
            except Exception as e:
                logger.error(f"Error broadcasting to user {user_id}: {e}")
                dead_queues.append(queue)
        
        # Clean up dead connections
        if dead_queues:
            async with self._lock:
                for queue in dead_queues:
                    self._connections[user_id].discard(queue)

    async def broadcast_to_space(self, space_id: str, user_ids: list[str], event_type: str, data: dict):
        """Broadcast a notification to all members of a space."""
        for user_id in user_ids:
            await self.broadcast_to_user(user_id, event_type, data)


# Singleton instance
broadcaster = NotificationBroadcaster()
