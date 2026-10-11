#!/bin/bash
# Run the application

poetry run uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload \
  --reload-exclude ".venv/*" \
  --reload-exclude "**/.venv/*" \
  --reload-exclude "Front-End/node_modules/*" \
  --reload-exclude "**/__pycache__/*"
