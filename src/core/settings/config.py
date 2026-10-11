"""Application configuration management."""

from typing import List

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings."""

    # Database
    POSTGRES_HOST: str = "localhost"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "teia_agents"
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str = "postgres"

    # AWS S3
    AWS_ACCESS_KEY_ID: str 
    AWS_SECRET_ACCESS_KEY: str
    AWS_REGION: str 
    AWS_S3_BUCKET: str 

    # Optional: create a dedicated bucket per space.
    # If enabled, each space will be assigned its own bucket name derived from `AWS_S3_SPACE_BUCKET_PREFIX`.
    AWS_S3_PER_SPACE_BUCKET: bool = False
    AWS_S3_SPACE_BUCKET_PREFIX: str = ""

    # Security / JWT
    SECRET_KEY: str = "change-me"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_HOURS: int = 24
    
    # OpenAI
    OPENAI_API_KEY: str = ""
    OPENAI_ORGANIZATION: str = ""
    OPENAI_PROJECT: str = ""
    OPENAI_ORG_ID: str = ""
    OPENAI_PROJECT_ID: str = ""
    OPENAI_BASE_URL: str = ""
    OPENAI_EMBEDDING_MODEL: str = "text-embedding-3-large"
    OPENAI_EMBEDDING_FALLBACK_MODEL: str = "text-embedding-3-small"
    OPENAI_CHAT_MODEL: str = "gpt-5-nano"
    # Optional JSON mapping of per-token pricing used for cost estimation.
    # Example: {"gpt-4o-mini": {"input": 0.15e-6, "output": 0.60e-6}}
    OPENAI_PRICING_PER_TOKEN_JSON: str = ""

    # Other LLM providers (optional; supply base_url if using OpenAI-compatible endpoints)
    ANTHROPIC_API_KEY: str = ""
    ANTHROPIC_BASE_URL: str = ""
    GEMINI_API_KEY: str = ""
    GOOGLE_API_KEY: str = ""
    GEMINI_BASE_URL: str = ""
    DEEPSEEK_API_KEY: str = ""
    DEEPSEEK_BASE_URL: str = ""
    QWEN_API_KEY: str = ""
    QWEN_BASE_URL: str = ""
    # Qwen (Alibaba Cloud Model Studio / DashScope) OpenAI-compatible
    # Some deployments export the API key/base URL under these names.
    DASHSCOPE_API_KEY: str = ""
    DASHSCOPE_BASE_URL: str = ""

    # Qdrant
    QDRANT_URL: str = "http://localhost:6333"
    QDRANT_COLLECTION: str = "documents"
    QDRANT_API_KEY: str = ""
    QDRANT_VECTOR_SIZE: int = 3072
    QDRANT_DISTANCE: str = "Cosine"
    QDRANT_TIMEOUT_SEC: int = 120
    QDRANT_UPSERT_BATCH_SIZE: int = 64
    QDRANT_UPSERT_MAX_RETRIES: int = 3
    QDRANT_MIN_UPSERT_BATCH_SIZE: int = 10
    QDRANT_SUPPRESS_INSECURE_WARNING: bool = True
    
    # Document Processing
    DOCUMENT_CHUNK_SIZE: int = 500
    DOCUMENT_CHUNK_OVERLAP: int = 100
    DEFAULT_RETRIEVAL_TOP_K: int = 10
    PDF_OCR_LANGUAGE: str = "eng"
    PDF_OCR_DPI: int = 300
    PDF_OCR_TESSDATA: str = ""
    
    # Advanced Chunking
    CHUNKING_STRATEGY: str = "recursive"
    CHUNK_SIZE: int = 800
    CHUNK_OVERLAP: int = 150
    MIN_CHUNK_SIZE: int = 200
    MAX_CHUNK_SIZE: int = 1200
    SEMANTIC_THRESHOLD: float = 0.75
    
    # Embedding Strategy
    EMBEDDING_PROVIDER: str = "openai"
    EMBEDDING_BATCH_SIZE: int = 100
    EMBEDDING_MAX_RETRIES: int = 3
    ENABLE_EMBEDDING_CACHE: bool = True
    EMBEDDING_CACHE_TTL: int = 86400
    
    # Hybrid Search
    ENABLE_HYBRID_SEARCH: bool = True
    HYBRID_ALPHA: float = 0.75
    BM25_K1: float = 1.5
    BM25_B: float = 0.75
    
    # Reranking
    ENABLE_RERANKING: bool = True
    RERANK_MODEL: str = "cross-encoder/ms-marco-MiniLM-L-6-v2"
    RERANK_TOP_K: int = 50
    FINAL_TOP_K: int = 10
    
    # Performance
    MAX_FILE_SIZE_MB: int = 100
    PROCESSING_TIMEOUT_SECONDS: int = 300
    MAX_CONCURRENT_UPLOADS: int = 10
    BATCH_INSERT_SIZE: int = 1000
    
    # Security
    ENABLE_PII_DETECTION: bool = False
    ENABLE_MALWARE_SCAN: bool = False
    MAX_REQUESTS_PER_MINUTE: int = 300
    ENABLE_AUDIT_LOGGING: bool = True
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_PER_MINUTE: int = 300

    # CORS
    CORS_ALLOW_ORIGINS: List[str] = [
        "http://localhost:5174",
        "http://127.0.0.1:5174",
        "http://87.106.87.218:5174",
        "https://d3d91yaicuwfj2.cloudfront.net",
        "http://teia-gpt-frontend-2026.s3-website.eu-central-1.amazonaws.com"
    ]

    # Cache / Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_ENABLED: bool = False
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: str = ""
    REDIS_DB: int = 0
    REDIS_SSL: bool = False

    # Email Configuration
    EMAIL_ENABLED: bool = False
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_USE_TLS: bool = True
    EMAIL_FROM: str = "noreply@teia-ai.com"
    EMAIL_FROM_NAME: str = "TEIA AI Agents"
    
    # Frontend URL for email links
    FRONTEND_URL: str = "http://localhost:5174"

    # Neo4j
    NEO4J_URI: str = "bolt://localhost:7687"
    NEO4J_USER: str = "neo4j"
    NEO4J_PASSWORD: str = "neo4j"
    
    # Function Calling / Tools
    ENABLE_FUNCTION_CALLING: bool = True
    MAX_TOOL_ITERATIONS: int = 5
    TOOL_CALL_TIMEOUT: int = 30
    ENABLE_WEB_SEARCH: bool = True
    ENABLE_CALCULATOR: bool = True
    ENABLE_DATA_ANALYSIS: bool = True
    SEARCH_PROVIDER: str = "duckduckgo"  # duckduckgo | tavily | serper
    TAVILY_API_KEY: str = ""
    SERPER_API_KEY: str = ""

    # Invoice PDF branding
    INVOICE_COMPANY_NAME: str = "TEIA"
    INVOICE_COMPANY_ADDRESS: str = "Marktplatz 1, 70173 Stuttgart, Germany"
    INVOICE_COMPANY_EMAIL: str = "Khalid@TEIA.com"
    INVOICE_LOGO_PATH: str = "configs/qader_logo.png"  # relative path to PNG/JPG logo (optional)
    INVOICE_VERIFY_URL: str = ""  # optional URL to encode in QR

    # Metrics
    ENABLE_METRICS: bool = True

    # Tool plugins
    TOOL_PLUGINS: List[str] = []

    # Default policy for new spaces
    DEFAULT_ALLOWED_MODELS: List[str] = ["gpt-5-nano"]
    DEFAULT_ALLOWED_TOOLS: List[str] = [
        "web_search",
        "web_search_tavily",
        "calculator",
        "analyze_data",
        "document_ops",
        "code_executor",
    ]

    # If true, do not auto-fallback to another model when the requested model is not allowed.
    STRICT_MODEL_SELECTION: bool = True

    # Alert threshold for expensive models (USD per 1M tokens)
    HIGH_PRICE_PER_1M_USD: float = 20.0
    
    # Model Pricing (per 1M tokens)
    MODEL_PRICING: dict = {
        # OpenAI (https://openai.com/api/pricing/ | https://platform.openai.com/docs/pricing)
        "gpt-5.2": {"input": 1.750, "output": 14.000},
        "gpt-5.2-pro": {"input": 21.000, "output": 168.000},
        "gpt-5-mini": {"input": 0.250, "output": 2.000},
        "gpt-5-nano": {"input": 0.050, "output": 0.400},
        "gpt-5.1": {"input": 1.250, "output": 10.000},
        "gpt-5": {"input": 1.250, "output": 10.000},
        "gpt-5-pro": {"input": 15.000, "output": 120.000},

        "gpt-4.1": {"input": 2.000, "output": 8.000},
        # "gpt-4.1-mini": {"input": 0.400, "output": 1.600}, # LEGACY/INVALID
        "gpt-4.1-nano": {"input": 0.100, "output": 0.400},

        # Existing / legacy IDs (keep for compatibility)
        "gpt-4o": {"input": 2.50, "output": 10.00},
        "gpt-4o-mini": {"input": 0.150, "output": 0.600},
        "gpt-4o-2024-08-06": {"input": 2.50, "output": 10.00},
        "gpt-4-turbo": {"input": 10.00, "output": 30.00},
        "gpt-3.5-turbo": {"input": 0.50, "output": 1.50},

        # Reasoning / o-series
        "o4-mini": {"input": 1.10, "output": 4.40},
        "o3": {"input": 2.00, "output": 8.00},
        "o3-pro": {"input": 20.00, "output": 80.00},
        "o1": {"input": 15.00, "output": 60.00},

        # Claude (Anthropic) - pricing based on Claude listed rates
        "claude-3-5-sonnet": {"input": 3.00, "output": 15.00},
        "claude-3-5-haiku": {"input": 0.80, "output": 4.00},
        "claude-3-7-sonnet": {"input": 3.00, "output": 15.00},
        "claude-3-sonnet": {"input": 3.00, "output": 15.00},
        "claude-3-opus": {"input": 15.00, "output": 75.00},
        "claude-3-haiku": {"input": 0.25, "output": 1.25},
        "claude-3-haiku-20240307": {"input": 0.25, "output": 1.25},
        "claude-3-sonnet-20240229": {"input": 3.00, "output": 15.00},
        "claude-3-opus-20240229": {"input": 15.00, "output": 75.00},
        "claude-3-5-sonnet-20241022": {"input": 3.00, "output": 15.00},
        "claude-3-5-haiku-20241022": {"input": 0.80, "output": 4.00},
        "claude-opus-4.5": {"input": 5.00, "output": 25.00},
        "claude-sonnet-4.5": {"input": 3.00, "output": 15.00},
        "claude-haiku-4.5": {"input": 1.00, "output": 5.00},
        "claude-opus-4.1": {"input": 15.00, "output": 75.00},
        "claude-opus-4": {"input": 15.00, "output": 75.00},
        "claude-sonnet-4": {"input": 3.00, "output": 15.00},

        # Gemini (https://ai.google.dev/gemini-api/docs/pricing)
        "gemini-2.5-pro": {"input": 1.25, "output": 10.00},
        "gemini-2.5-flash": {"input": 0.30, "output": 2.50},
        "gemini-2.5-flash-lite": {"input": 0.10, "output": 0.40},
        "gemini-3-pro": {"input": 2.00, "output": 12.00},
        "gemini-3-flash": {"input": 0.50, "output": 3.00},
        "gemini-3-pro-preview": {"input": 2.00, "output": 12.00},
        "gemini-3-flash-preview": {"input": 0.50, "output": 3.00},

        # DeepSeek (https://api-docs.deepseek.com/quick_start/pricing)
        "deepseek-chat": {"input": 0.28, "output": 0.42},
        "deepseek-reasoner": {"input": 0.28, "output": 0.42},

        # Qwen (pricing from partner model listings)
        "qwen3-next-80b-thinking": {"input": 0.15, "output": 1.20},
        "qwen3-next-80b-instruct": {"input": 0.15, "output": 1.20},
        "qwen3-coder-480b-a35b-instruct": {"input": 0.22, "output": 1.80},
        "qwen3-235b-a22b-instruct-2507": {"input": 0.22, "output": 0.88},

        # Embeddings (output tokens are not billed)
        "text-embedding-3-small": {"input": 0.020, "output": 0.0},
        "text-embedding-3-large": {"input": 0.130, "output": 0.0},
        "text-embedding-ada-002": {"input": 0.100, "output": 0.0},
    }

    # Map model IDs seen in the wild to priced model IDs.
    # This prevents usage dashboards from showing "Not priced" when OpenAI rotates model IDs.
    MODEL_ALIASES: dict = {
        # Commonly observed variants
        "gpt-5.2-chat-latest": "gpt-5.2",
        "gpt-5.1-chat-latest": "gpt-5.1",
        "gpt-5-chat-latest": "gpt-5",
        "gpt-5.1-mini": "gpt-5-mini",
        "gemini-3-pro": "gemini-3-pro-preview",
        "gemini-3-flash": "gemini-3-flash-preview",
        "gemini-2.5-flash-preview-09-2025": "gemini-2.5-flash",
        "gemini-2.5-flash-lite-preview-09-2025": "gemini-2.5-flash-lite",
        "claude-3-haiku": "claude-3-haiku-20240307",
        "claude-3-sonnet": "claude-3-sonnet-20240229",
        "claude-3-opus": "claude-3-opus-20240229",
        "claude-3-5-sonnet": "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku": "claude-3-5-haiku-20241022",
    }

    # Optional allowlist: if set, model listing will prefer these.
    # Keep empty to allow any priced model returned by OpenAI.
    SUPPORTED_CHAT_MODELS: list[str] = []

    # Catalog of additional models to show in model-access requests
    # (even if the current provider listing is limited).
    CATALOG_CHAT_MODELS: list[str] = [
        "gpt-5.2",
        "gpt-5.2-pro",
        "gpt-5-mini",
        "gpt-5-nano",
        "gpt-5.1",
        "gpt-5",
        "gpt-5-pro",
        "gpt-4.1",
        "gpt-4.1-mini",
        "gpt-4.1-nano",
        "gpt-4o",
        "gpt-4o-mini",
        "o4-mini",
        "o3",
        "o3-pro",
        "o1",
        "claude-3-5-sonnet",
        "claude-3-5-haiku",
        "claude-3-7-sonnet",
        "claude-3-sonnet",
        "claude-3-opus",
        "claude-3-haiku",
        "claude-3-haiku-20240307",
        "claude-3-sonnet-20240229",
        "claude-3-opus-20240229",
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022",
        "claude-opus-4.5",
        "claude-sonnet-4.5",
        "claude-haiku-4.5",
        "claude-opus-4.1",
        "claude-opus-4",
        "claude-sonnet-4",
        "gemini-2.5-pro",
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite",
        "gemini-3-pro",
        "gemini-3-flash",
        "deepseek-chat",
        "deepseek-reasoner",
        "qwen3-next-80b-thinking",
        "qwen3-next-80b-instruct",
        "qwen3-coder-480b-a35b-instruct",
        "qwen3-235b-a22b-instruct-2507",
        "qwen-plus",
        "qwen-max",
    ]

    # Tool pricing (per request) for billing/alerts
    TOOL_PRICING: dict = {
        "web_search": 0.0,
        "web_search_tavily": 0.008,
    }

    # Model package tokens for policy-based access control.
    MODEL_PACKAGES: list[str] = []

    # Default concrete model when a package token is allowed but no specific model is provided.
    MODEL_PACKAGE_DEFAULTS: dict[str, str] = {}
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "allow"  # Allow extra fields from .env

    @property
    def database_url(self) -> str:
        """PostgreSQL connection URL."""
        user = (self.POSTGRES_USER or "").strip()
        password = (self.POSTGRES_PASSWORD or "").strip()
        host = (self.POSTGRES_HOST or "").strip()
        db = (self.POSTGRES_DB or "").strip()
        return f"postgresql+asyncpg://{user}:{password}@{host}:{self.POSTGRES_PORT}/{db}"

    @property
    def redis_url(self) -> str:
        if self.REDIS_URL:
            return self.REDIS_URL
        scheme = "rediss" if self.REDIS_SSL else "redis"
        password = f":{self.REDIS_PASSWORD}@" if self.REDIS_PASSWORD else ""
        return f"{scheme}://{password}{self.REDIS_HOST}:{self.REDIS_PORT}/{self.REDIS_DB}"


settings = Settings()
