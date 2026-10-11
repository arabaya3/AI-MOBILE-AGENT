import { useMemo } from "react";

import { Box, Card, CardContent, Stack, Typography } from "@mui/material";
import { formatToolName, formatUsdCost } from "../utils/formatters";
import { ThemeConfig } from "../styles/ThemeConfig";

export type UsageCategory = "text" | "audio" | "image" | "web" | "tool" | "other";

export interface UsageRow {
  key: string;
  label: string;
  costUsd: number | null | undefined;
  category?: UsageCategory;
}

const iconFor = (category: UsageCategory | undefined, label: string) => {
  const l = label.toLowerCase();
  if (category === "text" || l.includes("text")) return "📝";
  if (category === "audio" || l.includes("audio") || l.includes("voice")) return "🎤";
  if (category === "image" || l.includes("image")) return "🖼";
  if (category === "web" || l.includes("web") || l.includes("search")) return "🌐";
  if (category === "tool") return "🧰";
  return "•";
};

export const UsageCard = ({
  title = "Usage & Cost",
  rows,
}: {
  title?: string;
  rows: UsageRow[];
}) => {
  const normalized = useMemo(() => {
    const safe = (rows ?? []).map((r) => ({
      ...r,
      label: r.label || formatToolName(r.key),
      cost: typeof r.costUsd === "number" && Number.isFinite(r.costUsd) ? r.costUsd : 0,
    }));
    const max = safe.reduce((acc, r) => Math.max(acc, r.cost), 0);
    return { safe, max };
  }, [rows]);

  return (
    <Card variant="outlined" sx={{ borderRadius: ThemeConfig.borderRadius, borderColor: "divider" }}>
      <CardContent sx={{ p: 2, "&:last-child": { pb: 2 } }}>
        <Typography variant="subtitle2" fontWeight={800}>
          {title}
        </Typography>

        <Stack spacing={1} sx={{ mt: 1.5 }}>
          {normalized.safe.length ? (
            normalized.safe.map((row) => {
              const isTop = normalized.max > 0 && row.cost === normalized.max;
              const pct = normalized.max > 0 ? Math.round((row.cost / normalized.max) * 100) : 0;

              return (
                <Box
                  key={row.key}
                  sx={{
                    borderRadius: ThemeConfig.borderRadius,
                    border: "1px solid",
                    borderColor: isTop ? "rgba(15,118,110,0.25)" : "divider",
                    bgcolor: isTop ? ThemeConfig.colors.brandSoft : "background.paper",
                    p: 1.5,
                  }}
                >
                  <Stack direction="row" alignItems="center" justifyContent="space-between" spacing={2}>
                    <Stack direction="row" spacing={1} alignItems="center" sx={{ minWidth: 0 }}>
                      <Typography component="span" sx={{ fontSize: 18 }} aria-hidden>
                        {iconFor(row.category, row.label)}
                      </Typography>
                      <Typography variant="body2" fontWeight={700} noWrap sx={{ minWidth: 0 }}>
                        {row.label}
                      </Typography>
                    </Stack>
                    <Typography variant="body2" fontWeight={800} sx={{ fontVariantNumeric: "tabular-nums" }}>
                      {formatUsdCost(row.costUsd)}
                    </Typography>
                  </Stack>

                  <Box
                    sx={{
                      mt: 1,
                      height: 6,
                      borderRadius: 999,
                      bgcolor: "rgba(15,23,42,0.06)",
                      overflow: "hidden",
                    }}
                  >
                    <Box
                      sx={{
                        height: "100%",
                        width: `${pct}%`,
                        borderRadius: 999,
                        bgcolor: ThemeConfig.colors.brandLight,
                        transition: "width 450ms ease",
                      }}
                    />
                  </Box>
                </Box>
              );
            })
          ) : (
            <Typography variant="body2" color="text.secondary">
              No usage recorded.
            </Typography>
          )}
        </Stack>
      </CardContent>
    </Card>
  );
};

export default UsageCard;
