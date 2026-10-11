"""Initialize and register tools on startup."""

from src.core.settings.config import settings
from src.services.tools.builtin.calculator import CalculatorTool
from src.services.tools.builtin.code_executor import CodeExecutorTool
from src.services.tools.builtin.data_analysis import DataAnalysisTool
from src.services.tools.builtin.document_ops import DocumentOpsTool
from src.services.tools.builtin.image_generation import ImageGenerationTool
from src.services.tools.builtin.image_understanding import ImageUnderstandingTool
from src.services.tools.builtin.speech_to_text import SpeechToTextTool
from src.services.tools.builtin.text_to_speech import TextToSpeechTool
from src.services.tools.builtin.usage_query import UsageQueryTool
from src.services.tools.builtin.web_search import TavilySearchTool, WebSearchTool
from src.services.tools.registry import tool_registry
from src.core.settings.logging import logger


def init_tools():
    """Register all available tools based on configuration."""
    import importlib


    if settings.ENABLE_WEB_SEARCH:
        tool_registry.register(TavilySearchTool())

    if settings.ENABLE_CALCULATOR:
        tool_registry.register(CalculatorTool())

    if settings.ENABLE_DATA_ANALYSIS:
        tool_registry.register(DataAnalysisTool())

    # Safe "code execution" (expression evaluator)
    if settings.ENABLE_FUNCTION_CALLING:
        tool_registry.register(CodeExecutorTool())
        tool_registry.register(DocumentOpsTool())
        tool_registry.register(UsageQueryTool())
        tool_registry.register(ImageUnderstandingTool())
        tool_registry.register(ImageGenerationTool())
        tool_registry.register(SpeechToTextTool())
        tool_registry.register(TextToSpeechTool())

    # External tool plugins (optional). Each module should expose `register(tool_registry)`.
    for module_path in getattr(settings, "TOOL_PLUGINS", []) or []:
        try:
            module = importlib.import_module(module_path)
            register_fn = getattr(module, "register", None)
            if callable(register_fn):
                register_fn(tool_registry)
                logger.info("Registered tool plugin", extra={"module": module_path})
            else:
                logger.warning("Tool plugin missing register()", extra={"module": module_path})
        except Exception as exc:  # noqa: BLE001
            logger.warning("Failed to load tool plugin", extra={"module": module_path, "error": str(exc)})
