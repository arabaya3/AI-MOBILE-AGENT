# API v1 Modules

Each API feature should be organized in its own subdirectory:

```
feature_name/
├── __init__.py
├── router.py       # FastAPI route definitions
├── schemas.py      # Request/response models
├── handlers.py     # Request handlers
├── service.py      # Business logic layer
└── validators.py   # Custom validation logic (optional)
```

## Example API Modules

- **agents**: Agent management endpoints
- **tasks**: Task creation and monitoring
- **chat**: Chat interface endpoints
- **documents**: Document processing endpoints
- **workflows**: Workflow orchestration endpoints
