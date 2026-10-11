"""Tool execution engine."""

import asyncio
import json
from typing import Any, Dict, List

from src.core.observability import tracer
from src.core.settings.logging import logger
from src.services.tools.registry import tool_registry


class ToolExecutor:
    """Execute tools based on LLM function calls."""

    async def execute_tool_call(self, tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute a single tool call."""
        span = tracer.start_child_span(tracer.get_current_span(), f"tool_execution:{tool_name}", input={"args": arguments})

        logger.debug("Tool execution start", extra={"tool": tool_name})

        try:
            tool = tool_registry.get(tool_name)
            if not tool:
                return {"success": False, "error": f"Tool '{tool_name}' not found"}

            if not tool.validate_input(**arguments):
                return {"success": False, "error": "Invalid tool arguments"}

            result = await tool.execute(**arguments)
            tracer.end_span(span, metadata={"tool": tool_name, "success": result.get("success")})
            logger.info("Tool execution complete", extra={"tool": tool_name, "success": result.get("success")})
            return result

        except Exception as e:
            tracer.end_span(span, metadata={"error": str(e)})
            logger.error("Tool execution failed", extra={"tool": tool_name, "error": str(e)})
            return {"success": False, "error": str(e)}

    async def execute_parallel_tools(self, tool_calls: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Execute multiple tools in parallel."""
        tasks = []
        for call in tool_calls:
            task = self.execute_tool_call(
                tool_name=call["function"]["name"],
                arguments=json.loads(call["function"]["arguments"]),
            )
            tasks.append(task)

        results = await asyncio.gather(*tasks, return_exceptions=True)

        return [
            r if isinstance(r, dict) else {"success": False, "error": str(r)} for r in results
        ]


# Global executor instance
tool_executor = ToolExecutor()
