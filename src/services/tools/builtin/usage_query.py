"""Read-only usage analytics tool.

Allows the model to fetch basic aggregated usage stats.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any, Dict, Optional

from sqlalchemy import func, select

from src.services.databases.postgresql.database import AsyncSessionLocal
from src.services.databases.postgresql.models import LLMUsageEvent
from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter


class UsageQueryTool(BaseTool):
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="usage_query",
            description="Fetch aggregated LLM usage totals (read-only).",
            parameters=[
                ToolParameter(
                    name="days",
                    type="number",
                    description="How many days back to include (default 30)",
                    required=False,
                ),
                ToolParameter(
                    name="model",
                    type="string",
                    description="Optional model filter",
                    required=False,
                ),
            ],
        )

    async def execute(self, days: int = 30, model: Optional[str] = None, **_: Any) -> Dict[str, Any]:
        try:
            days_i = max(1, min(int(days or 30), 365))
            end = datetime.utcnow()
            start = end - timedelta(days=days_i)

            async with AsyncSessionLocal() as db:
                stmt = select(
                    func.coalesce(func.sum(LLMUsageEvent.input_tokens), 0),
                    func.coalesce(func.sum(LLMUsageEvent.output_tokens), 0),
                    func.coalesce(func.sum(LLMUsageEvent.total_tokens), 0),
                    func.coalesce(func.sum(LLMUsageEvent.cost_usd), 0.0),
                ).where(LLMUsageEvent.created_at >= start, LLMUsageEvent.created_at <= end)

                if model:
                    stmt = stmt.where(LLMUsageEvent.model == model)

                row = (await db.execute(stmt)).one()

            return {
                "success": True,
                "start": start.isoformat() + "Z",
                "end": end.isoformat() + "Z",
                "model": model,
                "total_input_tokens": int(row[0] or 0),
                "total_output_tokens": int(row[1] or 0),
                "total_tokens": int(row[2] or 0),
                "total_cost_usd": float(row[3] or 0.0),
            }
        except Exception as exc:  # noqa: BLE001
            return {"success": False, "error": str(exc)}
