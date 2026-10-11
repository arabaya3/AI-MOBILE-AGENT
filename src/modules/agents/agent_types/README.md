# Agent Types

Each agent should be organized in its own subdirectory with the following structure:

```
agent_name/
├── __init__.py
├── prompts.py      # Agent-specific prompt templates
├── schemas.py      # Pydantic models for input/output
├── tools.py        # Agent-specific tools
├── wrapper.py      # Main agent implementation
└── utils.py        # Helper functions
```

## Example Agent Types

- **research_agent**: For web research and information gathering
- **code_agent**: For code generation and analysis
- **data_agent**: For data processing and analysis
- **orchestrator_agent**: For coordinating multiple agents
- **customer_service_agent**: For customer interaction
- **analysis_agent**: For analytical tasks
