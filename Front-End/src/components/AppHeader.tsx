import DarkModeIcon from "@mui/icons-material/DarkMode";
import InstallMobileRoundedIcon from "@mui/icons-material/InstallMobileRounded";
import KeyboardArrowDownIcon from "@mui/icons-material/KeyboardArrowDown";
import LightModeIcon from "@mui/icons-material/LightMode";
import LogoutRoundedIcon from "@mui/icons-material/LogoutRounded";
import MenuRoundedIcon from "@mui/icons-material/MenuRounded";
import MoreVertIcon from "@mui/icons-material/MoreVert";
import SecurityRoundedIcon from "@mui/icons-material/SecurityRounded";
import SettingsRoundedIcon from "@mui/icons-material/SettingsRounded";
import WifiOffRoundedIcon from "@mui/icons-material/WifiOffRounded";
import GavelRoundedIcon from "@mui/icons-material/GavelRounded";
import {
  AppBar,
  Avatar,
  Button,
  Chip,
  IconButton,
  ListItemIcon,
  ListItemText,
  Menu,
  MenuItem,
  Stack,
  Toolbar,
  Tooltip,
  Typography,
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
  onOpenLaws?: () => void;
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
  onOpenSpaceOptions,
  onOpenDangerZone,
  onToggleSidebar,
  onOpenSpaces,
  onOpenLaws,
}: AppHeaderProps) => {
  const theme = useTheme();
  const [mobileMoreAnchorEl, setMobileMoreAnchorEl] = useState<null | HTMLElement>(null);
  const [settingsAnchorEl, setSettingsAnchorEl] = useState<null | HTMLElement>(null);

  const isMobileMenuOpen = Boolean(mobileMoreAnchorEl);
  const isSettingsOpen = Boolean(settingsAnchorEl);

  const closeMobileMenu = () => setMobileMoreAnchorEl(null);
  const closeSettings = () => setSettingsAnchorEl(null);

  const withClose = (action?: () => void, closeMenu?: () => void) => () => {
    action?.();
    closeMenu?.();
  };

  return (
    <AppBar position="sticky" elevation={0} color="transparent">
      <Toolbar sx={{ display: "flex", justifyContent: "space-between", gap: 2, py: 1 }}>
        <Stack direction="row" spacing={1.5} alignItems="center" sx={{ minWidth: 0 }}>
          {onToggleSidebar ? (
            <IconButton onClick={onToggleSidebar} edge="start" sx={{ display: { lg: "none" }, mr: -0.5 }}>
              <MenuRoundedIcon />
            </IconButton>
          ) : null}
          <Avatar sx={{ bgcolor: "primary.main", color: "primary.contrastText", width: 36, height: 36 }}>
            <GavelRoundedIcon fontSize="small" />
          </Avatar>
          <Stack spacing={0.25} sx={{ minWidth: 0, display: { xs: "none", sm: "flex" } }}>
            <Stack direction="row" spacing={1} alignItems="center">
              <Typography variant="subtitle1" fontWeight={700} noWrap>
                LawTech | المنصة القانونية
              </Typography>
              <Chip label="للمحامين" size="small" color="primary" variant="filled" sx={{ height: 18, fontSize: "0.6rem", fontWeight: 700, borderRadius: 0.75 }} />
            </Stack>
            <Typography variant="caption" color="text.secondary" noWrap>
              {spaceName ? `المجال: ${spaceName}` : "مساعدك القانوني للقانون الفلسطيني"}
            </Typography>
          </Stack>
          <Typography variant="h6" fontWeight={800} sx={{ display: { xs: "block", sm: "none" }, color: "primary.main" }}>
            LawTech
          </Typography>
        </Stack>

        <Stack direction="row" spacing={1} alignItems="center" sx={{ display: { xs: "none", md: "flex" }, minWidth: 0 }}>
          <Button
            size="small"
            variant="outlined"
            color="inherit"
            startIcon={<SettingsRoundedIcon fontSize="small" />}
            endIcon={<KeyboardArrowDownIcon />}
            onClick={(event) => setSettingsAnchorEl(event.currentTarget)}
            sx={{ px: 1.75 }}
          >
            الجلسة
          </Button>

          <Chip
            size="small"
            color="primary"
            variant="outlined"
            label={(role || "viewer").replaceAll("_", " ").toUpperCase()}
          />

          {isOffline ? (
            <Chip
              size="small"
              color="warning"
              icon={<WifiOffRoundedIcon fontSize="small" />}
              label="Offline"
              variant="outlined"
            />
          ) : null}

          <Stack direction="row" spacing={1} alignItems="center" sx={{ minWidth: 0 }}>
            <Avatar sx={{ bgcolor: "background.paper", color: "primary.main", width: 32, height: 32, border: "1px solid", borderColor: "divider" }}>
              {initials(email)}
            </Avatar>
            <Typography variant="body2" noWrap sx={{ maxWidth: 200 }}>
              {email}
            </Typography>
          </Stack>

          {canInstall && onInstallPwa ? (
            <Tooltip title="Install app">
              <IconButton onClick={onInstallPwa} size="small" sx={{ border: "1px solid", borderColor: "divider" }}>
                <InstallMobileRoundedIcon fontSize="small" />
              </IconButton>
            </Tooltip>
          ) : null}

          {onToggleTheme ? (
            <Tooltip title={theme.palette.mode === "dark" ? "Light mode" : "Dark mode"}>
              <IconButton onClick={onToggleTheme} size="small" sx={{ border: "1px solid", borderColor: "divider" }}>
                {theme.palette.mode === "dark" ? <LightModeIcon fontSize="small" /> : <DarkModeIcon fontSize="small" />}
              </IconButton>
            </Tooltip>
          ) : null}

          <Tooltip title="Change password">
            <IconButton onClick={onChangePassword} size="small" sx={{ border: "1px solid", borderColor: "divider" }}>
              <SecurityRoundedIcon fontSize="small" />
            </IconButton>
          </Tooltip>

          <Tooltip title="Logout">
            <IconButton onClick={onLogout} size="small" color="error" sx={{ border: "1px solid", borderColor: "error.main" }}>
              <LogoutRoundedIcon fontSize="small" />
            </IconButton>
          </Tooltip>
        </Stack>

        <Stack direction="row" spacing={0.5} alignItems="center" sx={{ display: { xs: "flex", md: "none" } }}>
          <IconButton
            size="large"
            aria-label="show more"
            aria-controls="primary-header-mobile-menu"
            aria-haspopup="true"
            onClick={(event) => setMobileMoreAnchorEl(event.currentTarget)}
            color="inherit"
          >
            <MoreVertIcon />
          </IconButton>
        </Stack>
      </Toolbar>

      <Menu
        anchorEl={settingsAnchorEl}
        open={isSettingsOpen}
        onClose={closeSettings}
        anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
        transformOrigin={{ vertical: "top", horizontal: "right" }}
      >
        {onOpenSpaces ? (
          <MenuItem onClick={(event) => { onOpenSpaces(event); closeSettings(); }}>
            <ListItemText primary="جلسات القضايا" />
          </MenuItem>
        ) : null}
        {onOpenLaws ? (
          <MenuItem onClick={withClose(onOpenLaws, closeSettings)}>
            <ListItemIcon><GavelRoundedIcon fontSize="small" /></ListItemIcon>
            <ListItemText primary="مكتبة القوانين الفلسطينية" />
          </MenuItem>
        ) : null}
        {(role === "super_admin" || role === "admin") && onOpenAnalytics ? (
          <MenuItem onClick={withClose(onOpenAnalytics, closeSettings)}>
            <ListItemText primary="التحليلات" />
          </MenuItem>
        ) : null}
        <MenuItem onClick={withClose(onOpenUsage, closeSettings)}>
          <ListItemText primary="الاستخدام والتكلفة" />
        </MenuItem>
        <MenuItem onClick={withClose(onOpenSpaceAdmin, closeSettings)}>
          <ListItemText primary="إدارة الجلسة" />
        </MenuItem>
        <MenuItem onClick={withClose(onOpenSpaceOptions, closeSettings)}>
          <ListItemText primary="الإعدادات" />
        </MenuItem>
        <MenuItem onClick={withClose(onOpenDangerZone, closeSettings)}>
          <ListItemText primary="منطقة الخطر" sx={{ color: "error.main" }} />
        </MenuItem>
      </Menu>

      <Menu
        anchorEl={mobileMoreAnchorEl}
        anchorOrigin={{ vertical: "top", horizontal: "right" }}
        id="primary-header-mobile-menu"
        keepMounted
        transformOrigin={{ vertical: "top", horizontal: "right" }}
        open={isMobileMenuOpen}
        onClose={closeMobileMenu}
      >
        {onOpenSpaces ? (
          <MenuItem onClick={(event) => { onOpenSpaces(event); closeMobileMenu(); }}>
            <ListItemText primary="جلسات القضايا" />
          </MenuItem>
        ) : null}
        {onOpenLaws ? (
          <MenuItem onClick={withClose(onOpenLaws, closeMobileMenu)}>
            <ListItemIcon><GavelRoundedIcon fontSize="small" /></ListItemIcon>
            <ListItemText primary="مكتبة القوانين الفلسطينية" />
          </MenuItem>
        ) : null}
        {onToggleTheme ? (
          <MenuItem onClick={withClose(onToggleTheme, closeMobileMenu)}>
            <ListItemIcon>
              {theme.palette.mode === "dark" ? <LightModeIcon fontSize="small" /> : <DarkModeIcon fontSize="small" />}
            </ListItemIcon>
            <ListItemText primary={theme.palette.mode === "dark" ? "وضع نهاري" : "وضع ليلي"} />
          </MenuItem>
        ) : null}
        <MenuItem onClick={withClose(onChangePassword, closeMobileMenu)}>
          <ListItemIcon>
            <SecurityRoundedIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText primary="تغيير كلمة المرور" />
        </MenuItem>
        <MenuItem onClick={withClose(onLogout, closeMobileMenu)}>
          <ListItemIcon>
            <LogoutRoundedIcon fontSize="small" color="error" />
          </ListItemIcon>
          <ListItemText primary="تسجيل الخروج" sx={{ color: "error.main" }} />
        </MenuItem>
      </Menu>
    </AppBar>
  );
};

export default AppHeader;
