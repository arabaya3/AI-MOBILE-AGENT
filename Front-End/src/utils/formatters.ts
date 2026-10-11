/**
 * UI formatters.
 */

/**
 * Convert snake_case or kebab-case tool identifiers into a human-friendly title.
 *
 * Examples:
 * - web_search_tavily -> Tavily Web Search
 * - file-search      -> File Search
 */
export function formatToolName(raw: string): string {
  const input = String(raw ?? "").trim();
  if (!input) return "";

  const tokens = input
    .replaceAll("-", "_")
    .split(/[_\s]+/g)
    .map((t) => t.trim())
    .filter(Boolean);

  if (!tokens.length) return input;

  // A small heuristic: if the string looks like <category>_<provider>, prefer Provider Category.
  // e.g. web_search_tavily -> Tavily Web Search
  const shouldSwap = tokens.length === 3 && tokens[0] === "web" && tokens[1] === "search";

  const words = (shouldSwap ? [tokens[2], tokens[0], tokens[1]] : tokens).map((w) => {
    const lower = w.toLowerCase();
    // Keep common acronyms uppercased.
    if (lower === "api") return "API";
    if (lower === "pdf") return "PDF";
    if (lower === "url") return "URL";
    return lower.charAt(0).toUpperCase() + lower.slice(1);
  });

  return words.join(" ");
}

/**
 * USD cost formatting for UI.
 * - If < $0.01 => "< $0.01"
 * - Else => "$X.YY" (2 decimals)
 */
export function formatUsdCost(costUsd: number | null | undefined): string {
  if (costUsd == null || Number.isNaN(Number(costUsd))) return "—";

  const value = Number(costUsd);
  if (value > 0 && value < 0.01) return "< $0.01";

  return `$${value.toFixed(2)}`;
}
