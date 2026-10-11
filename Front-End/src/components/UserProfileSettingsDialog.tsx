/**
 * UserProfileSettingsDialog
 *
 * Allows users to customise their AI assistant behaviour by specifying their
 * professional industry and preferred response language.  These values are
 * persisted to localStorage via AuthContext and are injected into the backend
 * LLM system prompt on every chat request.
 */
import AccountCircleRoundedIcon from "@mui/icons-material/AccountCircleRounded";
import CloseRoundedIcon from "@mui/icons-material/CloseRounded";
import InfoOutlinedIcon from "@mui/icons-material/InfoOutlined";
import TuneRoundedIcon from "@mui/icons-material/TuneRounded";
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from "@mui/material";
import { useEffect, useState } from "react";

import { useAuth } from "../context/AuthContext";

// ─── Constants ───────────────────────────────────────────────────────────────

export const INDUSTRY_OPTIONS = [
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

export const LANGUAGE_OPTIONS = [
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

// ─── Component ────────────────────────────────────────────────────────────────

interface UserProfileSettingsDialogProps {
  open: boolean;
  onClose: () => void;
}

export const UserProfileSettingsDialog = ({ open, onClose }: UserProfileSettingsDialogProps) => {
  const { user, updateUserProfile } = useAuth();

  const [industry, setIndustry] = useState(user?.industry ?? "");
  const [language, setLanguage] = useState(user?.preferred_language ?? "en");
  const [customNote, setCustomNote] = useState("");
  const [saved, setSaved] = useState(false);

  // Sync with user profile when dialog opens
  useEffect(() => {
    if (open) {
      setIndustry(user?.industry ?? "");
      setLanguage(user?.preferred_language ?? "en");
      setSaved(false);
    }
  }, [open, user?.industry, user?.preferred_language]);

  const handleSave = () => {
    updateUserProfile({
      industry: industry || undefined,
      preferred_language: language || undefined,
    });
    setSaved(true);
  };

  const industryLabel = INDUSTRY_OPTIONS.includes(industry as (typeof INDUSTRY_OPTIONS)[number])
    ? industry
    : industry || "Not specified";

  const languageLabel =
    LANGUAGE_OPTIONS.find((l) => l.value === language)?.label ?? language ?? "English";

  // Build a live preview of what gets injected into the LLM system prompt
  const promptPreview = buildSystemPromptSnippet({ industry, language });

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle sx={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <Stack direction="row" spacing={1.5} alignItems="center">
          <TuneRoundedIcon color="primary" />
          <Typography variant="h6" fontWeight={700}>
            Customize Assistant
          </Typography>
        </Stack>
        <IconButton onClick={onClose} size="small" aria-label="Close">
          <CloseRoundedIcon fontSize="small" />
        </IconButton>
      </DialogTitle>

      <DialogContent dividers>
        <Stack spacing={3}>
          {/* Description */}
          <Stack direction="row" spacing={1} alignItems="flex-start">
            <InfoOutlinedIcon fontSize="small" color="info" sx={{ mt: 0.25 }} />
            <Typography variant="body2" color="text.secondary">
              Customize assistant behavior. Changes apply to your personal experience. The
              information below is injected into the AI system prompt so responses are more
              relevant to your professional context.
            </Typography>
          </Stack>

          <Divider />

          {/* User info banner */}
          <Stack direction="row" spacing={1.5} alignItems="center">
            <AccountCircleRoundedIcon color="action" />
            <Stack spacing={0.25}>
              <Typography variant="subtitle2" fontWeight={600}>
                {user?.email}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Role: {(user?.role ?? "viewer").replaceAll("_", " ")}
              </Typography>
            </Stack>
          </Stack>

          {/* Industry */}
          <FormControl fullWidth>
            <InputLabel id="profile-industry-label">Industry / Domain</InputLabel>
            <Select
              labelId="profile-industry-label"
              label="Industry / Domain"
              value={industry}
              onChange={(e) => { setIndustry(e.target.value); setSaved(false); }}
            >
              <MenuItem value=""><em>Not specified</em></MenuItem>
              {INDUSTRY_OPTIONS.map((ind) => (
                <MenuItem key={ind} value={ind}>
                  {ind}
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          {/* Language */}
          <FormControl fullWidth>
            <InputLabel id="profile-lang-label">Preferred response language</InputLabel>
            <Select
              labelId="profile-lang-label"
              label="Preferred response language"
              value={language}
              onChange={(e) => { setLanguage(e.target.value); setSaved(false); }}
            >
              {LANGUAGE_OPTIONS.map((lang) => (
                <MenuItem key={lang.value} value={lang.value}>
                  {lang.label}
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          {/* Optional free-text custom instruction */}
          <TextField
            label="Additional context (optional)"
            placeholder="e.g. I work on compliance at a mid-size bank focused on MENA markets."
            multiline
            minRows={2}
            maxRows={5}
            value={customNote}
            onChange={(e) => setCustomNote(e.target.value)}
            helperText="Not yet saved to the backend — future enhancement."
          />

          <Divider />

          {/* Live system prompt preview */}
          <Stack spacing={1}>
            <Tooltip title="This is the text prepended to the AI system prompt for your account" placement="top-start">
              <Typography variant="subtitle2" fontWeight={600} sx={{ cursor: "help" }}>
                System prompt preview
              </Typography>
            </Tooltip>
            <Box
              sx={{
                bgcolor: "background.default",
                border: "1px solid",
                borderColor: "divider",
                borderRadius: 1,
                p: 1.5,
              }}
            >
              <Typography
                variant="caption"
                component="pre"
                sx={{ whiteSpace: "pre-wrap", wordBreak: "break-word", fontFamily: "monospace", m: 0 }}
              >
                {promptPreview}
              </Typography>
            </Box>
            <Typography variant="caption" color="text.secondary">
              Current profile: industry=<strong>{industryLabel}</strong>, language=<strong>{languageLabel}</strong>
            </Typography>
          </Stack>

          {saved && (
            <Alert severity="success" onClose={() => setSaved(false)}>
              Profile saved. Your next chat message will use the updated preferences.
            </Alert>
          )}
        </Stack>
      </DialogContent>

      <DialogActions sx={{ px: 3, py: 2 }}>
        <Button onClick={onClose} color="inherit">
          Cancel
        </Button>
        <Button variant="contained" onClick={handleSave} disableElevation>
          Save preferences
        </Button>
      </DialogActions>
    </Dialog>
  );
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Builds the text snippet that will be prepended to the LLM system prompt.
 * Keep this in sync with the backend `build_user_context_prompt()` helper.
 */
export function buildSystemPromptSnippet({
  industry,
  language,
}: {
  industry?: string;
  language?: string;
}): string {
  const parts: string[] = [];

  if (industry) {
    parts.push(`- The user works in the ${industry} industry.`);
    parts.push(
      `  Tailor terminology, examples, and compliance considerations to the ${industry} context.`,
    );
  }

  if (language && language !== "en") {
    const langLabel =
      LANGUAGE_OPTIONS.find((l) => l.value === language)?.label ?? language;
    parts.push(
      `- Respond in ${langLabel} unless the user explicitly writes in a different language.`,
    );
  }

  if (!parts.length) {
    return "(No personal context set — responses will use the default system prompt.)";
  }

  return ["User context:", ...parts].join("\n");
}

export default UserProfileSettingsDialog;
