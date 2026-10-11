"""Sparse retrieval using BM25 algorithm."""

import asyncio
from typing import Any, Dict, List

from rank_bm25 import BM25Okapi


class SparseSearch:
    """BM25-based sparse retrieval for keyword matching."""

    def __init__(self, k1: float = 1.5, b: float = 0.75):
        self.k1 = k1
        self.b = b
        self.bm25 = None
        self.documents = []
        self.doc_ids = []

    async def index_documents(self, documents: List[Dict[str, Any]]) -> None:
        """Index documents for BM25 search."""
        self.documents = documents
        self.doc_ids = [doc.get("chunk_id", idx) for idx, doc in enumerate(documents)]
        
        tokenized_docs = [
            self._tokenize(doc.get("text", ""))
            for doc in documents
        ]
        
        self.bm25 = await asyncio.to_thread(
            BM25Okapi,
            tokenized_docs
        )

    def _tokenize(self, text: str) -> List[str]:
        """Simple whitespace tokenization."""
        return text.lower().split()

    async def search(self, query: str, top_k: int = 10) -> List[Dict[str, Any]]:
        """Search documents using BM25."""
        if not self.bm25:
            return []
        
        tokenized_query = self._tokenize(query)
        scores = await asyncio.to_thread(
            self.bm25.get_scores,
            tokenized_query
        )
        
        top_indices = scores.argsort()[-top_k:][::-1]
        
        results = []
        for idx in top_indices:
            if scores[idx] > 0:
                results.append({
                    "chunk_id": self.doc_ids[idx],
                    "score": float(scores[idx]),
                    "document": self.documents[idx],
                })
        
        return results


sparse_search = SparseSearch()
