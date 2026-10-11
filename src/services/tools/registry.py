"""Tool registry for managing available tools."""

from typing import Dict, List, Optional

from src.services.tools.base import BaseTool, ToolDefinition


class ToolRegistry:
    """Central registry for all tools."""

    def __init__(self):
        self._tools: Dict[str, BaseTool] = {}

    def register(self, tool: BaseTool):
        """Register a tool."""
        self._tools[tool.definition.name] = tool

    def get(self, name: str) -> Optional[BaseTool]:
        """Get tool by name."""
        return self._tools.get(name)

    def list_tools(self) -> List[ToolDefinition]:
        """List all registered tools."""
        return [tool.definition for tool in self._tools.values()]

    def get_openai_tools(self, allowlist: Optional[List[str]] = None) -> List[Dict]:
        """Get tools in OpenAI function calling format."""
        if allowlist is not None:
            allowset = {str(name).strip() for name in allowlist if str(name).strip()}
            return [
                tool.definition.to_openai_schema()
                for name, tool in self._tools.items()
                if name in allowset
            ]
        return [tool.definition.to_openai_schema() for tool in self._tools.values()]


# Global registry instance
tool_registry = ToolRegistry()
