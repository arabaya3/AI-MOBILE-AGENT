import React, { useState, useEffect } from "react";
import {
  Drawer,
  Box,
  Typography,
  Button,
  Autocomplete,
  TextField,
  Chip,
  Stack,
  IconButton,
  Divider,
  Alert,
  CircularProgress,
} from "@mui/material";
import CloseIcon from "@mui/icons-material/Close";
import ShareIcon from "@mui/icons-material/Share";
import type { AccessibleDocument } from "../api/documents";
import {
  fetchAccessibleDocuments,
  fetchDocumentPermissionStatus,
  grantDocumentPermissions,
  revokeDocumentPermissions,
  updateDocumentVisibility,
} from "../api/documents";
import type { UserResponse } from "../api/auth";
import { listMembers } from "../api/spaces";
import { DocumentsTable } from "./DocumentsTable";
import { useAuth } from "../context/AuthContext";
import { useSpace } from "../context/SpaceContext";

interface AdminDocumentsPanelProps {
  open: boolean;
  onClose: () => void;
}

export const AdminDocumentsPanel: React.FC<AdminDocumentsPanelProps> = ({
  open,
  onClose,
}) => {
  const { user: currentUser } = useAuth();
  const { activeSpaceId } = useSpace();
  const [documents, setDocuments] = useState<AccessibleDocument[]>([]);
  const [users, setUsers] = useState<UserResponse[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedDocIds, setSelectedDocIds] = useState<string[]>([]);
  const [selectedUser, setSelectedUser] = useState<UserResponse | null>(null);
  const [mode, setMode] = useState<"grant" | "revoke">("grant");
  const [permissionStatus, setPermissionStatus] = useState<{ any: Set<string>; all: Set<string> }>(() => ({
    any: new Set(),
    all: new Set(),
  }));
  const [statusLoading, setStatusLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [visibilityLoading, setVisibilityLoading] = useState(false);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      loadDocuments();
      loadUsers();
    }
  }, [open, activeSpaceId]);

  useEffect(() => {
    if (!open) return;
    if (selectedDocIds.length === 0) {
      setPermissionStatus({ any: new Set(), all: new Set() });
      return;
    }
    setStatusLoading(true);
    fetchDocumentPermissionStatus(selectedDocIds)
      .then((response) => {
        setPermissionStatus({
          any: new Set(response.data.any_user_ids ?? []),
          all: new Set(response.data.all_user_ids ?? []),
        });
      })
      .catch(() => {
        // Non-fatal: keep UI usable even if status lookup fails.
        setPermissionStatus({ any: new Set(), all: new Set() });
      })
      .finally(() => setStatusLoading(false));
  }, [open, selectedDocIds]);

  const filteredUsers = users
    .filter((u) => u.id !== currentUser?.id)
    .filter((u) => (mode === "grant" ? !permissionStatus.all.has(u.id) : permissionStatus.any.has(u.id)));

  useEffect(() => {
    if (selectedUser && !filteredUsers.some((u) => u.id === selectedUser.id)) {
      setSelectedUser(null);
    }
  }, [filteredUsers, selectedUser]);

  const loadDocuments = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetchAccessibleDocuments(activeSpaceId ?? undefined);
      setDocuments(response.data);
    } catch (err: any) {
      setError(err.response?.data?.detail || "Failed to load documents");
    } finally {
      setLoading(false);
    }
  };

  const handleToggleVisibility = async (docId: string, isHidden: boolean) => {
    setVisibilityLoading(true);
    setError(null);
    try {
      await updateDocumentVisibility(docId, { is_hidden: isHidden });
      await loadDocuments();
      setSuccessMsg(isHidden ? "Document hidden for members." : "Document visible to members.");
    } catch (err: any) {
      setError(err.response?.data?.detail || "Failed to update visibility");
    } finally {
      setVisibilityLoading(false);
    }
  };

  const loadUsers = async () => {
    if (!activeSpaceId) {
      setUsers([]);
      return;
    }
    try {
      const response = await listMembers(activeSpaceId);
      const members = response.data
        .filter((member) => member.status === "active")
        .map<UserResponse>((member) => ({
          id: member.user_id,
          // Never surface raw database IDs in the UI.
          email: member.email ?? "Unknown user",
          role: member.role,
        }));
      setUsers(members);
    } catch (err: any) {
      console.error("Failed to load users:", err);
      setUsers([]);
    }
  };

  const toggleDocSelection = (docId: string) => {
    setSelectedDocIds((prev) =>
      prev.includes(docId) ? prev.filter((id) => id !== docId) : [...prev, docId]
    );
  };

  const handleGrant = async () => {
    if (!selectedUser || selectedDocIds.length === 0) {
      setError("Please select a user and at least one document");
      return;
    }
    setActionLoading(true);
    setError(null);
    setSuccessMsg(null);
    try {
      await grantDocumentPermissions({
        user_id: selectedUser.id,
        document_ids: selectedDocIds,
      });
      setSuccessMsg(`Granted access to ${selectedDocIds.length} document(s) for ${selectedUser.email}`);
      setSelectedDocIds([]);
      setSelectedUser(null);
    } catch (err: any) {
      setError(err.response?.data?.detail || "Failed to grant permissions");
    } finally {
      setActionLoading(false);
    }
  };

  const handleRevoke = async () => {
    if (!selectedUser || selectedDocIds.length === 0) {
      setError("Please select a user and at least one document");
      return;
    }
    setActionLoading(true);
    setError(null);
    setSuccessMsg(null);
    try {
      await revokeDocumentPermissions({
        user_id: selectedUser.id,
        document_ids: selectedDocIds,
      });
      setSuccessMsg(`Revoked access to ${selectedDocIds.length} document(s) for ${selectedUser.email}`);
      setSelectedDocIds([]);
      setSelectedUser(null);
    } catch (err: any) {
      setError(err.response?.data?.detail || "Failed to revoke permissions");
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <Drawer anchor="right" open={open} onClose={onClose}>
      <Box
        sx={{
          width: { xs: "100vw", sm: 550 },
          p: { xs: 2, sm: 3 },
          boxSizing: "border-box",
        }}
      >
        <Stack direction="row" justifyContent="space-between" alignItems="center" mb={2}>
          <Typography variant="h6">Manage Document Permissions</Typography>
          <IconButton onClick={onClose} size="small">
            <CloseIcon />
          </IconButton>
        </Stack>

        <Divider sx={{ mb: 2 }} />

        {error && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
            {error}
          </Alert>
        )}

        {successMsg && (
          <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccessMsg(null)}>
            {successMsg}
          </Alert>
        )}

        <Stack direction="row" spacing={1} sx={{ mb: 2 }}>
          <Button
            variant={mode === "grant" ? "contained" : "outlined"}
            onClick={() => setMode("grant")}
            fullWidth
            disabled={actionLoading}
          >
            Grant
          </Button>
          <Button
            variant={mode === "revoke" ? "contained" : "outlined"}
            color={mode === "revoke" ? "error" : "primary"}
            onClick={() => setMode("revoke")}
            fullWidth
            disabled={actionLoading}
          >
            Revoke
          </Button>
        </Stack>

        <Autocomplete
          fullWidth
          options={filteredUsers}
          getOptionLabel={(option) => `${option.email} (${option.role})`}
          value={selectedUser}
          onChange={(_, newValue) => setSelectedUser(newValue)}
          renderInput={(params) => (
            <TextField
              {...params}
              label={mode === "grant" ? "Select user to grant" : "Select user to revoke"}
              placeholder={statusLoading ? "Checking current access…" : "Search users…"}
              size="small"
            />
          )}
          sx={{ mb: 2 }}
        />

        <Typography variant="subtitle2" gutterBottom>
          Selected Documents ({selectedDocIds.length})
        </Typography>
        <Box sx={{ mb: 2, minHeight: 40 }}>
          {selectedDocIds.length > 0 ? (
            <Stack direction="row" flexWrap="wrap" gap={1}>
              {selectedDocIds.map((id) => (
                <Chip
                  key={id}
                  label={documents.find((d) => d.id === id)?.filename || id}
                  onDelete={() => toggleDocSelection(id)}
                  size="small"
                />
              ))}
            </Stack>
          ) : (
            <Typography variant="body2" color="text.secondary">
              No documents selected
            </Typography>
          )}
        </Box>

        <Stack direction="row" spacing={1} mb={3}>
          {mode === "grant" ? (
            <Button
              variant="contained"
              startIcon={<ShareIcon />}
              onClick={handleGrant}
              disabled={actionLoading || selectedDocIds.length === 0 || !selectedUser}
              fullWidth
            >
              Grant access
            </Button>
          ) : (
            <Button
              variant="contained"
              color="error"
              onClick={handleRevoke}
              disabled={actionLoading || selectedDocIds.length === 0 || !selectedUser}
              fullWidth
            >
              Revoke access
            </Button>
          )}
        </Stack>

        <Divider sx={{ mb: 2 }} />

        <Typography variant="subtitle1" gutterBottom>
          Available Documents ({documents.length})
        </Typography>

        {loading ? (
          <Box display="flex" justifyContent="center" py={4}>
            <CircularProgress />
          </Box>
        ) : (
          <DocumentsTable
            documents={documents}
            selectedIds={selectedDocIds}
            onToggleSelection={toggleDocSelection}
            onToggleVisibility={handleToggleVisibility}
            visibilityLoading={visibilityLoading}
          />
        )}
      </Box>
    </Drawer>
  );
};
