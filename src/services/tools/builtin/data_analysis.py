"""Data analysis tool for CSV/Excel files."""

import base64
import io
from typing import Any, Dict, List, Optional

import matplotlib
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter

# Use non-interactive backend
matplotlib.use("Agg")


class DataAnalysisTool(BaseTool):
    """Analyze data files and generate visualizations."""

    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="analyze_data",
            description="Analyze CSV/Excel data and generate statistical summaries or visualizations",
            parameters=[
                ToolParameter(
                    name="file_path",
                    type="string",
                    description="Path to the data file (CSV or Excel)",
                    required=True,
                ),
                ToolParameter(
                    name="analysis_type",
                    type="string",
                    description="Type of analysis to perform",
                    required=True,
                    enum=["summary", "correlation", "distribution"],
                ),
                ToolParameter(
                    name="columns",
                    type="array",
                    description="Specific columns to analyze (optional)",
                    required=False,
                    items_type="string",
                ),
            ],
        )

    async def execute(
        self, file_path: str, analysis_type: str, columns: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """Perform data analysis."""
        try:
            # Load data
            if file_path.endswith(".csv"):
                df = pd.read_csv(file_path)
            elif file_path.endswith((".xlsx", ".xls")):
                df = pd.read_excel(file_path)
            else:
                return {"success": False, "error": "Unsupported file format"}

            # Filter columns if specified
            if columns:
                df = df[columns]

            if analysis_type == "summary":
                summary = df.describe().to_dict()
                return {"success": True, "summary": summary, "shape": df.shape}

            elif analysis_type == "correlation":
                # Select only numeric columns
                numeric_df = df.select_dtypes(include=["number"])
                if numeric_df.empty:
                    return {"success": False, "error": "No numeric columns found"}

                corr = numeric_df.corr().to_dict()

                # Generate heatmap
                plt.figure(figsize=(10, 8))
                sns.heatmap(numeric_df.corr(), annot=True, cmap="coolwarm", center=0)
                plt.title("Correlation Heatmap")

                buffer = io.BytesIO()
                plt.savefig(buffer, format="png", bbox_inches="tight")
                plt.close()
                img_base64 = base64.b64encode(buffer.getvalue()).decode()

                return {
                    "success": True,
                    "correlation": corr,
                    "chart": f"data:image/png;base64,{img_base64}",
                }

            elif analysis_type == "distribution":
                # Create distribution plots for numeric columns
                numeric_df = df.select_dtypes(include=["number"])
                if numeric_df.empty:
                    return {"success": False, "error": "No numeric columns found"}

                n_cols = min(3, len(numeric_df.columns))
                fig, axes = plt.subplots(1, n_cols, figsize=(5 * n_cols, 4))
                if n_cols == 1:
                    axes = [axes]

                for i, col in enumerate(numeric_df.columns[:n_cols]):
                    numeric_df[col].hist(ax=axes[i], bins=30)
                    axes[i].set_title(f"{col} Distribution")

                buffer = io.BytesIO()
                plt.savefig(buffer, format="png", bbox_inches="tight")
                plt.close()
                img_base64 = base64.b64encode(buffer.getvalue()).decode()

                return {"success": True, "chart": f"data:image/png;base64,{img_base64}"}

            return {"success": False, "error": "Invalid analysis type"}

        except Exception as e:
            return {"success": False, "error": str(e)}
