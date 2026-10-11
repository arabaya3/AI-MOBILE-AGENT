"""OpenAI embedding utilities with batching and optimization."""

from __future__ import annotations

import asyncio
import hashlib
from typing import Dict, List, Optional

from openai import OpenAI, RateLimitError, APIError, PermissionDeniedError

from src.core.settings.config import settings
from src.core.settings.logging import logger
from src.core.observability import tracer

class OpenAIEmbeddingService:
    """Enhanced OpenAI embeddings with batching and caching."""

    def __init__(self, model: str | None = None) -> None:
        self.model = model or settings.OPENAI_EMBEDDING_MODEL
        self.fallback_model = getattr(settings, "OPENAI_EMBEDDING_FALLBACK_MODEL", "") or ""
        self.api_key = settings.OPENAI_API_KEY
        self.batch_size = getattr(settings, "EMBEDDING_BATCH_SIZE", 100)
        self.max_retries = getattr(settings, "EMBEDDING_MAX_RETRIES", 3)
        self._client_instance: OpenAI | None = None

    async def _embed_with_model(self, texts: List[str], model_id: str) -> tuple[List[List[float]], Dict[str, int]]:
        response = await asyncio.to_thread(
            self._get_client().embeddings.create,
            model=model_id,
            input=texts,
        )
        embeddings = [item.embedding for item in response.data]
        usage = getattr(response, "usage", None)
        usage_details: Dict[str, int] = {}
        if usage is not None:
            usage_details = {
                "input_tokens": int(getattr(usage, "prompt_tokens", 0) or 0),
                "output_tokens": 0,
                "total_tokens": int(getattr(usage, "total_tokens", 0) or 0),
            }
        return embeddings, usage_details

    def _get_client(self) -> OpenAI:
        if not self.api_key:
            raise RuntimeError("OPENAI_API_KEY is not configured")
        if self._client_instance is None:
            org_value = (settings.OPENAI_ORGANIZATION or settings.OPENAI_ORG_ID or "").strip()
            proj_value = (settings.OPENAI_PROJECT or settings.OPENAI_PROJECT_ID or "").strip()
            organization = org_value if org_value.startswith("org_") else None
            project = proj_value if proj_value.startswith("proj_") else None
            self._client_instance = OpenAI(
                api_key=self.api_key,
                organization=organization,
                project=project,
                base_url=(settings.OPENAI_BASE_URL or None),
            )
        return self._client_instance

    async def embed_texts(self, texts: List[str]) -> List[List[float]]:
        """Create embeddings with batching for efficiency."""
        if not texts:
            logger.debug("No texts to embed")
            return []
        
        logger.info(f"Starting embedding for {len(texts)} texts using model {self.model}")
        all_embeddings = []
        
        try:
            for i in range(0, len(texts), self.batch_size):
                batch = texts[i:i + self.batch_size]
                logger.debug(f"Processing batch {i // self.batch_size + 1} with {len(batch)} texts")
                
                try:
                    batch_embeddings, _usage_details = await self._embed_batch(batch)
                    all_embeddings.extend(batch_embeddings)
                    logger.debug(f"Successfully embedded batch with {len(batch_embeddings)} vectors")
                except PermissionDeniedError as e:
                    logger.error("OpenAI permission error during embedding: %s", e)
                    raise
                except RateLimitError as e:
                    logger.error(f"Rate limit error during embedding: {str(e)}")
                    logger.warning(f"Skipping batch {i // self.batch_size + 1}. Check OpenAI quota and billing.")
                    all_embeddings.extend([[0.0] * 3072 for _ in batch])
                except APIError as e:
                    logger.error(f"OpenAI API error during embedding: {str(e)}")
                    logger.warning(f"Returning fallback embeddings for batch {i // self.batch_size + 1}")
                    all_embeddings.extend([[0.0] * 3072 for _ in batch])
                except Exception as e:
                    logger.error(f"Unexpected error during embedding batch: {str(e)}", exc_info=True)
                    logger.warning(f"Returning fallback embeddings for batch {i // self.batch_size + 1}")
                    all_embeddings.extend([[0.0] * 3072 for _ in batch])
            
            logger.info(f"Embedding completed. Generated {len(all_embeddings)} vectors")
            return all_embeddings
        except Exception as e:
            logger.error(f"Critical error in embed_texts: {str(e)}", exc_info=True)
            if isinstance(e, PermissionDeniedError):
                raise
            logger.warning(f"Returning fallback embeddings for all {len(texts)} texts")
            return [[0.0] * 3072 for _ in texts]

    async def embed_texts_with_usage(self, texts: List[str]) -> tuple[List[List[float]], Dict[str, int]]:
        """Create embeddings and return aggregated usage details.

        Usage details are best-effort and depend on OpenAI response fields.
        """
        if not texts:
            return [], {}

        all_embeddings: List[List[float]] = []
        aggregated: Dict[str, int] = {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0}

        for i in range(0, len(texts), self.batch_size):
            batch = texts[i : i + self.batch_size]
            try:
                batch_embeddings, usage_details = await self._embed_batch(batch)
                all_embeddings.extend(batch_embeddings)
                if usage_details:
                    aggregated["input_tokens"] += int(usage_details.get("input_tokens") or 0)
                    aggregated["output_tokens"] += int(usage_details.get("output_tokens") or 0)
                    aggregated["total_tokens"] += int(usage_details.get("total_tokens") or 0)
            except PermissionDeniedError as e:
                logger.error("OpenAI permission error during embedding: %s", e)
                raise
            except Exception:
                # Keep behavior consistent with embed_texts: fallback vectors for failed batches.
                all_embeddings.extend([[0.0] * 3072 for _ in batch])

        return all_embeddings, aggregated

    async def _embed_batch(self, texts: List[str]) -> tuple[List[List[float]], Dict[str, int]]:
        """Embed a single batch with retry logic and comprehensive error handling."""
        span = tracer.start_child_span(
            tracer.get_current_span(),
            "openai.embeddings.batch",
            input={"count": len(texts), "model": self.model},
        )
        
        last_error: Optional[Exception] = None
        
        for attempt in range(self.max_retries):
            try:
                logger.debug(f"Attempt {attempt + 1}/{self.max_retries} to embed {len(texts)} texts")
                
                response = await asyncio.to_thread(
                    self._get_client().embeddings.create,
                    model=self.model,
                    input=texts,
                )
                
                embeddings = [item.embedding for item in response.data]
                usage = getattr(response, "usage", None)
                usage_details: Dict[str, int] = {}
                if usage is not None:
                    usage_details = {
                        "input_tokens": int(getattr(usage, "prompt_tokens", 0) or 0),
                        "output_tokens": 0,
                        "total_tokens": int(getattr(usage, "total_tokens", 0) or 0),
                    }
                metadata = {
                    "model": self.model,
                    "vectors": len(embeddings),
                    "attempt": attempt + 1,
                }
                if usage_details:
                    metadata["usage"] = usage_details
                
                logger.info(f"Successfully embedded batch (attempt {attempt + 1}). Generated {len(embeddings)} vectors. Usage: {usage_details}")
                tracer.end_span(span, metadata=metadata)
                return embeddings, usage_details
                
            except RateLimitError as e:
                last_error = e
                error_msg = str(e)
                logger.error(f"Rate limit error (attempt {attempt + 1}/{self.max_retries}): {error_msg}")
                logger.error(f"Error code: {getattr(e, 'status', 'unknown')} - Check OpenAI API quota and billing at https://platform.openai.com/account/billing/overview")
                
                if attempt < self.max_retries - 1:
                    wait_time = 2 ** (attempt + 1)
                    logger.info(f"Waiting {wait_time}s before retry...")
                    await asyncio.sleep(wait_time)
                else:
                    tracer.end_span(span, status_message=f"Rate limit error after {self.max_retries} attempts: {error_msg}")
                    logger.error(f"Max retries ({self.max_retries}) exceeded for rate limit error")
                    raise
                    
            except PermissionDeniedError as e:
                last_error = e
                error_msg = str(e)
                logger.error(f"OpenAI permission error (attempt {attempt + 1}/{self.max_retries}): {error_msg}")
                if attempt < self.max_retries - 1:
                    wait_time = 2 ** attempt
                    logger.info(f"Waiting {wait_time}s before retry...")
                    await asyncio.sleep(wait_time)
                else:
                    tracer.end_span(span, status_message=f"Permission error after {self.max_retries} attempts: {error_msg}")
                    logger.error(f"Max retries ({self.max_retries}) exceeded for permission error")
                    raise

            except APIError as e:
                last_error = e
                error_msg = str(e)
                logger.error(f"OpenAI API error (attempt {attempt + 1}/{self.max_retries}): {error_msg}")
                logger.error(f"Error type: {type(e).__name__}")
                
                if attempt < self.max_retries - 1:
                    wait_time = 2 ** attempt
                    logger.info(f"Waiting {wait_time}s before retry...")
                    await asyncio.sleep(wait_time)
                else:
                    tracer.end_span(span, status_message=f"API error after {self.max_retries} attempts: {error_msg}")
                    logger.error(f"Max retries ({self.max_retries}) exceeded for API error")
                    raise
                    
            except Exception as e:
                last_error = e
                error_msg = str(e)
                logger.error(f"Unexpected error during embedding (attempt {attempt + 1}/{self.max_retries}): {error_msg}", exc_info=True)
                
                if attempt < self.max_retries - 1:
                    wait_time = 2 ** attempt
                    logger.info(f"Waiting {wait_time}s before retry...")
                    await asyncio.sleep(wait_time)
                else:
                    tracer.end_span(span, status_message=f"Unexpected error after {self.max_retries} attempts: {error_msg}")
                    logger.error(f"Max retries ({self.max_retries}) exceeded")
                    raise
        
        logger.error(f"Embedding batch failed after all retries. Last error: {last_error}")
        raise last_error if last_error else RuntimeError("Embedding batch failed")


embedding_service = OpenAIEmbeddingService()
