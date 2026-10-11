# Contributing to TEIA AI Agents

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone <your-fork-url>`
3. Create a branch: `git checkout -b feature/my-feature`
4. Make your changes
5. Run tests: `make test`
6. Commit your changes: `git commit -m "Add feature"`
7. Push to your fork: `git push origin feature/my-feature`
8. Create a Pull Request

## Development Setup

1. Install Poetry: `curl -sSL https://install.python-poetry.org | python3 -`
2. Install dependencies: `make install-dev`
3. Set up pre-commit hooks: `poetry run pre-commit install`

## Code Standards

### Python Style
- Follow PEP 8
- Use Black for formatting: `make format`
- Use isort for import sorting
- Maximum line length: 100 characters

### Type Hints
- Add type hints to all function signatures
- Use `typing` module for complex types

### Documentation
- Add docstrings to all classes and functions
- Use Google-style docstrings
- Update README.md for new features

### Testing
- Write unit tests for all new functions
- Maintain test coverage above 80%
- Run tests before committing: `make test`

## Commit Messages

Follow conventional commits:
- `feat: Add new feature`
- `fix: Fix bug`
- `docs: Update documentation`
- `test: Add tests`
- `refactor: Refactor code`
- `chore: Update dependencies`

## Pull Request Process

1. Update documentation
2. Add tests for new features
3. Ensure all tests pass
4. Update CHANGELOG.md
5. Request review from maintainers

## Code Review

- Be respectful and constructive
- Respond to feedback promptly
- Keep discussions focused on code quality

## Questions?

Open an issue for questions or discussions.

Thank you for contributing! 🎉
