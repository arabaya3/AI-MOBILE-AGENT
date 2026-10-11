"""Health check router."""

from datetime import datetime

from fastapi import APIRouter

from src.modules.apis.health.schemas import HealthResponse
from src.services.databases.postgresql.client import postgres_client
from src.services.databases.redis.client import redis_client
from src.services.databases.neo4j.client import neo4j_client
from src.services.databases.qdrant.client import qdrant_vector_store

router = APIRouter(tags=["health"])


@router.get("/ready", response_model=HealthResponse)
async def readiness_check() -> HealthResponse:
	"""Readiness probe endpoint."""
	postgres_ok = await postgres_client.ping()
	redis_ok = await redis_client.ping()
	neo4j_ok = await neo4j_client.ping()
	try:
		# Check if collection exists
		qdrant_vector_store.client.get_collection(qdrant_vector_store.collection_name)
		qdrant_ok = True
	except Exception:  # noqa: BLE001
		qdrant_ok = False

	return HealthResponse(
		status="ok",
		service="Lex-Tech-ai-agents",
		version="0.1.0",
		timestamp=datetime.utcnow(),
		details={
			"checks": {
				"database": "ok" if postgres_ok else "fail",
				"cache": "ok" if redis_ok else "fail",
				"neo4j": "ok" if neo4j_ok else "fail",
				"vector_store": "ok" if qdrant_ok else "fail",
			}
		},
	)


@router.get("/live", response_model=HealthResponse)
async def liveness_check() -> HealthResponse:
	"""Liveness probe endpoint."""
	return HealthResponse(
		status="ok",
		service="Lex-Tech-ai-agents",
		version="0.1.0",
		timestamp=datetime.utcnow(),
	)

