import AddRoundedIcon from "@mui/icons-material/AddRounded";
import GroupWorkRoundedIcon from "@mui/icons-material/GroupWorkRounded";
import RefreshRoundedIcon from "@mui/icons-material/RefreshRounded";
import VerifiedUserRoundedIcon from "@mui/icons-material/VerifiedUserRounded";
import SearchRoundedIcon from "@mui/icons-material/SearchRounded";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
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
  onDeleteSpace,
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
      setError("يجب أن يتكون اسم الجلسة أكثر من حرفين.");
      return;
    }
    setError(null);
    setFeedback(null);
    setPendingAction("create");
    try {
      await onCreateSpace(trimmed);
      setNewSpaceName("");
      setFeedback("تم إنشاء الجلسة بنجاح.");
    } catch (err) {
      setError((err as Error).message || "تعذر إنشاء الجلسة.");
    } finally {
      setPendingAction(null);
    }
  };

  const handleAccept = async () => {
    const trimmed = inviteToken.trim();
    if (!trimmed) {
      setError("رمز الدعوة مطلوب.");
      return;
    }
    setError(null);
    setFeedback(null);
    setPendingAction("invite");
    try {
      await onAcceptInvite(trimmed);
      setInviteToken("");
      setFeedback("تم قبول الدعوة. الجلسة متاحة الآن.");
    } catch (err) {
      setError((err as Error).message || "تعذر قبول الدعوة.");
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
          <Typography variant="subtitle1" fontWeight={700}>جلسات القضايا</Typography>
        </Stack>
        <Tooltip title="تحديث الجلسات">
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
          placeholder="البحث في الجلسات"
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
            عرض الكل
          </Button>
        ) : null}

        {!filteredSpaces.length ? (
          <Box sx={{ p: 2.5, textAlign: "center" }}>
            <GroupWorkRoundedIcon color="disabled" fontSize="large" />
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
              {spaces.length ? "لا توجد جلسات تطابق البحث." : "لا توجد جلسات بعد. أنشئ جلسة قضية جديدة أو انضم إلى إحداها."}
            </Typography>
            {spaceSearch.trim() ? (
              <Button size="small" variant="text" onClick={() => {
                setSpaceSearch("");
                setShowAll(false);
              }} sx={{ mt: 0.5, textTransform: "none", fontWeight: 700 }}>
                مسح البحث
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

      <Card variant="outlined" sx={{ borderRadius: 3, borderColor: "divider" }}>
        <CardContent sx={{ p: 2, "&:last-child": { pb: 2 } }}>
          <Stack spacing={2}>
            <Typography variant="subtitle2" color="text.secondary">
              إدارة العضوية
            </Typography>
            <Stack spacing={1.5}>
              <TextField
                size="small"
                label="رمز الدعوة"
                value={inviteToken}
                onChange={(event) => setInviteToken(event.target.value)}
                placeholder="الصق رمز الدعوة هنا"
                disabled={pendingAction === "invite"}
              />
              <Button
                variant="outlined"
                onClick={handleAccept}
                disabled={pendingAction === "invite" || !inviteToken.trim()}
                startIcon={pendingAction === "invite" ? <CircularProgress size={16} /> : null}
                sx={{ borderRadius: 2 }}
              >
                {pendingAction === "invite" ? "جارٍ الانضمام…" : "الانضمام للجلسة"}
              </Button>
            </Stack>
          </Stack>
        </CardContent>
      </Card>

      {canManage ? (
        <Card variant="outlined" sx={{ borderRadius: 3, borderColor: "divider" }}>
          <CardContent sx={{ p: 2, "&:last-child": { pb: 2 } }}>
            <Stack spacing={2}>
              <Typography variant="subtitle2" color="text.secondary">
                إنشاء جلسة قضية جديدة
              </Typography>
              <Stack spacing={1.5}>
                <TextField
                  size="small"
                  label="اسم الجلسة/القضية"
                  value={newSpaceName}
                  onChange={(event) => setNewSpaceName(event.target.value)}
                  placeholder="مثال: قضية مستأجر، نزاع عقاري"
                  disabled={pendingAction === "create"}
                />
                <Button
                  variant="contained"
                  startIcon={pendingAction === "create" ? <CircularProgress size={16} /> : <AddRoundedIcon />}
                  onClick={handleCreate}
                  disabled={pendingAction === "create" || busy}
                  sx={{ borderRadius: 2 }}
                >
                  {pendingAction === "create" ? "جارٍ الإنشاء…" : "إنشاء جلسة جديدة"}
                </Button>
              </Stack>

              <Divider flexItem />
              <Typography variant="subtitle2" color="text.secondary">
                منطقة الخطر
              </Typography>
              <Button
                variant="outlined"
                color="error"
                disabled={!activeSpaceId || busy}
                onClick={() => activeSpaceId && onDeleteSpace(activeSpaceId)}
                sx={{ borderRadius: 2 }}
              >
                حذف الجلسة الحالية
              </Button>
            </Stack>
          </CardContent>
        </Card>
      ) : null}
    </Stack>
  );
};

export default SpaceSidebar;
