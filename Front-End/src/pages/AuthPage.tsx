import LockOpenRoundedIcon from "@mui/icons-material/LockOpenRounded";
import PersonAddAltRoundedIcon from "@mui/icons-material/PersonAddAltRounded";
import VisibilityOffRoundedIcon from "@mui/icons-material/VisibilityOffRounded";
import VisibilityRoundedIcon from "@mui/icons-material/VisibilityRounded";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  IconButton,
  InputAdornment,
  Link,
  Stack,
  Tab,
  Tabs,
  TextField,
  Typography,
  useTheme,
} from "@mui/material";
import type { FormEvent } from "react";
import type { ReactElement } from "react";
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useSearchParams } from "react-router-dom";

import { useAuth } from "../context/AuthContext";

type AuthMode = "login" | "signup" | "reset-request" | "reset-final";

const tabConfig: Array<{ label: string; value: AuthMode; icon: ReactElement }> = [
  { label: "Sign in", value: "login", icon: <LockOpenRoundedIcon /> },
  { label: "Create account", value: "signup", icon: <PersonAddAltRoundedIcon /> },
];

export const AuthPage = () => {
  const { login, signup, requestPasswordReset, validatePasswordResetToken, completePasswordReset, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const theme = useTheme();
  const [activeTab, setActiveTab] = useState<AuthMode>("login");
  const [loginForm, setLoginForm] = useState({ email: "", password: "" });
  const [signupForm, setSignupForm] = useState({ email: "", password: "" });
  const [resetForm, setResetForm] = useState({ email: "", token: "", newPassword: "" });
  const [feedback, setFeedback] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [tokenValid, setTokenValid] = useState<boolean | null>(null);
  const [tokenChecking, setTokenChecking] = useState(false);

  useEffect(() => {
    if (isAuthenticated) {
      navigate("/", { replace: true });
    }
  }, [isAuthenticated, navigate]);

  useEffect(() => {
    const token = searchParams.get("token");
    if (token) {
      setResetForm((prev) => ({ ...prev, token }));
      setActiveTab("reset-final");
    }
  }, [searchParams]);

  useEffect(() => {
    const trimmed = resetForm.token.trim();
    if (activeTab !== "reset-final") return;
    if (!trimmed) {
      setTokenValid(null);
      return;
    }

    let cancelled = false;
    setTokenChecking(true);
    const t = window.setTimeout(async () => {
      try {
        const ok = await validatePasswordResetToken(trimmed);
        if (!cancelled) setTokenValid(ok);
      } catch {
        if (!cancelled) setTokenValid(false);
      } finally {
        if (!cancelled) setTokenChecking(false);
      }
    }, 250);

    return () => {
      cancelled = true;
      window.clearTimeout(t);
    };
  }, [activeTab, resetForm.token, validatePasswordResetToken]);


  const handleLogin = async (event: FormEvent) => {
    event.preventDefault();
    try {
      setSubmitting(true);
      await login(loginForm);
      setFeedback({ type: "success", message: "Authenticated. Redirecting to workspace..." });
      navigate("/", { replace: true });
    } catch (error) {
      setFeedback({ type: "error", message: "Unable to login. Check your credentials." });
    } finally {
      setSubmitting(false);
    }
  };

  const handleSignup = async (event: FormEvent) => {
    event.preventDefault();
    try {
      setSubmitting(true);
      await signup({ ...signupForm, role: "viewer" });
      setFeedback({ type: "success", message: "Account created. Redirecting..." });
      navigate("/", { replace: true });
    } catch (error) {
      setFeedback({ type: "error", message: "Registration failed. Try a different email." });
    } finally {
      setSubmitting(false);
    }
  };

  const handleRequestToken = async () => {
    try {
      setSubmitting(true);
      const response = await requestPasswordReset(resetForm.email);
      if (response.reset_token) {
        setResetForm((prev) => ({ ...prev, token: response.reset_token ?? prev.token }));
        setFeedback({ type: "success", message: "Reset token created. Continue to set a new password." });
        setActiveTab("reset-final");
      } else {
        setFeedback({ type: "success", message: response.message });
      }
    } catch (error) {
      setFeedback({ type: "error", message: "Could not request reset token." });
    } finally {
      setSubmitting(false);
    }
  };

  const handleApplyReset = async () => {
    try {
      setSubmitting(true);
      const ok = await validatePasswordResetToken(resetForm.token);
      if (!ok) {
        setFeedback({ type: "error", message: "Invalid or expired reset link/token." });
        return;
      }
      await completePasswordReset(resetForm.token, resetForm.newPassword);
      setFeedback({ type: "success", message: "Password updated. You may log in now." });
      setActiveTab("login");
    } catch (error) {
      setFeedback({ type: "error", message: "Unable to update password. Double-check the token." });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Box
      sx={{
        minHeight: "100dvh",
        height: "100dvh",
        display: "grid",
        placeItems: "center",
        p: { xs: 2, md: 4 },
        overflowY: "auto",
        overscrollBehaviorY: "none",
      }}
    >
      <Card sx={{ width: "min(1040px, 100%)", my: { xs: 2, md: 0 } }}>
        <CardContent sx={{ p: { xs: 2, md: 4 } }}>
          <Stack direction={{ xs: "column", md: "row" }} spacing={{ xs: 3, md: 4 }} alignItems="stretch">
            <Box
              sx={{
                flex: 1,
                borderRadius: 3,
                p: { xs: 3, md: 4 },
                background: `linear-gradient(135deg, ${theme.palette.primary.dark}, ${theme.palette.primary.main})`,
                color: "common.white",
                display: { xs: "none", md: "flex" },
                flexDirection: "column",
                justifyContent: "space-between",
                gap: 3,
              }}
            >
              <Stack spacing={1}>
                <Typography variant="h4" fontWeight={800}>
                  LawTech
                  <br />
                  المنصة القانونية الفلسطينية
                </Typography>
                <Typography variant="body1" sx={{ opacity: 0.9 }}>
                  استشارتك القانونية الذكية المتخصصة بالقانون الفلسطيني
                </Typography>
              </Stack>

              <Stack spacing={1}>
                <Typography variant="body2" sx={{ opacity: 0.85 }}>
                  احصل على إجابات قانونية دقيقة لقضيتك بناءً على القانون الفلسطيني والأنظمة المعمول بها.
                </Typography>
                <Typography variant="caption" sx={{ opacity: 0.75 }}>
                  منصة آمنة ومتخصصة — استشر المساعد القانوني الذكي في أي وقت.
                </Typography>
              </Stack>
            </Box>

            <Box sx={{ flex: 1, minWidth: 0 }}>
              <Stack spacing={0.5} sx={{ display: { xs: "flex", md: "none" }, mb: 3 }}>
                <Typography variant="h5" fontWeight={800} color="primary">
                  LawTech | المنصة القانونية
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  استشارتك القانونية الذكية للقانون الفلسطيني
                </Typography>
              </Stack>
              <Stack spacing={2.5}>
                <Stack spacing={0.5}>
                  <Typography variant="h5" fontWeight={800}>
                    {activeTab === "login"
                      ? "Sign in"
                      : activeTab === "signup"
                        ? "Create your account"
                        : activeTab === "reset-request"
                          ? "Reset Password"
                          : "Set New Password"}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    سجّل الدخول للوصول إلى المستشار القانوني الذكي
                  </Typography>
                </Stack>

                <Box sx={{ position: "relative" }}>
                  <Tabs
                    value={tabConfig.some(t => t.value === activeTab) ? activeTab : false}
                    onChange={(_e, value) => setActiveTab(value)}
                    variant="scrollable"
                    scrollButtons={false}
                    allowScrollButtonsMobile
                    sx={{
                      "& .MuiTabs-scroller": {
                        overflowX: "auto !important",
                        scrollbarWidth: "none",
                        "&::-webkit-scrollbar": { display: "none" },
                      },
                      "& .MuiTabs-flexContainer": { gap: 1, px: 0.5 },
                      "& .MuiTab-root": {
                        minHeight: 40,
                        textTransform: "none",
                        fontWeight: 800,
                        whiteSpace: "nowrap",
                      },
                    }}
                  >
                    {tabConfig.map((tab) => (
                      <Tab key={tab.value} value={tab.value} icon={tab.icon} iconPosition="start" label={tab.label} />
                    ))}
                  </Tabs>

                  {/* Right gradient "peek" to hint horizontal scroll */}
                  <Box
                    sx={{
                      pointerEvents: "none",
                      position: "absolute",
                      top: 0,
                      right: 0,
                      height: "100%",
                      width: 36,
                      background: (theme) =>
                        `linear-gradient(90deg, rgba(0,0,0,0) 0%, ${theme.palette.background.paper} 80%)`,
                    }}
                  />
                </Box>

                {feedback && <Alert severity={feedback.type}>{feedback.message}</Alert>}

                {activeTab === "login" && (
                  <Stack component="form" spacing={2} onSubmit={handleLogin}>
                    <TextField
                      label="Email"
                      type="email"
                      autoComplete="email"
                      value={loginForm.email}
                      onChange={(event) => setLoginForm((prev) => ({ ...prev, email: event.target.value }))}
                      required
                    />
                    <TextField
                      label="Password"
                      type={showPassword ? "text" : "password"}
                      autoComplete="current-password"
                      value={loginForm.password}
                      onChange={(event) => setLoginForm((prev) => ({ ...prev, password: event.target.value }))}
                      required
                      InputProps={{
                        endAdornment: (
                          <InputAdornment position="end">
                            <IconButton onClick={() => setShowPassword((s) => !s)} edge="end">
                              {showPassword ? <VisibilityOffRoundedIcon /> : <VisibilityRoundedIcon />}
                            </IconButton>
                          </InputAdornment>
                        ),
                      }}
                    />
                    <Button type="submit" variant="contained" size="large" disabled={submitting}>
                      {submitting ? "Signing in…" : "Sign in"}
                    </Button>
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Link component="button" underline="hover" onClick={() => setActiveTab("reset-request")}>
                        Forgot password?
                      </Link>
                      <Link component="button" underline="hover" onClick={() => setActiveTab("signup")}>
                        Create account
                      </Link>
                    </Stack>
                  </Stack>
                )}

                {activeTab === "signup" && (
                  <Stack component="form" spacing={2} onSubmit={handleSignup}>
                    <TextField
                      label="البريد الإلكتروني"
                      type="email"
                      autoComplete="email"
                      value={signupForm.email}
                      onChange={(event) => setSignupForm((prev) => ({ ...prev, email: event.target.value }))}
                      required
                    />
                    <TextField
                      label="Password"
                      type={showPassword ? "text" : "password"}
                      autoComplete="new-password"
                      value={signupForm.password}
                      onChange={(event) => setSignupForm((prev) => ({ ...prev, password: event.target.value }))}
                      required
                      InputProps={{
                        endAdornment: (
                          <InputAdornment position="end">
                            <IconButton onClick={() => setShowPassword((s) => !s)} edge="end">
                              {showPassword ? <VisibilityOffRoundedIcon /> : <VisibilityRoundedIcon />}
                            </IconButton>
                          </InputAdornment>
                        ),
                      }}
                    />
                    <Button type="submit" variant="contained" size="large" disabled={submitting}>
                      {submitting ? "Creating…" : "Create account"}
                    </Button>
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Link component="button" underline="hover" onClick={() => setActiveTab("login")}>
                        Already have an account?
                      </Link>
                      <Link component="button" underline="hover" onClick={() => setActiveTab("reset-request")}>
                        Reset password
                      </Link>
                    </Stack>
                  </Stack>
                )}

                {activeTab === "reset-request" && (
                  <Stack spacing={2}>
                     <Typography variant="body2" color="text.secondary">
                        Enter your email to receive a password reset token.
                      </Typography>
                    <TextField
                      label="Email"
                      type="email"
                      autoComplete="email"
                      value={resetForm.email}
                      onChange={(event) => setResetForm((prev) => ({ ...prev, email: event.target.value }))}
                      required
                    />
                    <Button variant="contained" onClick={handleRequestToken} disabled={submitting || !resetForm.email}>
                      {submitting ? "Requesting…" : "Request reset token"}
                    </Button>
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Link component="button" underline="hover" onClick={() => setActiveTab("login")}>
                        Back to sign in
                      </Link>
                      <Link component="button" underline="hover" onClick={() => setActiveTab("reset-final")}>
                        I already have a token
                      </Link>
                    </Stack>
                  </Stack>
                )}

                {activeTab === "reset-final" && (
                  <Stack spacing={2}>
                    <TextField
                      label="Reset token"
                      value={resetForm.token}
                      onChange={(event) => setResetForm((prev) => ({ ...prev, token: event.target.value }))}
                      error={tokenValid === false}
                      helperText={
                        tokenChecking
                          ? "Checking token…"
                          : tokenValid === false
                            ? "Invalid or expired token. Request a new one."
                            : tokenValid === true
                              ? "Token looks valid."
                              : "Check your email for the token."
                      }
                    />
                    <TextField
                      label="New password"
                      type={showPassword ? "text" : "password"}
                      autoComplete="new-password"
                      value={resetForm.newPassword}
                      onChange={(event) => setResetForm((prev) => ({ ...prev, newPassword: event.target.value }))}
                      InputProps={{
                        endAdornment: (
                          <InputAdornment position="end">
                            <IconButton onClick={() => setShowPassword((s) => !s)} edge="end">
                              {showPassword ? <VisibilityOffRoundedIcon /> : <VisibilityRoundedIcon />}
                            </IconButton>
                          </InputAdornment>
                        ),
                      }}
                    />
                    <Button
                      variant="contained"
                      onClick={handleApplyReset}
                      disabled={submitting || tokenChecking || tokenValid === false || !resetForm.token || !resetForm.newPassword}
                    >
                      {submitting ? "Updating…" : "Update password"}
                    </Button>
                    <Link component="button" underline="hover" onClick={() => setActiveTab("login")}>
                      Back to sign in
                    </Link>
                  </Stack>
                )}
              </Stack>
            </Box>
          </Stack>
        </CardContent>
      </Card>
    </Box>
  );
};

export default AuthPage;
