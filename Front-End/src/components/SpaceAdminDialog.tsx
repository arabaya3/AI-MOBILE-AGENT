import {
  Alert,
  alpha,
  Autocomplete,
  Avatar,
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
  InputAdornment,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Switch,
  Stack,
  Tab,
  Tabs,
  TextField,
  Typography,
} from "@mui/material";
import DeleteForeverIcon from "@mui/icons-material/DeleteForever";
import SettingsIcon from "@mui/icons-material/Settings";
import AddRoundedIcon from "@mui/icons-material/AddRounded";
import GroupWorkRoundedIcon from "@mui/icons-material/GroupWorkRounded";
import SearchRoundedIcon from "@mui/icons-material/SearchRounded";
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
import RefreshRoundedIcon from "@mui/icons-material/RefreshRounded";
import { AdminAnalyticsDashboard } from "./AdminAnalyticsDashboard";
import { DashboardView } from "./DashboardView";
import { formatToolName } from "../utils/formatters";

interface SpaceAdminDialogProps {
  open: boolean;
  onClose: () => void;
  space?: SpaceSummary | null;
  currentUserId: string;
  onUpdate?: () => void;
  initialTab?: string;
  /** Callback fired when user confirms "Delete Space" in the danger zone */
  onDeleteSpace?: (spaceId: string) => void;
  /** ── Space Management tab props ── */
  allSpaces?: SpaceSummary[];
  activeSpaceId?: string | null;
  onSelectSpace?: (spaceId: string) => void;
  onRefreshSpaces?: () => Promise<void>;
  onCreateSpace?: (name: string) => Promise<void>;
  onAcceptInvite?: (token: string) => Promise<void>;
  canManageSpaces?: boolean;
  spaceBusy?: boolean;
}

const REQUEST_TYPE_LABELS: Record<string, string> = {
  join: "Join Space",
  model_access: "Model Access",
  tool_access: "Tool Access",
  upload_access: "Upload Access",
  quota_change: "Quota Change",
  other: "Other",
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
    return "Daily limit cannot exceed monthly limit";
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

export const SpaceAdminDialog = ({
  open,
  onClose,
  space,
  onUpdate,
  initialTab,
  onDeleteSpace,
  allSpaces = [],
  activeSpaceId,
  onSelectSpace,
  onRefreshSpaces,
  onCreateSpace,
  onAcceptInvite,
  canManageSpaces = false,
  spaceBusy = false,
}: SpaceAdminDialogProps) => {
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
  const hasSpace = Boolean(space);

  // ── Spaces-tab local state ──
  const [spaceSearch, setSpaceSearch] = useState("");
  const [showAllSpaces, setShowAllSpaces] = useState(false);
  const [newSpaceName, setNewSpaceName] = useState("");
  const [joinToken, setJoinToken] = useState("");
  const [spaceFeedback, setSpaceFeedback] = useState<string | null>(null);
  const [spaceError, setSpaceError] = useState<string | null>(null);
  const [pendingSpaceAction, setPendingSpaceAction] = useState<"create" | "invite" | null>(null);

  // Delete confirmation state
  const [deleteConfirmationOpen, setDeleteConfirmationOpen] = useState(false);
  const [deleteConfirmationInput, setDeleteConfirmationInput] = useState("");

  const filteredAllSpaces = useMemo(
    () => allSpaces.filter((s) => s.name.toLowerCase().includes(spaceSearch.trim().toLowerCase())),
    [allSpaces, spaceSearch],
  );

  const handleCreateSpaceLocal = async () => {
    const trimmed = newSpaceName.trim();
    if (trimmed.length < 2) { setSpaceError("Space name must be at least 2 characters."); return; }
    setSpaceError(null); setSpaceFeedback(null); setPendingSpaceAction("create");
    try {
      await onCreateSpace?.(trimmed);
      setNewSpaceName("");
      setSpaceFeedback("Space created successfully.");
    } catch (err) { setSpaceError((err as Error).message || "Failed to create space."); }
    finally { setPendingSpaceAction(null); }
  };

  const handleAcceptInviteLocal = async () => {
    const trimmed = joinToken.trim();
    if (!trimmed) { setSpaceError("Invite token is required."); return; }
    setSpaceError(null); setSpaceFeedback(null); setPendingSpaceAction("invite");
    try {
      await onAcceptInvite?.(trimmed);
      setJoinToken("");
      setSpaceFeedback("Invite accepted. Space is now available.");
    } catch (err) { setSpaceError((err as Error).message || "Failed to accept invite."); }
    finally { setPendingSpaceAction(null); }
  };

  const effectivePolicy = useMemo(() => {
    if (!space) return {};
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
  }, [myMembership, space?.policy]);

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
            ["Daily tokens", payload.daily_token_limit] as [string, any],
            ["Monthly tokens", payload.monthly_token_limit] as [string, any],
            ["Daily requests", payload.daily_request_limit] as [string, any],
            ["Monthly requests", payload.monthly_request_limit] as [string, any],
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
    if (!space) return;
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

    // Always load available spaces so user can switch/join even without a current space
    setAvailableSpacesLoading(true);
    listAvailableSpaces()
      .then(({ data }) => {
        setAvailableSpaces(data);
        setAvailableSpacesError(null);
      })
      .catch(() => setAvailableSpacesError("Unable to load available spaces."))
      .finally(() => setAvailableSpacesLoading(false));

    if (!space) {
        setTab("spaces");
        return;
    }

    if (lastSpaceIdRef.current !== space.id) {
      initRef.current = false;
    }
    if (initRef.current) return;
    initRef.current = true;
    lastSpaceIdRef.current = space.id;
    const allowedTabs = ["spaces", "requests", "settings", "usage", ...(isSpaceAdmin ? ["members", "policy"] : [])];
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
  }, [open, space?.id, initialTab, isSpaceAdmin]);

  const handleInvite = async () => {
    if (!space) return;
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
    if (!space) return;
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
    if (!space) return;
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
    if (!editTarget || !space) return;
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
    if (!space) return;
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
      let targetSpaceId = space?.id ?? "";
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
      setSystemPromptsSaved(true);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle>
        <Stack direction="row" alignItems="center" spacing={2}>
          <Avatar sx={{ bgcolor: "primary.main", width: 48, height: 48 }}>
            <SettingsIcon fontSize="medium" />
          </Avatar>
          <Stack>
            <Typography variant="h6" fontWeight={700}>
              Space Settings
            </Typography>
            {space ? (
              <Typography variant="body2" color="text.secondary">
                {space.name}
              </Typography>
            ) : (
              <Typography variant="body2" color="text.secondary">
                No space selected. Please join or create a space.
              </Typography>
            )}
          </Stack>
        </Stack>
      </DialogTitle>
      <DialogContent dividers>
        {error ? <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert> : null}

        <Tabs value={tab} onChange={(_, v) => setTab(String(v))} sx={{ mb: 2 }} variant="scrollable" scrollButtons="auto">
          <Tab value="spaces" label="Spaces" />
          {hasSpace && <Tab value="requests" label="Requests" />}
          {hasSpace && isSpaceAdmin && <Tab value="members" label="Members" />}
          {hasSpace && isSpaceAdmin && <Tab value="policy" label="Policy" />}
          {hasSpace && isSpaceAdmin && <Tab value="usage" label="Usage" />}
          {hasSpace && <Tab value="settings" label="Settings" />}
        </Tabs>

        {loading ? (
          <Stack direction="row" spacing={1} alignItems="center" justifyContent="center" sx={{ py: 6 }}>
            <CircularProgress size={22} />
            <Typography color="text.secondary">Loading…</Typography>
          </Stack>
        ) : (
          <>
            {tab === "spaces" && (
              <Stack spacing={3}>
                {/* Search */}
                <TextField
                  fullWidth
                  size="small"
                  placeholder="Search spaces…"
                  value={spaceSearch}
                  onChange={(e) => { setSpaceSearch(e.target.value); setShowAllSpaces(false); }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <SearchRoundedIcon fontSize="small" />
                      </InputAdornment>
                    ),
                  }}
                />

                {/* Space list */}
                <DashboardView
                  spaces={allSpaces}
                  activeSpaceId={activeSpaceId ?? null}
                  onSelect={(id) => { onSelectSpace?.(id); onClose(); }}
                  list={showAllSpaces ? filteredAllSpaces : filteredAllSpaces.slice(0, 7)}
                />

                {!showAllSpaces && filteredAllSpaces.length > 7 && (
                  <Button size="small" variant="text" onClick={() => setShowAllSpaces(true)} sx={{ textTransform: "none", fontWeight: 700 }}>
                    View all
                  </Button>
                )}

                {!filteredAllSpaces.length && (
                  <Box sx={{ p: 2.5, textAlign: "center" }}>
                    <GroupWorkRoundedIcon color="disabled" fontSize="large" />
                    <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                      {allSpaces.length ? "No spaces match your search." : "No spaces yet. Create or join one to get started."}
                    </Typography>
                    {spaceSearch.trim() && (
                      <Button size="small" variant="text" onClick={() => { setSpaceSearch(""); setShowAllSpaces(false); }} sx={{ mt: 0.5, textTransform: "none", fontWeight: 700 }}>
                        Clear search
                      </Button>
                    )}
                  </Box>
                )}

                {/* Feedback / Error */}
                {spaceError && <Alert severity="error" onClose={() => setSpaceError(null)}>{spaceError}</Alert>}
                {spaceFeedback && <Alert severity="success" onClose={() => setSpaceFeedback(null)}>{spaceFeedback}</Alert>}

                {/* Join space */}
                <Stack spacing={1.5}>
                  <Typography variant="subtitle2" color="text.secondary">Join a space</Typography>
                  <TextField
                    size="small"
                    label="Invite token"
                    value={joinToken}
                    onChange={(e) => setJoinToken(e.target.value)}
                    placeholder="Paste invite token"
                    disabled={pendingSpaceAction === "invite"}
                  />
                  <Button
                    variant="outlined"
                    onClick={handleAcceptInviteLocal}
                    disabled={pendingSpaceAction === "invite" || !joinToken.trim()}
                    startIcon={pendingSpaceAction === "invite" ? <CircularProgress size={16} /> : null}
                  >
                    {pendingSpaceAction === "invite" ? "Joining…" : "Join space"}
                  </Button>
                </Stack>

                {/* Create space */}
                {canManageSpaces && (
                  <Stack spacing={1.5}>
                    <Divider />
                    <Typography variant="subtitle2" color="text.secondary">Create new space</Typography>
                    <TextField
                      size="small"
                      label="Space name"
                      value={newSpaceName}
                      onChange={(e) => setNewSpaceName(e.target.value)}
                      placeholder="e.g. Marketing"
                      disabled={pendingSpaceAction === "create"}
                    />
                    <Button
                      variant="contained"
                      startIcon={pendingSpaceAction === "create" ? <CircularProgress size={16} /> : <AddRoundedIcon />}
                      onClick={handleCreateSpaceLocal}
                      disabled={pendingSpaceAction === "create" || spaceBusy}
                    >
                      {pendingSpaceAction === "create" ? "Creating…" : "Create space"}
                    </Button>
                  </Stack>
                )}

                {/* Refresh */}
                {onRefreshSpaces && (
                  <Button
                    size="small"
                    variant="text"
                    startIcon={<RefreshRoundedIcon fontSize="small" />}
                    onClick={onRefreshSpaces}
                    disabled={spaceBusy}
                    sx={{ alignSelf: "flex-start", textTransform: "none" }}
                  >
                    Refresh spaces
                  </Button>
                )}
              </Stack>
            )}

            {tab === "members" && (
              <Stack spacing={2}>
                {!isSpaceAdmin ? (
                  <Alert severity="info">You can view members, but only space admins can change roles or revoke users.</Alert>
                ) : null}

                <Card variant="outlined">
                  <CardContent>
                    <Stack spacing={1.5}>
                      <Typography fontWeight={700}>Invite member</Typography>
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
                      Members
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
                      <Typography fontWeight={700}>Your access in this space</Typography>
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
                        <InputLabel id="req-type-label">Type</InputLabel>
                        <Select
                          labelId="req-type-label"
                          label="Type"
                          value={newRequestType}
                          onChange={(e) => setNewRequestType(String(e.target.value))}
                        >
                          <MenuItem value="join">Join space</MenuItem>
                          <MenuItem value="model_access">Model access</MenuItem>
                          <MenuItem value="tool_access">Tool access</MenuItem>
                          <MenuItem value="quota_change">Quota change</MenuItem>
                          <MenuItem value="upload_access">Upload access</MenuItem>
                          <MenuItem value="other">Other</MenuItem>
                        </Select>
                        <FormHelperText>Sent to space admins for review.</FormHelperText>
                      </FormControl>

                      {availableModelsError ? <Alert severity="warning">{availableModelsError}</Alert> : null}

                      {newRequestType === "join" ? (
                        <Stack spacing={1}>
                          {availableSpacesError ? <Alert severity="warning">{availableSpacesError}</Alert> : null}
                          {availableSpacesLoading ? (
                            <Stack direction="row" spacing={1} alignItems="center">
                              <CircularProgress size={18} />
                              <Typography variant="body2" color="text.secondary">
                                Loading available spaces…
                              </Typography>
                            </Stack>
                          ) : availableSpaces.length ? (
                            <FormControl size="small" fullWidth>
                              <InputLabel id="join-space-label">Space to join</InputLabel>
                              <Select
                                labelId="join-space-label"
                                label="Space to join"
                                value={joinSpaceId}
                                onChange={(e) => setJoinSpaceId(String(e.target.value))}
                              >
                                {availableSpaces.map((s) => (
                                  <MenuItem key={s.id} value={s.id}>
                                    {s.name}
                                  </MenuItem>
                                ))}
                              </Select>
                              <FormHelperText>Select a space to request access.</FormHelperText>
                            </FormControl>
                          ) : (
                            <Typography variant="body2" color="text.secondary">
                              No available spaces to join right now.
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
                              label="Requested models"
                              placeholder={availableModels.length ? "Select models" : "No models available"}
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
                              label="Requested tools"
                              placeholder={ADVANCED_TOOL_OPTIONS.length ? "Select tools" : "No tools available"}
                              helperText="Advanced tools require admin approval."
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
                                label="Requested models (optional)"
                                placeholder={availableModels.length ? "Select models" : "No models available"}
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
                                  label="Daily token limit"
                                  helperText="Select or type a value"
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
                                  label="Monthly token limit"
                                  helperText="Select or type a value"
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
                                  label="Daily request limit"
                                  helperText="Select or type a value"
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
                                  label="Monthly request limit"
                                  helperText="Select or type a value"
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
                          <InputLabel id="req-upload-access">Upload permission</InputLabel>
                          <Select
                            labelId="req-upload-access"
                            label="Upload permission"
                            value={requestUploadAccess ? "allow" : "deny"}
                            onChange={(e) => setRequestUploadAccess(e.target.value === "allow")}
                          >
                            <MenuItem value="allow">Request upload permission</MenuItem>
                            <MenuItem value="deny">Request removal of upload permission</MenuItem>
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
                          placeholder="Describe what you need and why"
                        />
                      ) : null}

                      <Button variant="contained" onClick={handleCreateRequest}>
                        Submit request
                      </Button>
                    </Stack>
                  </CardContent>
                </Card>

                <Card variant="outlined">
                  <CardContent>
                    <Typography fontWeight={700} sx={{ mb: 1 }}>
                      Requests
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
                                {(REQUEST_TYPE_LABELS[r.type] || r.type)} · {r.status.charAt(0).toUpperCase() + r.status.slice(1)}
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
                                  {loadingAction === `review-${r.id}` ? "Approving..." : "Approve"}
                                </Button>
                                <Button
                                  size="small"
                                  variant="outlined"
                                  onClick={() => handleReview(r, "declined")}
                                  disabled={loadingAction === `review-${r.id}`}
                                  startIcon={loadingAction === `review-${r.id}` ? <CircularProgress size={16} /> : null}
                                >
                                  {loadingAction === `review-${r.id}` ? "Declining..." : "Decline"}
                                </Button>
                              </Stack>
                            ) : null}
                          </Stack>
                          <Box sx={{ mt: 1 }}>
                            <Typography variant="caption" color="text.secondary">
                              Details
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
                        <Typography color="text.secondary">No requests found.</Typography>
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
                      <Typography fontWeight={700}>Policy & quotas</Typography>
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

            {tab === "usage" && space && (
              <AdminAnalyticsDashboard spaceId={space.id} />
            )}

            {tab === "settings" && (
              <Stack spacing={2}>
                <Card variant="outlined">
                  <CardContent>
                    <Stack spacing={1.5}>
                      <Stack spacing={0.25}>
                        <Typography fontWeight={700}>System prompts</Typography>
                        <Typography variant="body2" color="text.secondary">
                          Customize assistant behavior. Changes apply to your personal experience.
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

                {/* ── Danger Zone ─────────────────────────────────── */}
                {onDeleteSpace && isSpaceAdmin && (
                  <Card variant="outlined" sx={{ borderColor: "error.main" }}>
                    <CardContent>
                      <Typography variant="h6" color="error" gutterBottom fontWeight={700}>
                        Danger Zone
                      </Typography>
                      <Paper
                        variant="outlined"
                        sx={{
                          p: 2.5,
                          borderColor: "error.main",
                          bgcolor: (theme) => alpha(theme.palette.error.main, 0.04),
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "space-between",
                          gap: 2,
                        }}
                      >
                        <Box>
                          <Typography variant="subtitle1" fontWeight={700} color="error">
                            Delete this Space
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            Once you delete a space, there is no going back. Please be certain.
                          </Typography>
                        </Box>
                        <Button
                          variant="outlined"
                          color="error"
                          startIcon={<DeleteForeverIcon />}
                          onClick={() => {
                            setDeleteConfirmationInput("");
                            setDeleteConfirmationOpen(true);
                          }}
                          sx={{ flexShrink: 0 }}
                          disabled={!space}
                        >
                          Delete Space
                        </Button>
                      </Paper>
                    </CardContent>
                  </Card>
                )}
              </Stack>
            )}
          </>
        )}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Close</Button>
      </DialogActions>

      <Dialog open={deleteConfirmationOpen} onClose={() => setDeleteConfirmationOpen(false)} maxWidth="xs">
        <DialogTitle sx={{ color: "error.main", fontWeight: 700 }}>Confirm Space Deletion</DialogTitle>
        <DialogContent>
          <Typography gutterBottom>
            This action cannot be undone. This will permanently delete the space <b>{space?.name}</b> and all associated data, files, and users.
          </Typography>
          <Typography variant="body2" sx={{ mt: 2, mb: 1 }}>
            Please type in the name of the space to confirm.
          </Typography>
          <TextField
              size="small"
              fullWidth
              autoFocus
              label="Space name"
              value={deleteConfirmationInput}
              onChange={(e) => setDeleteConfirmationInput(e.target.value)}
              placeholder={space?.name}
              error={deleteConfirmationInput.trim() !== space?.name && deleteConfirmationInput !== ""}
          />
        </DialogContent>
        <DialogActions>
            <Button onClick={() => setDeleteConfirmationOpen(false)}>Cancel</Button>
            <Button
                color="error"
                variant="contained"
                disabled={deleteConfirmationInput.trim() !== space?.name}
                onClick={() => {
                   if (space) {
                    onDeleteSpace?.(space.id);
                    setDeleteConfirmationOpen(false);
                   }
                }}
            >
                Confirm Delete
            </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={editOverridesOpen} onClose={() => setEditOverridesOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Member limits</DialogTitle>
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
