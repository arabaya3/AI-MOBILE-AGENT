import FolderOpenRoundedIcon from "@mui/icons-material/FolderOpenRounded";
import AdminPanelSettingsRoundedIcon from "@mui/icons-material/AdminPanelSettingsRounded";
import UploadFileRoundedIcon from "@mui/icons-material/UploadFileRounded";
import MoreVertRoundedIcon from "@mui/icons-material/MoreVertRounded";
import InsertDriveFileOutlinedIcon from "@mui/icons-material/InsertDriveFileOutlined";
import {
  Box,
  Checkbox,
  Chip,
  Divider,
  IconButton,
  Menu,
  MenuItem,
  Stack,
  TextField,
  Tooltip,
  Typography,
  useTheme,
} from "@mui/material";
import { useState, type MouseEvent } from "react";

import type { AccessibleDocument } from "../api/documents";

interface DocumentSelectorProps {
  documents: AccessibleDocument[];
  selected: string[];
  onToggle: (id: string) => void;
  onUploadClick: () => void;
  canUpload?: boolean;
  canManagePermissions?: boolean;
  onManagePermissions?: () => void;
  topK?: number;
  onTopKChange?: (val: number) => void;
}

const EXT_COLORS: Record<string, string> = {
  PDF: "#e53e3e",
  DOCX: "#3182ce",
  DOC: "#3182ce",
  XLSX: "#38a169",
  XLS: "#38a169",
  CSV: "#38a169",
  PPTX: "#dd6b20",
  PPT: "#dd6b20",
  TXT: "#718096",
  MD: "#718096",
};

export const DocumentSelector = ({
  documents,
  selected,
  onToggle,
  onUploadClick,
  canUpload = true,
  canManagePermissions = false,
  onManagePermissions,
  topK,
  onTopKChange,
}: DocumentSelectorProps) => {
  const theme = useTheme();
  const [menuAnchor, setMenuAnchor] = useState<HTMLElement | null>(null);

  return (
    <Box sx={{ display: "flex", flexDirection: "column", height: "100%", gap: 0 }}>
      {/* Header */}
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ px: 2, pt: 2, pb: 1.5 }}>
        <Stack direction="row" alignItems="center" spacing={1}>
          <FolderOpenRoundedIcon sx={{ fontSize: 18, color: "primary.main" }} />
          <Typography variant="subtitle2" fontWeight={700} sx={{ letterSpacing: "-0.01em" }}>
            Documents
          </Typography>
          {selected.length > 0 && (
            <Chip
              label={selected.length}
              size="small"
              color="primary"
              sx={{ height: 18, fontSize: 11, fontWeight: 700, "& .MuiChip-label": { px: 0.8 } }}
            />
          )}
        </Stack>
        <Stack direction="row" alignItems="center" spacing={0.5}>
          {canUpload && (
            <Tooltip title="Upload document">
              <IconButton size="small" onClick={onUploadClick} sx={{ color: "text.secondary" }}>
                <UploadFileRoundedIcon sx={{ fontSize: 18 }} />
              </IconButton>
            </Tooltip>
          )}
          {(canManagePermissions || canUpload) && (
            <IconButton size="small" onClick={(e: MouseEvent<HTMLElement>) => setMenuAnchor(e.currentTarget)} sx={{ color: "text.secondary" }}>
              <MoreVertRoundedIcon sx={{ fontSize: 18 }} />
            </IconButton>
          )}
        </Stack>
      </Stack>

      <Typography
        variant="caption"
        color="text.secondary"
        sx={{ px: 2, pb: 1.5, display: "block", lineHeight: 1.4 }}
      >
        Select documents to ground the chat on
      </Typography>

      <Menu
        anchorEl={menuAnchor}
        open={Boolean(menuAnchor)}
        onClose={() => setMenuAnchor(null)}
        anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
        transformOrigin={{ vertical: "top", horizontal: "right" }}
        slotProps={{ paper: { sx: { minWidth: 190 } } }}
      >
        {canUpload && (
          <MenuItem onClick={() => { setMenuAnchor(null); onUploadClick(); }} dense>
            <UploadFileRoundedIcon sx={{ fontSize: 16, mr: 1.5, color: "text.secondary" }} />
            <Typography variant="body2">Upload document</Typography>
          </MenuItem>
        )}
        {canManagePermissions && onManagePermissions && (
          <MenuItem onClick={() => { setMenuAnchor(null); onManagePermissions(); }} dense>
            <AdminPanelSettingsRoundedIcon sx={{ fontSize: 16, mr: 1.5, color: "text.secondary" }} />
            <Typography variant="body2">Manage permissions</Typography>
          </MenuItem>
        )}
      </Menu>

      {/* Document list */}
      <Box
        sx={{
          flex: 1,
          overflowY: "auto",
          px: 1.5,
          "&::-webkit-scrollbar": { width: 4 },
          "&::-webkit-scrollbar-thumb": { bgcolor: "action.hover", borderRadius: 99 },
        }}
      >
        {documents.length === 0 ? (
          <Stack alignItems="center" spacing={1} sx={{ py: 4, color: "text.disabled" }}>
            <InsertDriveFileOutlinedIcon sx={{ fontSize: 32 }} />
            <Typography variant="caption" align="center">
              No documents yet.{canUpload ? "\nUpload one to get started." : ""}
            </Typography>
          </Stack>
        ) : (
          documents.map((doc) => {
            const isSelected = selected.includes(doc.id);
            const ext = doc.filename.split(".").pop()?.toUpperCase() ?? (doc.file_type ?? "").toUpperCase();
            const date = doc.uploaded_at
              ? new Date(doc.uploaded_at).toLocaleDateString(undefined, { month: "numeric", day: "numeric", year: "2-digit" })
              : "";
            const extColor = EXT_COLORS[ext] ?? theme.palette.text.disabled;

            return (
              <Stack
                key={doc.id}
                direction="row"
                alignItems="center"
                spacing={1}
                onClick={() => onToggle(doc.id)}
                sx={{
                  py: 1,
                  px: 1,
                  borderRadius: 1.5,
                  cursor: "pointer",
                  transition: "background 0.12s",
                  bgcolor: isSelected
                    ? theme.palette.mode === "dark"
                      ? "rgba(99,102,241,0.12)"
                      : "rgba(99,102,241,0.07)"
                    : "transparent",
                  "&:hover": { bgcolor: "action.hover" },
                  mb: 0.25,
                }}
              >
                {/* File type badge */}
                <Typography
                  variant="caption"
                  sx={{
                    fontSize: 9.5,
                    fontWeight: 700,
                    letterSpacing: "0.04em",
                    color: extColor,
                    bgcolor: `${extColor}18`,
                    px: 0.75,
                    py: 0.2,
                    borderRadius: 0.75,
                    flexShrink: 0,
                    lineHeight: 1.6,
                    minWidth: 34,
                    textAlign: "center",
                  }}
                >
                  {ext || "FILE"}
                </Typography>

                {/* Name + date */}
                <Box sx={{ flex: 1, minWidth: 0 }}>
                  <Typography
                    variant="body2"
                    fontWeight={isSelected ? 600 : 400}
                    noWrap
                    title={doc.filename}
                    sx={{ fontSize: "0.8rem", lineHeight: 1.3, color: isSelected ? "primary.main" : "text.primary" }}
                  >
                    {doc.filename}
                  </Typography>
                  {date && (
                    <Typography variant="caption" color="text.disabled" sx={{ fontSize: "0.7rem", lineHeight: 1.2 }}>
                      {date}
                    </Typography>
                  )}
                </Box>

                <Checkbox
                  checked={isSelected}
                  size="small"
                  disableRipple
                  sx={{
                    p: 0,
                    flexShrink: 0,
                    color: "text.disabled",
                    "&.Mui-checked": { color: "primary.main" },
                    "& .MuiSvgIcon-root": { fontSize: 16 },
                  }}
                  onChange={() => onToggle(doc.id)}
                  onClick={(e) => e.stopPropagation()}
                />
              </Stack>
            );
          })
        )}
      </Box>

      {/* Depth field */}
      {topK !== undefined && onTopKChange && (
        <>
          <Divider sx={{ mt: 1 }} />
          <Stack direction="row" alignItems="center" spacing={1.5} sx={{ px: 2, py: 1.5 }}>
            <Typography variant="caption" color="text.secondary" fontWeight={600} sx={{ flexShrink: 0 }}>
              Depth
            </Typography>
            <TextField
              type="number"
              value={topK}
              onChange={(e) => onTopKChange(Math.max(1, Math.min(20, parseInt(e.target.value) || 1)))}
              size="small"
              inputProps={{ min: 1, max: 20 }}
              sx={{
                width: 72,
                "& .MuiInputBase-input": { py: 0.5, px: 1, fontSize: "0.85rem", textAlign: "center" },
              }}
            />
            <Typography variant="caption" color="text.disabled">
              chunks per doc
            </Typography>
          </Stack>
        </>
      )}
    </Box>
  );
};

export default DocumentSelector;
