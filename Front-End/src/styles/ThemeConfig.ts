/**
 * Centralized UI tokens.
 *
 * Note: This frontend primarily uses MUI. We keep these as raw values
 * (colors, radii, etc.) rather than Tailwind class strings.
 */
export const ThemeConfig = {
  borderRadius: 12,
  colors: {
    brand: "#1a472a",
    brandLight: "#2e7d46",
    brandSoft: "#c8e6c9",
    error: "#dc2626",
    errorSoft: "#fee2e2",
    neutral: "#334155",
    neutralSoft: "#e2e8f0",
    surface: "#ffffff",
    appBg: "#f5f7f5",
    border: "#c8d5c9",
    text: "#0f1f0f",
    textMuted: "#4a6750",
    progressTrack: "#d0e8d2",
  },
  radius: {
    sm: 6,
    md: 12,
    pill: 999,
  },
} as const;

export default ThemeConfig;
