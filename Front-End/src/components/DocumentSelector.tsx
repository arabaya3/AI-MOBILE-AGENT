import DescriptionRoundedIcon from "@mui/icons-material/DescriptionRounded";
import AdminPanelSettingsRoundedIcon from "@mui/icons-material/AdminPanelSettingsRounded";
import UploadFileRoundedIcon from "@mui/icons-material/UploadFileRounded";
import MoreHorizRoundedIcon from "@mui/icons-material/MoreHorizRounded";
import {
  Box,
  Button,
  Checkbox,
  IconButton,
  List,
  ListItem,
  ListItemAvatar,
  ListItemText,
  Menu,
  MenuItem,
  Stack,
  Typography,
} from "@mui/material";
import { useState, type MouseEvent } from "react";

import type { AccessibleDocument } from "../api/documents";
import { ThemeConfig } from "../styles/ThemeConfig";

interface DocumentSelectorProps {
  documents: AccessibleDocument[];
  selected: string[];
  onToggle: (id: string) => void;
  onUploadClick: () => void;
  canUpload?: boolean;
  canManagePermissions?: boolean;
  onManagePermissions?: () => void;
}

export const DocumentSelector = ({
  documents,
  selected,
  onToggle,
  onUploadClick,
  canUpload = true,
  canManagePermissions = false,
  onManagePermissions,
}: DocumentSelectorProps) => {
  const [actionsAnchor, setActionsAnchor] = useState<HTMLElement | null>(null);
  const actionsOpen = Boolean(actionsAnchor);

  const openActions = (event: MouseEvent<HTMLElement>) => setActionsAnchor(event.currentTarget);
  const closeActions = () => setActionsAnchor(null);
  const runAction = (action?: () => void) => () => {
    action?.();
    closeActions();
  };

  return (
    <Box sx={{ display: "flex", flexDirection: "column", minHeight: 0, height: "100%" }}>
      <Stack direction="row" justifyContent="space-between" alignItems="center" mb={2}>
        <Stack direction="row" spacing={1} alignItems="flex-start" sx={{ minWidth: 0 }}>
          <IconButton
            size="small"
            onClick={openActions}
            title="Documents actions"
            aria-label="Documents actions"
            sx={{ border: "1px solid", borderColor: "divider", mt: 0.25 }}
          >
            <MoreHorizRoundedIcon />
          </IconButton>
          <Stack spacing={0.5} sx={{ minWidth: 0 }}>
            <Typography variant="subtitle1" fontWeight={700}>
              Documents Accessible Files
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ display: { xs: "none", sm: "block" } }}>
              Choose which documents to ground the chat on
            </Typography>
          </Stack>
        </Stack>
        <Stack direction="row" spacing={1} alignItems="center">
          <Button
            variant="contained"
            startIcon={<UploadFileRoundedIcon />}
            onClick={onUploadClick}
            disabled={!canUpload}
            title={canUpload ? "Upload and index new documents" : "Only admins can upload here"}
            size="small"
            disableElevation
            sx={{
              height: 36,
              px: 2,
              fontWeight: 600,
              letterSpacing: 0.2,
            }}
          >
            <Box component="span" sx={{ display: { xs: "none", sm: "inline" } }}>
              {canUpload ? "Upload" : "Admin only"}
            </Box>
            <Box component="span" sx={{ display: { xs: "inline", sm: "none" } }}>
              Upload
            </Box>
          </Button>
        </Stack>
      </Stack>
      <Menu
        anchorEl={actionsAnchor}
        open={actionsOpen}
        onClose={closeActions}
        anchorOrigin={{ vertical: "bottom", horizontal: "left" }}
        transformOrigin={{ vertical: "top", horizontal: "left" }}
      >
        {canManagePermissions && onManagePermissions ? (
          <MenuItem onClick={runAction(onManagePermissions)}>
            <Stack direction="row" spacing={1} alignItems="center">
              <AdminPanelSettingsRoundedIcon fontSize="small" />
              <Typography variant="body2">إدارة الصلاحيات</Typography>
            </Stack>
          </MenuItem>
        ) : null}
        {canUpload ? (
          <MenuItem onClick={runAction(onUploadClick)}>
            <Stack direction="row" spacing={1} alignItems="center">
              <UploadFileRoundedIcon fontSize="small" />
              <Typography variant="body2">رفع مستند</Typography>
            </Stack>
          </MenuItem>
        ) : null}
      </Menu>
      <Box
        sx={(theme) => ({
          flex: 1,
          minHeight: 0,
          overflowY: "auto",
          pr: 0.5,
          scrollbarGutter: "stable",
          scrollbarWidth: "thin",
          "&::-webkit-scrollbar": {
            width: 10,
          },
          "&::-webkit-scrollbar-thumb": {
            backgroundColor: theme.palette.action.hover,
            borderRadius: 999,
            border: "2px solid transparent",
            backgroundClip: "content-box",
          },
          "&::-webkit-scrollbar-thumb:hover": {
            backgroundColor: theme.palette.action.selected,
          },
        })}
      >
        <List dense disablePadding>
          {documents.map((doc) => (
            <ListItem
              key={doc.id}
              sx={{
                borderRadius: ThemeConfig.borderRadius,
                mb: 1,
                bgcolor: "background.paper",
                border: "1px solid",
                borderColor: "divider",
              }}
              secondaryAction={
                <Checkbox edge="end" checked={selected.includes(doc.id)} onChange={() => onToggle(doc.id)} />
              }
            >
              <ListItemAvatar>
                <DescriptionRoundedIcon color="primary" />
              </ListItemAvatar>
              <ListItemText
                primary={doc.filename}
                primaryTypographyProps={{ noWrap: true, title: doc.filename }}
                secondary={`${doc.file_type.toUpperCase()} • ${doc.uploaded_at ? new Date(doc.uploaded_at).toLocaleDateString() : "pending"}${doc.is_hidden ? " • hidden" : ""}`}
                secondaryTypographyProps={{ noWrap: true }}
              />
            </ListItem>
          ))}
          {!documents.length && (
            <Stack spacing={1.5} alignItems="center" justifyContent="center" sx={{ py: 4 }}>
              <DescriptionRoundedIcon color="disabled" fontSize="large" />
              <Typography variant="body2" color="text.secondary" textAlign="center">
                No documents shared with you yet.
              </Typography>
              {canUpload ? (
                <Button
                  variant="outlined"
                  size="small"
                  onClick={onUploadClick}
                  startIcon={<UploadFileRoundedIcon />}
                  sx={{ height: 34, px: 1.75, fontWeight: 600 }}
                >
                  Upload your first file
                </Button>
              ) : null}
            </Stack>
          )}
        </List>
      </Box>
    </Box>
  );
};

export default DocumentSelector;
