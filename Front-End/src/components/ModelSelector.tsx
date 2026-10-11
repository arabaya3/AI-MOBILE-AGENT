import ErrorOutlineIcon from "@mui/icons-material/ErrorOutline";
import BoltRoundedIcon from "@mui/icons-material/BoltRounded";
import AutoAwesomeRoundedIcon from "@mui/icons-material/AutoAwesomeRounded";
import MonetizationOnOutlinedIcon from "@mui/icons-material/MonetizationOnOutlined";
import KeyboardArrowDownIcon from "@mui/icons-material/KeyboardArrowDown";
import {
  Chip,
  FormControl,
  FormHelperText,
  ListItemIcon,
  ListItemText,
  MenuItem,
  Select,
  Snackbar,
  Stack,
  Typography,
  type SelectChangeEvent,
} from "@mui/material";
import { useMemo, useState } from "react";

import type { ModelPricingEntry } from "../api/chat";

export interface ModelSelectorProps {
  models: string[];
  value: string;
  onChange: (next: string) => void;
  disabled?: boolean;
  pricing?: ModelPricingEntry | null;
  tier?: "low" | "medium" | "high" | null;
  errorText?: string | null;
  /** Compact mode for header placement */
  compact?: boolean;
}

/** Maps tier → human-friendly labels & context */
const TIER_META = {
  high: {
    color: "error" as const,
    chipLabel: "Premium",
    icon: <MonetizationOnOutlinedIcon sx={{ fontSize: 14, color: "error.main" }} />,
  },
  medium: {
    color: "warning" as const,
    chipLabel: "Standard",
    icon: <BoltRoundedIcon sx={{ fontSize: 14, color: "warning.main" }} />,
  },
  low: {
    color: "success" as const,
    chipLabel: "Efficient",
    icon: <BoltRoundedIcon sx={{ fontSize: 14, color: "success.main" }} />,
  },
} as const;

/** Infer a tier from model name when no pricing is available */
const inferTier = (model: string): "low" | "medium" | "high" => {
  const lower = model.toLowerCase();
  if (lower.includes("nano") || lower.includes("mini")) return "low";
  if (lower.includes("turbo") || lower.includes("pro")) return "high";
  return "medium";
};

export const ModelSelector = ({
  models,
  value,
  onChange,
  disabled,
  pricing: _pricing,
  tier,
  errorText,
  compact = false,
}: ModelSelectorProps) => {
  const [feedbackOpen, setFeedbackOpen] = useState(false);

  const sortedModels = useMemo(() => {
    const cleaned = models.map((m) => m.trim()).filter(Boolean);
    return Array.from(new Set(cleaned)).sort((a, b) => a.localeCompare(b));
  }, [models]);

  const handleChange = (event: SelectChangeEvent<string>) => {
    const next = event.target.value;
    if (next !== value) {
      onChange(next);
      setFeedbackOpen(true);
    }
  };

  return (
    <>
      <FormControl size="small" fullWidth={!compact} disabled={disabled} error={Boolean(errorText)}>
        <Select
          value={value || ""}
          onChange={handleChange}
          displayEmpty
          IconComponent={KeyboardArrowDownIcon}
          aria-label="Select AI model"
          id="model-selector"
          renderValue={(selected) => {
            if (!selected) {
              return (
                <Typography variant="body2" color="text.secondary">
                  Model…
                </Typography>
              );
            }
            const selectedTier = tier ?? inferTier(selected);
            const meta = TIER_META[selectedTier];
            return (
              <Stack direction="row" alignItems="center" spacing={0.75}>
                <AutoAwesomeRoundedIcon sx={{ fontSize: 16, color: "primary.main" }} />
                <Typography variant="body2" fontWeight={600} noWrap>
                  {selected}
                </Typography>
                {meta && (
                  <Chip
                    label={meta.chipLabel}
                    size="small"
                    color={meta.color}
                    variant="outlined"
                    sx={{ height: 18, fontSize: "0.6rem", fontWeight: 700 }}
                  />
                )}
              </Stack>
            );
          }}
          sx={{
            minWidth: compact ? 180 : 200,
            "& .MuiSelect-select": {
              display: "flex",
              alignItems: "center",
              py: 0.75,
            },
          }}
          MenuProps={{
            PaperProps: {
              sx: { maxHeight: 320, mt: 0.5 },
            },
          }}
        >
          {sortedModels.map((model) => {
            const modelTier = inferTier(model);
            const meta = TIER_META[modelTier];
            const isPreferred = model === "gpt-5-nano" || model === "gpt-5-mini";
            return (
              <MenuItem
                key={model}
                value={model}
                sx={{
                  minHeight: 40,
                  display: "flex",
                  alignItems: "center",
                  gap: 1,
                }}
              >
                <ListItemIcon sx={{ minWidth: 28 }}>
                  <AutoAwesomeRoundedIcon sx={{ fontSize: 18, color: "primary.main" }} />
                </ListItemIcon>
                <ListItemText
                  primary={model}
                  primaryTypographyProps={{ variant: "body2", fontWeight: 600, noWrap: true }}
                />
                <Stack direction="row" spacing={0.5} alignItems="center">
                  {isPreferred && (
                    <Chip
                      label="Recommended"
                      size="small"
                      color="primary"
                      variant="outlined"
                      sx={{ height: 18, fontSize: "0.55rem", fontWeight: 700 }}
                    />
                  )}
                  <Chip
                    label={meta.chipLabel}
                    size="small"
                    color={meta.color}
                    variant="outlined"
                    sx={{ height: 18, fontSize: "0.55rem", fontWeight: 700 }}
                  />
                </Stack>
              </MenuItem>
            );
          })}
        </Select>

        {/* Error text */}
        {errorText && (
          <FormHelperText>
            <Stack direction="row" spacing={0.5} alignItems="center">
              <ErrorOutlineIcon sx={{ fontSize: 14 }} />
              <span>{errorText}</span>
            </Stack>
          </FormHelperText>
        )}
      </FormControl>

      {/* Instant visual feedback on model switch */}
      <Snackbar
        open={feedbackOpen}
        autoHideDuration={1500}
        onClose={() => setFeedbackOpen(false)}
        message={`Switched to ${value}`}
        anchorOrigin={{ vertical: "top", horizontal: "center" }}
        sx={{ mt: 8 }}
      />
    </>
  );
};

export default ModelSelector;

