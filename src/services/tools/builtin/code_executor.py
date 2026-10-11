"""Safe (non-multimodal) code execution tool.

This is intentionally *not* a general-purpose Python runtime. It supports a small
subset of Python expressions for math / lightweight computation.
"""

from __future__ import annotations

import ast
import math
from typing import Any, Dict

from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter


_ALLOWED_FUNCS = {
    "abs": abs,
    "round": round,
    "min": min,
    "max": max,
    "sum": sum,
}

_ALLOWED_MATH = {
    name: getattr(math, name)
    for name in [
        "sqrt",
        "log",
        "log10",
        "exp",
        "sin",
        "cos",
        "tan",
        "asin",
        "acos",
        "atan",
        "pi",
        "e",
    ]
    if hasattr(math, name)
}


class _SafeEval(ast.NodeVisitor):
    def __init__(self, names: Dict[str, Any]):
        self.names = names

    def visit(self, node):  # type: ignore[override]
        if isinstance(
            node,
            (
                ast.Expression,
                ast.BinOp,
                ast.UnaryOp,
                ast.Constant,
                ast.Num,
                ast.List,
                ast.Tuple,
                ast.Dict,
                ast.Name,
                ast.Call,
                ast.Load,
            ),
        ):
            return super().visit(node)
        raise ValueError(f"Unsupported syntax: {node.__class__.__name__}")

    def visit_Expression(self, node: ast.Expression):
        return self.visit(node.body)

    def visit_Constant(self, node: ast.Constant):
        if isinstance(node.value, (int, float, str, bool)) or node.value is None:
            return node.value
        raise ValueError("Unsupported constant")

    def visit_Num(self, node: ast.Num):
        return node.n

    def visit_List(self, node: ast.List):
        return [self.visit(elt) for elt in node.elts]

    def visit_Tuple(self, node: ast.Tuple):
        return tuple(self.visit(elt) for elt in node.elts)

    def visit_Dict(self, node: ast.Dict):
        return {self.visit(k): self.visit(v) for k, v in zip(node.keys, node.values)}

    def visit_Name(self, node: ast.Name):
        if node.id in self.names:
            return self.names[node.id]
        raise ValueError(f"Unknown name: {node.id}")

    def visit_UnaryOp(self, node: ast.UnaryOp):
        operand = self.visit(node.operand)
        if isinstance(node.op, ast.UAdd):
            return +operand
        if isinstance(node.op, ast.USub):
            return -operand
        raise ValueError("Unsupported unary operator")

    def visit_BinOp(self, node: ast.BinOp):
        left = self.visit(node.left)
        right = self.visit(node.right)
        op = node.op
        if isinstance(op, ast.Add):
            return left + right
        if isinstance(op, ast.Sub):
            return left - right
        if isinstance(op, ast.Mult):
            return left * right
        if isinstance(op, ast.Div):
            return left / right
        if isinstance(op, ast.FloorDiv):
            return left // right
        if isinstance(op, ast.Mod):
            return left % right
        if isinstance(op, ast.Pow):
            return left**right
        raise ValueError("Unsupported binary operator")

    def visit_Call(self, node: ast.Call):
        if not isinstance(node.func, ast.Name):
            raise ValueError("Only simple function calls are allowed")
        fn = self.visit(node.func)
        if fn not in self.names.values():
            raise ValueError("Function not allowed")
        args = [self.visit(a) for a in node.args]
        kwargs = {kw.arg: self.visit(kw.value) for kw in node.keywords if kw.arg}
        return fn(*args, **kwargs)


def safe_eval(expr: str) -> Any:
    names = {**_ALLOWED_FUNCS, **_ALLOWED_MATH}
    tree = ast.parse(expr, mode="eval")
    return _SafeEval(names).visit(tree)


class CodeExecutorTool(BaseTool):
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="code_executor",
            description=(
                "Safely evaluate a small subset of Python expressions for math/light computation. "
                "Use for calculations beyond basic arithmetic (e.g., sqrt/log/trig)."
            ),
            parameters=[
                ToolParameter(
                    name="code",
                    type="string",
                    description="Python expression to evaluate (expression-only; no imports, no file/network).",
                    required=True,
                )
            ],
        )

    async def execute(self, code: str) -> Dict[str, Any]:
        try:
            result = safe_eval(code)
            return {"success": True, "result": result}
        except Exception as exc:  # noqa: BLE001
            return {"success": False, "error": str(exc)}
