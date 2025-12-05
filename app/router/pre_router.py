from __future__ import annotations

from app.logger import TraceLogger


class PreRouter:
    def __init__(self, logger: TraceLogger | None = None) -> None:
        self.logger = logger

    def normalize(self, query: str) -> str:
        normalized = " ".join(query.strip().split())
        if self.logger:
            self.logger.log("query_preprocess", original=query, normalized=normalized)
        return normalized
