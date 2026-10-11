"""Rate limiting for API endpoints."""

import time
from collections import defaultdict
from typing import Dict

from src.core.settings.config import settings


class RateLimiter:
    """Simple in-memory rate limiter."""

    def __init__(self):
        self.requests: Dict[str, list] = defaultdict(list)
        self.max_requests = getattr(settings, "MAX_REQUESTS_PER_MINUTE", 60)
        self.window_seconds = 60

    def check_rate_limit(self, identifier: str) -> bool:
        """Check if request is within rate limit."""
        now = time.time()
        cutoff = now - self.window_seconds
        
        self.requests[identifier] = [
            ts for ts in self.requests[identifier]
            if ts > cutoff
        ]
        
        if len(self.requests[identifier]) >= self.max_requests:
            return False
        
        self.requests[identifier].append(now)
        return True

    def cleanup(self):
        """Remove old entries to prevent memory buildup."""
        now = time.time()
        cutoff = now - self.window_seconds
        
        for key in list(self.requests.keys()):
            self.requests[key] = [
                ts for ts in self.requests[key]
                if ts > cutoff
            ]
            if not self.requests[key]:
                del self.requests[key]


rate_limiter = RateLimiter()
