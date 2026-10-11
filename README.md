# TEIA AI Agents

A production-ready, scalable Agentic AI system built with modern best practices for multi-agent orchestration, microservices architecture, and enterprise-grade reliability.

## 🌟 Features

- **Multi-Agent Orchestration**: Build and coordinate multiple AI agents with different capabilities
- **Flexible LLM Integration**: Support for OpenAI, Anthropic, and other LLM providers via factory pattern
- **RESTful API**: FastAPI-based APIs with versioning, health checks, and comprehensive documentation
- **Enterprise Security**: JWT authentication, rate limiting, encryption, and role-based access control
- **Observability**: Integrated metrics (Prometheus), distributed tracing (OpenTelemetry), and structured logging
- **Scalable Architecture**: Async-first design with connection pooling, caching, and message queues
- **Multiple Database Support**: PostgreSQL, Neo4j (graph DB), and Redis (cache/queue)
- **Cloud-Native**: Ready for deployment on AWS, Azure, and GCP
- **Type-Safe**: Full type hints with Pydantic models for validation
- **Test Coverage**: Unit, integration, and E2E tests with pytest

## 📋 Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Project Structure](#project-structure)
- [Usage](#usage)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)

## 🏗️ Architecture

The project follows a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│          API Layer (FastAPI)            │
│  Health, v1/agents, v1/tasks, etc.      │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Business Logic Layer            │
│   Agents, Orchestration, Workflows      │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          Services Layer                 │
│  LLM Providers, Cloud, Databases        │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│           Core Layer                    │
│  Settings, Security, Memory, Monitoring │
└─────────────────────────────────────────┘
```

### Key Components

#### 1. **Core Layer** (`src/core/`)
- **Settings**: Configuration management with Pydantic
- **Observability**: Metrics, tracing, and logging
- **Concurrency**: Async task management and thread pools
- **Security**: Authentication, encryption, rate limiting
- **Memory**: Caching, agent memory, message queues
- **Exceptions**: Centralized error handling

#### 2. **Modules Layer** (`src/modules/`)
- **Agents**: AI agent implementations with shared base classes
  - Common utilities and LLM factory
  - Agent-specific prompts, tools, and schemas
- **APIs**: RESTful endpoints organized by version
  - Health checks
  - Feature-based API modules

#### 3. **Services Layer** (`src/services/`)
- **LLM Providers**: OpenAI, Anthropic integrations
- **Cloud Services**: AWS, Azure, GCP clients
- **Databases**: Neo4j, PostgreSQL, Redis adapters

For detailed architecture documentation, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## 📦 Prerequisites

- **Python**: 3.11 or higher
- **Poetry**: For dependency management
- **Docker** (optional): For running databases locally
- **API Keys**: OpenAI, Anthropic, or other LLM providers

### Optional Services
- PostgreSQL 15+
- Neo4j 5+
- Redis 7+

## 🚀 Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd "AI Agents"
```

### 2. Install Poetry

If you don't have Poetry installed:

```bash
curl -sSL https://install.python-poetry.org | python3 -
```

Add Poetry to your PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 3. Run Setup Script

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

This script will:
- Install all Python dependencies via Poetry
- Create a `.env` file from `.env.example`
- Set up necessary directories

### 4. Manual Installation (Alternative)

```bash
# Install dependencies
poetry install

# Activate virtual environment
poetry shell

# Copy environment template
cp .env.example .env
```

### 5. Configure Environment Variables

Edit `.env` and add your credentials:

```bash
# Required
OPENAI_API_KEY=sk-...
SECRET_KEY=your-secure-secret-key

# Optional: Add other service credentials as needed
```

## ⚙️ Configuration

### Environment Variables

The application uses environment variables for configuration. Key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_ENV` | Environment (development/staging/production) | `development` |
| `API_PORT` | API server port | `8000` |
| `LOG_LEVEL` | Logging level | `INFO` |
| `OPENAI_API_KEY` | OpenAI API key | Required |
| `POSTGRES_HOST` | PostgreSQL host | `localhost` |
| `NEO4J_URI` | Neo4j connection URI | `bolt://localhost:7687` |
| `REDIS_HOST` | Redis host | `localhost` |

See `.env.example` for all available configuration options.

### Configuration Files

YAML configuration files in `configs/` directory:
- `development.yaml`: Development settings
- `staging.yaml`: Staging settings
- `production.yaml`: Production settings

## 📁 Project Structure

```
AI Agents/
├── src/                          # Source code
│   ├── main.py                   # Application entry point
│   ├── core/                     # Core infrastructure
│   │   ├── settings/             # Configuration
│   │   ├── observability/        # Monitoring & tracing
│   │   ├── concurrency/          # Async management
│   │   ├── security/             # Auth & encryption
│   │   ├── memory/               # Caching & queues
│   │   └── exceptions/           # Error handling
│   ├── modules/                  # Business logic
│   │   ├── agents/               # AI agents
│   │   │   ├── common/           # Shared components
│   │   │   │   ├── base_agent.py
│   │   │   │   ├── llm_factory.py
│   │   │   │   └── tools.py
│   │   │   └── agent_types/      # Specific agents
│   │   └── apis/                 # REST APIs
│   │       ├── health/           # Health checks
│   │       └── v1/               # API version 1
│   └── services/                 # External integrations
│       ├── llm_providers/        # OpenAI, Anthropic, etc.
│       ├── cloud/                # AWS, Azure, GCP
│       └── databases/            # Neo4j, PostgreSQL, Redis
├── tests/                        # Test suite
│   ├── unit/                     # Unit tests
│   ├── integration/              # Integration tests
│   └── e2e/                      # End-to-end tests
├── docs/                         # Documentation
├── scripts/                      # Utility scripts
├── configs/                      # Configuration files
├── logs/                         # Application logs
├── data/                         # Data files
├── pyproject.toml                # Poetry configuration
├── .env.example                  # Environment template
└── README.md                     # This file
```

## 🎯 Usage

### Start the Application

#### Using the run script:
```bash
chmod +x scripts/run.sh
./scripts/run.sh
```

#### Using Poetry directly:
```bash
poetry run uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload
```

#### Using Docker (if configured):
```bash
docker-compose up -d
```

### Access the API

Once running, access:
- **API Documentation**: http://localhost:8000/docs
- **ReDoc Documentation**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health

### Basic API Usage

```python
import requests

# Health check
response = requests.get("http://localhost:8000/health")
print(response.json())

# Example agent interaction (implement endpoints first)
# response = requests.post(
#     "http://localhost:8000/api/v1/agents/chat",
#     json={"message": "Hello, agent!"}
# )
```

### Creating a New Agent

1. Create agent directory in `src/modules/agents/agent_types/`:

```bash
mkdir -p src/modules/agents/agent_types/my_agent
cd src/modules/agents/agent_types/my_agent
```

2. Create agent files:

```
my_agent/
├── __init__.py
├── prompts.py      # Agent prompts
├── schemas.py      # Data models
├── tools.py        # Agent tools
├── wrapper.py      # Main implementation
└── utils.py        # Helper functions
```

3. Implement the agent using the base agent class:

```python
# wrapper.py
from src.modules.agents.common.base_agent import BaseAgent

class MyAgent(BaseAgent):
    """Custom agent implementation."""
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Initialize agent-specific components
    
    async def process(self, input_data):
        # Implement agent logic
        pass
```

### Creating a New API Endpoint

1. Create module in `src/modules/apis/v1/`:

```bash
mkdir -p src/modules/apis/v1/my_feature
```

2. Create module files:

```
my_feature/
├── __init__.py
├── router.py       # FastAPI routes
├── schemas.py      # Request/response models
├── handlers.py     # Request handlers
└── service.py      # Business logic
```

3. Implement the endpoint:

```python
# router.py
from fastapi import APIRouter, Depends
from .schemas import MyRequest, MyResponse
from .handlers import handle_request

router = APIRouter(prefix="/my-feature", tags=["My Feature"])

@router.post("/", response_model=MyResponse)
async def my_endpoint(request: MyRequest):
    return await handle_request(request)
```

4. Register router in `src/main.py`.

## 🛠️ Development

### Activate Virtual Environment

```bash
poetry shell
```

### Install Development Dependencies

```bash
poetry install --with dev
```

### Code Formatting

```bash
# Format code with Black
poetry run black src/

# Sort imports with isort
poetry run isort src/

# Run both
poetry run black src/ && poetry run isort src/
```

### Code Quality Checks

```bash
# Type checking
poetry run mypy src/

# Linting
poetry run flake8 src/
poetry run pylint src/

# Security checks
poetry run bandit -r src/
```

### Pre-commit Hooks

```bash
# Install pre-commit hooks
poetry run pre-commit install

# Run manually
poetry run pre-commit run --all-files
```

## 🧪 Testing

### Run All Tests

```bash
chmod +x scripts/test.sh
./scripts/test.sh
```

Or with Poetry:

```bash
poetry run pytest
```

### Run Specific Tests

```bash
# Unit tests only
poetry run pytest tests/unit/

# Integration tests
poetry run pytest tests/integration/

# E2E tests
poetry run pytest tests/e2e/

# Specific test file
poetry run pytest tests/unit/test_example.py

# Specific test function
poetry run pytest tests/unit/test_example.py::test_function_name
```

### Test Coverage

```bash
# Generate coverage report
poetry run pytest --cov=src --cov-report=html --cov-report=term

# Open HTML report
open htmlcov/index.html
```

### Test with Different Environments

```bash
# Set environment variable
APP_ENV=staging poetry run pytest
```

## 🚢 Deployment

### Docker Deployment

1. Create `Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install Poetry
RUN pip install poetry

# Copy dependency files
COPY pyproject.toml poetry.lock ./

# Install dependencies
RUN poetry config virtualenvs.create false \
    && poetry install --no-dev --no-interaction --no-ansi

# Copy application
COPY src/ ./src/

# Expose port
EXPOSE 8000

# Run application
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

2. Build and run:

```bash
docker build -t teia-ai-agents .
docker run -p 8000:8000 --env-file .env teia-ai-agents
```

### Docker Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8000:8000"
    env_file:
      - .env
    depends_on:
      - postgres
      - redis
      - neo4j

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: teia_agents
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  neo4j:
    image: neo4j:5
    environment:
      NEO4J_AUTH: neo4j/password
    ports:
      - "7474:7474"
      - "7687:7687"
```

### Cloud Deployment

#### AWS (using ECS/Fargate)
- Build Docker image and push to ECR
- Create ECS task definition
- Deploy to Fargate cluster

#### Azure (using Container Apps)
- Push image to Azure Container Registry
- Deploy to Azure Container Apps
- Configure environment variables

#### GCP (using Cloud Run)
- Push image to Google Container Registry
- Deploy to Cloud Run
- Set environment variables

### Environment Variables for Production

Ensure these are set securely in production:

```bash
APP_ENV=production
DEBUG=false
SECRET_KEY=<strong-random-secret>
JWT_SECRET_KEY=<strong-random-jwt-secret>
# Add all service credentials
```

## 📚 Additional Resources

### Documentation
- [Architecture Guide](docs/ARCHITECTURE.md)
- [API Documentation](http://localhost:8000/docs) (when running)
- [Agent Types README](src/modules/agents/agent_types/README.md)
- [API Modules README](src/modules/apis/v1/README.md)

### External Documentation
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [LangChain Documentation](https://python.langchain.com/)
- [LangGraph Documentation](https://langchain-ai.github.io/langgraph/)
- [Poetry Documentation](https://python-poetry.org/docs/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Follow PEP 8 style guide
- Add type hints to all functions
- Write docstrings for classes and functions
- Maintain test coverage above 80%
- Update documentation for new features

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Contact the development team
- Check the documentation in `docs/`

## 🙏 Acknowledgments

- Built with [FastAPI](https://fastapi.tiangolo.com/)
- Inspired by [LangGraph](https://github.com/langchain-ai/langgraph) and [AutoGen](https://github.com/microsoft/autogen)
- Architecture based on Domain-Driven Design and Clean Architecture principles

---

**Happy Building! 🚀**
