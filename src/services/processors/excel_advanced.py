"""Advanced Excel processing with intelligent chunking."""

from pathlib import Path
from typing import Any, Dict, List

import pandas as pd

from src.services.chunking.recursive import chunker


class AdvancedExcelProcessor:
    """Enhanced Excel processor with sheet and structure awareness."""

    async def process(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process Excel file with sheet-aware chunking."""
        chunks = []
        
        excel_file = pd.ExcelFile(file_path)
        
        for sheet_name in excel_file.sheet_names:
            df = pd.read_excel(excel_file, sheet_name=sheet_name)
            
            if df.empty:
                continue
            
            sheet_text = self._format_sheet(df, sheet_name)
            
            sheet_chunks = await chunker.chunk_text(
                sheet_text,
                metadata={
                    "sheet_name": sheet_name,
                    "rows": len(df),
                    "columns": len(df.columns),
                    "column_names": list(df.columns),
                }
            )
            chunks.extend(sheet_chunks)
        
        return chunks

    def _format_sheet(self, df: pd.DataFrame, sheet_name: str) -> str:
        """Format DataFrame as readable text."""
        lines = [f"Sheet: {sheet_name}", ""]
        
        lines.append("Columns: " + ", ".join(str(col) for col in df.columns))
        lines.append("")
        
        chunk_size = 100
        for start_idx in range(0, len(df), chunk_size):
            end_idx = min(start_idx + chunk_size, len(df))
            chunk_df = df.iloc[start_idx:end_idx]
            lines.append(f"Rows {start_idx+1} to {end_idx}:")
            lines.append(chunk_df.to_string(index=False))
            lines.append("")
        
        return "\n".join(lines)


excel_processor = AdvancedExcelProcessor()
