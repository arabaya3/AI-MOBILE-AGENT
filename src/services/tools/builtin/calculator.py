"""Calculator tool for mathematical operations."""

import math
from typing import Any, Dict

from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter


class CalculatorTool(BaseTool):
    """Perform mathematical calculations."""

    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="calculator",
            description="Perform mathematical calculations. Supports basic arithmetic, powers, and math functions like sqrt, sin, cos, log.",
            parameters=[
                ToolParameter(
                    name="expression",
                    type="string",
                    description="Mathematical expression to evaluate (e.g., '2 + 2', 'sqrt(16)', 'sin(pi/2)')",
                    required=True,
                )
            ],
        )

    async def execute(self, expression: str) -> Dict[str, Any]:
        """Safely evaluate mathematical expression."""
        try:
            # Define safe math functions
            safe_dict = {
                "sqrt": math.sqrt,
                "sin": math.sin,
                "cos": math.cos,
                "tan": math.tan,
                "log": math.log,
                "log10": math.log10,
                "exp": math.exp,
                "pi": math.pi,
                "e": math.e,
                "abs": abs,
                "pow": pow,
                "round": round,
            }

            # Evaluate expression
            result = eval(expression, {"__builtins__": {}}, safe_dict)

            return {"success": True, "result": result, "expression": expression}

        except Exception as e:
            return {"success": False, "error": f"Calculation error: {str(e)}"}
