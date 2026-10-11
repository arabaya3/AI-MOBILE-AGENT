"""Hybrid search combining dense and sparse retrieval."""

from typing import Any, Dict, List

from src.core.settings.config import settings


class HybridSearch:
    """Combines dense vector search with sparse BM25 search."""

    def __init__(self, alpha: float = None):
        self.alpha = alpha or getattr(settings, "HYBRID_ALPHA", 0.75)

    def combine_results(
        self,
        dense_results: List[Dict[str, Any]],
        sparse_results: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        """Combine and rerank results from dense and sparse search."""
        dense_scores = self._normalize_scores(
            {r["chunk_id"]: r["score"] for r in dense_results}
        )
        sparse_scores = self._normalize_scores(
            {r["chunk_id"]: r["score"] for r in sparse_results}
        )
        
        all_chunk_ids = set(dense_scores.keys()) | set(sparse_scores.keys())
        
        combined = []
        for chunk_id in all_chunk_ids:
            dense_score = dense_scores.get(chunk_id, 0.0)
            sparse_score = sparse_scores.get(chunk_id, 0.0)
            
            hybrid_score = self.alpha * dense_score + (1 - self.alpha) * sparse_score
            
            doc = self._find_document(chunk_id, dense_results, sparse_results)
            if doc:
                combined.append({
                    "chunk_id": chunk_id,
                    "score": hybrid_score,
                    "dense_score": dense_score,
                    "sparse_score": sparse_score,
                    **doc,
                })
        
        combined.sort(key=lambda x: x["score"], reverse=True)
        return combined

    def _normalize_scores(self, scores: Dict[str, float]) -> Dict[str, float]:
        """Min-max normalization of scores."""
        if not scores:
            return {}
        
        values = list(scores.values())
        min_val = min(values)
        max_val = max(values)
        
        if max_val == min_val:
            return {k: 1.0 for k in scores}
        
        return {
            k: (v - min_val) / (max_val - min_val)
            for k, v in scores.items()
        }

    def _find_document(
        self,
        chunk_id: str,
        dense_results: List[Dict[str, Any]],
        sparse_results: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        """Find document data from either result set."""
        for result in dense_results:
            if result["chunk_id"] == chunk_id:
                return result
        
        for result in sparse_results:
            if result["chunk_id"] == chunk_id:
                return result.get("document", {})
        
        return {}


hybrid_search = HybridSearch()
