/**
 * Data presentation helpers used by the UI.
 */

/**
 * Humanize a tag / identifier for display.
 *
 * Examples:
 * - web_search_tavily -> "Tavily Web Search"
 * - gpt-4o-mini -> "GPT-4o Mini"
 */
export function humanizeTag(raw: string): string {
  const input = String(raw ?? "").trim();
  if (!input) return "";

  // snake_case or mixed -> tokens
  if (input.includes("_")) {
    const tokens = input
      .split(/[_\s]+/g)
      .map((t) => t.trim())
      .filter(Boolean);

    if (!tokens.length) return input;

    // Heuristic: web_search_tavily -> Tavily Web Search
    const shouldSwap = tokens.length === 3 && tokens[0] === "web" && tokens[1] === "search";
    const ordered = shouldSwap ? [tokens[2], tokens[0], tokens[1]] : tokens;

    return ordered
      .map((t) => titleToken(t))
      .join(" ");
  }

  // kebab-case (commonly model names)
  if (input.includes("-")) {
    const parts = input
      .split(/[-\s]+/g)
      .map((t) => t.trim())
      .filter(Boolean);

    if (!parts.length) return input;

    // GPT style: gpt-4o-mini -> GPT-4o Mini
    if (parts[0].toLowerCase() === "gpt" && parts.length >= 2) {
      const first = `GPT-${parts[1]}`;
      const rest = parts.slice(2).map((t) => titleToken(t));
      return [first, ...rest].join(" ").trim();
    }

    return parts.map((t) => titleToken(t)).join(" ");
  }

  return titleToken(input);
}

function titleToken(token: string): string {
  const t = String(token ?? "").trim();
  if (!t) return "";

  const lower = t.toLowerCase();

  // Common acronyms
  if (lower === "api") return "API";
  if (lower === "pdf") return "PDF";
  if (lower === "url") return "URL";
  if (lower === "ui") return "UI";

  // Preserve tokens like 4o, 3.5, etc.
  if (/^\d/.test(t)) return t;

  return lower.charAt(0).toUpperCase() + lower.slice(1);
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
