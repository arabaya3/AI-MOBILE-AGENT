import GroupAddRoundedIcon from "@mui/icons-material/GroupAddRounded";
import { Alert, Box, Button, Card, CardContent, CircularProgress, Stack, Typography } from "@mui/material";
import { isAxiosError } from "axios";
import { useState } from "react";
import { useNavigate } from "react-router-dom";

import { acceptInvite } from "../api/spaces";
import { useAuth } from "../context/AuthContext";
import { useSpace } from "../context/SpaceContext";
import { clearPendingInvite, peekPendingInvite } from "../invite/pendingInvite";

type Outcome = { kind: "error"; message: string } | null;

function describe(error: unknown): string {
  const status = isAxiosError(error) ? error.response?.status : undefined;
  switch (status) {
    case 403:
      return "This invitation was sent to a different email address. Sign in with the invited address to accept it.";
    case 400:
      return "This invitation has expired. Ask a space administrator to send a new one.";
    case 404:
      return "This invitation is no longer valid. It may have been used, revoked or replaced by a newer one.";
    default:
      return "The invitation could not be accepted right now. Check your connection and try again.";
  }
}

export default function JoinSpacePage() {
  const { isAuthenticated, user, logout } = useAuth();
  const { refreshSpaces, selectSpace } = useSpace();
  const navigate = useNavigate();
  const [busy, setBusy] = useState(false);
  const [outcome, setOutcome] = useState<Outcome>(null);
  const token = peekPendingInvite();

  const accept = async () => {
    if (!token || busy) return;
    setBusy(true);
    setOutcome(null);
    try {
      const { data } = await acceptInvite({ token });
      clearPendingInvite();
      selectSpace(data.space_id);
      await refreshSpaces();
      navigate("/", { replace: true });
    } catch (error) {
      const status = isAxiosError(error) ? error.response?.status : undefined;
      // Only a definite refusal discards the token; a network failure keeps it for a retry.
      if (status === 400 || status === 404) clearPendingInvite();
      setOutcome({ kind: "error", message: describe(error) });
    } finally {
      setBusy(false);
    }
  };

  const leave = () => {
    clearPendingInvite();
    navigate(isAuthenticated ? "/" : "/auth", { replace: true });
  };

  return (
    <Box sx={{ minHeight: "100dvh", display: "grid", placeItems: "center", p: 2 }}>
      <Card sx={{ width: "100%", maxWidth: 460 }}>
        <CardContent>
          <Stack spacing={2}>
            <Stack direction="row" spacing={1.5} alignItems="center">
              <GroupAddRoundedIcon color="primary" />
              <Typography variant="h6" component="h1">
                Space invitation
              </Typography>
            </Stack>
            {!token ? (
              <>
                <Typography color="text.secondary">
                  No invitation is open in this tab. Open the link from your invitation email again.
                </Typography>
                <Button variant="contained" onClick={leave}>
                  Continue
                </Button>
              </>
            ) : !isAuthenticated ? (
              <>
                <Typography color="text.secondary">
                  Sign in, or create an account, with the email address the invitation was sent to. You will come back
                  here to accept it.
                </Typography>
                <Button variant="contained" onClick={() => navigate("/auth")}>
                  Sign in or create an account
                </Button>
                <Button onClick={leave}>Not now</Button>
              </>
            ) : (
              <>
                <Typography color="text.secondary">
                  Accept to join the space as a member, signed in as <strong>{user?.email}</strong>.
                </Typography>
                {outcome && <Alert severity="error">{outcome.message}</Alert>}
                <Button variant="contained" onClick={accept} disabled={busy || !peekPendingInvite()}>
                  {busy ? <CircularProgress size={22} /> : "Accept invitation"}
                </Button>
                <Stack direction="row" spacing={1} justifyContent="space-between">
                  <Button onClick={leave}>Not now</Button>
                  <Button onClick={() => logout()}>Use another account</Button>
                </Stack>
              </>
            )}
          </Stack>
        </CardContent>
      </Card>
    </Box>
  );
}
