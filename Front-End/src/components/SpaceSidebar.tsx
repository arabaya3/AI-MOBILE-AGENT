import AddRoundedIcon from "@mui/icons-material/AddRounded";
import GroupWorkRoundedIcon from "@mui/icons-material/GroupWorkRounded";
import RefreshRoundedIcon from "@mui/icons-material/RefreshRounded";
import VerifiedUserRoundedIcon from "@mui/icons-material/VerifiedUserRounded";
import SearchRoundedIcon from "@mui/icons-material/SearchRounded";
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Divider,
  IconButton,
  InputAdornment,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from "@mui/material";
import { useState } from "react";

import type { SpaceSummary } from "../api/spaces";
import { DashboardView } from "./DashboardView";

interface SpaceSidebarProps {
  spaces: SpaceSummary[];
  activeSpaceId: string | null;
  onSelect(spaceId: string): void;
  onRefresh(): Promise<void>;
  onCreateSpace(name: string): Promise<void>;
  onAcceptInvite(token: string): Promise<void>;
  onDeleteSpace(spaceId: string): Promise<void>;
  canManage: boolean;
  busy?: boolean;
}

const SpaceSidebar = ({
  spaces,
  activeSpaceId,
  onSelect,
  onRefresh,
  onCreateSpace,
  onAcceptInvite,
  // onDeleteSpace moved to Space Settings dialog
  canManage,
  busy,
}: SpaceSidebarProps) => {
  const [newSpaceName, setNewSpaceName] = useState("");
  const [inviteToken, setInviteToken] = useState("");
  const [feedback, setFeedback] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState<"create" | "invite" | null>(null);
  const [spaceSearch, setSpaceSearch] = useState("");
  const [showAll, setShowAll] = useState(false);

  const filteredSpaces = spaces.filter((space) =>
    space.name.toLowerCase().includes(spaceSearch.trim().toLowerCase())
  );

  const handleCreate = async () => {
    const trimmed = newSpaceName.trim();
    if (trimmed.length < 2) {
      setError("Space name must be at least 2 characters.");
      return;
    }
    setError(null);
    setFeedback(null);
    setPendingAction("create");
    try {
      await onCreateSpace(trimmed);
      setNewSpaceName("");
      setFeedback("Space created successfully.");
    } catch (err) {
      setError((err as Error).message || "Failed to create space.");
    } finally {
      setPendingAction(null);
    }
  };

  const handleAccept = async () => {
    const trimmed = inviteToken.trim();
    if (!trimmed) {
      setError("Invite token is required.");
      return;
    }
    setError(null);
    setFeedback(null);
    setPendingAction("invite");
    try {
      await onAcceptInvite(trimmed);
      setInviteToken("");
      setFeedback("Invite accepted. Space is now available.");
    } catch (err) {
      setError((err as Error).message || "Failed to accept invite.");
    } finally {
      setPendingAction(null);
    }
  };

  return (
    <Stack
      spacing={3}
      sx={{
        width: { xs: "100%", md: 320 },
        flexShrink: 0,
        p: 2,
        minHeight: 0,
        height: "100%",
        overflow: "hidden",
        bgcolor: "background.default",
        borderRight: "none",
        borderColor: "divider",
      }}
    >
      <Stack
        direction="row"
        alignItems="center"
        justifyContent="space-between"
        sx={{ px: { xs: 0, md: 1 } }}
      >
        <Stack direction="row" spacing={1} alignItems="center">
          <VerifiedUserRoundedIcon color="primary" />
          <Typography variant="subtitle1" fontWeight={700}>Spaces</Typography>
        </Stack>
        <Tooltip title="Refresh spaces">
          <span>
            <IconButton onClick={onRefresh} size="small" disabled={busy}>
              <RefreshRoundedIcon fontSize="small" />
            </IconButton>
          </span>
        </Tooltip>
      </Stack>

      <Box sx={{ px: { xs: 0, md: 1 } }}>
        <TextField
          fullWidth
          size="small"
          placeholder="Search spaces"
          value={spaceSearch}
          onChange={(event) => {
            setSpaceSearch(event.target.value);
            setShowAll(false);
          }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchRoundedIcon fontSize="small" />
              </InputAdornment>
            ),
          }}
        />
      </Box>

      <Box sx={{ flex: { xs: "0 0 auto", md: "1 1 auto" }, minHeight: { xs: "auto", md: 0 }, px: { xs: 0, md: 1 } }}>
        <DashboardView
          spaces={spaces}
          activeSpaceId={activeSpaceId}
          onSelect={onSelect}
          list={showAll ? filteredSpaces : filteredSpaces.slice(0, 7)}
        />

        {(!showAll && filteredSpaces.length > 7) ? (
          <Button
            size="small"
            variant="text"
            onClick={() => setShowAll(true)}
            sx={{ mt: 1, textTransform: "none", fontWeight: 700 }}
          >
            View all
          </Button>
        ) : null}

        {!filteredSpaces.length ? (
          <Box sx={{ p: 2.5, textAlign: "center" }}>
            <GroupWorkRoundedIcon color="disabled" fontSize="large" />
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
              {spaces.length ? "No spaces match your search." : "No spaces yet. Create or join one to get started."}
            </Typography>
            {spaceSearch.trim() ? (
              <Button size="small" variant="text" onClick={() => {
                setSpaceSearch("");
                setShowAll(false);
              }} sx={{ mt: 0.5, textTransform: "none", fontWeight: 700 }}>
                Clear search
              </Button>
            ) : null}
          </Box>
        ) : null}
      </Box>

      {error ? (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      ) : null}
      {feedback ? (
        <Alert severity="success" onClose={() => setFeedback(null)}>
          {feedback}
        </Alert>
      ) : null}

      <Stack spacing={2} sx={{ px: { xs: 0, md: 1 } }}>
        <Typography variant="subtitle2" color="text.secondary">
          Manage membership
        </Typography>
        <Stack spacing={1.5}>
          <TextField
            size="small"
            label="Invite token"
            value={inviteToken}
            onChange={(event) => setInviteToken(event.target.value)}
            placeholder="Paste invite token"
            disabled={pendingAction === "invite"}
          />
          <Button
            variant="outlined"
            onClick={handleAccept}
            disabled={pendingAction === "invite" || !inviteToken.trim()}
            startIcon={pendingAction === "invite" ? <CircularProgress size={16} /> : null}
          >
            {pendingAction === "invite" ? "Joining…" : "Join space"}
          </Button>
        </Stack>
      </Stack>

      {canManage ? (
        <Stack spacing={2} sx={{ px: { xs: 0, md: 1 } }}>
          <Divider flexItem />
          <Typography variant="subtitle2" color="text.secondary">
            Create new space
          </Typography>
          <Stack spacing={1.5}>
            <TextField
              size="small"
              label="Space name"
              value={newSpaceName}
              onChange={(event) => setNewSpaceName(event.target.value)}
              placeholder="e.g. Marketing"
              disabled={pendingAction === "create"}
            />
            <Button
              variant="contained"
              startIcon={pendingAction === "create" ? <CircularProgress size={16} /> : <AddRoundedIcon />}
              onClick={handleCreate}
              disabled={pendingAction === "create" || busy}
            >
              {pendingAction === "create" ? "Creating…" : "Create space"}
            </Button>
          </Stack>
        </Stack>
      ) : null}
    </Stack>
  );
};

export default SpaceSidebar;
