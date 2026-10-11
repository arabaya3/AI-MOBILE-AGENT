/**
 * TEIA Professional Industry-Specific Theme System
 *
 * Three high-end, trust-inspiring palettes for enterprise verticals:
 *   1. Healthcare — Deep Teal + Soft Blue  (Trust & Cleanliness)
 *   2. Corporate  — Deep Navy + Slate      (Authority & Focus)
 *   3. Legal      — Charcoal + Burgundy    (Tradition & Prestige)
 *
 * Each palette ships light + dark surface tokens and is consumed by
 * the dynamic MUI `createTheme()` call in App.tsx.
 */

export type IndustryPalette = "healthcare" | "corporate" | "legal";

export interface PaletteTokens {
  brand: string;
  brandDark: string;
  brandLight: string;
  brandSoft: string;
  brandMuted: string;
  secondary: string;
  secondaryDark: string;
  secondaryLight: string;
  accent?: string;

  error: string;
  errorDark: string;
  errorSoft: string;
  errorMuted: string;
  success: string;
  successSoft: string;
  warning: string;
  warningSoft: string;
  info: string;
  infoSoft: string;

  neutral: string;
  neutralMid: string;
  neutralSoft: string;
  neutralMuted: string;

  surface: string;
  surfaceAlt: string;
  appBg: string;
  border: string;
  borderStrong: string;
  progressTrack: string;

  text: string;
  textMuted: string;
  textSubtle: string;
}

export interface DarkTokens {
  bg: string;
  paper: string;
  paperAlt: string;
  border: string;
  borderStrong: string;
  text: string;
  textMuted: string;
  textSubtle: string;
}

export interface IndustryThemeConfig {
  label: string;
  colors: PaletteTokens;
  dark: DarkTokens;
}

// ─────────────────────────────────────────────────────────────────
// 1. Healthcare — Trust & Cleanliness
// ─────────────────────────────────────────────────────────────────
const healthcarePalette: IndustryThemeConfig = {
  label: "Healthcare",
  colors: {
    brand: "#006B5F",
    brandDark: "#004D44",
    brandLight: "#00897B",
    brandSoft: "#B2DFDB",
    brandMuted: "#E0F2F1",
    secondary: "#4A90E2",
    secondaryDark: "#357ABD",
    secondaryLight: "#6FB3F2",

    error: "#D32F2F",
    errorDark: "#B71C1C",
    errorSoft: "#FFEBEE",
    errorMuted: "#FEF2F2",
    success: "#2E7D32",
    successSoft: "#E8F5E9",
    warning: "#ED6C02",
    warningSoft: "#FFF3E0",
    info: "#0288D1",
    infoSoft: "#E1F5FE",

    neutral: "#1E293B",
    neutralMid: "#475569",
    neutralSoft: "#E2E8F0",
    neutralMuted: "#F1F5F9",

    surface: "#FFFFFF",
    surfaceAlt: "#F8FAFC",
    appBg: "#F8FAFC",
    border: "#E2E8F0",
    borderStrong: "#CBD5E1",
    progressTrack: "#E2E8F0",

    text: "#0F172A",
    textMuted: "#475569",
    textSubtle: "#64748B",
  },
  dark: {
    bg: "#0C1F1C",
    paper: "#142926",
    paperAlt: "#1E3A35",
    border: "#1E3A35",
    borderStrong: "#2D524B",
    text: "#E0F2F1",
    textMuted: "#80CBC4",
    textSubtle: "#4DB6AC",
  },
};

// ─────────────────────────────────────────────────────────────────
// 2. Corporate / Enterprise — Authority & Focus
// ─────────────────────────────────────────────────────────────────
const corporatePalette: IndustryThemeConfig = {
  label: "Corporate",
  colors: {
    brand: "#0F172A",
    brandDark: "#020617",
    brandLight: "#1E293B",
    brandSoft: "#CBD5E1",
    brandMuted: "#E2E8F0",
    secondary: "#475569",
    secondaryDark: "#334155",
    secondaryLight: "#64748B",
    accent: "#2563EB",

    error: "#DC2626",
    errorDark: "#B91C1C",
    errorSoft: "#FEE2E2",
    errorMuted: "#FEF2F2",
    success: "#16A34A",
    successSoft: "#DCFCE7",
    warning: "#D97706",
    warningSoft: "#FEF3C7",
    info: "#2563EB",
    infoSoft: "#DBEAFE",

    neutral: "#0F172A",
    neutralMid: "#475569",
    neutralSoft: "#E2E8F0",
    neutralMuted: "#F1F5F9",

    surface: "#FFFFFF",
    surfaceAlt: "#F8FAFC",
    appBg: "#F1F5F9",
    border: "#E2E8F0",
    borderStrong: "#CBD5E1",
    progressTrack: "#E2E8F0",

    text: "#0F172A",
    textMuted: "#475569",
    textSubtle: "#64748B",
  },
  dark: {
    bg: "#020617",
    paper: "#0F172A",
    paperAlt: "#1E293B",
    border: "#1E293B",
    borderStrong: "#334155",
    text: "#F1F5F9",
    textMuted: "#94A3B8",
    textSubtle: "#64748B",
  },
};

// ─────────────────────────────────────────────────────────────────
// 3. Law / Legal — Tradition & Prestige
// ─────────────────────────────────────────────────────────────────
const legalPalette: IndustryThemeConfig = {
  label: "Legal",
  colors: {
    brand: "#2C3E50",
    brandDark: "#1A252F",
    brandLight: "#34495E",
    brandSoft: "#D5DBDF",
    brandMuted: "#ECF0F1",
    secondary: "#800020",
    secondaryDark: "#5C0017",
    secondaryLight: "#A3193B",
    accent: "#D4AF37",

    error: "#C62828",
    errorDark: "#B71C1C",
    errorSoft: "#FFEBEE",
    errorMuted: "#FEF2F2",
    success: "#2E7D32",
    successSoft: "#E8F5E9",
    warning: "#E65100",
    warningSoft: "#FFF3E0",
    info: "#1565C0",
    infoSoft: "#E3F2FD",

    neutral: "#1C2833",
    neutralMid: "#566573",
    neutralSoft: "#D5DBDB",
    neutralMuted: "#F2F3F4",

    surface: "#FFFFFF",
    surfaceAlt: "#FAFAFA",
    appBg: "#F5F5F5",
    border: "#D5D8DC",
    borderStrong: "#ABB2B9",
    progressTrack: "#D5D8DC",

    text: "#1C2833",
    textMuted: "#566573",
    textSubtle: "#7F8C8D",
  },
  dark: {
    bg: "#0D1117",
    paper: "#1C2833",
    paperAlt: "#2C3E50",
    border: "#2C3E50",
    borderStrong: "#34495E",
    text: "#ECF0F1",
    textMuted: "#95A5A6",
    textSubtle: "#7F8C8D",
  },
};

// ─────────────────────────────────────────────────────────────────
// Palette registry
// ─────────────────────────────────────────────────────────────────
export const INDUSTRY_PALETTES: Record<IndustryPalette, IndustryThemeConfig> = {
  healthcare: healthcarePalette,
  corporate: corporatePalette,
  legal: legalPalette,
};

/**
 * Retrieve a palette by key, falling back to "healthcare" (default).
 */
export const getIndustryPalette = (key?: string | null): IndustryThemeConfig => {
  if (key && key in INDUSTRY_PALETTES) {
    return INDUSTRY_PALETTES[key as IndustryPalette];
  }
  return INDUSTRY_PALETTES.healthcare;
};

/**
 * Persistence key used in localStorage to remember the user's palette preference.
 */
export const PALETTE_STORAGE_KEY = "teia_industry_palette";
