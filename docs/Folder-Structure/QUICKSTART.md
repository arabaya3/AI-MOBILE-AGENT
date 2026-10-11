# Quick Start Guide

This guide will help you get up and running with TEIA AI Agents quickly.

## Prerequisites Check

```bash
# Check Python version (should be 3.11+)
python --version

# Check Poetry installation
poetry --version

# If Poetry is not installed:
curl -sSL https://install.python-poetry.org | python3 -
```

## Installation (5 minutes)

### Step 1: Install Dependencies

```bash
# Run the setup script
chmod +x scripts/setup.sh
./scripts/setup.sh

# Or manually:
poetry install
```

### Step 2: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env and add your API keys
# At minimum, add:
# - OPENAI_API_KEY=your-key-here
# - SECRET_KEY=your-secret-key
```

### Step 3: Start the Application

```bash
# Using the run script
chmod +x scripts/run.sh
./scripts/run.sh

# Or using Poetry
poetry run uvicorn src.main:app --reload

# Or using Make
make run
```

### Step 4: Verify Installation

Open your browser and visit:
- API Docs: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

## Using Docker (Alternative)

```bash
# Start all services (app, postgres, redis, neo4j)
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Next Steps

### 1. Explore the API

Visit http://localhost:8000/docs to see interactive API documentation.

### 2. Create Your First Agent

```bash
# Create agent directory
mkdir -p src/modules/agents/agent_types/my_agent

# Create agent files (see README for structure)
```

### 3. Add an API Endpoint

```bash
# Create API module
mkdir -p src/modules/apis/v1/my_endpoint

# Create endpoint files (see README for structure)
```

### 4. Run Tests

```bash
# Run all tests
make test

# Or with coverage
make test-cov
```

## Common Commands

```bash
# Development
make run              # Run application
make test             # Run tests
make format           # Format code
make lint             # Check code quality

# Docker
make docker-up        # Start containers
make docker-down      # Stop containers
make docker-logs      # View logs

# Database
make db-upgrade       # Run migrations
make db-revision      # Create migration
```

## Troubleshooting

### Port Already in Use

```bash
# Change port in .env
API_PORT=8001

# Or specify when running
poetry run uvicorn src.main:app --port 8001
```

### Database Connection Issues

```bash
# Start database containers
docker-compose up postgres redis neo4j -d

# Or update .env with your database credentials
```

### Poetry Issues

```bash
# Clear cache
poetry cache clear . --all

# Reinstall
poetry install
```

## Getting Help

- Check [README.md](README.md) for detailed documentation
- Read [ARCHITECTURE.md](docs/ARCHITECTURE.md) for system design
- Open an issue on GitHub
- Check existing issues for solutions

## What's Next?

1. **Read the Architecture**: Understand the system design in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
2. **Explore Examples**: Check example implementations in the codebase
3. **Build Your First Agent**: Follow the agent creation guide in README
4. **Add Your First API**: Create a new API endpoint
5. **Deploy**: Use Docker or cloud deployment options

Happy coding! 🚀
