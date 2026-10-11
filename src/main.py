"""Main entry point for the Agentic AI application."""

import os

os.environ.setdefault("LANGFUSE_OTEL_ENABLED", "false")

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, Response
from fastapi.responses import Response as FastAPIResponse
from fastapi.middleware.cors import CORSMiddleware

from src.core.observability.observability import record_http_request
from src.core.settings.config import settings
from src.core.security.rate_limiter import rate_limiter
from src.core.observability.metrics import metrics
from src.core.settings.logging_config import setup_logging
from src.modules.apis.health.router import router as health_router
from src.modules.apis.v1.auth.router import router as auth_router
from src.modules.apis.v1.chat.router import router as chat_router
from src.modules.apis.v1.documents import router as documents_router
from src.modules.apis.v1.laws import router as laws_router
from src.modules.apis.v1.spaces.router import router as spaces_router
from src.modules.apis.v1.system_prompts.router import router as system_prompts_router
from src.modules.apis.v1.vector_search.router import router as vector_search_router
from src.modules.apis.v1.notifications.router import router as notifications_router
from src.modules.apis.v1.requests.router import router as requests_router
from src.services.databases.postgresql.database import init_db
from src.core.settings.logging import logger


setup_logging()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events."""
    
    # Startup
    logger.info("Starting application initialization...")
    await init_db()
    
    # Initialize tools
    logger.info("Initializing tools...")
    from src.services.tools.init import init_tools
    init_tools()
    logger.info("Tools initialization complete")
    
    # Warm up models during startup to avoid slow first request
    try:
        logger.info("Warming up reranker model...")
        from src.services.search.reranker import Reranker
        reranker = Reranker()
        await reranker._get_model()
        logger.info("Reranker model warm-up complete")
    except Exception as e:
        logger.warning(f"Reranker model warm-up failed: {str(e)}. Will load on first use.")
    
    logger.info("Application initialization complete")
    yield
    
    # Shutdown
    logger.info("Shutting down application")
    pass


# Initialize FastAPI app
app = FastAPI(
    title="LawTech - Palestinian Legal Platform API",
    description="منصة الاستشارات القانونية الذكية للقانون الفلسطيني",
    version="1.0.0",
    lifespan=lifespan,
)

# Configure CORS (must use explicit origins when allow_credentials=True)
app.add_middleware(
    CORSMiddleware,
    allow_origins=getattr(settings, "CORS_ALLOW_ORIGINS", ["http://localhost:5174", "http://127.0.0.1:5174", "http://87.106.87.218:5174"]),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def request_middleware(request: Request, call_next):
    import time

    # Rate limiting (apply to API routes only)
    if request.url.path.startswith("/api/") and settings.RATE_LIMIT_ENABLED:
        limit = settings.RATE_LIMIT_PER_MINUTE or settings.MAX_REQUESTS_PER_MINUTE
        client_ip = request.client.host if request.client else "unknown"
        key = f"rate:{client_ip}:{request.url.path}"
        result = await rate_limiter.hit(key, limit)
        if not result.allowed:
            return FastAPIResponse(
                content="Rate limit exceeded",
                status_code=429,
                headers={
                    "X-RateLimit-Limit": str(limit),
                    "X-RateLimit-Remaining": str(result.remaining),
                    "X-RateLimit-Reset": str(result.reset_seconds),
                    "Access-Control-Allow-Origin": request.headers.get("origin", "*"),
                    "Access-Control-Allow-Credentials": "true",
                },
            )

    try:
        start = time.perf_counter()
        logger.debug("HTTP request start", extra={"method": request.method, "path": request.url.path})
        response = await call_next(request)
        elapsed = time.perf_counter() - start
        if settings.ENABLE_METRICS:
            record_http_request(request.method, request.url.path, response.status_code, elapsed)
        response.headers["X-Process-Time"] = f"{elapsed:.6f}"
        logger.info(
            "HTTP request complete",
            extra={
                "method": request.method,
                "path": request.url.path,
                "status": response.status_code,
                "elapsed_s": round(elapsed, 6),
            },
        )
        return response
    except Exception as exc:  # noqa: BLE001
        logger.error(
            "HTTP request failed",
            extra={"method": request.method, "path": request.url.path, "error": str(exc)},
        )
        raise


# Include routers
app.include_router(health_router)
app.include_router(auth_router, prefix="/api/v1")
app.include_router(chat_router, prefix="/api/v1")
app.include_router(documents_router, prefix="/api/v1")
app.include_router(laws_router, prefix="/api/v1")
app.include_router(spaces_router, prefix="/api/v1")
app.include_router(system_prompts_router, prefix="/api/v1")
app.include_router(vector_search_router, prefix="/api/v1")
app.include_router(notifications_router, prefix="/api/v1")
app.include_router(requests_router, prefix="/api/v1")



@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "Lex-Tech-ai-agents"}


@app.get("/metrics")
async def metrics_endpoint():
    if not settings.ENABLE_METRICS:
        return FastAPIResponse(status_code=404)
    content, content_type = metrics.render()
    return FastAPIResponse(content=content, media_type=content_type)


@app.get("/")
async def root() -> dict[str, str]:
    """Return a simple landing payload instead of FastAPI's default 404."""
    return {"service": "Lex-Tech-ai-agents", "status": "ready"}


@app.api_route("/socket.io", methods=["GET", "POST", "OPTIONS"], include_in_schema=False)
@app.api_route("/socket.io/", methods=["GET", "POST", "OPTIONS"], include_in_schema=False)
async def socket_placeholder() -> Response:
    """Swallow UI polling requests so they do not spam logs."""
    return Response(status_code=204)
