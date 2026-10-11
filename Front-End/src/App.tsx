import { CssBaseline, ThemeProvider, createTheme, useMediaQuery } from "@mui/material";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { useState, useMemo, useEffect } from "react";
import createCache from "@emotion/cache";
import { CacheProvider } from "@emotion/react";
import { prefixer } from "stylis";
import rtlPlugin from "stylis-plugin-rtl";

import "./i18n";
import { useAuth } from "./context/AuthContext";
import AuthPage from "./pages/AuthPage";
import ChatPage from "./pages/ChatPage";
import PalestinianLawsPage from "./pages/PalestinianLawsPage";
import { ThemeConfig } from "./styles/ThemeConfig";

function App() {
  const prefersDarkMode = useMediaQuery('(prefers-color-scheme: dark)');
  const [mode, setMode] = useState<'light' | 'dark'>(() => {
    const saved = localStorage.getItem('theme-mode');
    return (saved as 'light' | 'dark') || (prefersDarkMode ? 'dark' : 'light');
  });

  useEffect(() => {
    localStorage.setItem('theme-mode', mode);
  }, [mode]);

  const theme = useMemo(
    () =>
      createTheme({
        direction: "rtl",
        palette: {
          mode,
          primary: {
            main: ThemeConfig.colors.brand,
            dark: "#12311d",
            light: ThemeConfig.colors.brandLight,
          },
          secondary: {
            main: ThemeConfig.colors.neutral,
          },
          error: {
            main: ThemeConfig.colors.error,
          },
          background: {
            default: mode === "dark" ? "#0a1a0c" : ThemeConfig.colors.appBg,
            paper: mode === "dark" ? "#0f1f12" : ThemeConfig.colors.surface,
          },
          text: {
            primary: mode === "dark" ? "#e2e8f0" : ThemeConfig.colors.text,
            secondary: mode === "dark" ? "#94a3b8" : "#475569",
          },
          divider: mode === "dark" ? "#1e293b" : ThemeConfig.colors.border,
        },
        typography: {
          fontFamily:
            "'Cairo', 'Noto Sans Arabic', 'Inter', 'Roboto', 'Helvetica', 'Arial', sans-serif",
          h4: { fontWeight: 700 },
          h5: { fontWeight: 700 },
          h6: { fontWeight: 700 },
          subtitle1: { fontWeight: 600 },
          subtitle2: { fontWeight: 600 },
          button: { textTransform: "none", fontWeight: 600 },
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
            styleOverrides: {
              root: ({ theme }) => ({
                background: theme.palette.mode === "dark"
                  ? "linear-gradient(90deg, rgba(10,26,12,0.95) 0%, rgba(15,31,18,0.8) 100%)"
                  : "linear-gradient(90deg, rgba(245,247,245,0.97) 0%, rgba(200,230,201,0.5) 100%)",
                backdropFilter: "blur(10px)",
                borderBottom: `1px solid ${theme.palette.divider}`,
              }),
            },
          },
          MuiButton: {
            styleOverrides: {
              root: {
                borderRadius: ThemeConfig.borderRadius,
                paddingInline: 16,
                paddingBlock: 8,
              },
            },
          },
          MuiCard: {
            styleOverrides: {
              root: ({ theme }) => ({
                borderRadius: ThemeConfig.borderRadius,
                border: "1px solid",
                borderColor: theme.palette.divider,
                boxShadow:
                  theme.palette.mode === "dark"
                    ? "0 18px 45px rgba(15,23,42,0.55)"
                    : "0 10px 24px rgba(15,23,42,0.08)",
              }),
            },
          },
          MuiPaper: {
            styleOverrides: {
              root: ({ theme }) => ({
                backgroundImage: "none",
                borderColor: theme.palette.divider,
                borderRadius: ThemeConfig.borderRadius,
              }),
              elevation1: {
                boxShadow: "none",
                border: "1px solid #cbd5e1",
              },
            },
          },
          MuiDialog: {
            styleOverrides: {
              paper: {
                borderRadius: ThemeConfig.borderRadius,
              },
            },
          },
          MuiDialogTitle: {
            styleOverrides: {
              root: {
                borderTopLeftRadius: ThemeConfig.borderRadius,
                borderTopRightRadius: ThemeConfig.borderRadius,
              },
            },
          },
          MuiOutlinedInput: {
            styleOverrides: {
              root: ({ theme }) => ({
                borderRadius: ThemeConfig.borderRadius,
                backgroundColor: theme.palette.mode === "dark" ? "rgba(148,163,184,0.08)" : "rgba(15,23,42,0.04)",
                "&:hover .MuiOutlinedInput-notchedOutline": {
                  borderColor: theme.palette.text.secondary,
                },
              }),
            },
          },
          MuiInputBase: {
            styleOverrides: {
              root: {
                borderRadius: ThemeConfig.borderRadius,
              },
            },
          },
          MuiFilledInput: {
            styleOverrides: {
              root: {
                borderRadius: ThemeConfig.borderRadius,
              },
            },
          },
          MuiListItemButton: {
            styleOverrides: {
              root: ({ theme }) => ({
                borderRadius: ThemeConfig.borderRadius,
                marginInline: 6,
                marginBlock: 4,
                "&.Mui-selected": {
                  backgroundColor: theme.palette.action.selected,
                },
                "&.Mui-selected:hover": {
                  backgroundColor: theme.palette.action.selected,
                },
              }),
            },
          },
          MuiChip: {
            styleOverrides: {
              root: {
                borderRadius: ThemeConfig.borderRadius,
                fontWeight: 600,
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
    [mode]
  );

  const { isAuthenticated } = useAuth();

  const rtlCache = useMemo(() =>
    createCache({ key: "muirtl", stylisPlugins: [prefixer, rtlPlugin] }),
    []
  );

  return (
    <CacheProvider value={rtlCache}>
    <ThemeProvider theme={theme}>
      <CssBaseline enableColorScheme />
      <BrowserRouter>
        <Routes>
          <Route
            path="/"
            element={
              isAuthenticated ? (
                <ChatPage toggleTheme={() => setMode(m => m === 'light' ? 'dark' : 'light')} />
              ) : (
                <Navigate to="/auth" replace />
              )
            }
          />
          <Route path="/auth" element={isAuthenticated ? <Navigate to="/" replace /> : <AuthPage />} />
          <Route
            path="/laws"
            element={isAuthenticated ? <PalestinianLawsPage /> : <Navigate to="/auth" replace />}
          />
          <Route path="*" element={<Navigate to={isAuthenticated ? "/" : "/auth"} replace />} />
        </Routes>
      </BrowserRouter>
    </ThemeProvider>
    </CacheProvider>
  );
}

export default App;
