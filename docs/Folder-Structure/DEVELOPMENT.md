# Development Guide

This guide covers development workflows, best practices, and conventions for TEIA AI Agents.

## Table of Contents

- [Development Environment](#development-environment)
- [Code Organization](#code-organization)
- [Coding Standards](#coding-standards)
- [Testing Strategy](#testing-strategy)
- [Git Workflow](#git-workflow)
- [Debugging](#debugging)
- [Performance Optimization](#performance-optimization)

## Development Environment

### Required Tools

- Python 3.11+
- Poetry 1.7+
- Docker & Docker Compose
- Git
- VS Code or PyCharm (recommended)

### VS Code Setup

Recommended extensions:
- Python
- Pylance
- Black Formatter
- autoDocstring
- GitLens
- Docker

### IDE Configuration

Create `.vscode/settings.json`:

```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.formatting.provider": "black",
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.linting.flake8Enabled": true,
  "python.testing.pytestEnabled": true,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": true
  }
}
```

## Code Organization

### Module Structure

```python
# Each module should have clear purpose
# Example: src/modules/agents/agent_types/research_agent/

research_agent/
├── __init__.py          # Package exports
├── prompts.py           # Prompt templates
├── schemas.py           # Pydantic models
├── tools.py             # Agent-specific tools
├── wrapper.py           # Main implementation
└── utils.py             # Helper functions
```

### Import Conventions

```python
# Standard library imports
import asyncio
from typing import Optional, List

# Third-party imports
from fastapi import FastAPI, Depends
from pydantic import BaseModel

# Local imports
from src.core.settings import get_settings
from src.modules.agents.common import BaseAgent
```

## Coding Standards

### Type Hints

Always use type hints:

```python
from typing import Optional, List, Dict, Any

async def process_data(
    data: List[Dict[str, Any]],
    timeout: Optional[int] = None
) -> Dict[str, Any]:
    """Process data with optional timeout."""
    pass
```

### Docstrings

Use Google-style docstrings:

```python
def calculate_score(data: List[float], weights: Optional[List[float]] = None) -> float:
    """Calculate weighted score from data.

    Args:
        data: List of numerical values to score
        weights: Optional weights for each value

    Returns:
        Calculated weighted score

    Raises:
        ValueError: If data is empty or weights length mismatch

    Example:
        >>> calculate_score([1.0, 2.0, 3.0])
        2.0
    """
    pass
```

### Error Handling

```python
from src.core.exceptions import AgentError

async def process_request(request: Request) -> Response:
    """Process request with proper error handling."""
    try:
        result = await agent.process(request)
        return Response(data=result)
    except ValidationError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except AgentError as e:
        logger.error(f"Agent processing failed: {e}")
        raise HTTPException(status_code=500, detail="Processing failed")
    except Exception as e:
        logger.exception("Unexpected error")
        raise HTTPException(status_code=500, detail="Internal server error")
```

### Async Best Practices

```python
# Good: Use async/await properly
async def fetch_data(url: str) -> Dict:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        return response.json()

# Good: Use asyncio.gather for parallel operations
async def fetch_multiple(urls: List[str]) -> List[Dict]:
    tasks = [fetch_data(url) for url in urls]
    return await asyncio.gather(*tasks)

# Bad: Blocking in async function
async def bad_fetch(url: str) -> Dict:
    response = requests.get(url)  # Blocking!
    return response.json()
```

## Testing Strategy

### Test Structure

```
tests/
├── unit/                    # Fast, isolated tests
│   ├── core/
│   ├── modules/
│   └── services/
├── integration/             # Service integration tests
│   ├── test_database.py
│   └── test_llm_providers.py
└── e2e/                     # End-to-end workflows
    └── test_agent_workflow.py
```

### Writing Tests

```python
import pytest
from unittest.mock import Mock, patch

@pytest.fixture
async def agent():
    """Create test agent instance."""
    return MyAgent(config={"model": "gpt-4"})

@pytest.mark.asyncio
async def test_agent_process(agent):
    """Test agent processing logic."""
    # Arrange
    input_data = {"query": "test"}
    
    # Act
    result = await agent.process(input_data)
    
    # Assert
    assert result is not None
    assert "response" in result

@pytest.mark.asyncio
@patch('src.services.llm_providers.openai.client.OpenAIClient')
async def test_agent_with_mock(mock_client, agent):
    """Test agent with mocked LLM."""
    # Setup mock
    mock_client.return_value.complete.return_value = "mocked response"
    
    # Test
    result = await agent.process({"query": "test"})
    
    # Verify
    assert result == "mocked response"
    mock_client.return_value.complete.assert_called_once()
```

### Test Coverage

Maintain minimum 80% coverage:

```bash
# Check coverage
make test-cov

# View HTML report
open htmlcov/index.html
```

## Git Workflow

### Branch Naming

- `feature/add-new-agent` - New features
- `fix/agent-memory-leak` - Bug fixes
- `refactor/improve-caching` - Code refactoring
- `docs/update-readme` - Documentation
- `test/add-integration-tests` - Tests

### Commit Messages

```bash
# Good commits
feat: Add research agent with web scraping
fix: Resolve memory leak in agent cache
docs: Update API endpoint documentation
test: Add unit tests for LLM factory

# Bad commits
update code
fix bug
changes
wip
```

### Pre-commit Checks

```bash
# Install hooks
poetry run pre-commit install

# Run manually
make pre-commit
```

## Debugging

### Logging

```python
import structlog

logger = structlog.get_logger(__name__)

async def process_data(data: Dict):
    logger.info("processing_data", data_size=len(data))
    
    try:
        result = await expensive_operation(data)
        logger.info("processing_complete", result_size=len(result))
        return result
    except Exception as e:
        logger.error("processing_failed", error=str(e), data=data)
        raise
```

### Using Debugger

```python
# Add breakpoint
import pdb; pdb.set_trace()

# Or with IPython
import ipdb; ipdb.set_trace()

# VS Code: Set breakpoints in UI
```

### Debug Configuration

VS Code `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: FastAPI",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": [
        "src.main:app",
        "--reload"
      ],
      "jinja": true
    }
  ]
}
```

## Performance Optimization

### Profiling

```python
import cProfile
import pstats

def profile_function():
    profiler = cProfile.Profile()
    profiler.enable()
    
    # Your code here
    
    profiler.disable()
    stats = pstats.Stats(profiler)
    stats.sort_stats('cumulative')
    stats.print_stats()
```

### Memory Optimization

```python
# Use generators for large datasets
def process_large_file(filename: str):
    with open(filename) as f:
        for line in f:  # Generator, not loading all in memory
            yield process_line(line)

# Use connection pooling
from sqlalchemy.pool import NullPool

engine = create_async_engine(
    DATABASE_URL,
    poolclass=NullPool,
    echo=False
)
```

### Caching

```python
from functools import lru_cache
from src.core.memory.cache import Cache

# LRU cache for pure functions
@lru_cache(maxsize=128)
def expensive_calculation(n: int) -> int:
    return n ** 2

# Redis cache for distributed systems
cache = Cache()

async def get_data(key: str) -> Dict:
    cached = await cache.get(key)
    if cached:
        return cached
    
    data = await fetch_from_db(key)
    await cache.set(key, data, ttl=3600)
    return data
```

## Best Practices Checklist

- [ ] Type hints on all functions
- [ ] Docstrings for public APIs
- [ ] Error handling with specific exceptions
- [ ] Logging for important operations
- [ ] Tests for new features
- [ ] No secrets in code
- [ ] Use async/await correctly
- [ ] Connection pooling for databases
- [ ] Proper resource cleanup
- [ ] Code formatted with Black
- [ ] Imports sorted with isort
- [ ] No linting errors
- [ ] Tests pass locally
- [ ] Documentation updated

## Additional Resources

- [FastAPI Best Practices](https://fastapi.tiangolo.com/tutorial/)
- [Python Async/Await Guide](https://docs.python.org/3/library/asyncio.html)
- [Pydantic Documentation](https://docs.pydantic.dev/)
- [SQLAlchemy Async](https://docs.sqlalchemy.org/en/14/orm/extensions/asyncio.html)

---

Happy developing! 💻
