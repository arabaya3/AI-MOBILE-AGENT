# Configuration Files

This directory contains configuration files for different environments and services.

## Structure

```
configs/
├── development.yaml    # Development environment config
├── staging.yaml        # Staging environment config
├── production.yaml     # Production environment config
├── agents/            # Agent-specific configurations
├── logging/           # Logging configurations
└── services/          # Service-specific configurations
```

## Usage

Configuration files are loaded based on the `APP_ENV` environment variable.
