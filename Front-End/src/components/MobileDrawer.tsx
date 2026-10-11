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

import type { ModelPricingEntry } from "../api/chat";
import { ModelSelector } from "./ModelSelector";

export interface MobileDrawerProps {
  open: boolean;
  onClose: () => void;
  // Model Selection
  models: string[];
  selectedModel: string;
  onModelChange: (model: string) => void;
  modelPricing?: ModelPricingEntry | null;
  modelTier?: "low" | "medium" | "high" | null;
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
  modelPricing,
  modelTier,
  modelsError,
  modelDisabled,
  onNewChat,
  onManageAccess,
  onSpaceAdmin,
  onSuperAdmin,
  onDiagnostics,
  onSummary,
  onUsage,
  onSpaceOptions,
  onDangerZone,
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
        display: { xs: "block", md: "none" },
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
                نموذج الذكاء الاصطناعي
              </Typography>
              <ModelSelector
                models={models}
                value={selectedModel}
                onChange={onModelChange}
                pricing={modelPricing}
                tier={modelTier}
                errorText={modelsError}
                disabled={modelDisabled}
              />
            </Box>

            <Divider />

            {/* Primary Actions */}
            <Stack spacing={1}>
              <Typography variant="subtitle2" fontWeight={700} gutterBottom sx={{ px: 0.5 }}>
                إجراءات
              </Typography>
              <Button
                variant="contained"
                startIcon={<AutoFixHighRoundedIcon />}
                onClick={() => handleAction(onNewChat)}
                fullWidth
                disableElevation
                sx={{ justifyContent: "flex-start", height: 44 }}
              >
                استشارة جديدة
              </Button>
            </Stack>

            <Divider />

            {/* Secondary Actions */}
            <Box>
              <Typography variant="subtitle2" fontWeight={700} gutterBottom sx={{ px: 0.5 }}>
                أدوات
              </Typography>
              <List disablePadding>
                {onManageAccess && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onManageAccess)} disabled={!activeSpace}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <FolderOpenRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="إدارة الصلاحيات" />
                    </ListItemButton>
                  </ListItem>
                )}

                {onSpaceAdmin && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onSpaceAdmin)} disabled={!activeSpace}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <SettingsRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="إدارة الجلسة" />
                    </ListItemButton>
                  </ListItem>
                )}
                {onSpaceOptions && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onSpaceOptions)} disabled={!activeSpace}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <SettingsRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="الإعدادات" />
                    </ListItemButton>
                  </ListItem>
                )}
                {onDangerZone && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onDangerZone)} disabled={!activeSpace}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <SettingsRoundedIcon fontSize="small" color="error" />
                      </ListItemIcon>
                      <ListItemText primary="منطقة الخطر" />
                    </ListItemButton>
                  </ListItem>
                )}

                {isSuperAdmin && onSuperAdmin && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onSuperAdmin)}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <AdminPanelSettingsRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="الإدارة العليا" />
                    </ListItemButton>
                  </ListItem>
                )}

                {onDiagnostics && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onDiagnostics)} disabled={sourcesCount === 0}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <SearchRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary={`المصادر (${sourcesCount})`} />
                    </ListItemButton>
                  </ListItem>
                )}

                {onSummary && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onSummary)} disabled={!hasMessages || !hasActiveSession}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <SummarizeRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="ملخص الجلسة" />
                    </ListItemButton>
                  </ListItem>
                )}

                {onUsage && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onUsage)}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <AssessmentRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="الاستخدام والتكلفة" />
                    </ListItemButton>
                  </ListItem>
                )}

                {onExport && (
                  <ListItem disablePadding>
                    <ListItemButton onClick={() => handleAction(onExport)} disabled={!hasMessages || !hasActiveSession}>
                      <ListItemIcon sx={{ minWidth: 40 }}>
                        <GetAppRoundedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText primary="تصدير" />
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
