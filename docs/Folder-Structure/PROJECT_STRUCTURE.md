# TEIA AI Agents - Project Structure Overview

## 📁 Complete Folder Structure

```
AI Agents/
│
├── 📄 README.md                          # Comprehensive project documentation
├── 📄 pyproject.toml                     # Poetry dependencies & configuration
├── 📄 Dockerfile                         # Docker container configuration
├── 📄 docker-compose.yml                 # Multi-container orchestration
├── 📄 Makefile                           # Development commands
├── 📄 CHANGELOG.md                       # Version history
├── 📄 CONTRIBUTING.md                    # Contribution guidelines
├── 📄 CODE_OF_CONDUCT.md                 # Community standards
├── 📄 .env.example                       # Environment variables template
├── 📄 .gitignore                         # Git ignore patterns
│
├── 📂 src/                               # Source code
│   ├── 📄 __init__.py
│   ├── 📄 main.py                        # Application entry point
│   │
│   ├── 📂 core/                          # Core infrastructure
│   │   ├── 📂 settings/                  # Configuration management
│   │   │   ├── config.py
│   │   │   └── logging_config.py
│   │   │
│   │   ├── 📂 observability/             # Monitoring & tracing
│   │   │   ├── observability.py
│   │   │   ├── metrics.py
│   │   │   └── tracing.py
│   │   │
│   │   ├── 📂 concurrency/               # Async management
│   │   │   ├── async_manager.py
│   │   │   └── thread_pool.py
│   │   │
│   │   ├── 📂 security/                  # Authentication & encryption
│   │   │   ├── auth.py
│   │   │   ├── encryption.py
│   │   │   └── rate_limiter.py
│   │   │
│   │   ├── 📂 memory/                    # Caching & queues
│   │   │   ├── cache.py
│   │   │   ├── memory_manager.py
│   │   │   └── queue.py
│   │   │
│   │   └── 📂 exceptions/                # Error handling
│   │       ├── base.py
│   │       └── handlers.py
│   │
│   ├── 📂 modules/                       # Business logic
│   │   │
│   │   ├── 📂 agents/                    # AI Agents
│   │   │   ├── 📂 common/                # Shared components
│   │   │   │   ├── base_agent.py         # Base agent class
│   │   │   │   ├── llm_factory.py        # LLM provider factory
│   │   │   │   ├── tools.py              # Common tools
│   │   │   │   ├── utils.py              # Utilities
│   │   │   │   └── schemas.py            # Data models
│   │   │   │
│   │   │   └── 📂 agent_types/           # Specific agent implementations
│   │   │       └── 📄 README.md          # Agent structure guide
│   │   │       # Each agent folder contains:
│   │   │       # - prompts.py
│   │   │       # - schemas.py
│   │   │       # - tools.py
│   │   │       # - wrapper.py
│   │   │       # - utils.py
│   │   │
│   │   └── 📂 apis/                      # REST APIs
│   │       ├── dependencies.py           # API dependencies
│   │       │
│   │       ├── 📂 health/                # Health check endpoints
│   │       │   ├── router.py
│   │       │   └── schemas.py
│   │       │
│   │       └── 📂 v1/                    # API version 1
│   │           └── 📄 README.md          # API module guide
│   │           # Each API module contains:
│   │           # - router.py
│   │           # - schemas.py
│   │           # - handlers.py
│   │           # - service.py
│   │
│   └── 📂 services/                      # External integrations
│       │
│       ├── 📂 llm_providers/             # LLM integrations
│       │   ├── 📂 openai/
│       │   │   ├── client.py
│       │   │   ├── auth.py
│       │   │   ├── schemas.py
│       │   │   └── utils.py
│       │   │
│       │   └── 📂 anthropic/
│       │       ├── client.py
│       │       ├── auth.py
│       │       ├── schemas.py
│       │       └── utils.py
│       │
│       ├── 📂 cloud/                     # Cloud providers
│       │   ├── 📂 aws/
│       │   │   ├── client.py
│       │   │   └── auth.py
│       │   │
│       │   ├── 📂 azure/
│       │   │   ├── client.py
│       │   │   └── auth.py
│       │   │
│       │   └── 📂 gcp/
│       │       ├── client.py
│       │       └── auth.py
│       │
│       └── 📂 databases/                 # Database integrations
│           ├── 📂 neo4j/
│           │   ├── client.py
│           │   ├── auth.py
│           │   └── queries.py
│           │
│           ├── 📂 postgresql/
│           │   ├── client.py
│           │   ├── auth.py
│           │   └── models.py
│           │
│           └── 📂 redis/
│               ├── client.py
│               └── auth.py
│
├── 📂 tests/                             # Test suite
│   ├── conftest.py                       # Test fixtures
│   ├── 📂 unit/                          # Unit tests
│   ├── 📂 integration/                   # Integration tests
│   └── 📂 e2e/                           # End-to-end tests
│
├── 📂 docs/                              # Documentation
│   ├── ARCHITECTURE.md                   # Architecture overview
│   ├── QUICKSTART.md                     # Quick start guide
│   └── DEVELOPMENT.md                    # Development guide
│
├── 📂 scripts/                           # Utility scripts
│   ├── setup.sh                          # Setup script
│   ├── run.sh                            # Run application
│   └── test.sh                           # Run tests
│
├── 📂 configs/                           # Configuration files
│   └── README.md                         # Config structure guide
│
├── 📂 logs/                              # Application logs (gitignored)
│
└── 📂 data/                              # Data files (gitignored)
```

## 🏗️ Architecture Layers

### 1. Core Layer
**Location**: `src/core/`

Provides foundational infrastructure:
- ⚙️ **Settings**: Environment configuration, logging setup
- 📊 **Observability**: Metrics, tracing, monitoring
- ⚡ **Concurrency**: Async tasks, thread pools
- 🔐 **Security**: Auth, encryption, rate limiting
- 💾 **Memory**: Caching, agent memory, message queues
- ⚠️ **Exceptions**: Centralized error handling

### 2. Modules Layer
**Location**: `src/modules/`

Business logic and features:

#### Agents (`src/modules/agents/`)
- **Common**: Shared agent infrastructure
  - `base_agent.py`: Abstract base for all agents
  - `llm_factory.py`: Factory for LLM provider selection
  - `tools.py`: Reusable agent tools
  - `utils.py`: Helper functions
  - `schemas.py`: Pydantic data models

- **Agent Types**: Specific agent implementations
  - Each agent: prompts, schemas, tools, wrapper, utils

#### APIs (`src/modules/apis/`)
- **Health**: System health endpoints
- **v1**: Versioned API endpoints
  - Each module: router, schemas, handlers, service

### 3. Services Layer
**Location**: `src/services/`

External service integrations:
- 🤖 **LLM Providers**: OpenAI, Anthropic, etc.
- ☁️ **Cloud**: AWS, Azure, GCP
- 🗄️ **Databases**: Neo4j, PostgreSQL, Redis

Each service: client, auth, utilities

## 🎯 Key Features

### ✅ Production-Ready
- Docker & docker-compose for deployment
- Comprehensive error handling
- Structured logging
- Health checks
- Metrics and monitoring

### ✅ Developer-Friendly
- Poetry for dependency management
- Pre-configured Makefile
- Development scripts
- Extensive documentation
- Type hints throughout

### ✅ Scalable Architecture
- Async-first design
- Connection pooling
- Caching strategies
- Message queues
- Microservices-ready

### ✅ Testing
- Unit tests
- Integration tests
- End-to-end tests
- Test fixtures
- Coverage reporting

### ✅ Security
- JWT authentication
- API key management
- Rate limiting
- Encryption support
- Secrets management

## 📦 Dependencies (via Poetry)

### Core Framework
- FastAPI + Uvicorn
- Pydantic v2

### LLM & AI
- OpenAI
- Anthropic
- LangChain
- LangGraph

### Databases
- asyncpg (PostgreSQL)
- SQLAlchemy 2.0
- neo4j
- redis

### Async & Tasks
- asyncio
- aiohttp
- httpx
- celery

### Cloud Services
- boto3 (AWS)
- azure-identity
- google-cloud-storage

### Observability
- prometheus-client
- opentelemetry
- structlog

### Development
- pytest
- black
- isort
- mypy
- pylint

## 🚀 Quick Commands

```bash
# Setup
make install              # Install dependencies
make setup                # Run setup script

# Development
make run                  # Run application
make test                 # Run tests
make format               # Format code
make lint                 # Check code quality

# Docker
make docker-up            # Start containers
make docker-down          # Stop containers

# Testing
make test-cov             # Test with coverage
make test-unit            # Unit tests only
make test-integration     # Integration tests
```

## 📚 Documentation

- **README.md**: Complete project documentation
- **docs/ARCHITECTURE.md**: System architecture details
- **docs/QUICKSTART.md**: 5-minute setup guide
- **docs/DEVELOPMENT.md**: Development best practices
- **CONTRIBUTING.md**: Contribution guidelines

## 🎓 Best Practices Implemented

✅ **Clean Architecture**: Layered design with clear boundaries  
✅ **SOLID Principles**: Well-structured, maintainable code  
✅ **Type Safety**: Full type hints with mypy  
✅ **Async/Await**: Modern async Python patterns  
✅ **Dependency Injection**: Testable, loosely coupled  
✅ **Factory Pattern**: Flexible LLM provider selection  
✅ **Repository Pattern**: Database abstraction  
✅ **Service Layer**: Separated business logic  
✅ **API Versioning**: Backward compatible APIs  
✅ **Configuration Management**: Environment-based config  
✅ **Structured Logging**: JSON logs for production  
✅ **Error Handling**: Comprehensive exception hierarchy  
✅ **Testing Pyramid**: Unit, integration, E2E tests  
✅ **Documentation**: Comprehensive guides  
✅ **CI/CD Ready**: Docker, health checks, metrics

## 🔄 Next Steps

1. ✅ **Setup Complete** - Project structure created
2. 📝 **Install Dependencies** - Run `make install`
3. ⚙️ **Configure Environment** - Edit `.env` file
4. 🏃 **Start Development** - Run `make run`
5. 🧪 **Write Tests** - Add tests as you code
6. 🤖 **Build Agents** - Create your agents
7. 🌐 **Add APIs** - Expose agent functionality
8. 🚀 **Deploy** - Use Docker or cloud platform

---

**Project Status**: ✅ Structure Complete - Ready for Implementation

The folder structure is production-ready and follows industry best practices from frameworks like AutoGen, LangGraph, and enterprise Python applications. All documentation, configuration, and scaffolding is in place. You can now start implementing your agent logic and business features!
