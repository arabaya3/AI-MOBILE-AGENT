import DarkModeIcon from "@mui/icons-material/DarkMode";
import InstallMobileRoundedIcon from "@mui/icons-material/InstallMobileRounded";
import LightModeIcon from "@mui/icons-material/LightMode";
import LogoutRoundedIcon from "@mui/icons-material/LogoutRounded";
import MenuRoundedIcon from "@mui/icons-material/MenuRounded";
import MoreVertIcon from "@mui/icons-material/MoreVert";
import SecurityRoundedIcon from "@mui/icons-material/SecurityRounded";
import SettingsRoundedIcon from "@mui/icons-material/SettingsRounded";
import TuneRoundedIcon from "@mui/icons-material/TuneRounded";
import WifiOffRoundedIcon from "@mui/icons-material/WifiOffRounded";
import WorkspacePremiumRoundedIcon from "@mui/icons-material/WorkspacePremiumRounded";
import AdminPanelSettingsRoundedIcon from "@mui/icons-material/AdminPanelSettingsRounded";
import SwapHorizRoundedIcon from "@mui/icons-material/SwapHorizRounded";
import AutoAwesomeRoundedIcon from "@mui/icons-material/AutoAwesomeRounded";
import InsightsRoundedIcon from "@mui/icons-material/InsightsRounded";
import ReceiptLongRoundedIcon from "@mui/icons-material/ReceiptLongRounded";
import {
  AppBar,
  Avatar,
  Box,
  Button,
  Chip,
  Divider,
  IconButton,
  ListItemIcon,
  ListItemText,
  Menu,
  MenuItem,
  Snackbar,
  Stack,
  Toolbar,
  Tooltip,
  Typography,
  useMediaQuery,
  useTheme,
} from "@mui/material";
import { useState } from "react";

interface AppHeaderProps {
  email?: string;
  role?: string;
  spaceName?: string;
  onLogout: () => void;
  onChangePassword: () => void;
  onToggleTheme?: () => void;
  onInstallPwa?: () => void;
  canInstall?: boolean;
  isOffline?: boolean;
  onOpenAnalytics?: () => void;
  onOpenUsage?: () => void;
  onOpenSpaceAdmin?: () => void;
  onOpenSpaceOptions?: () => void;
  onOpenDangerZone?: () => void;
  onToggleSidebar?: () => void;
  onOpenSpaces?: (event: React.MouseEvent<HTMLElement>) => void;
  /** Opens the "Customize Assistant" user-profile dialog */
  onOpenUserProfile?: () => void;
  /** Inline model selector (desktop) */
  modelSelector?: React.ReactNode;
}

const initials = (value?: string) => (value ? value.charAt(0).toUpperCase() : "?");

export const AppHeader = ({
  email,
  role,
  spaceName,
  onLogout,
  onChangePassword,
  onToggleTheme,
  onInstallPwa,
  canInstall,
  isOffline,
  onOpenAnalytics,
  onOpenUsage,
  onOpenSpaceAdmin,
  onToggleSidebar,
  onOpenSpaces,
  onOpenUserProfile,
  modelSelector,
}: AppHeaderProps) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("md"));
  const [mobileMoreAnchorEl, setMobileMoreAnchorEl] = useState<null | HTMLElement>(null);
  const [spaceAdminAnchorEl, setSpaceAdminAnchorEl] = useState<null | HTMLElement>(null);
  const [userMenuAnchorEl, setUserMenuAnchorEl] = useState<null | HTMLElement>(null);
  const [modelFeedback, setModelFeedback] = useState(false);

  const isMobileMenuOpen = Boolean(mobileMoreAnchorEl);
  const isSpaceAdminOpen = Boolean(spaceAdminAnchorEl);
  const isUserMenuOpen = Boolean(userMenuAnchorEl);
  const isAdmin = role === "admin" || role === "super_admin";

  const closeMobileMenu = () => setMobileMoreAnchorEl(null);
  const closeSpaceAdmin = () => setSpaceAdminAnchorEl(null);
  const closeUserMenu = () => setUserMenuAnchorEl(null);

  const withClose = (action?: () => void, closeMenu?: () => void) => () => {
    action?.();
    closeMenu?.();
  };

  return (
    <AppBar position="sticky" elevation={0} color="transparent" sx={{ zIndex: theme.zIndex.appBar }}>
      <Toolbar
        sx={{
          display: "flex",
          justifyContent: "space-between",
          gap: 1,
          py: 0.5,
          minHeight: { xs: 56, md: 64 },
          px: { xs: 1, md: 2 },
        }}
      >
        {/* ─── LEFT: Logo + Space Selector ─── */}
        <Stack direction="row" spacing={1} alignItems="center" sx={{ minWidth: 0, flex: "0 1 auto" }}>
          {/* Mobile hamburger */}
          {onToggleSidebar && (
            <IconButton
              onClick={onToggleSidebar}
              edge="start"
              aria-label="Open menu"
              sx={{ display: { lg: "none" }, mr: -0.5 }}
            >
              <MenuRoundedIcon />
            </IconButton>
          )}

          {/* Logo — icon on mobile, full on desktop */}
          <Avatar
            sx={{
              bgcolor: "primary.main",
              color: "primary.contrastText",
              width: 32,
              height: 32,
              display: { xs: "none", sm: "flex" },
            }}
          >
            <WorkspacePremiumRoundedIcon sx={{ fontSize: 18 }} />
          </Avatar>
          <Typography
            variant="subtitle1"
            fontWeight={800}
            noWrap
            sx={{ display: { xs: "none", lg: "block" }, color: "primary.main", letterSpacing: "-0.02em" }}
          >
            TEIA
          </Typography>
          <Typography
            variant="h6"
            fontWeight={800}
            sx={{ display: { xs: "block", lg: "none" }, color: "primary.main", fontSize: "1rem" }}
          >
            TEIA
          </Typography>

          {/* Vertical divider */}
          <Divider orientation="vertical" flexItem sx={{ mx: 0.5, display: { xs: "none", sm: "block" } }} />

          {/* Space selector button — prominent */}
          {onOpenSpaces && (
            <Tooltip title="Switch space">
              <Button
                size="small"
                variant="text"
                color="inherit"
                endIcon={<SwapHorizRoundedIcon sx={{ fontSize: "16px !important" }} />}
                onClick={onOpenSpaces}
                aria-label="Switch space"
                sx={{
                  textTransform: "none",
                  fontWeight: 600,
                  maxWidth: { xs: 120, sm: 200 },
                  px: 1,
                  borderRadius: 2,
                  "&:hover": { bgcolor: "action.hover" },
                }}
              >
                <Typography variant="body2" noWrap fontWeight={600}>
                  {spaceName || "Select space"}
                </Typography>
              </Button>
            </Tooltip>
          )}
        </Stack>

        {/* ─── CENTER: Model Selector (desktop only) ─── */}
        {!isMobile && modelSelector && (
          <Box sx={{ flex: "0 0 auto", minWidth: 200, maxWidth: 280 }}>
            {modelSelector}
          </Box>
        )}

        {/* ─── RIGHT: Actions ─── */}
        <Stack direction="row" spacing={0.5} alignItems="center" sx={{ flex: "0 0 auto" }}>
          {/* Desktop actions */}
          <Stack direction="row" spacing={0.5} alignItems="center" sx={{ display: { xs: "none", md: "flex" } }}>
            {isOffline && (
              <Chip
                size="small"
                color="warning"
                icon={<WifiOffRoundedIcon sx={{ fontSize: 14 }} />}
                label="Offline"
                variant="outlined"
              />
            )}

            {/* Space Admin menu (admin only) */}
            {isAdmin && (
              <Tooltip title="Space Admin">
                <IconButton
                  onClick={(e) => setSpaceAdminAnchorEl(e.currentTarget)}
                  size="small"
                  aria-label="Space admin menu"
                  sx={{
                    border: "1px solid",
                    borderColor: "divider",
                    color: "primary.main",
                  }}
                >
                  <AdminPanelSettingsRoundedIcon fontSize="small" />
                </IconButton>
              </Tooltip>
            )}

            {/* Non-admin settings shortcut */}
            {!isAdmin && onOpenSpaceAdmin && (
              <Tooltip title="Space settings">
                <IconButton
                  onClick={onOpenSpaceAdmin}
                  size="small"
                  aria-label="Space settings"
                  sx={{ border: "1px solid", borderColor: "divider" }}
                >
                  <SettingsRoundedIcon fontSize="small" />
                </IconButton>
              </Tooltip>
            )}

            {canInstall && onInstallPwa && (
              <Tooltip title="Install app">
                <IconButton
                  onClick={onInstallPwa}
                  size="small"
                  aria-label="Install app"
                  sx={{ border: "1px solid", borderColor: "divider" }}
                >
                  <InstallMobileRoundedIcon fontSize="small" />
                </IconButton>
              </Tooltip>
            )}

            {onToggleTheme && (
              <Tooltip title={theme.palette.mode === "dark" ? "Light mode" : "Dark mode"}>
                <IconButton
                  onClick={onToggleTheme}
                  size="small"
                  aria-label={theme.palette.mode === "dark" ? "Switch to light mode" : "Switch to dark mode"}
                  sx={{ border: "1px solid", borderColor: "divider" }}
                >
                  {theme.palette.mode === "dark" ? <LightModeIcon fontSize="small" /> : <DarkModeIcon fontSize="small" />}
                </IconButton>
              </Tooltip>
            )}

            {/* User avatar + menu */}
            <Tooltip title={email || "Account"}>
              <IconButton
                onClick={(e) => setUserMenuAnchorEl(e.currentTarget)}
                size="small"
                aria-label="User menu"
              >
                <Avatar
                  sx={{
                    width: 32,
                    height: 32,
                    bgcolor: "primary.main",
                    color: "primary.contrastText",
                    fontSize: "0.875rem",
                    fontWeight: 700,
                  }}
                >
                  {initials(email)}
                </Avatar>
              </IconButton>
            </Tooltip>
          </Stack>

          {/* Mobile: more menu */}
          <Stack direction="row" spacing={0.5} alignItems="center" sx={{ display: { xs: "flex", md: "none" } }}>
            {/* Model icon for mobile — opens model selector in drawer */}
            <Tooltip title="AI Model">
              <IconButton
                onClick={onToggleSidebar}
                size="small"
                aria-label="Select AI model"
                sx={{ color: "primary.main" }}
              >
                <AutoAwesomeRoundedIcon fontSize="small" />
              </IconButton>
            </Tooltip>
            <IconButton
              size="small"
              aria-label="More options"
              aria-controls="primary-header-mobile-menu"
              aria-haspopup="true"
              onClick={(event) => setMobileMoreAnchorEl(event.currentTarget)}
              color="inherit"
            >
              <MoreVertIcon />
            </IconButton>
          </Stack>
        </Stack>
      </Toolbar>

      {/* ─── Space Admin dropdown menu (desktop) ─── */}
      <Menu
        anchorEl={spaceAdminAnchorEl}
        open={isSpaceAdminOpen}
        onClose={closeSpaceAdmin}
        anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
        transformOrigin={{ vertical: "top", horizontal: "right" }}
        slotProps={{ paper: { sx: { minWidth: 220 } } }}
      >
        {onOpenAnalytics && (
          <MenuItem onClick={withClose(onOpenAnalytics, closeSpaceAdmin)}>
            <ListItemIcon><InsightsRoundedIcon fontSize="small" /></ListItemIcon>
            <ListItemText primary="Analytics" primaryTypographyProps={{ variant: "body2", fontWeight: 500 }} />
          </MenuItem>
        )}
        <MenuItem onClick={withClose(onOpenUsage, closeSpaceAdmin)}>
          <ListItemIcon><ReceiptLongRoundedIcon fontSize="small" /></ListItemIcon>
          <ListItemText primary="Usage & Billing" primaryTypographyProps={{ variant: "body2", fontWeight: 500 }} />
        </MenuItem>
        {onOpenSpaceAdmin && (
          <MenuItem onClick={withClose(onOpenSpaceAdmin, closeSpaceAdmin)}>
            <ListItemIcon><SettingsRoundedIcon fontSize="small" /></ListItemIcon>
            <ListItemText primary="Space Settings" primaryTypographyProps={{ variant: "body2", fontWeight: 500 }} />
          </MenuItem>
        )}
        <Divider />
        {onOpenUserProfile && (
          <MenuItem onClick={withClose(onOpenUserProfile, closeSpaceAdmin)}>
            <ListItemIcon><TuneRoundedIcon fontSize="small" color="primary" /></ListItemIcon>
            <ListItemText primary="Customize Assistant" primaryTypographyProps={{ variant: "body2", fontWeight: 500 }} />
          </MenuItem>
        )}
      </Menu>

      {/* ─── User menu (desktop) ─── */}
      <Menu
        anchorEl={userMenuAnchorEl}
        open={isUserMenuOpen}
        onClose={closeUserMenu}
        anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
        transformOrigin={{ vertical: "top", horizontal: "right" }}
        slotProps={{ paper: { sx: { minWidth: 200 } } }}
      >
        <Box sx={{ px: 2, py: 1 }}>
          <Typography variant="body2" fontWeight={600} noWrap>{email}</Typography>
          <Chip
            size="small"
            color="primary"
            variant="outlined"
            label={(role || "viewer").replaceAll("_", " ").toUpperCase()}
            sx={{ mt: 0.5 }}
          />
        </Box>
        <Divider />
        {onOpenUserProfile && (
          <MenuItem onClick={withClose(onOpenUserProfile, closeUserMenu)}>
            <ListItemIcon><TuneRoundedIcon fontSize="small" color="primary" /></ListItemIcon>
            <ListItemText primary="Customize Assistant" />
          </MenuItem>
        )}
        <MenuItem onClick={withClose(onChangePassword, closeUserMenu)}>
          <ListItemIcon><SecurityRoundedIcon fontSize="small" /></ListItemIcon>
          <ListItemText primary="Change Password" />
        </MenuItem>
        <Divider />
        <MenuItem onClick={withClose(onLogout, closeUserMenu)}>
          <ListItemIcon><LogoutRoundedIcon fontSize="small" color="error" /></ListItemIcon>
          <ListItemText primary="Sign Out" sx={{ color: "error.main" }} />
        </MenuItem>
      </Menu>

      {/* ─── Mobile menu ─── */}
      <Menu
        anchorEl={mobileMoreAnchorEl}
        anchorOrigin={{ vertical: "top", horizontal: "right" }}
        id="primary-header-mobile-menu"
        keepMounted
        transformOrigin={{ vertical: "top", horizontal: "right" }}
        open={isMobileMenuOpen}
        onClose={closeMobileMenu}
      >
        {onOpenSpaces && (
          <MenuItem onClick={(event) => { onOpenSpaces(event); closeMobileMenu(); }}>
            <ListItemIcon><SwapHorizRoundedIcon fontSize="small" /></ListItemIcon>
            <ListItemText primary="Switch Space" />
          </MenuItem>
        )}
        {onOpenUserProfile && (
          <MenuItem onClick={withClose(onOpenUserProfile, closeMobileMenu)}>
            <ListItemIcon><TuneRoundedIcon fontSize="small" color="primary" /></ListItemIcon>
            <ListItemText primary="Customize Assistant" />
          </MenuItem>
        )}
        <Divider />
        {onOpenSpaceAdmin && (
          <MenuItem onClick={withClose(onOpenSpaceAdmin, closeMobileMenu)}>
            <ListItemIcon><SettingsRoundedIcon fontSize="small" /></ListItemIcon>
            <ListItemText primary="Space Settings" />
          </MenuItem>
        )}
        {onOpenUsage && (
          <MenuItem onClick={withClose(onOpenUsage, closeMobileMenu)}>
            <ListItemText primary="Usage & Billing" />
          </MenuItem>
        )}
        <Divider />
        {onToggleTheme && (
          <MenuItem onClick={withClose(onToggleTheme, closeMobileMenu)}>
            <ListItemIcon>
              {theme.palette.mode === "dark" ? <LightModeIcon fontSize="small" /> : <DarkModeIcon fontSize="small" />}
            </ListItemIcon>
            <ListItemText primary={theme.palette.mode === "dark" ? "Light Mode" : "Dark Mode"} />
          </MenuItem>
        )}
        <MenuItem onClick={withClose(onChangePassword, closeMobileMenu)}>
          <ListItemIcon><SecurityRoundedIcon fontSize="small" /></ListItemIcon>
          <ListItemText primary="Change Password" />
        </MenuItem>
        <MenuItem onClick={withClose(onLogout, closeMobileMenu)}>
          <ListItemIcon><LogoutRoundedIcon fontSize="small" color="error" /></ListItemIcon>
          <ListItemText primary="Sign Out" sx={{ color: "error.main" }} />
        </MenuItem>
      </Menu>

      {/* Model switch feedback toast */}
      <Snackbar
        open={modelFeedback}
        autoHideDuration={1500}
        onClose={() => setModelFeedback(false)}
        message="Model updated"
        anchorOrigin={{ vertical: "top", horizontal: "center" }}
      />
    </AppBar>
  );
};

export default AppHeader;
