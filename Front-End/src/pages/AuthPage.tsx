import LockOpenRoundedIcon from "@mui/icons-material/LockOpenRounded";
import PersonAddAltRoundedIcon from "@mui/icons-material/PersonAddAltRounded";
import VisibilityOffRoundedIcon from "@mui/icons-material/VisibilityOffRounded";
import VisibilityRoundedIcon from "@mui/icons-material/VisibilityRounded";
import ExpandMoreIcon from "@mui/icons-material/ExpandMore";
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Checkbox,
  FormControl,
  FormControlLabel,
  IconButton,
  InputAdornment,
  InputLabel,
  Link,
  MenuItem,
  Select,
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

const INDUSTRY_OPTIONS = [
  "Fintech",
  "Law",
  "Healthcare",
  "Insurance",
  "Real Estate",
  "Technology",
  "Education",
  "Manufacturing",
  "Retail",
  "Government",
  "Consulting",
  "Media & Entertainment",
  "Logistics",
  "Energy",
  "Other",
] as const;

const LANGUAGE_OPTIONS = [
  { label: "English", value: "en" },
  { label: "Arabic (العربية)", value: "ar" },
  { label: "French (Français)", value: "fr" },
  { label: "Spanish (Español)", value: "es" },
  { label: "German (Deutsch)", value: "de" },
  { label: "Italian (Italiano)", value: "it" },
  { label: "Portuguese (Português)", value: "pt" },
  { label: "Russian (Русский)", value: "ru" },
  { label: "Chinese Simplified (中文)", value: "zh" },
  { label: "Japanese (日本語)", value: "ja" },
  { label: "Korean (한국어)", value: "ko" },
  { label: "Turkish (Türkçe)", value: "tr" },
  { label: "Hindi (हिन्दी)", value: "hi" },
  { label: "Dutch (Nederlands)", value: "nl" },
  { label: "Polish (Polski)", value: "pl" },
] as const;

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
  const [signupForm, setSignupForm] = useState({
    email: "",
    password: "",
    first_name: "",
    last_name: "",
    date_of_birth: "",
    phone_number: "",
    country: "",
    job_title: "",
    company: "",
    industry: "",
    preferred_language: "en",
  });
  const [resetForm, setResetForm] = useState({ email: "", token: "", newPassword: "" });
  const [feedback, setFeedback] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [legalAccepted, setLegalAccepted] = useState(false);
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
    // Client-side 18+ validation
    if (signupForm.date_of_birth) {
      const dob = new Date(signupForm.date_of_birth);
      const cutoff = new Date();
      cutoff.setFullYear(cutoff.getFullYear() - 18);
      if (dob > cutoff) {
        setFeedback({ type: "error", message: "You must be at least 18 years old to register." });
        return;
      }
    }
    try {
      setSubmitting(true);
      await signup({
        ...signupForm,
        role: "viewer",
        first_name:         signupForm.first_name         || undefined,
        last_name:          signupForm.last_name          || undefined,
        date_of_birth:      signupForm.date_of_birth      || undefined,
        phone_number:       signupForm.phone_number       || undefined,
        country:            signupForm.country            || undefined,
        job_title:          signupForm.job_title          || undefined,
        company:            signupForm.company            || undefined,
        industry:           signupForm.industry           || undefined,
        preferred_language: signupForm.preferred_language || undefined,
      });
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
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        p: { xs: 2, md: 4 },
        overflowY: "auto",
        overscrollBehaviorY: "contain",
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
                  TEIA Workspace
                </Typography>
                <Typography variant="body1" sx={{ opacity: 0.9 }}>
                  Secure, space-scoped chat with enterprise documents.
                </Typography>
              </Stack>

              <Stack spacing={1}>
                <Typography variant="body2" sx={{ opacity: 0.85 }}>
                  After sign-in, you’ll select or create a space.
                </Typography>
                <Typography variant="caption" sx={{ opacity: 0.75 }}>
                  Spaces control access, quotas, models, and usage reporting.
                </Typography>
              </Stack>
            </Box>

            <Box sx={{ flex: 1, minWidth: 0 }}>
              <Stack spacing={0.5} sx={{ display: { xs: "flex", md: "none" }, mb: 3 }}>
                <Typography variant="h5" fontWeight={800} color="primary">
                  TEIA Workspace
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Secure, space-scoped chat with enterprise documents.
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
                    Use your company email to continue.
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
                  <Stack component="form" spacing={1.5} onSubmit={handleSignup}>
                    {/* ── Name row ─────────────────────────────────────────── */}
                    <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", sm: "1fr 1fr" }, gap: 2 }}>
                      <TextField
                        label="First name"
                        autoComplete="given-name"
                        value={signupForm.first_name}
                        onChange={(e) => setSignupForm((prev) => ({ ...prev, first_name: e.target.value }))}
                        required
                      />
                      <TextField
                        label="Last name"
                        autoComplete="family-name"
                        value={signupForm.last_name}
                        onChange={(e) => setSignupForm((prev) => ({ ...prev, last_name: e.target.value }))}
                        required
                      />
                    </Box>

                    {/* ── Credentials ──────────────────────────────────────── */}
                    <TextField
                      label="Work email"
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
                      helperText="Minimum 8 characters"
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

                    {/* ── Date of birth ────────────────────────────────────── */}
                    <TextField
                      label="Date of birth"
                      type="date"
                      autoComplete="bday"
                      value={signupForm.date_of_birth}
                      onChange={(e) => setSignupForm((prev) => ({ ...prev, date_of_birth: e.target.value }))}
                      required
                      inputProps={{
                        max: (() => {
                          const d = new Date();
                          d.setFullYear(d.getFullYear() - 18);
                          return d.toISOString().split("T")[0];
                        })(),
                      }}
                      InputLabelProps={{ shrink: true }}
                      helperText="Must be 18 years or older"
                    />

                    {/* ── Optional details (collapsible) ───────────────── */}
                    <Accordion
                      disableGutters
                      elevation={0}
                      sx={{
                        border: "1px solid",
                        borderColor: "divider",
                        borderRadius: "8px !important",
                        "&:before": { display: "none" },
                        "&.Mui-expanded": { mt: 0 },
                      }}
                    >
                      <AccordionSummary
                        expandIcon={<ExpandMoreIcon />}
                        sx={{ minHeight: 44, "& .MuiAccordionSummary-content": { my: 0.5 } }}
                      >
                        <Typography variant="body2" color="text.secondary">
                          Optional details (phone, country, job, language…)
                        </Typography>
                      </AccordionSummary>
                      <AccordionDetails sx={{ pt: 0 }}>
                        <Stack spacing={2}>
                          {/* ── Phone + Country */}
                          <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", sm: "1fr 1fr" }, gap: 2 }}>
                            <TextField
                              label="Phone number"
                              type="tel"
                              autoComplete="tel"
                              value={signupForm.phone_number}
                              onChange={(e) => setSignupForm((prev) => ({ ...prev, phone_number: e.target.value }))}
                              size="small"
                            />
                            <TextField
                              label="Country"
                              autoComplete="country-name"
                              value={signupForm.country}
                              onChange={(e) => setSignupForm((prev) => ({ ...prev, country: e.target.value }))}
                              size="small"
                            />
                          </Box>

                          {/* ── Job title + Company */}
                          <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", sm: "1fr 1fr" }, gap: 2 }}>
                            <TextField
                              label="Job title"
                              autoComplete="organization-title"
                              value={signupForm.job_title}
                              onChange={(e) => setSignupForm((prev) => ({ ...prev, job_title: e.target.value }))}
                              size="small"
                            />
                            <TextField
                              label="Company"
                              autoComplete="organization"
                              value={signupForm.company}
                              onChange={(e) => setSignupForm((prev) => ({ ...prev, company: e.target.value }))}
                              size="small"
                            />
                          </Box>

                          {/* ── Industry + Language */}
                          <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", sm: "1fr 1fr" }, gap: 2 }}>
                            <FormControl size="small" fullWidth>
                              <InputLabel id="signup-industry-label">Industry</InputLabel>
                              <Select
                                labelId="signup-industry-label"
                                label="Industry"
                                value={signupForm.industry}
                                onChange={(e) => setSignupForm((prev) => ({ ...prev, industry: e.target.value }))}
                              >
                                <MenuItem value=""><em>Not specified</em></MenuItem>
                                {INDUSTRY_OPTIONS.map((ind) => (
                                  <MenuItem key={ind} value={ind}>{ind}</MenuItem>
                                ))}
                              </Select>
                            </FormControl>
                            <FormControl size="small" fullWidth>
                              <InputLabel id="signup-lang-label">Response language</InputLabel>
                              <Select
                                labelId="signup-lang-label"
                                label="Response language"
                                value={signupForm.preferred_language}
                                onChange={(e) => setSignupForm((prev) => ({ ...prev, preferred_language: e.target.value }))}
                              >
                                {LANGUAGE_OPTIONS.map((lang) => (
                                  <MenuItem key={lang.value} value={lang.value}>{lang.label}</MenuItem>
                                ))}
                              </Select>
                            </FormControl>
                          </Box>
                        </Stack>
                      </AccordionDetails>
                    </Accordion>

                    <FormControlLabel
                      control={
                        <Checkbox
                          checked={legalAccepted}
                          onChange={(e) => setLegalAccepted(e.target.checked)}
                          size="small"
                          color="primary"
                        />
                      }
                      label={
                        <Typography variant="body2" color="text.secondary">
                          I agree to the{" "}
                          <Link href="/terms" target="_blank" underline="hover">Terms of Service</Link>
                          {" and "}
                          <Link href="/privacy" target="_blank" underline="hover">Privacy Policy</Link>
                          . I understand this product uses AI to generate responses and my data may be processed accordingly.
                        </Typography>
                      }
                      sx={{ alignItems: "flex-start", mt: 0.5 }}
                    />

                    <Button type="submit" variant="contained" size="large" disabled={submitting || !legalAccepted}>
                      {submitting ? "Creating account…" : "Create account"}
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
