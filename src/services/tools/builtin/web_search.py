"""Web search tool using DuckDuckGo/Tavily/Serper."""

import asyncio
from typing import Any, Dict

import httpx
from duckduckgo_search import DDGS

from src.core.settings.config import settings
from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter


def _coerce_num_results(num_results: int | None) -> int:
    safe_n = int(num_results or 5)
    if safe_n < 1:
        safe_n = 1
    if safe_n > 10:
        safe_n = 10
    return safe_n


class WebSearchTool(BaseTool):
    """Search the web for current information using DuckDuckGo."""

    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="web_search",
            description="Search the web for current information, news, facts, or data. Use this when you need up-to-date information not in the documents.",
            parameters=[
                ToolParameter(
                    name="query",
                    type="string",
                    description="The search query string",
                    required=True,
                ),
                ToolParameter(
                    name="num_results",
                    type="integer",
                    description="Number of results to return (default: 5)",
                    required=False,
                ),
            ],
        )

    async def execute(self, query: str, num_results: int = 5) -> Dict[str, Any]:
        """Execute web search using DuckDuckGo."""
        try:
            safe_n = _coerce_num_results(num_results)

            formatted_results = []
            provider = "duckduckgo"
            backends = ("api", "html", "lite")
            last_error: Exception | None = None
            max_retries = 2
            
            for backend in backends:
                for retry in range(max_retries):
                    try:
                        with DDGS() as ddgs:
                            results_iter = ddgs.text(query, max_results=safe_n, backend=backend)
                            for r in list(results_iter or [])[:safe_n]:
                                title = (r.get("title") or "").strip()
                                snippet = (r.get("body") or r.get("snippet") or "").strip()
                                url = (r.get("href") or r.get("url") or "").strip()
                                if not (title or snippet or url):
                                    continue
                                formatted_results.append({"title": title, "snippet": snippet, "url": url})
                        if formatted_results:
                            break
                    except Exception as exc:  # noqa: BLE001
                        last_error = exc
                        message = str(exc).lower()
                        if "202" in message or "rate" in message:
                            if retry < max_retries - 1:
                                await asyncio.sleep(2.5 * (retry + 1))
                                continue
                        formatted_results = []
                        break
                if formatted_results:
                    break

            if not formatted_results and last_error is not None:
                error_msg = str(last_error)
                if "202" in error_msg or "rate" in error_msg.lower():
                    return {
                        "success": False,
                        "error": "DuckDuckGo rate limit reached. Please try again later or use Tavily search (premium).",
                        "query": query,
                        "provider": provider,
                    }
                raise last_error

            citations = [item.get("url") for item in formatted_results if item.get("url")]
            payload = {
                "success": True,
                "results": formatted_results,
                "citations": citations,
                "query": query,
                "provider": provider,
            }
            return payload

        except Exception as e:  # noqa: BLE001
            return {"success": False, "error": str(e), "query": query}


class TavilySearchTool(BaseTool):
    """Search the web using Tavily (paid)."""

    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="web_search_tavily",
            description=(
                "Search the web using Tavily for current information. "
                "This is a premium tool that may incur extra cost."
            ),
            parameters=[
                ToolParameter(
                    name="query",
                    type="string",
                    description="The search query string",
                    required=True,
                ),
                ToolParameter(
                    name="num_results",
                    type="integer",
                    description="Number of results to return (default: 5)",
                    required=False,
                ),
            ],
        )

    async def execute(self, query: str, num_results: int = 5) -> Dict[str, Any]:
        """Execute web search using Tavily."""
        try:
            api_key = (settings.TAVILY_API_KEY or "").strip()
            if not api_key:
                return {
                    "success": False,
                    "error": "TAVILY_API_KEY is not configured",
                    "query": query,
                    "provider": "tavily",
                }

            safe_n = _coerce_num_results(num_results)
            formatted_results = []

            async with httpx.AsyncClient(timeout=20) as client:
                resp = await client.post(
                    "https://api.tavily.com/search",
                    json={"api_key": api_key, "query": query, "max_results": safe_n},
                )
                resp.raise_for_status()
                data = resp.json()
            for r in data.get("results", [])[:safe_n]:
                title = (r.get("title") or "").strip()
                snippet = (r.get("content") or r.get("snippet") or "").strip()
                url = (r.get("url") or "").strip()
                if not (title or snippet or url):
                    continue
                formatted_results.append({"title": title, "snippet": snippet, "url": url})

            citations = [item.get("url") for item in formatted_results if item.get("url")]
            return {
                "success": True,
                "results": formatted_results,
                "citations": citations,
                "query": query,
                "provider": "tavily",
            }

        except Exception as e:  # noqa: BLE001
            return {"success": False, "error": str(e), "query": query, "provider": "tavily"}
