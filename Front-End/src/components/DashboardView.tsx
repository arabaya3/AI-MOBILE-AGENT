import {
  Box,
  Card,
  CardActionArea,
  CardContent,
  Chip,
  LinearProgress,
  Stack,
  Typography,
} from "@mui/material";
import type { SpaceSummary } from "../api/spaces";
import { ThemeConfig } from "../styles/ThemeConfig";

export interface DashboardViewProps {
  spaces: SpaceSummary[];
  activeSpaceId: string | null;
  onSelect: (spaceId: string) => void;
  /** Max spaces allowed for the current plan (UI-only; server enforcement may differ). */
  spacesLimit?: number;
  /** Optional list to render (e.g. filtered). Defaults to `spaces`. */
  list?: SpaceSummary[];
}

const clampPercent = (value: number) => Math.min(100, Math.max(0, Math.round(value)));

export const DashboardView = ({
  spaces,
  activeSpaceId,
  onSelect,
  spacesLimit = 5,
  list,
}: DashboardViewProps) => {
  const listToRender = list ?? spaces;
  const used = spaces.length;
  const limit = Math.max(1, Number(spacesLimit) || 1);
  const percent = clampPercent((used / limit) * 100);

  return (
    <Stack spacing={1.5}>
      {/* Plan Overview Card */}
      <Card
        variant="outlined"
        sx={{
          borderRadius: ThemeConfig.borderRadius,
          bgcolor: "background.paper",
          boxShadow: "0 1px 2px rgba(15,23,42,0.06)",
          borderColor: "divider",
        }}
      >
        <CardContent sx={{ p: 2, "&:last-child": { pb: 2 } }}>
          <Stack direction="row" alignItems="center" justifyContent="space-between" spacing={2}>
            <Box sx={{ minWidth: 0 }}>
              <Typography variant="body2" fontWeight={600} noWrap>
                Plan Usage
              </Typography>
              <Typography variant="caption" color="text.secondary" noWrap>
                {used.toLocaleString()} of {limit.toLocaleString()} Spaces
              </Typography>
            </Box>
            <Typography variant="caption" fontWeight={700} sx={{ color: ThemeConfig.colors.textMuted }}>
              {percent}%
            </Typography>
          </Stack>

          <Box sx={{ mt: 1 }}>
            <LinearProgress
              variant="determinate"
              value={percent}
              sx={{
                height: 4, // 4px thin bar
                borderRadius: 2,
                bgcolor: ThemeConfig.colors.progressTrack,
                "& .MuiLinearProgress-bar": {
                  borderRadius: 2,
                  backgroundColor: ThemeConfig.colors.brand,
                  transition: "transform 450ms ease, width 450ms ease",
                },
              }}
            />
          </Box>
        </CardContent>
      </Card>

      {/* Spaces list */}
      <Stack
        spacing={1}
        sx={{
          maxHeight: { xs: 220, md: 300 },
          overflowY: "auto",
          pr: 0.5,
        }}
      >
        {listToRender.map((space) => {
          const isActive = space.id === activeSpaceId;
          return (
            <Card
              key={space.id}
              variant="outlined"
              sx={{
                borderRadius: ThemeConfig.borderRadius,
                borderWidth: isActive ? 2 : 1,
                borderColor: isActive ? ThemeConfig.colors.brand : "divider",
                bgcolor: "background.paper",
                boxShadow: isActive ? "0 2px 10px rgba(79,70,229,0.12)" : "none",
                transition: "box-shadow 180ms ease, border-color 180ms ease",
                "&:hover": {
                  boxShadow: isActive ? "0 2px 12px rgba(79,70,229,0.16)" : "0 2px 10px rgba(15,23,42,0.06)",
                  borderColor: isActive ? ThemeConfig.colors.brand : "rgba(79,70,229,0.30)",
                },
              }}
            >
              <CardActionArea onClick={() => onSelect(space.id)} sx={{ borderRadius: ThemeConfig.borderRadius }}>
                <CardContent sx={{ p: 1.75, "&:last-child": { pb: 1.75 } }}>
                  <Stack direction="row" alignItems="center" justifyContent="space-between" spacing={1.5}>
                    <Box sx={{ minWidth: 0 }}>
                      <Typography fontWeight={800} noWrap sx={{ maxWidth: 180 }}>
                        {space.name}
                      </Typography>
                      <Typography variant="caption" color="text.secondary" noWrap>
                        Created {new Date(space.created_at).toLocaleDateString()}
                      </Typography>
                    </Box>

                    {isActive ? (
                      <Chip
                        size="small"
                        label="Active"
                        sx={{
                          fontWeight: 800,
                          bgcolor: ThemeConfig.colors.brand,
                          color: "#fff",
                        }}
                      />
                    ) : null}
                  </Stack>
                </CardContent>
              </CardActionArea>
            </Card>
          );
        })}

        {!listToRender.length ? (
          <Card variant="outlined" sx={{ borderRadius: ThemeConfig.borderRadius, borderColor: "divider" }}>
            <CardContent sx={{ p: 2, "&:last-child": { pb: 2 } }}>
              <Typography variant="body2" color="text.secondary">
                No spaces yet.
              </Typography>
            </CardContent>
          </Card>
        ) : null}
      </Stack>
    </Stack>
  );
};

export default DashboardView;
