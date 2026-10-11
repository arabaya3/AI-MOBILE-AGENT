import { CssBaseline, ThemeProvider, createTheme, useMediaQuery, alpha } from "@mui/material";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { useState, useMemo, useEffect, useCallback } from "react";

import "./i18n";
import { useAuth } from "./context/AuthContext";
import AuthPage from "./pages/AuthPage";
import ChatPage from "./pages/ChatPage";
import { buildThemeConfig } from "./styles/ThemeConfig";
import {
  getIndustryPalette,
  PALETTE_STORAGE_KEY,
  INDUSTRY_PALETTES,
  type IndustryPalette,
} from "./styles/theme";

function App() {
  const prefersDarkMode = useMediaQuery('(prefers-color-scheme: dark)');
  const [mode, setMode] = useState<'light' | 'dark'>(() => {
    const saved = localStorage.getItem('theme-mode');
    return (saved as 'light' | 'dark') || (prefersDarkMode ? 'dark' : 'light');
  });

  const [paletteKey, setPaletteKey] = useState<IndustryPalette>(() => {
    const saved = localStorage.getItem(PALETTE_STORAGE_KEY);
    return (saved && saved in INDUSTRY_PALETTES ? saved : "healthcare") as IndustryPalette;
  });

  useEffect(() => {
    localStorage.setItem('theme-mode', mode);
  }, [mode]);

  useEffect(() => {
    localStorage.setItem(PALETTE_STORAGE_KEY, paletteKey);
  }, [paletteKey]);

  const handleChangePalette = useCallback((key: IndustryPalette) => {
    setPaletteKey(key);
  }, []);

  const ThemeConfig = useMemo(() => buildThemeConfig(getIndustryPalette(paletteKey)), [paletteKey]);

  const theme = useMemo(
    () =>
      createTheme({
        spacing: 8, // Strict 8pt grid
        palette: {
          mode,
          primary: {
            main: ThemeConfig.colors.brand,
            dark: ThemeConfig.colors.brandDark,
            light: ThemeConfig.colors.brandLight,
          },
          secondary: {
            main: ThemeConfig.colors.secondary || ThemeConfig.colors.neutral,
            dark: ThemeConfig.colors.secondaryDark || ThemeConfig.colors.neutral,
            light: ThemeConfig.colors.secondaryLight || ThemeConfig.colors.neutralMid,
          },
          error: {
            main: ThemeConfig.colors.error,
          },
          background: {
            default: mode === "dark" ? ThemeConfig.dark.bg : ThemeConfig.colors.appBg,
            paper: mode === "dark" ? ThemeConfig.dark.paper : ThemeConfig.colors.surface,
          },
          text: {
            primary: mode === "dark" ? ThemeConfig.dark.text : ThemeConfig.colors.text,
            secondary: mode === "dark" ? ThemeConfig.dark.textMuted : ThemeConfig.colors.textMuted,
          },
          divider: mode === "dark" ? ThemeConfig.dark.border : ThemeConfig.colors.border,
        },
        typography: {
          fontFamily: ThemeConfig.fontFamily,
          h1: ThemeConfig.typographyScale.h1,
          h2: ThemeConfig.typographyScale.h2,
          h3: ThemeConfig.typographyScale.h3,
          h4: { fontSize: "1.5rem", fontWeight: 700, lineHeight: 1.334, letterSpacing: "-0.01em" },
          h5: { fontSize: "1.25rem", fontWeight: 700, lineHeight: 1.4 },
          h6: { fontSize: "1.125rem", fontWeight: 700, lineHeight: 1.4 },
          subtitle1: { fontWeight: 600, fontSize: "1rem", lineHeight: 1.5 },
          subtitle2: { fontWeight: 600, fontSize: "0.875rem", lineHeight: 1.57 },
          body1: ThemeConfig.typographyScale.body1,
          body2: ThemeConfig.typographyScale.body2,
          caption: ThemeConfig.typographyScale.caption,
          button: ThemeConfig.typographyScale.button,
        },
        shape: {
          borderRadius: ThemeConfig.borderRadius,
        },
        components: {
          MuiCssBaseline: {
            styleOverrides: (theme) => ({
              "*": {
                scrollbarWidth: "thin",
                scrollbarColor: `${theme.palette.text.secondary} transparent`,
              },
              "*::-webkit-scrollbar": {
                width: 10,
                height: 10,
              },
              "*::-webkit-scrollbar-track": {
                background: "transparent",
              },
              "*::-webkit-scrollbar-thumb": {
                backgroundColor: theme.palette.action.hover,
                borderRadius: 999,
                border: "2px solid transparent",
                backgroundClip: "content-box",
              },
              "*::-webkit-scrollbar-thumb:hover": {
                backgroundColor: theme.palette.action.selected,
              },
            }),
          },
          MuiAppBar: {
            defaultProps: {
              elevation: 0,
            },
            styleOverrides: {
              root: ({ theme }) => ({
                backgroundColor: theme.palette.background.paper,
                color: theme.palette.text.primary,
                backdropFilter: "blur(10px)",
                borderBottom: `1px solid ${theme.palette.divider}`,
              }),
            },
          },
          MuiButton: {
            defaultProps: {
              disableElevation: true,
            },
            styleOverrides: {
              root: {
                borderRadius: 8,
                textTransform: "none" as const,
                fontWeight: 600,
                paddingInline: 16,
                paddingBlock: 8,
                letterSpacing: "0.01em",
                transition: `all ${ThemeConfig.transition.fast}`,
              },
              sizeLarge: {
                paddingInline: 24,
                paddingBlock: 12,
                fontSize: "1rem",
              },
              contained: {
                boxShadow: "none",
                "&:hover": {
                  boxShadow: ThemeConfig.shadow.sm,
                },
              },
            },
          },
          MuiCard: {
            defaultProps: {
              elevation: 0,
            },
            styleOverrides: {
              root: ({ theme }) => ({
                borderRadius: ThemeConfig.radius.md,
                border: "1px solid",
                borderColor: theme.palette.divider,
                boxShadow: ThemeConfig.shadow.lg,
              }),
            },
          },
          MuiPaper: {
            defaultProps: {
              elevation: 0,
            },
            styleOverrides: {
              root: ({ theme }) => ({
                backgroundImage: "none",
                borderColor: theme.palette.divider,
                borderRadius: ThemeConfig.radius.md,
                boxShadow: ThemeConfig.shadow.lg,
              }),
              elevation1: ({ theme }) => ({
                boxShadow: theme.palette.mode === "dark"
                  ? ThemeConfig.shadow.smDark
                  : ThemeConfig.shadow.sm,
                border: `1px solid ${theme.palette.divider}`,
              }),
            },
          },
          MuiDialog: {
            styleOverrides: {
              paper: ({ theme }) => ({
                borderRadius: ThemeConfig.radius.md,
                boxShadow:
                  theme.palette.mode === "dark"
                    ? ThemeConfig.shadow.lgDark
                    : ThemeConfig.shadow.xl,
              }),
            },
          },
          MuiDialogTitle: {
            styleOverrides: {
              root: {
                borderTopLeftRadius: ThemeConfig.radius.md,
                borderTopRightRadius: ThemeConfig.radius.md,
                fontSize: "1.05rem",
                fontWeight: 700,
                letterSpacing: "-0.01em",
              },
            },
          },
          MuiOutlinedInput: {
            styleOverrides: {
              root: ({ theme }) => ({
                borderRadius: ThemeConfig.radius.sm,
                backgroundColor:
                  theme.palette.mode === "dark"
                    ? alpha(theme.palette.background.paper, 0.4)
                    : alpha(theme.palette.background.paper, 0.8),
                transition: `all ${ThemeConfig.transition.fast}`,
                "& .MuiOutlinedInput-notchedOutline": {
                  borderColor: theme.palette.divider,
                },
                "&:hover .MuiOutlinedInput-notchedOutline": {
                  borderColor: theme.palette.primary.main,
                },
                "&.Mui-focused": {
                  boxShadow: `0 0 0 4px ${alpha(theme.palette.primary.main, 0.1)}`,
                  backgroundColor: theme.palette.background.paper,
                },
                "&.Mui-focused .MuiOutlinedInput-notchedOutline": {
                  borderWidth: 1,
                  borderColor: theme.palette.primary.main,
                },
              }),
            },
          },
          MuiInputLabel: {
            styleOverrides: {
              root: ({ theme }) => ({
                fontSize: "0.875rem",
                fontWeight: 500,
                color: theme.palette.text.secondary,
                "&.Mui-focused": {
                  color: theme.palette.primary.main,
                  fontWeight: 600,
                },
              }),
            },
          },
          MuiInputBase: {
            styleOverrides: {
              root: {
                borderRadius: ThemeConfig.radius.sm,
              },
            },
          },
          MuiFilledInput: {
            styleOverrides: {
              root: {
                borderRadius: ThemeConfig.radius.sm,
              },
            },
          },
          MuiListItemButton: {
            styleOverrides: {
              root: ({ theme }) => ({
                borderRadius: ThemeConfig.radius.sm,
                marginInline: 6,
                marginBlock: 2,
                transition: `background-color ${ThemeConfig.transition.fast}`,
                "&.Mui-selected": {
                  backgroundColor:
                    theme.palette.mode === "dark"
                      ? "rgba(79,70,229,0.15)"
                      : "rgba(79,70,229,0.08)",
                },
                "&.Mui-selected:hover": {
                  backgroundColor:
                    theme.palette.mode === "dark"
                      ? "rgba(79,70,229,0.22)"
                      : "rgba(79,70,229,0.12)",
                },
              }),
            },
          },
          MuiIconButton: {
            styleOverrides: {
              root: {
                transition: `all ${ThemeConfig.transition.fast}`,
                "&:focus-visible": {
                  outline: "2px solid",
                  outlineOffset: 2,
                },
              },
            },
          },
          MuiChip: {
            styleOverrides: {
              root: {
                borderRadius: ThemeConfig.radius.xs,
                fontWeight: 600,
                fontSize: "0.75rem",
                letterSpacing: "0.02em",
              },
            },
          },
          MuiTooltip: {
            styleOverrides: {
              tooltip: ({ theme }) => ({
                borderRadius: ThemeConfig.radius.xs,
                fontSize: "0.75rem",
                fontWeight: 500,
                backgroundColor:
                  theme.palette.mode === "dark"
                    ? "rgba(30,41,59,0.95)"
                    : "rgba(15,23,42,0.92)",
                backdropFilter: "blur(4px)",
                padding: "6px 10px",
              }),
            },
          },
          MuiTab: {
            styleOverrides: {
              root: {
                fontWeight: 600,
                fontSize: "0.875rem",
                letterSpacing: "0.01em",
                minHeight: 44,
                textTransform: "none",
              },
            },
          },
          MuiDivider: {
            styleOverrides: {
              root: ({ theme }) => ({
                borderColor: theme.palette.divider,
              }),
            },
          },
        },
      }),
    [mode, ThemeConfig]
  );

  const { isAuthenticated } = useAuth();

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline enableColorScheme />
      <BrowserRouter>
        <Routes>
          <Route
            path="/"
            element={
              isAuthenticated ? (
                <ChatPage
                  toggleTheme={() => setMode(m => m === 'light' ? 'dark' : 'light')}
                  currentPalette={paletteKey}
                  onChangePalette={handleChangePalette}
                />
              ) : (
                <Navigate to="/auth" replace />
              )
            }
          />
          <Route path="/auth" element={isAuthenticated ? <Navigate to="/" replace /> : <AuthPage />} />
          <Route path="*" element={<Navigate to={isAuthenticated ? "/" : "/auth"} replace />} />
        </Routes>
      </BrowserRouter>
    </ThemeProvider>
  );
}

export default App;
