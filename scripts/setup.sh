#!/bin/bash
# Setup script for development environment

echo "Setting up TEIA AI Agents development environment..."

# Check if Poetry is installed
if ! command -v poetry &> /dev/null; then
    echo "Poetry not found. Installing Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
fi

# Install dependencies
echo "Installing dependencies..."
poetry install

# Copy environment file
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
    echo "Please update .env with your actual credentials"
fi

# Create necessary directories
mkdir -p logs data

echo "Setup complete! Run 'poetry shell' to activate the virtual environment."
