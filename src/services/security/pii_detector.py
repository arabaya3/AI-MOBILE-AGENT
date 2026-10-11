"""PII detection and anonymization."""

import re
from typing import Any, Dict, List


class PIIDetector:
    """Detect and mask PII in text."""

    def __init__(self):
        self.patterns = {
            "email": r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
            "phone": r'\b(?:\+?1[-.]?)?\(?([0-9]{3})\)?[-.]?([0-9]{3})[-.]?([0-9]{4})\b',
            "ssn": r'\b\d{3}-\d{2}-\d{4}\b',
            "credit_card": r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b',
        }

    def detect(self, text: str) -> List[Dict[str, Any]]:
        """Detect PII entities in text."""
        entities = []
        
        for entity_type, pattern in self.patterns.items():
            matches = re.finditer(pattern, text)
            for match in matches:
                entities.append({
                    "type": entity_type,
                    "text": match.group(),
                    "start": match.start(),
                    "end": match.end(),
                })
        
        return entities

    def mask(self, text: str) -> str:
        """Mask PII in text."""
        masked_text = text
        
        for entity_type, pattern in self.patterns.items():
            if entity_type == "email":
                masked_text = re.sub(pattern, "[EMAIL]", masked_text)
            elif entity_type == "phone":
                masked_text = re.sub(pattern, "[PHONE]", masked_text)
            elif entity_type == "ssn":
                masked_text = re.sub(pattern, "[SSN]", masked_text)
            elif entity_type == "credit_card":
                masked_text = re.sub(pattern, "[CREDIT_CARD]", masked_text)
        
        return masked_text


pii_detector = PIIDetector()
