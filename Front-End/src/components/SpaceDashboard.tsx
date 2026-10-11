import ExpandMoreRoundedIcon from "@mui/icons-material/ExpandMoreRounded";
import {
  Box,
  Button,
  Card,
  CardActionArea,
  CardContent,
  Divider,
  List,
  ListItemButton,
  ListItemText,
  Menu,
  MenuItem,
  Stack,
  Typography,
} from "@mui/material";
import { useMemo, useState, type MouseEvent } from "react";

import type { SpaceSummary } from "../api/spaces";
import { ThemeConfig } from "../styles/ThemeConfig";

export interface SpaceDashboardProps {
  spaces: SpaceSummary[];
  activeSpaceId: string | null;
  onSelect: (spaceId: string) => void;
  /**
   * Optional: when provided and the list is truncated, clicking "View all" calls this.
   */
  onViewAll?: () => void;
  /**
   * Optional list to render (e.g., a filtered subset). Defaults to `spaces`.
   */
  list?: SpaceSummary[];
  /**
   * Max rows to show in list mode before showing a "View all" affordance.
   */
  listLimit?: number;
}

export const SpaceDashboard = ({
  spaces,
  activeSpaceId,
  onSelect,
  onViewAll,
  list,
  listLimit = 6,
}: SpaceDashboardProps) => {
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const menuOpen = Boolean(anchorEl);

  const listToRender = list ?? spaces;
  const activeSpace = useMemo(() => spaces.find((s) => s.id === activeSpaceId) ?? null, [spaces, activeSpaceId]);

  const spaceCountLabel = `${spaces.length.toLocaleString()} ${spaces.length === 1 ? "Space" : "Spaces"}`;

  const openMenu = (event: MouseEvent<HTMLElement>) => setAnchorEl(event.currentTarget);
  const closeMenu = () => setAnchorEl(null);

  const isCardMode = spaces.length > 0 && spaces.length < 3;

  const truncated = !isCardMode && listToRender.length > listLimit;
  const visibleList = truncated ? listToRender.slice(0, listLimit) : listToRender;

  return (
    <Card
      variant="outlined"
      sx={{
        borderRadius: ThemeConfig.borderRadius,
        overflow: "hidden",
        bgcolor: "background.paper",
        display: "flex",
        flexDirection: "column",
        minHeight: 0,
      }}
    >
      <CardContent sx={{ pb: 1.25 }}>
        <Stack direction="row" alignItems="center" justifyContent="space-between" spacing={1.5}>
          <Stack spacing={0.25} sx={{ minWidth: 0 }}>
            <Typography variant="subtitle2" fontWeight={800} noWrap>
              {spaceCountLabel}
            </Typography>
            <Typography variant="caption" color="text.secondary" noWrap>
              {activeSpace ? `Current: ${activeSpace.name}` : "No active space"}
            </Typography>
          </Stack>

          <Button
            variant="outlined"
            size="small"
            onClick={openMenu}
            endIcon={<ExpandMoreRoundedIcon />}
            sx={{ textTransform: "none", fontWeight: 700, height: 34 }}
          >
            Switch
          </Button>

          <Menu anchorEl={anchorEl} open={menuOpen} onClose={closeMenu}>
            {spaces.map((space) => (
              <MenuItem
                key={space.id}
                selected={space.id === activeSpaceId}
                onClick={() => {
                  onSelect(space.id);
                  closeMenu();
                }}
              >
                {space.name}
              </MenuItem>
            ))}
          </Menu>
        </Stack>
      </CardContent>

      <Divider />

      {isCardMode ? (
        <Box sx={{ position: "relative" }}>
          <Box
            sx={{
              display: "flex",
              gap: 1,
              p: 1.5,
              overflowX: "auto",
              overflowY: "hidden",
              WebkitOverflowScrolling: "touch",
              scrollSnapType: "x mandatory",
            }}
          >
            {spaces.map((space) => (
              <Card
                key={space.id}
                variant={space.id === activeSpaceId ? "elevation" : "outlined"}
                sx={{
                  minWidth: 220,
                  flex: "0 0 auto",
                  borderRadius: ThemeConfig.borderRadius,
                  scrollSnapAlign: "start",
                }}
              >
                <CardActionArea onClick={() => onSelect(space.id)}>
                  <CardContent>
                    <Typography fontWeight={800} noWrap>
                      {space.name}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      Created {new Date(space.created_at).toLocaleDateString()}
                    </Typography>
                  </CardContent>
                </CardActionArea>
              </Card>
            ))}
          </Box>

          {/* Right gradient "peek" to hint horizontal scroll */}
          <Box
            sx={{
              pointerEvents: "none",
              position: "absolute",
              top: 0,
              right: 0,
              height: "100%",
              width: 44,
              background: (theme) =>
                `linear-gradient(90deg, rgba(0,0,0,0) 0%, ${theme.palette.background.paper} 85%)`,
            }}
          />
        </Box>
      ) : (
        <Box sx={{ p: 1, overflowY: "auto", minHeight: 0 }}>
          <List dense disablePadding>
            {visibleList.map((space) => (
              <ListItemButton
                key={space.id}
                selected={space.id === activeSpaceId}
                onClick={() => onSelect(space.id)}
                sx={{ borderRadius: ThemeConfig.borderRadius, px: 1.5, py: 1 }}
              >
                <ListItemText
                  primary={space.name}
                  secondary={`Created ${new Date(space.created_at).toLocaleDateString()}`}
                  primaryTypographyProps={{ fontWeight: 700, noWrap: true }}
                  secondaryTypographyProps={{ variant: "caption", noWrap: true }}
                />
              </ListItemButton>
            ))}

            {truncated ? (
              <Box sx={{ px: 1.5, pt: 1, pb: 0.5 }}>
                <Button
                  size="small"
                  variant="text"
                  onClick={onViewAll}
                  disabled={!onViewAll}
                  sx={{ textTransform: "none", fontWeight: 700 }}
                >
                  View all
                </Button>
              </Box>
            ) : null}
          </List>
        </Box>
      )}
    </Card>
  );
};

export default SpaceDashboard;
