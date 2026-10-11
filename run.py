#!/usr/bin/env python3
"""Quick start script to run the API server."""

import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "src.main:app",
        host="0.0.0.0",
        port=8001,
        reload=True,
        reload_excludes=[".venv/*", "**/.venv/*", "Front-End/node_modules/*", "**/__pycache__/*"],
        log_level="info"
    )
