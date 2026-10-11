# Architecture Documentation

## Overview

TEIA AI Agents is a production-ready, scalable Agentic AI system built with modern best practices.

## Architecture Layers

### 1. Core Layer (`src/core/`)
Foundation components providing cross-cutting concerns:
- **Settings**: Configuration management and environment variables
- **Observability**: Metrics, logging, and distributed tracing
- **Concurrency**: Async operations and thread pool management
- **Security**: Authentication, authorization, and encryption
- **Memory**: Caching, agent memory, and message queues
- **Exceptions**: Centralized error handling

### 2. Modules Layer (`src/modules/`)
Business logic and application features:

#### Agents (`src/modules/agents/`)
- **Common**: Shared agent infrastructure
  - `base_agent.py`: Abstract base class for all agents
  - `llm_factory.py`: Factory for LLM provider selection
  - `tools.py`: Reusable agent tools
  - `utils.py`: Helper functions
  
- **Agent Types**: Specific agent implementations
  - Each agent has: prompts, schemas, tools, wrapper, utils

#### APIs (`src/modules/apis/`)
RESTful API endpoints organized by version:
- **Health**: System health and readiness checks
- **v1**: API version 1 with feature-based modules
  - Each module: router, schemas, handlers, service

### 3. Services Layer (`src/services/`)
External service integrations:

- **LLM Providers**: OpenAI, Anthropic, etc.
- **Cloud**: AWS, Azure, GCP
- **Databases**: Neo4j, PostgreSQL, Redis

Each service module contains:
- `client.py`: Service client wrapper
- `auth.py`: Authentication management
- Additional helpers as needed

## Design Patterns

### Dependency Injection
Services are injected through FastAPI dependencies for testability.

### Factory Pattern
LLM providers are instantiated through factory pattern for flexibility.

### Repository Pattern
Database access is abstracted through repository pattern.

### Service Layer Pattern
Business logic is separated from API handlers in service layer.

## Data Flow

```
API Request → Router → Handler → Service → Agent/External Service → Response
```

## Scaling Considerations

- Async/await throughout for concurrency
- Connection pooling for databases
- Redis caching for performance
- Queue-based task processing
- Horizontal scaling with load balancer
