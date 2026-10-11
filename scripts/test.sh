#!/bin/bash
# Run tests

poetry run pytest tests/ -v --cov=src --cov-report=html --cov-report=term
