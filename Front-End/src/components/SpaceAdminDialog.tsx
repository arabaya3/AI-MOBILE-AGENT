import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  FormHelperText,
  InputLabel,
  MenuItem,
  Select,
  Switch,
  Stack,
  Tab,
  Tabs,
  TextField,
  Typography,
} from "@mui/material";
import { useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent } from "react";

import type {
  SpaceMemberSummary,
  MySpaceMembership,
  SpacePolicy,
  SpaceRequestSummary,
  SpaceSummary,
} from "../api/spaces";
import type { SystemPrompts } from "../api/systemPrompts";
import {
  createSpaceRequest,
  getMyMembership,
  inviteMember,
  listAvailableSpaces,
  listMembers,
  listSpaceRequests,
  reviewSpaceRequest,
  updateMember,
  updatePolicy,
} from "../api/spaces";
import { listAllChatModels } from "../api/chat";
import { getSystemPrompts, updateSystemPrompts } from "../api/systemPrompts";
import { AdminAnalyticsDashboard } from "./AdminAnalyticsDashboard";
import { formatToolName } from "../utils/formatters";

interface SpaceAdminDialogProps {
  open: boolean;
  onClose: () => void;
  space: SpaceSummary;
  currentUserId: string;
  onUpdate?: () => void;
  initialTab?: string;
}

const REQUEST_TYPE_LABELS: Record<string, string> = {
  join: "طلب انضمام",
  model_access: "صلاحية النموذج",
  tool_access: "صلاحية الأداة",
  upload_access: "صلاحية الرفع",
  quota_change: "تغيير الحصة",
  other: "أخرى",
};

const policyToList = (policy?: SpacePolicy) => (policy?.allowed_models ?? []).filter(Boolean);

const validateTokenLimits = (dailyTokens: string, monthlyTokens: string): string | null => {
  const daily = dailyTokens === "" ? 0 : Number(dailyTokens);
  const monthly = monthlyTokens === "" ? 0 : Number(monthlyTokens);
  
  if (daily > 0 && daily < 1000) {
    return "Daily token limit must be at least 1,000 tokens for meaningful usage";
  }
  
  if (monthly > 0 && monthly < 10000) {
    return "Monthly token limit must be at least 10,000 tokens for meaningful usage";
  }
  
  if (daily > 0 && monthly > 0 && daily > monthly) {
    return "لا يمكن أن يتجاوز الحد اليومي الحد الشهري";
  }
  
  return null;
};

const TOKEN_LIMIT_OPTIONS = [
  1000,
  5000,
  10000,
  25000,
  50000,
  100000,
  250000,
  500000,
  1000000,
  3000000,
  5000000,
];

const REQUEST_LIMIT_OPTIONS = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000];
const BASIC_TOOL_OPTIONS = ["calculator", "analyze_data", "document_ops", "code_executor"];
const ADVANCED_TOOL_OPTIONS = [
  "web_search",
  "web_search_tavily",
  "usage_query",
  "image_understanding",
  "image_generation",
  "speech_to_text",
  "text_to_speech",
];
const TOOL_OPTIONS = [...BASIC_TOOL_OPTIONS, ...ADVANCED_TOOL_OPTIONS];

const asTokenOption = (value: string) => {
  if (!value) return "";
  const num = Number(value);
  if (!Number.isFinite(num)) return "";
  return String(Math.max(0, Math.floor(num)));
};

const asRequestOption = (value: string) => {
  if (!value) return "";
  const num = Number(value);
  if (!Number.isFinite(num)) return "";
  return String(Math.max(0, Math.floor(num)));
};

export const SpaceAdminDialog = ({ open, onClose, space, onUpdate, initialTab }: SpaceAdminDialogProps) => {
  const [tab, setTab] = useState("members");
  const initRef = useRef(false);
  const lastSpaceIdRef = useRef<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [myMembership, setMyMembership] = useState<MySpaceMembership | null>(null);

  const [members, setMembers] = useState<SpaceMemberSummary[]>([]);
  const [requests, setRequests] = useState<SpaceRequestSummary[]>([]);

  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteToken, setInviteToken] = useState<string | null>(null);

  const [editOverridesOpen, setEditOverridesOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<SpaceMemberSummary | null>(null);
  const [overrideModels, setOverrideModels] = useState<string[]>([]);
  const [overrideDailyTokenLimit, setOverrideDailyTokenLimit] = useState<string>("");
  const [overrideMonthlyTokenLimit, setOverrideMonthlyTokenLimit] = useState<string>("");
  const [overrideDailyRequestLimit, setOverrideDailyRequestLimit] = useState<string>("");
  const [overrideMonthlyRequestLimit, setOverrideMonthlyRequestLimit] = useState<string>("");
  const [overrideTools, setOverrideTools] = useState<string[]>([]);
  const [overrideDailyToolLimit, setOverrideDailyToolLimit] = useState<string>("");
  const [overrideMonthlyToolLimit, setOverrideMonthlyToolLimit] = useState<string>("");

  const [policyModels, setPolicyModels] = useState<string[]>([]);
  const [policyTools, setPolicyTools] = useState<string[]>([]);
  const [dailyTokenLimit, setDailyTokenLimit] = useState<string>("");
  const [monthlyTokenLimit, setMonthlyTokenLimit] = useState<string>("");
  const [dailyRequestLimit, setDailyRequestLimit] = useState<string>("");
  const [monthlyRequestLimit, setMonthlyRequestLimit] = useState<string>("");
  const [dailyToolRequestLimit, setDailyToolRequestLimit] = useState<string>("");
  const [monthlyToolRequestLimit, setMonthlyToolRequestLimit] = useState<string>("");

  const [availableModels, setAvailableModels] = useState<string[]>([]);
  const [availableModelsError, setAvailableModelsError] = useState<string | null>(null);
  const [availableSpaces, setAvailableSpaces] = useState<SpaceSummary[]>([]);
  const [availableSpacesError, setAvailableSpacesError] = useState<string | null>(null);
  const [availableSpacesLoading, setAvailableSpacesLoading] = useState(false);
  const [joinSpaceId, setJoinSpaceId] = useState<string>("");
  const [loadingAction, setLoadingAction] = useState<string | null>(null);

  const [systemPrompts, setSystemPrompts] = useState<SystemPrompts | null>(null);
  const [draftPrompts, setDraftPrompts] = useState<SystemPrompts | null>(null);
  const [systemPromptsLoading, setSystemPromptsLoading] = useState(false);
  const [systemPromptsSaving, setSystemPromptsSaving] = useState(false);
  const [systemPromptsError, setSystemPromptsError] = useState<string | null>(null);
  const [systemPromptsSaved, setSystemPromptsSaved] = useState(false);

  const isSpaceAdmin = (myMembership?.role ?? "").toLowerCase() === "admin";

  const effectivePolicy = useMemo(() => {
    const overrides = myMembership?.overrides;
    const allowedModels = overrides?.allowed_models?.length
      ? overrides.allowed_models
      : (space.policy.allowed_models ?? []);
    const allowedTools = overrides?.allowed_tools?.length
      ? overrides.allowed_tools
      : (space.policy.allowed_tools ?? []);

    const dailyTokenLimit = overrides?.daily_token_limit ?? space.policy.daily_token_limit ?? null;
    const monthlyTokenLimit = overrides?.monthly_token_limit ?? space.policy.monthly_token_limit ?? null;
    const dailyRequestLimit = overrides?.daily_request_limit ?? space.policy.daily_request_limit ?? null;
    const monthlyRequestLimit = overrides?.monthly_request_limit ?? space.policy.monthly_request_limit ?? null;
    const dailyToolRequestLimit = overrides?.daily_tool_request_limit ?? space.policy.daily_tool_request_limit ?? null;
    const monthlyToolRequestLimit = overrides?.monthly_tool_request_limit ?? space.policy.monthly_tool_request_limit ?? null;

    return {
      allowed_models: allowedModels,
      allowed_tools: allowedTools,
      daily_token_limit: dailyTokenLimit,
      monthly_token_limit: monthlyTokenLimit,
      daily_request_limit: dailyRequestLimit,
      monthly_request_limit: monthlyRequestLimit,
      daily_tool_request_limit: dailyToolRequestLimit,
      monthly_tool_request_limit: monthlyToolRequestLimit,
    };
  }, [myMembership, space.policy]);

  const displayUser = useCallback(
    (userId: string) => members.find((m) => m.user_id === userId)?.email ?? "Unknown user",
    [members],
  );

  const renderRequestDetails = useCallback(
    (req: SpaceRequestSummary) => {
      const payload = (req.payload ?? {}) as Record<string, any>;
      if (req.type === "join") {
        return <Typography variant="body2" color="text.secondary">Request to join this space.</Typography>;
      }

      if (req.type === "upload_access") {
        const wantsUpload = payload.can_upload_documents !== false;
        return (
          <Typography variant="body2" color="text.secondary">
            {wantsUpload ? "Requested permission to upload documents." : "Requested removal of upload permission."}
          </Typography>
        );
      }

      if (req.type === "model_access") {
        const models = (Array.isArray(payload.allowed_models) ? payload.allowed_models : []).filter(Boolean);
        return models.length ? (
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            {models.map((m: string) => (
              <Chip key={m} label={m} size="small" variant="outlined" />
            ))}
          </Stack>
        ) : (
          <Typography variant="body2" color="text.secondary">Requested additional model access.</Typography>
        );
      }

      if (req.type === "tool_access") {
        const tools = (Array.isArray(payload.allowed_tools) ? payload.allowed_tools : []).filter(Boolean);
        return tools.length ? (
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            {tools.map((t: string) => (
              <Chip key={t} label={formatToolName(t)} size="small" variant="outlined" />
            ))}
          </Stack>
        ) : (
          <Typography variant="body2" color="text.secondary">Requested additional tool access.</Typography>
        );
      }

      if (req.type === "quota_change") {
        const models = (Array.isArray(payload.allowed_models) ? payload.allowed_models : []).filter(Boolean);
        const fields = (
          [
            ["رصيد يومي", payload.daily_token_limit] as [string, any],
            ["رصيد شهري", payload.monthly_token_limit] as [string, any],
            ["طلبات يومية", payload.daily_request_limit] as [string, any],
            ["طلبات شهرية", payload.monthly_request_limit] as [string, any],
          ].filter(([, v]) => v != null)
        ) as Array<[string, any]>;

        return (
          <Stack spacing={1}>
            {models.length ? (
              <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                {models.map((m: string) => (
                  <Chip key={m} label={m} size="small" variant="outlined" />
                ))}
              </Stack>
            ) : null}
            {fields.length ? (
              <Stack direction={{ xs: "column", md: "row" }} spacing={2} flexWrap="wrap" useFlexGap>
                {fields.map(([label, value]) => (
                  <Stack key={label} spacing={0}>
                    <Typography variant="caption" color="text.secondary">{label}</Typography>
                    <Typography variant="body2" fontWeight={600}>{String(value)}</Typography>
                  </Stack>
                ))}
              </Stack>
            ) : (
              <Typography variant="body2" color="text.secondary">Requested quota changes.</Typography>
            )}
          </Stack>
        );
      }

      const details = String(payload.details ?? "").trim();
      return details ? (
        <Typography variant="body2" color="text.secondary" sx={{ whiteSpace: "pre-wrap" }}>{details}</Typography>
      ) : (
        <Typography variant="body2" color="text.secondary">No details provided.</Typography>
      );
    },
    [],
  );

  const refreshAll = async () => {
    setLoading(true);
    setError(null);
    try {
      const membershipRes = await getMyMembership(space.id);
      setMyMembership(membershipRes.data);
      const role = (membershipRes.data.role ?? "").toLowerCase();

      if (role === "admin") {
        const [membersRes, reqRes] = await Promise.all([
          listMembers(space.id),
          listSpaceRequests(space.id),
        ]);
        setMembers(membersRes.data);
        setRequests(reqRes.data);
      } else {
        // Non-admins: keep the dialog focused on requests.
        setMembers([]);
        setRequests([]);
      }
    } catch {
      setError("Unable to load space data.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!open) {
      initRef.current = false;
      lastSpaceIdRef.current = null;
      return;
    }
    if (lastSpaceIdRef.current !== space.id) {
      initRef.current = false;
    }
    if (initRef.current) return;
    initRef.current = true;
    lastSpaceIdRef.current = space.id;
    const allowedTabs = ["requests", "settings", "usage", ...(isSpaceAdmin ? ["members", "policy"] : [])];
    const nextTab = initialTab && allowedTabs.includes(initialTab) ? initialTab : "requests";
    setTab(nextTab);
    setInviteEmail("");
    setInviteToken(null);
    setMyMembership(null);
    setPolicyModels(policyToList(space.policy));
    setPolicyTools((space.policy.allowed_tools ?? []).filter(Boolean));
    setDailyTokenLimit(space.policy.daily_token_limit == null ? "" : String(space.policy.daily_token_limit));
    setMonthlyTokenLimit(space.policy.monthly_token_limit == null ? "" : String(space.policy.monthly_token_limit));
    setDailyRequestLimit(space.policy.daily_request_limit == null ? "" : String(space.policy.daily_request_limit));
    setMonthlyRequestLimit(space.policy.monthly_request_limit == null ? "" : String(space.policy.monthly_request_limit));
    setDailyToolRequestLimit(
      space.policy.daily_tool_request_limit == null ? "" : String(space.policy.daily_tool_request_limit),
    );
    setMonthlyToolRequestLimit(
      space.policy.monthly_tool_request_limit == null ? "" : String(space.policy.monthly_tool_request_limit),
    );
    setAvailableModelsError(null);
    setAvailableSpacesError(null);
    setJoinSpaceId("");
    // Load ALL models for admin to choose from
    listAllChatModels()
      .then(({ data }) => {
        setAvailableModels(data);
        setAvailableModelsError(null);
      })
      .catch(() => setAvailableModelsError("Unable to load models list."));

    setAvailableSpacesLoading(true);
    listAvailableSpaces()
      .then(({ data }) => {
        setAvailableSpaces(data);
        setAvailableSpacesError(null);
      })
      .catch(() => setAvailableSpacesError("Unable to load available spaces."))
      .finally(() => setAvailableSpacesLoading(false));

    setSystemPromptsLoading(true);
    setSystemPromptsError(null);
    setSystemPromptsSaved(false);
    getSystemPrompts()
      .then(({ data }) => {
        setSystemPrompts(data);
        setDraftPrompts(data);
      })
      .catch(() => setSystemPromptsError("Unable to load system prompts."))
      .finally(() => setSystemPromptsLoading(false));
    
    // Also refresh to get latest data
    refreshAll();
  }, [open, space.id, initialTab, isSpaceAdmin]);

  const handleInvite = async () => {
    setInviteToken(null);
    setError(null);
    try {
      const { data } = await inviteMember(space.id, { email: inviteEmail.trim() });
      setInviteToken(data.invite_token);
      setInviteEmail("");
      await refreshAll();
    } catch {
      setError("Failed to invite member.");
    }
  };

  const handleSavePolicy = async () => {
    setError(null);
    
    // Validate token limits
    const validationError = validateTokenLimits(dailyTokenLimit, monthlyTokenLimit);
    if (validationError) {
      setError(validationError);
      return;
    }
    
    try {
      const { data } = await updatePolicy(space.id, {
        allowed_models: policyModels,
        allowed_tools: policyTools,
        daily_token_limit: dailyTokenLimit === "" ? null : Number(dailyTokenLimit),
        monthly_token_limit: monthlyTokenLimit === "" ? null : Number(monthlyTokenLimit),
        daily_request_limit: dailyRequestLimit === "" ? null : Number(dailyRequestLimit),
        monthly_request_limit: monthlyRequestLimit === "" ? null : Number(monthlyRequestLimit),
        daily_tool_request_limit: dailyToolRequestLimit === "" ? null : Number(dailyToolRequestLimit),
        monthly_tool_request_limit: monthlyToolRequestLimit === "" ? null : Number(monthlyToolRequestLimit),
      });
      // Update local state with new policy
      setPolicyModels(data.policy.allowed_models ?? []);
      setPolicyTools(data.policy.allowed_tools ?? []);
      setDailyTokenLimit(data.policy.daily_token_limit == null ? "" : String(data.policy.daily_token_limit));
      setMonthlyTokenLimit(data.policy.monthly_token_limit == null ? "" : String(data.policy.monthly_token_limit));
      setDailyRequestLimit(data.policy.daily_request_limit == null ? "" : String(data.policy.daily_request_limit));
      setMonthlyRequestLimit(data.policy.monthly_request_limit == null ? "" : String(data.policy.monthly_request_limit));
      setDailyToolRequestLimit(
        data.policy.daily_tool_request_limit == null ? "" : String(data.policy.daily_tool_request_limit),
      );
      setMonthlyToolRequestLimit(
        data.policy.monthly_tool_request_limit == null ? "" : String(data.policy.monthly_tool_request_limit),
      );
      await refreshAll();
      onUpdate?.(); // Notify parent to refresh space list
    } catch {
      setError("Failed to update policy.");
    }
  };

  const handleUpdateMember = async (
    member: SpaceMemberSummary,
    patch: { role?: string; status?: string; can_upload_documents?: boolean },
  ) => {
    setError(null);
    try {
      const { data } = await updateMember(space.id, member.user_id, patch);
      setMembers((prev) => prev.map((m) => (m.user_id === data.user_id ? data : m)));
    } catch {
      setError("Failed to update member.");
    }
  };

  const openOverridesEditor = (member: SpaceMemberSummary) => {
    setEditTarget(member);
    setOverrideModels(policyToList(member.overrides));
    setOverrideTools((member.overrides.allowed_tools ?? []).filter(Boolean));
    setOverrideDailyTokenLimit(member.overrides.daily_token_limit == null ? "" : String(member.overrides.daily_token_limit));
    setOverrideMonthlyTokenLimit(member.overrides.monthly_token_limit == null ? "" : String(member.overrides.monthly_token_limit));
    setOverrideDailyRequestLimit(member.overrides.daily_request_limit == null ? "" : String(member.overrides.daily_request_limit));
    setOverrideMonthlyRequestLimit(member.overrides.monthly_request_limit == null ? "" : String(member.overrides.monthly_request_limit));
    setOverrideDailyToolLimit(
      member.overrides.daily_tool_request_limit == null ? "" : String(member.overrides.daily_tool_request_limit),
    );
    setOverrideMonthlyToolLimit(
      member.overrides.monthly_tool_request_limit == null ? "" : String(member.overrides.monthly_tool_request_limit),
    );
    setEditOverridesOpen(true);
  };

  const handleSaveOverrides = async () => {
    if (!editTarget) return;
    setError(null);
    
    // Validate token limits
    const validationError = validateTokenLimits(overrideDailyTokenLimit, overrideMonthlyTokenLimit);
    if (validationError) {
      setError(validationError);
      return;
    }
    
    try {
      const { data } = await updateMember(space.id, editTarget.user_id, {
        overrides: {
          allowed_models: overrideModels,
          allowed_tools: overrideTools,
          daily_token_limit: overrideDailyTokenLimit === "" ? null : Number(overrideDailyTokenLimit),
          monthly_token_limit: overrideMonthlyTokenLimit === "" ? null : Number(overrideMonthlyTokenLimit),
          daily_request_limit: overrideDailyRequestLimit === "" ? null : Number(overrideDailyRequestLimit),
          monthly_request_limit: overrideMonthlyRequestLimit === "" ? null : Number(overrideMonthlyRequestLimit),
          daily_tool_request_limit: overrideDailyToolLimit === "" ? null : Number(overrideDailyToolLimit),
          monthly_tool_request_limit: overrideMonthlyToolLimit === "" ? null : Number(overrideMonthlyToolLimit),
        },
      });
      setMembers((prev) => prev.map((m) => (m.user_id === data.user_id ? data : m)));
      setEditOverridesOpen(false);
      setEditTarget(null);
    } catch {
      setError("Failed to update member limits.");
    }
  };

  const handleReview = async (req: SpaceRequestSummary, decision: "approved" | "declined") => {
    setError(null);
    setLoadingAction(`review-${req.id}`);

    // Optimistic update for immediate feedback
    setRequests((prev) => prev.map((r) => (r.id === req.id ? { ...r, status: decision } : r)));

    try {
      const { data } = await reviewSpaceRequest(space.id, req.id, { decision });
      setRequests((prev) => prev.map((r) => (r.id === data.id ? data : r)));
      // Refresh members list silently to show updated permissions
      refreshAll().catch(() => {});
      onUpdate?.(); // Notify parent
    } catch {
      setError("Failed to review request.");
      // Revert if needed, though usually strict consistency isn't critical here
      refreshAll().catch(() => {});
    } finally {
      setLoadingAction(null);
    }
  };

  const [newRequestType, setNewRequestType] = useState("join");
  const [requestModels, setRequestModels] = useState<string[]>([]);
  const [requestDailyTokenLimit, setRequestDailyTokenLimit] = useState<string>("");
  const [requestMonthlyTokenLimit, setRequestMonthlyTokenLimit] = useState<string>("");
  const [requestDailyRequestLimit, setRequestDailyRequestLimit] = useState<string>("");
  const [requestMonthlyRequestLimit, setRequestMonthlyRequestLimit] = useState<string>("");
  const [requestTools, setRequestTools] = useState<string[]>([]);
  const [requestDetails, setRequestDetails] = useState<string>("");
  const [requestUploadAccess, setRequestUploadAccess] = useState(true);

  useEffect(() => {
    if (!open) return;
    setRequestModels([]);
    setRequestDailyTokenLimit("");
    setRequestMonthlyTokenLimit("");
    setRequestDailyRequestLimit("");
    setRequestMonthlyRequestLimit("");
    setRequestTools([]);
    setRequestDetails("");
    setRequestUploadAccess(true);
  }, [newRequestType, open]);

  const handleCreateRequest = async () => {
    setError(null);
    try {
      let payloadObj: Record<string, unknown> = {};
      let targetSpaceId = space.id;
      if (newRequestType === "model_access") {
        payloadObj = { allowed_models: requestModels };
      } else if (newRequestType === "tool_access") {
        payloadObj = { allowed_tools: requestTools };
      } else if (newRequestType === "quota_change") {
        payloadObj = {
          allowed_models: requestModels,
          daily_token_limit: requestDailyTokenLimit === "" ? null : Number(requestDailyTokenLimit),
          monthly_token_limit: requestMonthlyTokenLimit === "" ? null : Number(requestMonthlyTokenLimit),
          daily_request_limit: requestDailyRequestLimit === "" ? null : Number(requestDailyRequestLimit),
          monthly_request_limit: requestMonthlyRequestLimit === "" ? null : Number(requestMonthlyRequestLimit),
        };
      } else if (newRequestType === "join") {
        if (!joinSpaceId) {
          setError("Please select a space to join.");
          return;
        }
        targetSpaceId = joinSpaceId;
      } else if (newRequestType === "upload_access") {
        payloadObj = { can_upload_documents: requestUploadAccess };
      } else if (newRequestType === "other") {
        payloadObj = { details: requestDetails.trim() };
      }

      const { data } = await createSpaceRequest(targetSpaceId, { type: newRequestType, payload: payloadObj });
      setRequests((prev) => [data, ...prev]);
      setTab("requests");
    } catch {
      setError("Failed to create request.");
    }
  };

  const handleSystemPromptChange = (field: keyof SystemPrompts) => (event: ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value;
    setDraftPrompts((prev) => (prev ? { ...prev, [field]: value } : prev));
    setSystemPromptsSaved(false);
  };

  const handleSaveSystemPrompts = async () => {
    if (!draftPrompts) return;
    setSystemPromptsSaving(true);
    setSystemPromptsError(null);
    try {
      const { data } = await updateSystemPrompts(draftPrompts);
      setSystemPrompts(data);
      setDraftPrompts(data);
      setSystemPromptsSaved(true);
    } catch {
      setSystemPromptsError("Unable to save system prompts.");
    } finally {
      setSystemPromptsSaving(false);
    }
  };

  const handleResetSystemPrompts = () => {
    if (systemPrompts) {
      setDraftPrompts(systemPrompts);
      setSystemPromptsSaved(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="lg" fullWidth>
      <DialogTitle>
        <Stack spacing={0.5}>
          <Typography variant="h6" fontWeight={700}>
            إعدادات الجلسة القانونية
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {space.name}
          </Typography>
        </Stack>
      </DialogTitle>
      <DialogContent dividers>
        {error ? <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert> : null}

        <Tabs value={tab} onChange={(_, v) => setTab(String(v))} sx={{ mb: 2 }}>
          <Tab value="requests" label="الطلبات" />
          {isSpaceAdmin ? <Tab value="members" label="الأعضاء" /> : null}
          {isSpaceAdmin ? <Tab value="policy" label="الصلاحيات" /> : null}
          {isSpaceAdmin ? <Tab value="usage" label="الاستخدام" /> : null}
          <Tab value="settings" label="الإعدادات" />
        </Tabs>

        {loading ? (
          <Stack direction="row" spacing={1} alignItems="center" justifyContent="center" sx={{ py: 6 }}>
            <CircularProgress size={22} />
            <Typography color="text.secondary">Loading…</Typography>
          </Stack>
        ) : (
          <>
            {tab === "members" && (
              <Stack spacing={2}>
                {!isSpaceAdmin ? (
                  <Alert severity="info">You can view members, but only space admins can change roles or revoke users.</Alert>
                ) : null}

                <Card variant="outlined">
                  <CardContent>
                    <Stack spacing={1.5}>
                      <Typography fontWeight={700}>دعوة عضو</Typography>
                      <Stack direction={{ xs: "column", md: "row" }} spacing={1} alignItems={{ md: "center" }}>
                        <TextField
                          fullWidth
                          size="small"
                          label="Email"
                          value={inviteEmail}
                          onChange={(e) => setInviteEmail(e.target.value)}
                        />
                        <Button variant="contained" onClick={handleInvite} disabled={!isSpaceAdmin || !inviteEmail.trim()}>
                          Invite
                        </Button>
                      </Stack>
                      {inviteToken ? (
                        <Alert severity="success">Invite token: {inviteToken}</Alert>
                      ) : null}
                    </Stack>
                  </CardContent>
                </Card>

                <Card variant="outlined">
                  <CardContent>
                    <Typography fontWeight={700} sx={{ mb: 1 }}>
                      الأعضاء
                    </Typography>
                    <Divider sx={{ mb: 2 }} />

                    <Stack spacing={1.5}>
                      {members.map((m) => (
                        <Box
                          key={m.user_id}
                          sx={{
                            display: "flex",
                            flexDirection: { xs: "column", md: "row" },
                            gap: 1,
                            alignItems: { md: "center" },
                            justifyContent: "space-between",
                            border: "1px solid",
                            borderColor: "divider",
                            borderRadius: 2,
                            p: 1.5,
                          }}
                        >
                          <Stack spacing={0.25} sx={{ flex: 1 }}>
                            <Typography fontWeight={600}>
                              {m.email ? formatToolName(m.email.split("@")[0].replaceAll(".", " ")) : "Member"}
                            </Typography>
                            {m.email ? (
                              <Typography variant="body2" color="text.secondary">
                                {m.email}
                              </Typography>
                            ) : null}
                          </Stack>

                          <Stack direction={{ xs: "column", md: "row" }} spacing={1} alignItems={{ md: "center" }}>
                            <FormControl size="small" sx={{ minWidth: 140 }}>
                              <InputLabel>Role</InputLabel>
                              <Select
                                label="Role"
                                value={m.role}
                                onChange={(e) =>
                                  handleUpdateMember(m, { role: String(e.target.value) })
                                }
                                disabled={!isSpaceAdmin}
                              >
                                <MenuItem value="admin">admin</MenuItem>
                                <MenuItem value="member">member</MenuItem>
                              </Select>
                            </FormControl>

                            <Stack direction="row" spacing={1} alignItems="center" sx={{ minWidth: 170 }}>
                              <Typography variant="body2" color="text.secondary">
                                Upload
                              </Typography>
                              <Switch
                                checked={Boolean(m.can_upload_documents)}
                                onChange={(e) => handleUpdateMember(m, { can_upload_documents: e.target.checked })}
                                disabled={!isSpaceAdmin || (m.role ?? "").toLowerCase() === "admin"}
                                inputProps={{ "aria-label": "Toggle upload permission" }}
                              />
                            </Stack>

                            <FormControl size="small" sx={{ minWidth: 140 }}>
                              <InputLabel>Status</InputLabel>
                              <Select
                                label="Status"
                                value={m.status}
                                onChange={(e) =>
                                  handleUpdateMember(m, { status: String(e.target.value) })
                                }
                                disabled={!isSpaceAdmin}
                              >
                                <MenuItem value="active">active</MenuItem>
                                <MenuItem value="revoked">revoked</MenuItem>
                              </Select>
                            </FormControl>

                            <Button
                              size="small"
                              variant="outlined"
                              onClick={() => openOverridesEditor(m)}
                              disabled={!isSpaceAdmin}
                            >
                              Limits
                            </Button>
                          </Stack>
                        </Box>
                      ))}
                      {!members.length ? (
                        <Typography color="text.secondary">No members found.</Typography>
                      ) : null}
                    </Stack>
                  </CardContent>
                </Card>
              </Stack>
            )}

            {tab === "requests" && (
              <Stack spacing={2}>
                <Card variant="outlined">
                  <CardContent>
                    <Stack spacing={1}>
                      <Typography fontWeight={700}>صلاحياتك في هذه الجلسة</Typography>
                      <Typography variant="body2" color="text.secondary">
                        These are the models and limits that apply to you right now. On this page you can still request any model.
                      </Typography>
                      <Stack spacing={1}>
                        <Box>
                          <Typography variant="caption" color="text.secondary">
                            Allowed models
                          </Typography>
                          {effectivePolicy.allowed_models?.length ? (
                            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mt: 0.5 }}>
                              {effectivePolicy.allowed_models.map((m) => (
                                <Chip key={m} label={m} size="small" variant="outlined" />
                              ))}
                            </Stack>
                          ) : (
                            <Typography variant="body2" sx={{ mt: 0.25 }}>
                              Inherits server defaults
                            </Typography>
                          )}
                        </Box>

                        <Box>
                          <Typography variant="caption" color="text.secondary">
                            Allowed tools
                          </Typography>
                          {effectivePolicy.allowed_tools?.length ? (
                            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mt: 0.5 }}>
                              {effectivePolicy.allowed_tools.map((t) => (
                                <Chip key={t} label={formatToolName(t)} size="small" variant="outlined" />
                              ))}
                            </Stack>
                          ) : (
                            <Typography variant="body2" sx={{ mt: 0.25 }}>
                              No tools enabled
                            </Typography>
                          )}
                        </Box>

                        <Stack direction={{ xs: "column", md: "row" }} spacing={2} flexWrap="wrap" useFlexGap>
                          <Box>
                            <Typography variant="caption" color="text.secondary">
                              Daily tokens
                            </Typography>
                            <Typography variant="body2" fontWeight={600}>
                              {effectivePolicy.daily_token_limit == null ? "—" : Number(effectivePolicy.daily_token_limit).toLocaleString()}
                            </Typography>
                          </Box>
                          <Box>
                            <Typography variant="caption" color="text.secondary">
                              Monthly tokens
                            </Typography>
                            <Typography variant="body2" fontWeight={600}>
                              {effectivePolicy.monthly_token_limit == null ? "—" : Number(effectivePolicy.monthly_token_limit).toLocaleString()}
                            </Typography>
                          </Box>
                          <Box>
                            <Typography variant="caption" color="text.secondary">
                              Daily conversations
                            </Typography>
                            <Typography variant="body2" fontWeight={600}>
                              {effectivePolicy.daily_request_limit == null ? "—" : Number(effectivePolicy.daily_request_limit).toLocaleString()}
                            </Typography>
                          </Box>
                          <Box>
                            <Typography variant="caption" color="text.secondary">
                              Monthly conversations
                            </Typography>
                            <Typography variant="body2" fontWeight={600}>
                              {effectivePolicy.monthly_request_limit == null ? "—" : Number(effectivePolicy.monthly_request_limit).toLocaleString()}
                            </Typography>
                          </Box>
                          <Box>
                            <Typography variant="caption" color="text.secondary">
                              Daily tool requests
                            </Typography>
                            <Typography variant="body2" fontWeight={600}>
                              {effectivePolicy.daily_tool_request_limit == null ? "—" : Number(effectivePolicy.daily_tool_request_limit).toLocaleString()}
                            </Typography>
                          </Box>
                          <Box>
                            <Typography variant="caption" color="text.secondary">
                              Monthly tool requests
                            </Typography>
                            <Typography variant="body2" fontWeight={600}>
                              {effectivePolicy.monthly_tool_request_limit == null ? "—" : Number(effectivePolicy.monthly_tool_request_limit).toLocaleString()}
                            </Typography>
                          </Box>
                        </Stack>
                      </Stack>
                    </Stack>
                  </CardContent>
                </Card>

                <Card variant="outlined">
                  <CardContent>
                    <Typography fontWeight={700} sx={{ mb: 1 }}>
                      Create request
                    </Typography>
                    <Stack spacing={1.5}>
                      <FormControl size="small" fullWidth>
                        <InputLabel id="req-type-label">نوع الطلب</InputLabel>
                        <Select
                          labelId="req-type-label"
                          label="نوع الطلب"
                          value={newRequestType}
                          onChange={(e) => setNewRequestType(String(e.target.value))}
                        >
                          <MenuItem value="join">طلب انضمام</MenuItem>
                          <MenuItem value="model_access">صلاحية النموذج</MenuItem>
                          <MenuItem value="tool_access">صلاحية الأداة</MenuItem>
                          <MenuItem value="quota_change">تغيير الحصة</MenuItem>
                          <MenuItem value="upload_access">صلاحية الرفع</MenuItem>
                          <MenuItem value="other">أخرى</MenuItem>
                        </Select>
                        <FormHelperText>سيُرسل إلى مشرفي الجلسة للمراجعة.</FormHelperText>
                      </FormControl>

                      {availableModelsError ? <Alert severity="warning">{availableModelsError}</Alert> : null}

                      {newRequestType === "join" ? (
                        <Stack spacing={1}>
                          {availableSpacesError ? <Alert severity="warning">{availableSpacesError}</Alert> : null}
                          {availableSpacesLoading ? (
                            <Stack direction="row" spacing={1} alignItems="center">
                              <CircularProgress size={18} />
                              <Typography variant="body2" color="text.secondary">
                                جارٍ تحميل الجلسات المتاحة…
                              </Typography>
                            </Stack>
                          ) : availableSpaces.length ? (
                            <FormControl size="small" fullWidth>
                              <InputLabel id="join-space-label">اختر جلسة</InputLabel>
                              <Select
                                labelId="join-space-label"
                                label="اختر جلسة"
                                value={joinSpaceId}
                                onChange={(e) => setJoinSpaceId(String(e.target.value))}
                              >
                                {availableSpaces.map((s) => (
                                  <MenuItem key={s.id} value={s.id}>
                                    {s.name}
                                  </MenuItem>
                                ))}
                              </Select>
                              <FormHelperText>اختر جلسة لطلب الوصول.</FormHelperText>
                            </FormControl>
                          ) : (
                            <Typography variant="body2" color="text.secondary">
                              لا توجد جلسات متاحة للانضمام حالياً.
                            </Typography>
                          )}
                        </Stack>
                      ) : null}

                      {newRequestType === "model_access" ? (
                        <Autocomplete
                          multiple
                          options={availableModels}
                          value={requestModels}
                          onChange={(_, value) => setRequestModels(value)}
                          filterSelectedOptions
                          renderTags={(value, getTagProps) =>
                            value.map((option, index) => (
                              <Chip variant="outlined" label={option} {...getTagProps({ index })} key={option} />
                            ))
                          }
                          renderInput={(params) => (
                            <TextField
                              {...params}
                              label="النماذج المطلوبة"
                              placeholder={availableModels.length ? "اختر نماذج" : "لا توجد نماذج"}
                            />
                          )}
                        />
                      ) : null}

                      {newRequestType === "tool_access" ? (
                        <Autocomplete
                          multiple
                          options={ADVANCED_TOOL_OPTIONS}
                          value={requestTools}
                          onChange={(_, value) => setRequestTools(value)}
                          filterSelectedOptions
                          renderOption={(props, option) => (
                            <li {...props}>{formatToolName(option)}</li>
                          )}
                          renderTags={(value, getTagProps) =>
                            value.map((option, index) => (
                              <Chip variant="outlined" label={formatToolName(option)} {...getTagProps({ index })} key={option} />
                            ))
                          }
                          renderInput={(params) => (
                            <TextField
                              {...params}
                              label="الأدوات المطلوبة"
                              placeholder={ADVANCED_TOOL_OPTIONS.length ? "اختر أدوات" : "لا توجد أدوات"}
                              helperText="الأدوات المتقدمة تتطلب موافقة المشرف."
                            />
                          )}
                        />
                      ) : null}

                      {newRequestType === "quota_change" ? (
                        <Stack spacing={1.5}>
                          <Autocomplete
                            multiple
                            options={availableModels}
                            value={requestModels}
                            onChange={(_, value) => setRequestModels(value)}
                            filterSelectedOptions
                            renderTags={(value, getTagProps) =>
                              value.map((option, index) => (
                                <Chip variant="outlined" label={option.replace(/_/g, " ")} {...getTagProps({ index })} key={option} />
                              ))
                            }
                            renderInput={(params) => (
                              <TextField
                                {...params}
                                label="النماذج المطلوبة (اختياري)"
                                placeholder={availableModels.length ? "اختر نماذج" : "لا توجد نماذج"}
                              />
                            )}
                          />
                          <Stack direction={{ xs: "column", md: "row" }} spacing={1.5}>
                            <Autocomplete
                              freeSolo
                              fullWidth
                              sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                              options={TOKEN_LIMIT_OPTIONS.map(String)}
                              value={asTokenOption(requestDailyTokenLimit)}
                              onInputChange={(_, value) => setRequestDailyTokenLimit(value)}
                              renderInput={(params) => (
                                <TextField
                                  {...params}
                                  label="حد الرصيد اليومي"
                                  helperText="اختر قيمة أو اكتبها"
                                  inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                                  fullWidth
                                />
                              )}
                            />
                            <Autocomplete
                              freeSolo
                              fullWidth
                              sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                              options={TOKEN_LIMIT_OPTIONS.map(String)}
                              value={asTokenOption(requestMonthlyTokenLimit)}
                              onInputChange={(_, value) => setRequestMonthlyTokenLimit(value)}
                              renderInput={(params) => (
                                <TextField
                                  {...params}
                                  label="حد الرصيد الشهري"
                                  helperText="اختر قيمة أو اكتبها"
                                  inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                                  fullWidth
                                />
                              )}
                            />
                          </Stack>
                          <Stack direction={{ xs: "column", md: "row" }} spacing={1.5}>
                            <Autocomplete
                              freeSolo
                              fullWidth
                              sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                              options={REQUEST_LIMIT_OPTIONS.map(String)}
                              value={asRequestOption(requestDailyRequestLimit)}
                              onInputChange={(_, value) => setRequestDailyRequestLimit(value)}
                              renderInput={(params) => (
                                <TextField
                                  {...params}
                                  label="حد الطلبات اليومي"
                                  helperText="اختر قيمة أو اكتبها"
                                  inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                                  fullWidth
                                />
                              )}
                            />
                            <Autocomplete
                              freeSolo
                              fullWidth
                              sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                              options={REQUEST_LIMIT_OPTIONS.map(String)}
                              value={asRequestOption(requestMonthlyRequestLimit)}
                              onInputChange={(_, value) => setRequestMonthlyRequestLimit(value)}
                              renderInput={(params) => (
                                <TextField
                                  {...params}
                                  label="حد الطلبات الشهري"
                                  helperText="اختر قيمة أو اكتبها"
                                  inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                                  fullWidth
                                />
                              )}
                            />
                          </Stack>
                        </Stack>
                      ) : null}

                      {newRequestType === "upload_access" ? (
                        <FormControl fullWidth>
                          <InputLabel id="req-upload-access">صلاحية الرفع</InputLabel>
                          <Select
                            labelId="req-upload-access"
                            label="صلاحية الرفع"
                            value={requestUploadAccess ? "allow" : "deny"}
                            onChange={(e) => setRequestUploadAccess(e.target.value === "allow")}
                          >
                            <MenuItem value="allow">طلب صلاحية الرفع</MenuItem>
                            <MenuItem value="deny">طلب إلغاء صلاحية الرفع</MenuItem>
                          </Select>
                        </FormControl>
                      ) : null}

                      {newRequestType === "other" ? (
                        <TextField
                          label="Details"
                          value={requestDetails}
                          onChange={(e) => setRequestDetails(e.target.value)}
                          multiline
                          minRows={3}
                          placeholder="اشرح ما تحتاجه وسبب الطلب"
                        />
                      ) : null}

                      <Button variant="contained" onClick={handleCreateRequest}>
                        إرسال الطلب
                      </Button>
                    </Stack>
                  </CardContent>
                </Card>

                <Card variant="outlined">
                  <CardContent>
                    <Typography fontWeight={700} sx={{ mb: 1 }}>
                      الطلبات
                    </Typography>
                    <Divider sx={{ mb: 2 }} />

                    <Stack spacing={1.5}>
                      {!isSpaceAdmin ? (
                        <Alert severity="info">
                          Only space admins can review requests history. You can still create a request above.
                        </Alert>
                      ) : null}
                      {requests.map((r) => (
                        <Box
                          key={r.id}
                          sx={{
                            border: "1px solid",
                            borderColor: "divider",
                            borderRadius: 2,
                            p: 1.5,
                          }}
                        >
                          <Stack direction={{ xs: "column", md: "row" }} spacing={1} justifyContent="space-between">
                            <Stack spacing={0.25}>
                              <Typography fontWeight={600}>
                                {(REQUEST_TYPE_LABELS[r.type] || r.type)} · {{ pending: "قيد الانتظار", approved: "مقبول", declined: "مرفوض" }[r.status] ?? r.status}
                              </Typography>
                              <Typography variant="caption" color="text.secondary">
                                {new Date(r.created_at).toLocaleString()} · {displayUser(r.user_id)}
                              </Typography>
                            </Stack>
                            {r.status === "pending" && isSpaceAdmin ? (
                              <Stack direction="row" spacing={1}>
                                <Button
                                  size="small"
                                  variant="contained"
                                  onClick={() => handleReview(r, "approved")}
                                  disabled={loadingAction === `review-${r.id}`}
                                  startIcon={loadingAction === `review-${r.id}` ? <CircularProgress size={16} /> : null}
                                >
                                  {loadingAction === `review-${r.id}` ? "جارٍ القبول..." : "قبول"}
                                </Button>
                                <Button
                                  size="small"
                                  variant="outlined"
                                  onClick={() => handleReview(r, "declined")}
                                  disabled={loadingAction === `review-${r.id}`}
                                  startIcon={loadingAction === `review-${r.id}` ? <CircularProgress size={16} /> : null}
                                >
                                  {loadingAction === `review-${r.id}` ? "جارٍ الرفض..." : "رفض"}
                                </Button>
                              </Stack>
                            ) : null}
                          </Stack>
                          <Box sx={{ mt: 1 }}>
                            <Typography variant="caption" color="text.secondary">
                              التفاصيل
                            </Typography>
                            <Box
                              sx={{
                                mt: 0.5,
                                p: 1,
                                borderRadius: 2,
                                border: "1px solid",
                                borderColor: "divider",
                                bgcolor: "background.paper",
                              }}
                            >
                              {renderRequestDetails(r)}
                            </Box>
                          </Box>
                        </Box>
                      ))}
                      {!requests.length ? (
                        <Typography color="text.secondary">لا توجد طلبات.</Typography>
                      ) : null}
                    </Stack>
                  </CardContent>
                </Card>
              </Stack>
            )}

            {tab === "policy" && (
              <Stack spacing={2}>
                {!isSpaceAdmin ? (
                  <Alert severity="info">Only space admins can change policy and quotas.</Alert>
                ) : null}

                <Card variant="outlined">
                  <CardContent>
                    <Stack spacing={2}>
                      <Typography fontWeight={700}>الصلاحيات والحدود</Typography>
                      {availableModelsError ? <Alert severity="warning">{availableModelsError}</Alert> : null}
                      <Autocomplete
                        multiple
                        freeSolo
                        options={availableModels}
                        value={policyModels}
                        onChange={(_, value) => setPolicyModels(value)}
                        filterSelectedOptions
                        disabled={!isSpaceAdmin}
                        renderTags={(value, getTagProps) =>
                          value.map((option, index) => (
                            <Chip variant="outlined" label={option} {...getTagProps({ index })} key={option} />
                          ))
                        }
                        renderInput={(params) => (
                          <TextField
                            {...params}
                            label="Allowed models"
                            placeholder={availableModels.length ? "Select models" : "No models available"}
                            helperText="Leave empty to inherit defaults."
                          />
                        )}
                      />
                      <Autocomplete
                        multiple
                        options={TOOL_OPTIONS}
                        value={policyTools}
                        onChange={(_, value) => setPolicyTools(value)}
                        filterSelectedOptions
                        disabled={!isSpaceAdmin}
                        renderOption={(props, option) => (
                          <li {...props}>{formatToolName(option)}</li>
                        )}
                        renderTags={(value, getTagProps) =>
                          value.map((option, index) => (
                            <Chip variant="outlined" label={formatToolName(option)} {...getTagProps({ index })} key={option} />
                          ))
                        }
                        renderInput={(params) => (
                          <TextField
                            {...params}
                            label="Allowed tools"
                            placeholder="Select tools"
                            helperText="Tools are disabled unless explicitly allowed."
                          />
                        )}
                      />
                      <Stack direction={{ xs: "column", md: "row" }} spacing={1.5}>
                        <Autocomplete
                          freeSolo
                          fullWidth
                          sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                          options={TOKEN_LIMIT_OPTIONS.map(String)}
                          value={asTokenOption(dailyTokenLimit)}
                          onInputChange={(_, value) => setDailyTokenLimit(value)}
                          renderInput={(params) => (
                            <TextField
                              {...params}
                              label="Daily token limit"
                              helperText="Select or type a value. Minimum 1,000 tokens."
                              inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                              fullWidth
                            />
                          )}
                        />
                        <Autocomplete
                          freeSolo
                          fullWidth
                          sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                          options={TOKEN_LIMIT_OPTIONS.map(String)}
                          value={asTokenOption(monthlyTokenLimit)}
                          onInputChange={(_, value) => setMonthlyTokenLimit(value)}
                          renderInput={(params) => (
                            <TextField
                              {...params}
                              label="Monthly token limit"
                              helperText="Select or type a value. Minimum 10,000 tokens."
                              inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                              fullWidth
                            />
                          )}
                        />
                      </Stack>
                      <Stack direction={{ xs: "column", md: "row" }} spacing={1.5}>
                        <Autocomplete
                          freeSolo
                          fullWidth
                          sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                          options={REQUEST_LIMIT_OPTIONS.map(String)}
                          value={asRequestOption(dailyRequestLimit)}
                          onInputChange={(_, value) => setDailyRequestLimit(value)}
                          renderInput={(params) => (
                            <TextField
                              {...params}
                              label="Daily request limit"
                              inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                              fullWidth
                            />
                          )}
                        />
                        <Autocomplete
                          freeSolo
                          fullWidth
                          sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                          options={REQUEST_LIMIT_OPTIONS.map(String)}
                          value={asRequestOption(monthlyRequestLimit)}
                          onInputChange={(_, value) => setMonthlyRequestLimit(value)}
                          renderInput={(params) => (
                            <TextField
                              {...params}
                              label="Monthly request limit"
                              inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                              fullWidth
                            />
                          )}
                        />
                      </Stack>
                      <Stack direction={{ xs: "column", md: "row" }} spacing={1.5}>
                        <Autocomplete
                          freeSolo
                          fullWidth
                          sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                          options={REQUEST_LIMIT_OPTIONS.map(String)}
                          value={asRequestOption(dailyToolRequestLimit)}
                          onInputChange={(_, value) => setDailyToolRequestLimit(value)}
                          renderInput={(params) => (
                            <TextField
                              {...params}
                              label="Daily tool request limit"
                              inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                              fullWidth
                            />
                          )}
                        />
                        <Autocomplete
                          freeSolo
                          fullWidth
                          sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                          options={REQUEST_LIMIT_OPTIONS.map(String)}
                          value={asRequestOption(monthlyToolRequestLimit)}
                          onInputChange={(_, value) => setMonthlyToolRequestLimit(value)}
                          renderInput={(params) => (
                            <TextField
                              {...params}
                              label="Monthly tool request limit"
                              inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                              fullWidth
                            />
                          )}
                        />
                      </Stack>
                      <Button variant="contained" onClick={handleSavePolicy} disabled={!isSpaceAdmin}>
                        Save policy
                      </Button>
                    </Stack>
                  </CardContent>
                </Card>
              </Stack>
            )}

            {tab === "usage" && (
              <AdminAnalyticsDashboard spaceId={space.id} />
            )}

            {tab === "settings" && (
              <Stack spacing={2}>
                <Card variant="outlined">
                  <CardContent>
                    <Stack spacing={1.5}>
                      <Stack spacing={0.25}>
                        <Typography fontWeight={700}>نصوص المساعد القانوني</Typography>
                        <Typography variant="body2" color="text.secondary">
                          تخصيص سلوك المساعد القانوني. التغييرات تُطبَّق على تجربتك الشخصية.
                        </Typography>
                      </Stack>

                      {systemPromptsError ? (
                        <Alert severity="error">{systemPromptsError}</Alert>
                      ) : null}

                      {systemPromptsLoading || !draftPrompts ? (
                        <Stack direction="row" spacing={1} alignItems="center">
                          <CircularProgress size={18} />
                          <Typography variant="body2" color="text.secondary">
                            Loading prompts…
                          </Typography>
                        </Stack>
                      ) : (
                        <Stack spacing={1.5}>
                          <TextField
                            label="Tools system prompt"
                            multiline
                            minRows={5}
                            value={draftPrompts.tools_system_prompt}
                            onChange={handleSystemPromptChange("tools_system_prompt")}
                            fullWidth
                          />
                          <TextField
                            label="Web search decision prompt"
                            multiline
                            minRows={4}
                            value={draftPrompts.web_search_decision_prompt}
                            onChange={handleSystemPromptChange("web_search_decision_prompt")}
                            fullWidth
                          />
                          <TextField
                            label="Memory system prompt"
                            multiline
                            minRows={4}
                            value={draftPrompts.memory_system_prompt}
                            onChange={handleSystemPromptChange("memory_system_prompt")}
                            fullWidth
                          />
                          <TextField
                            label="Stream system prompt"
                            multiline
                            minRows={4}
                            value={draftPrompts.stream_system_prompt}
                            onChange={handleSystemPromptChange("stream_system_prompt")}
                            fullWidth
                          />
                          <TextField
                            label="Answer-question system prompt"
                            multiline
                            minRows={4}
                            value={draftPrompts.answer_question_system_prompt}
                            onChange={handleSystemPromptChange("answer_question_system_prompt")}
                            fullWidth
                          />
                          <Stack direction={{ xs: "column", sm: "row" }} spacing={1} justifyContent="flex-end">
                            <Button variant="outlined" onClick={handleResetSystemPrompts} disabled={!systemPrompts || systemPromptsSaving}>
                              Reset changes
                            </Button>
                            <Button variant="contained" onClick={handleSaveSystemPrompts} disabled={systemPromptsSaving}>
                              {systemPromptsSaving ? "Saving…" : "Save prompts"}
                            </Button>
                          </Stack>
                          {systemPromptsSaved ? <Alert severity="success">Prompts saved.</Alert> : null}
                        </Stack>
                      )}
                    </Stack>
                  </CardContent>
                </Card>
              </Stack>
            )}
          </>
        )}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Close</Button>
      </DialogActions>

      <Dialog open={editOverridesOpen} onClose={() => setEditOverridesOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>حدود الأعضاء</DialogTitle>
        <DialogContent dividers>
          <Stack spacing={2}>
            <Typography variant="body2" color="text.secondary">
              {editTarget?.email ?? "Unknown user"}
            </Typography>
            {availableModelsError ? <Alert severity="warning">{availableModelsError}</Alert> : null}
            <Autocomplete
              multiple
              freeSolo
              options={availableModels}
              value={overrideModels}
              onChange={(_, value) => setOverrideModels(value)}
              filterSelectedOptions
              renderTags={(value, getTagProps) =>
                value.map((option, index) => (
                  <Chip variant="outlined" label={option.replace(/_/g, " ")} {...getTagProps({ index })} key={option} />
                ))
              }
              renderInput={(params) => (
                <TextField
                  {...params}
                  label="Allowed models"
                  placeholder={availableModels.length ? "Select models" : "No models available"}
                />
              )}
            />
            <Autocomplete
              multiple
              options={TOOL_OPTIONS}
              value={overrideTools}
              onChange={(_, value) => setOverrideTools(value)}
              filterSelectedOptions
              renderOption={(props, option) => (
                <li {...props}>{formatToolName(option)}</li>
              )}
              renderTags={(value, getTagProps) =>
                value.map((option, index) => (
                  <Chip variant="outlined" label={formatToolName(option)} {...getTagProps({ index })} key={option} />
                ))
              }
              renderInput={(params) => (
                <TextField
                  {...params}
                  label="Allowed tools"
                  placeholder="Select tools"
                />
              )}
            />
            <Stack direction={{ xs: "column", md: "row" }} spacing={1.5}>
              <Autocomplete
                freeSolo
                fullWidth
                sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                options={TOKEN_LIMIT_OPTIONS.map(String)}
                value={asTokenOption(overrideDailyTokenLimit)}
                onInputChange={(_, value) => setOverrideDailyTokenLimit(value)}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label="Daily token limit"
                    inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                    fullWidth
                  />
                )}
              />
              <Autocomplete
                freeSolo
                fullWidth
                sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                options={TOKEN_LIMIT_OPTIONS.map(String)}
                value={asTokenOption(overrideMonthlyTokenLimit)}
                onInputChange={(_, value) => setOverrideMonthlyTokenLimit(value)}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label="Monthly token limit"
                    inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                    fullWidth
                  />
                )}
              />
            </Stack>
            <Stack direction={{ xs: "column", md: "row" }} spacing={1.5}>
              <Autocomplete
                freeSolo
                fullWidth
                sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                options={REQUEST_LIMIT_OPTIONS.map(String)}
                value={asRequestOption(overrideDailyRequestLimit)}
                onInputChange={(_, value) => setOverrideDailyRequestLimit(value)}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label="Daily request limit"
                    inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                    fullWidth
                  />
                )}
              />
              <Autocomplete
                freeSolo
                fullWidth
                sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                options={REQUEST_LIMIT_OPTIONS.map(String)}
                value={asRequestOption(overrideMonthlyRequestLimit)}
                onInputChange={(_, value) => setOverrideMonthlyRequestLimit(value)}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label="Monthly request limit"
                    inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                    fullWidth
                  />
                )}
              />
            </Stack>
            <Stack direction={{ xs: "column", md: "row" }} spacing={1.5}>
              <Autocomplete
                freeSolo
                fullWidth
                sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                options={REQUEST_LIMIT_OPTIONS.map(String)}
                value={asRequestOption(overrideDailyToolLimit)}
                onInputChange={(_, value) => setOverrideDailyToolLimit(value)}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label="Daily tool request limit"
                    inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                    fullWidth
                  />
                )}
              />
              <Autocomplete
                freeSolo
                fullWidth
                sx={{ flex: 1, minWidth: { xs: "100%", md: 240 } }}
                options={REQUEST_LIMIT_OPTIONS.map(String)}
                value={asRequestOption(overrideMonthlyToolLimit)}
                onInputChange={(_, value) => setOverrideMonthlyToolLimit(value)}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label="Monthly tool request limit"
                    inputProps={{ ...params.inputProps, inputMode: "numeric" }}
                    fullWidth
                  />
                )}
              />
            </Stack>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditOverridesOpen(false)}>Cancel</Button>
          <Button variant="contained" onClick={handleSaveOverrides}>
            Save
          </Button>
        </DialogActions>
      </Dialog>
    </Dialog>
  );
};

export default SpaceAdminDialog;
