import ErrorOutlineIcon from "@mui/icons-material/ErrorOutline";
import {
  Autocomplete,
  Chip,
  FormControl,
  FormHelperText,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import { createFilterOptions } from "@mui/material/Autocomplete";
import {
  Children,
  forwardRef,
  useEffect,
  useMemo,
  useState,
  type HTMLAttributes,
  type ReactElement,
} from "react";

import type { ModelPricingEntry } from "../api/chat";

export interface ModelSelectorProps {
  models: string[];
  value: string;
  onChange: (next: string) => void;
  disabled?: boolean;
  pricing?: ModelPricingEntry | null;
  tier?: "low" | "medium" | "high" | null;
  errorText?: string | null;
}

const OPTION_HEIGHT = 40;
const VISIBLE_OPTIONS = 8;
const OVERSCAN = 4;
const VIRTUALIZATION_THRESHOLD = 120;

const VirtualizedListbox = forwardRef<HTMLDivElement, HTMLAttributes<HTMLElement>>(function VirtualizedListbox(
  props,
  ref,
) {
  const { children, ...other } = props;
  const [scrollTop, setScrollTop] = useState(0);
  const items = useMemo(
    () => Children.toArray(children).filter(Boolean) as ReactElement[],
    [children],
  );

  useEffect(() => {
    setScrollTop(0);
  }, [items.length]);

  const start = Math.max(0, Math.floor(scrollTop / OPTION_HEIGHT) - OVERSCAN);
  const end = Math.min(items.length, start + VISIBLE_OPTIONS + OVERSCAN * 2);
  const visible = items.slice(start, end);
  const offsetTop = start * OPTION_HEIGHT;
  const viewportHeight = Math.min(items.length, VISIBLE_OPTIONS) * OPTION_HEIGHT;

  return (
    <div
      {...other}
      ref={ref}
      onScroll={(event) => setScrollTop((event.currentTarget as HTMLDivElement).scrollTop)}
      style={{
        ...(other.style || {}),
        maxHeight: viewportHeight || OPTION_HEIGHT,
        overflowY: "auto",
      }}
    >
      <div style={{ height: items.length * OPTION_HEIGHT, position: "relative" }}>
        <div style={{ position: "absolute", top: offsetTop, left: 0, right: 0 }}>
          {visible}
        </div>
      </div>
    </div>
  );
});

export const ModelSelector = ({
  models,
  value,
  onChange,
  disabled,
  pricing,
  tier,
  errorText,
}: ModelSelectorProps) => {
  const sortedModels = useMemo(() => {
    const cleaned = models.map((model) => model.trim()).filter(Boolean);
    return Array.from(new Set(cleaned)).sort((a, b) => a.localeCompare(b));
  }, [models]);
  const useVirtualizedList = sortedModels.length > VIRTUALIZATION_THRESHOLD;
  const filterOptions = useMemo(
    () =>
      createFilterOptions<string>({
        trim: true,
        matchFrom: "any",
        stringify: (option) => option,
      }),
    [],
  );

  const getTierColor = (t: "low" | "medium" | "high" | null) => {
    if (t === "high") return "error";
    if (t === "medium") return "warning";
    return "success";
  };

  const getTierLabel = (t: "low" | "medium" | "high" | null) => {
    if (t === "high") return "Premium";
    if (t === "medium") return "Standard";
    return "Budget";
  };

  return (
    <FormControl size="small" fullWidth disabled={disabled} error={Boolean(errorText)}>
      <Autocomplete
        size="small"
        options={sortedModels}
        value={value || null}
        onChange={(_, next) => onChange(next ?? "")}
        disabled={disabled}
        autoHighlight
        disablePortal
        isOptionEqualToValue={(option, optionValue) => option === optionValue}
        filterOptions={filterOptions}
        slots={useVirtualizedList ? { listbox: VirtualizedListbox } : undefined}
        ListboxProps={useVirtualizedList ? undefined : { style: { maxHeight: 320 } }}
        renderInput={(params) => <TextField {...params} label="النموذج" placeholder="بحث عن نماذج" />}
        renderOption={(props, option) => (
          <li {...props} key={option} style={{ ...props.style, minHeight: OPTION_HEIGHT, display: "flex", alignItems: "center" }}>
            <Typography variant="body2" noWrap sx={{ fontWeight: 600 }}>
              {option}
            </Typography>
          </li>
        )}
      />
      {tier && !errorText ? (
        <FormHelperText component="div">
          <Stack direction="row" spacing={1} alignItems="center">
            <Typography variant="caption" color="text.secondary">
              مستوى التكلفة
            </Typography>
            <Chip
              label={getTierLabel(tier)}
              size="small"
              color={getTierColor(tier)}
              variant="outlined"
              sx={{ height: 20, fontSize: "0.65rem" }}
            />
          </Stack>
        </FormHelperText>
      ) : null}
      {errorText && (
        <FormHelperText component="div">
          <Stack direction="row" spacing={0.5} alignItems="center">
            <ErrorOutlineIcon sx={{ fontSize: 14 }} />
            <span>{errorText}</span>
          </Stack>
        </FormHelperText>
      )}
      {pricing && !errorText && (
        <FormHelperText component="div">
          <Typography variant="caption" color="text.secondary">
            {pricing.input && pricing.output
              ? `$${pricing.input.toFixed(2)} / $${pricing.output.toFixed(2)} لكل مليون رمز (مدخل/مخرج)`
              : "التسعيرة غير متاحة"}
          </Typography>
        </FormHelperText>
      )}
    </FormControl>
  );
};

export default ModelSelector;
