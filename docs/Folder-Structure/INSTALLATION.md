# Installation & Setup Guide

## ✅ Project Setup Complete!

Your TEIA AI Agents project structure has been successfully created with best practices for scalable Agentic AI systems.

## 📋 What Has Been Created

### 📁 Directory Structure
- ✅ `src/` - Complete source code structure with core, modules, and services
- ✅ `tests/` - Test suite with unit, integration, and E2E directories
- ✅ `docs/` - Comprehensive documentation (Architecture, QuickStart, Development)
- ✅ `scripts/` - Utility scripts for setup, run, and test
- ✅ `configs/` - Configuration files directory

### 📄 Configuration Files
- ✅ `pyproject.toml` - Poetry configuration with all dependencies
- ✅ `.env.example` - Environment variables template
- ✅ `.gitignore` - Git ignore patterns
- ✅ `Dockerfile` - Docker container configuration
- ✅ `docker-compose.yml` - Multi-service orchestration
- ✅ `Makefile` - Development commands
- ✅ `README.md` - Complete project documentation

### 📚 Documentation
- ✅ Architecture guide with layer explanations
- ✅ Quick start guide for 5-minute setup
- ✅ Development guide with best practices
- ✅ Contributing guidelines
- ✅ Code of conduct
- ✅ Changelog template

### 🏗️ Code Structure
- ✅ 92+ Python files with proper `__init__.py` modules
- ✅ Placeholder implementations with TODO comments
- ✅ Organized by architectural layers
- ✅ Type hints and docstring templates

## 🚀 Next Steps - Installation

### Step 1: Install Poetry (if not installed)

```bash
# Check if Poetry is installed
poetry --version

# If not installed, run:
curl -sSL https://install.python-poetry.org | python3 -
```

Add to PATH (add to ~/.zshrc):
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Step 2: Install Dependencies

```bash
# Navigate to project directory
cd "/Users/khalidkhader/Desktop/my docs/Work/TEIA/AI Agents"

# Run setup script (recommended)
./scripts/setup.sh

# OR manually:
poetry install
```

This will install:
- FastAPI & Uvicorn (Web framework)
- OpenAI & Anthropic (LLM providers)
- LangChain & LangGraph (Agent frameworks)
- SQLAlchemy, asyncpg, neo4j, redis (Databases)
- boto3, azure, google-cloud (Cloud services)
- OpenTelemetry, Prometheus (Observability)
- pytest, black, mypy (Development tools)
- And 50+ other dependencies

### Step 3: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env file and add your API keys
# At minimum, you need:
# - OPENAI_API_KEY
# - SECRET_KEY (generate a secure random string)
```

Example:
```bash
# Generate a secret key
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Add to .env:
OPENAI_API_KEY=sk-your-openai-key-here
SECRET_KEY=your-generated-secret-key
```

### Step 4: Start Development

```bash
# Activate Poetry shell
poetry shell

# Run the application
./scripts/run.sh

# OR using Make
make run

# OR directly
poetry run uvicorn src.main:app --reload
```

### Step 5: Verify Installation

Open your browser:
- API Docs: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

## 🐳 Docker Setup (Alternative)

If you prefer Docker:

```bash
# Start all services (app + databases)
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

This starts:
- FastAPI application (port 8000)
- PostgreSQL (port 5432)
- Redis (port 6379)
- Neo4j (ports 7474, 7687)

## 🧪 Running Tests

```bash
# Run all tests
./scripts/test.sh

# OR using Make
make test

# Test with coverage
make test-cov

# Run specific test types
make test-unit          # Unit tests
make test-integration   # Integration tests
make test-e2e          # End-to-end tests
```

## 🛠️ Development Commands

### Using Make (Recommended)

```bash
make help              # Show all available commands
make install           # Install dependencies
make run              # Run application
make test             # Run tests
make format           # Format code (black + isort)
make lint             # Run linting (flake8, pylint, mypy)
make clean            # Clean up generated files
make docker-up        # Start Docker services
make docker-down      # Stop Docker services
```

### Manual Commands

```bash
# Format code
poetry run black src/
poetry run isort src/

# Type checking
poetry run mypy src/

# Linting
poetry run flake8 src/
poetry run pylint src/

# Security check
poetry run bandit -r src/
```

## 📝 Creating Your First Agent

1. Create agent directory:
```bash
mkdir -p src/modules/agents/agent_types/my_agent
cd src/modules/agents/agent_types/my_agent
```

2. Create required files:
```bash
touch __init__.py prompts.py schemas.py tools.py wrapper.py utils.py
```

3. Implement your agent using the base class in:
   `src/modules/agents/common/base_agent.py`

## 🌐 Creating Your First API Endpoint

1. Create API module:
```bash
mkdir -p src/modules/apis/v1/my_feature
cd src/modules/apis/v1/my_feature
```

2. Create required files:
```bash
touch __init__.py router.py schemas.py handlers.py service.py
```

3. Implement endpoint and register in `src/main.py`

## 📚 Documentation

All documentation is available in:
- `README.md` - Main documentation
- `docs/ARCHITECTURE.md` - System architecture
- `docs/QUICKSTART.md` - Quick setup guide
- `docs/DEVELOPMENT.md` - Development practices
- `PROJECT_STRUCTURE.md` - Complete folder structure
- `CONTRIBUTING.md` - How to contribute

## 🆘 Troubleshooting

### Poetry Issues
```bash
# Clear cache
poetry cache clear . --all

# Reinstall
rm -rf .venv
poetry install
```

### Port Already in Use
```bash
# Change port in .env
API_PORT=8001

# Or when running
poetry run uvicorn src.main:app --port 8001
```

### Database Connection
```bash
# Start database containers
docker-compose up postgres redis neo4j -d

# Check container status
docker-compose ps
```

### Import Errors
```bash
# Ensure Poetry shell is active
poetry shell

# Or prefix commands with poetry run
poetry run python your_script.py
```

## ✅ Pre-Development Checklist

Before starting development, ensure:

- [ ] Poetry is installed (`poetry --version`)
- [ ] Dependencies are installed (`poetry install`)
- [ ] `.env` file is configured with API keys
- [ ] Application runs without errors (`make run`)
- [ ] Tests pass (`make test`)
- [ ] Docker is running (if using containers)
- [ ] Database connections work (if configured)

## 🎯 Project Features Ready to Use

### ✅ Infrastructure
- Async FastAPI application structure
- Configuration management (Pydantic Settings)
- Structured logging setup
- Error handling framework
- Security scaffolding (auth, rate limiting)

### ✅ Agent Framework
- Base agent class for inheritance
- LLM factory for provider selection
- Common tools and utilities
- Agent type organization structure

### ✅ API Framework
- Health check endpoints
- API versioning structure
- Dependency injection setup
- Request/response schemas

### ✅ Service Integrations
- LLM provider structure (OpenAI, Anthropic)
- Cloud service structure (AWS, Azure, GCP)
- Database structure (PostgreSQL, Neo4j, Redis)

### ✅ Development Tools
- Pre-configured Makefile
- Docker & docker-compose
- Test framework (pytest)
- Code formatting (black, isort)
- Linting (flake8, pylint, mypy)
- Pre-commit hooks template

## 🚀 You're Ready to Build!

The project structure is complete and follows industry best practices. All scaffolding is in place - you can now focus on implementing your agent logic and business features.

**Start coding with:**
```bash
cd "/Users/khalidkhader/Desktop/my docs/Work/TEIA/AI Agents"
poetry shell
make run
```

Visit http://localhost:8000/docs to see your API!

---

**Need Help?**
- Read the [README.md](README.md) for detailed documentation
- Check [docs/QUICKSTART.md](docs/QUICKSTART.md) for 5-minute setup
- Review [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for best practices
- See [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for folder overview

**Happy Building! 🎉**
