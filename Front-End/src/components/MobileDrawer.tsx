import CloseRoundedIcon from "@mui/icons-material/CloseRounded";
import AutoFixHighRoundedIcon from "@mui/icons-material/AutoFixHighRounded";
import FolderOpenRoundedIcon from "@mui/icons-material/FolderOpenRounded";
import SettingsRoundedIcon from "@mui/icons-material/SettingsRounded";
import AdminPanelSettingsRoundedIcon from "@mui/icons-material/AdminPanelSettingsRounded";
import AssessmentRoundedIcon from "@mui/icons-material/AssessmentRounded";
import GetAppRoundedIcon from "@mui/icons-material/GetAppRounded";
import SummarizeRoundedIcon from "@mui/icons-material/SummarizeRounded";
import SearchRoundedIcon from "@mui/icons-material/SearchRounded";
import {
  Box,
  Button,
  Divider,
  IconButton,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Stack,
  SwipeableDrawer,
  Typography,
  useTheme,
} from "@mui/material";

import { ModelSelector } from "./ModelSelector";

export interface MobileDrawerProps {
  open: boolean;
  onClose: () => void;
  // Model Selection
  models: string[];
  selectedModel: string;
  onModelChange: (model: string) => void;
  modelsError?: string | null;
  modelDisabled?: boolean;
  // Actions
  onNewChat: () => void;
  onManageAccess?: () => void;
  onSpaceAdmin?: () => void;
  onSuperAdmin?: () => void;
  onDiagnostics?: () => void;
  onSummary?: () => void;
  onUsage?: () => void;
  onSpaceOptions?: () => void;
  onDangerZone?: () => void;
  onExport?: () => void;
  isSuperAdmin?: boolean;
  sourcesCount?: number;
  hasMessages?: boolean;
  hasActiveSession?: boolean;
  activeSpace?: any;
}

export const MobileDrawer = ({
  open,
  onClose,
  models,
  selectedModel,
  onModelChange,
  modelsError,
  modelDisabled,
  onNewChat,
  onManageAccess,
  onSpaceAdmin,
  onSuperAdmin,
  onDiagnostics,
  onSummary,
  onUsage,
  onExport,
  isSuperAdmin,
  sourcesCount = 0,
  hasMessages = false,
  hasActiveSession = false,
  activeSpace,
}: MobileDrawerProps) => {
  const theme = useTheme();

  const handleAction = (action: () => void) => {
    action();
    onClose();
  };

  return (
    <SwipeableDrawer
      anchor="left"
      open={open}
      onClose={onClose}
      onOpen={() => {}}
      sx={{
        display: { xs: "block", lg: "none" },
        "& .MuiDrawer-paper": {
          width: 300,
          maxWidth: "85vw",
        },
      }}
    >
      <Box sx={{ height: "100%", display: "flex", flexDirection: "column" }}>
        {/* Header */}
        <Stack
          direction="row"
          alignItems="center"
          justifyContent="space-between"
          sx={{
            p: 2,
            borderBottom: `1px solid ${theme.palette.divider}`,
          }}
        >
          <Typography variant="h6" fontWeight={700}>
            Menu
          </Typography>
          <IconButton onClick={onClose} edge="end">
            <CloseRoundedIcon />
          </IconButton>
        </Stack>

        {/* Content */}
        <Box sx={{ flex: 1, overflow: "auto", p: 2 }}>
          <Stack spacing={3}>
            {/* Model Selection */}
            <Box>
              <Typography variant="subtitle2" fontWeight={700} gutterBottom sx={{ px: 0.5 }}>
                AI Model
              </Typography>
              <ModelSelector
                models={models}
                value={selectedModel}
                onChange={onModelChange}
                errorText={modelsError}
                disabled={modelDisabled}
              />
            </Box>

            <Divider />

            {/* Primary Actions */}
            <Stack spacing={1}>
              <Typography variant="subtitle2" fontWeight={700} gutterBottom sx={{ px: 0.5 }}>
                Actions
              </Typography>
              <Button
                variant="contained"
                startIcon={<AutoFixHighRoundedIcon />}
                onClick={() => handleAction(onNewChat)}
                fullWidth
                disableElevation
                sx={{ justifyContent: "flex-start", height: 44 }}
              >
                New Chat
              </Button>
            </Stack>

            <Divider />

            {/* Secondary Actions */}
            <Box>
              <Typography variant="subtitle2" fontWeight={700} gutterBottom sx={{ px: 0.5 }}>
                Tools
              </Typography>
              <List disablePadding>
                {onManageAccess && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onManageAccess)} disabled={!activeSpace}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <FolderOpenRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="Manage Permissions" />
                    </ListItemButton>
                  </ListItem>
                )}

                {onSpaceAdmin && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onSpaceAdmin)} disabled={!activeSpace}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <SettingsRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="Space Settings" />
                    </ListItemButton>
                  </ListItem>
                )}

                {isSuperAdmin && onSuperAdmin && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onSuperAdmin)}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <AdminPanelSettingsRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="Super Admin" />
                    </ListItemButton>
                  </ListItem>
                )}

                {onDiagnostics && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onDiagnostics)} disabled={sourcesCount === 0}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <SearchRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary={`Sources (${sourcesCount})`} />
                    </ListItemButton>
                  </ListItem>
                )}

                {onSummary && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onSummary)} disabled={!hasMessages || !hasActiveSession}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <SummarizeRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="Summary" />
                    </ListItemButton>
                  </ListItem>
                )}

                {onUsage && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onUsage)}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <AssessmentRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="Usage & Billing" />
                    </ListItemButton>
                  </ListItem>
                )}

                {onExport && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onExport)} disabled={!hasMessages || !hasActiveSession}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <GetAppRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="Export" />
                    </ListItemButton>
                  </ListItem>
                )}
              </List>
            </Box>
          </Stack>
        </Box>
      </Box>
    </SwipeableDrawer>
  );
};

export default MobileDrawer;
