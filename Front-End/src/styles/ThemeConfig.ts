/**
 * TEIA Design System — single source of truth for all visual tokens.
 *
 * ─ Radius scale  (px)   : xs=4  sm=8  md=12  lg=16  pill=999
 * ─ Spacing scale (px/8) : Base MUI unit (1 = 8px)
 * ─ Font stack           : Inter → system fallbacks
 * ─ Color roles          : brand / neutral / danger / success / warning / info
 * ─ Typography scale     : h1=32  h2=24  body=16  small=14  caption=12
 *
 * Only raw values live here (no Tailwind classes, no MUI props).
 * The MUI theme in App.tsx consumes these tokens exclusively.
 *
 * Industry-specific palettes are defined in ./theme.ts and can
 * override the default color tokens at runtime.
 */
import {
  getIndustryPalette,
  PALETTE_STORAGE_KEY,
  type IndustryThemeConfig,
} from "./theme";

/**
 * Build a ThemeConfig using the given industry palette (or the persisted one).
 */
export const buildThemeConfig = (palette?: IndustryThemeConfig) => {
  const p =
    palette ??
    getIndustryPalette(
      typeof localStorage !== "undefined"
        ? localStorage.getItem(PALETTE_STORAGE_KEY)
        : null,
    );

  return {
    // ── Radius ──────────────────────────────────────────────────────────────
    borderRadius: 8,
    radius: {
      xs: 4,
      sm: 8,
      md: 12,
      lg: 16,
      xl: 20,
      pill: 999,
    },

    // ── Spacing tokens (multiples of 8) ─────────────────────────────────────
    spacing: [0, 4, 8, 16, 24, 32, 48, 64] as const,

    // ── Typography ──────────────────────────────────────────────────────────
    fontFamily: "'Inter', 'Segoe UI', system-ui, -apple-system, sans-serif",

    typographyScale: {
      h1:      { fontSize: "2rem",    fontWeight: 700, lineHeight: 1.25,  letterSpacing: "-0.02em" },
      h2:      { fontSize: "1.5rem",  fontWeight: 700, lineHeight: 1.333, letterSpacing: "-0.01em" },
      h3:      { fontSize: "1.25rem", fontWeight: 600, lineHeight: 1.4 },
      body1:   { fontSize: "1rem",    fontWeight: 400, lineHeight: 1.5 },
      body2:   { fontSize: "0.875rem",fontWeight: 400, lineHeight: 1.57 },
      caption: { fontSize: "0.75rem", fontWeight: 400, lineHeight: 1.66 },
      button:  { fontSize: "0.875rem",fontWeight: 600, lineHeight: 1.75, textTransform: "none" as const },
    },

    // ── Colors — injected from the active industry palette ──────────────────
    colors: p.colors,

    // ── Dark mode overrides ─────────────────────────────────────────────────
    dark: p.dark,

    // ── Shadow scale — soft, enterprise-grade ───────────────────────────────
    shadow: {
      sm:    "0 1px 2px rgba(0,0,0,0.04), 0 1px 3px rgba(0,0,0,0.06)",
      md:    "0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -2px rgba(0,0,0,0.05)",
      lg:    "0 4px 6px -1px rgb(0 0 0 / 0.05)",
      xl:    "0 20px 48px rgba(15,23,42,0.12), 0 8px 16px rgba(15,23,42,0.06)",
      smDark: "0 1px 3px rgba(0,0,0,0.25)",
      mdDark: "0 4px 12px rgba(0,0,0,0.35)",
      lgDark: "0 10px 32px rgba(0,0,0,0.50)",
    },

    // ── Animation ───────────────────────────────────────────────────────────
    transition: {
      fast:   "150ms cubic-bezier(0.4,0,0.2,1)",
      normal: "250ms cubic-bezier(0.4,0,0.2,1)",
      slow:   "400ms cubic-bezier(0.4,0,0.2,1)",
    },
  } as const;
};

/** Default instance — used for backward-compat imports. */
export const ThemeConfig = buildThemeConfig();

export default ThemeConfig;

