import AutoFixHighRoundedIcon from "@mui/icons-material/AutoFixHighRounded";
import GavelRoundedIcon from "@mui/icons-material/GavelRounded";
import HistoryRoundedIcon from "@mui/icons-material/HistoryRounded";
import KeyboardDoubleArrowLeftRoundedIcon from "@mui/icons-material/KeyboardDoubleArrowLeftRounded";
import KeyboardDoubleArrowRightRoundedIcon from "@mui/icons-material/KeyboardDoubleArrowRightRounded";
import RefreshIcon from "@mui/icons-material/Refresh";
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  List,
  ListItemButton,
  ListItemText,
  LinearProgress,
  Popover, // Added Popover
  Snackbar,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
  useMediaQuery,
  useTheme,
  IconButton,
} from "@mui/material";
import type { AlertColor } from "@mui/material";
import { isAxiosError } from "axios";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import ReactMarkdown from "react-markdown";

import type { AccessibleDocument } from "../api/documents";
import { fetchAccessibleDocuments, uploadAndVectorizeDocument } from "../api/documents";
import type {
  ChatQueryPayload,
  ChatSessionSummary,
  ConversationMessage,
  UsageEvent,
  UsageSummary,
  UsageInvoice,
  VectorSearchMatch,
  ModelPricingEntry,
  ModelPricingResponse,
} from "../api/chat";
import {
  branchChatSession,
  downloadUsageInvoicePdf,
  exportChatSession,
  getChatSession,
  getSessionSummary,
  getUsageInvoice,
  getUsageSummary,
  listChatModels,
  listChatModelPricing,
  listChatSessions,
  listUsageEvents,
  reactToMessage,
  streamChatMessage,
} from "../api/chat";
import { acceptInvite, deleteSpace, getMyMembership } from "../api/spaces";
import type { SpaceSummary } from "../api/spaces";

import { AdminDocumentsPanel } from "../components/AdminDocumentsPanel";
import { AppHeader } from "../components/AppHeader";
import { ChatComposer } from "../components/ChatComposer";
import { ChatMessageList } from "../components/ChatMessageList";
import { DocumentSelector } from "../components/DocumentSelector";
import EditMessageDialog from "../components/EditMessageDialog";
import { FileUploadDialog } from "../components/FileUploadDialog";
import { RetrievalDiagnostics } from "../components/RetrievalDiagnostics";
import { SpaceAdminDialog } from "../components/SpaceAdminDialog";
import SpaceSidebar from "../components/SpaceSidebar";
import { SuperAdminDialog } from "../components/SuperAdminDialog";
import { LegalCasePanel } from "../components/LegalCasePanel";
import { ModelSelector } from "../components/ModelSelector";
import { MobileDrawer } from "../components/MobileDrawer";
import { UsageCard } from "../components/UsageCard";
import { useAuth } from "../context/AuthContext";
import { useSpace } from "../context/SpaceContext";
import { ThemeConfig } from "../styles/ThemeConfig";
import { formatToolName, formatUsdCost } from "../utils/formatters";

const SUGGESTED_PROMPTS = [
  // Civil & Tenancy
  "ما هي حقوقي كمستأجر في حالة رفض المالك إعادة التأمين؟",
  // Court procedure
  "كيف أرفع دعوى قضائية أمام المحاكم الفلسطينية وما هي الرسوم المطلوبة؟",
  // Family law
  "ما هي إجراءات الطلاق وحضانة الأطفال وفق قانون الأحوال الشخصية الفلسطيني؟",
  // Labor
  "ما هي حقوق العمال في حالة الفصل التعسفي وكيف أطالب بمستحقاتي؟",
  // Property
  "كيف أسجل ملكية عقارية أو أتحقق من صحة عقد البيع في السجل العقاري؟",
  // Inheritance
  "ما هي إجراءات توثيق الوصية وتوزيع الميراث وفق الشريعة الإسلامية والقانون الفلسطيني؟",
  // Criminal defense
  "ما هي حقوقي القانونية عند الاعتقال أو التوقيف وما هي إجراءات الإفراج بكفالة؟",
  // Land disputes
  "كيف أحل نزاع على أرض أو عقار وما هي الأدلة المطلوبة أمام محكمة الأراضي؟",
  // Administrative law
  "كيف أطعن في قرار إداري حكومي أو قرار صادر عن جهة رسمية؟",
  // Contracts
  "ما هي شروط صحة العقود التجارية وكيف أتعامل مع الإخلال بالعقد؟",
  // Human rights
  "ما هي الجهات التي يمكن التقدم إليها بشكوى انتهاك حقوق الإنسان في فلسطين؟",
  // Statute of limitations
  "ما هي مدد التقادم القانونية للدعاوى المدنية والجزائية في القانون الفلسطيني؟",
];

interface ChatPageProps {
  toggleTheme?: () => void;
}

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>; 
}

const clampTopK = (value: number) => {
  if (!Number.isFinite(value) || value <= 0) return 1;
  if (value > 20) return 20;
  return Math.floor(value);
};

const clampPercent = (value: number) => Math.min(100, Math.max(0, Math.round(value)));

const getUsagePercent = (used: number, limit?: number | null) => {
  if (!limit || limit <= 0) return 0;
  return clampPercent((used / limit) * 100);
};

const getPriceTier = (perMillion: number) => {
  if (perMillion >= 20) return "high";
  if (perMillion >= 5) return "medium";
  return "low";
};

const mergeModelCatalog = (...modelGroups: Array<string[] | undefined | null>) =>
  Array.from(new Set(modelGroups.flatMap((group) => (group ?? []).map((model) => model.trim()).filter(Boolean))))
    .sort((a, b) => a.localeCompare(b));

const ChatPage = ({ toggleTheme }: ChatPageProps) => {
  const { user, logout, changePassword } = useAuth();
  const navigate = useNavigate();
  const { spaces, activeSpaceId, selectSpace, refreshSpaces, createSpace: createSpaceInContext, isReady } = useSpace();
  const theme = useTheme();
  // Mobile breakpoint matches sidebar drawer logic
  const isMobile = useMediaQuery(theme.breakpoints.down("lg"));
  
  const [spacesAnchorEl, setSpacesAnchorEl] = useState<null | HTMLElement>(null);
  const handleOpenSpaces = (event: React.MouseEvent<HTMLElement>) => setSpacesAnchorEl(event.currentTarget);
  const handleCloseSpaces = () => setSpacesAnchorEl(null);
  const spacesOpen = Boolean(spacesAnchorEl);

  const [rightPanelOpen, setRightPanelOpen] = useState(true);
  const [legalPanelOpen, setLegalPanelOpen] = useState(true);
  const [mobileDrawerOpen, setMobileDrawerOpen] = useState(false);

  useEffect(() => {
    if (isMobile) {
      setRightPanelOpen(false);
    }
  }, [isMobile]);

  const activeSpace: SpaceSummary | undefined = useMemo(
    () => spaces.find((space) => space.id === activeSpaceId),
    [spaces, activeSpaceId],
  );
  const [canUpload, setCanUpload] = useState(false);
  const [spaceRole, setSpaceRole] = useState<string>("");

  const [sessions, setSessions] = useState<ChatSessionSummary[]>([]);
  const [sessionsLoading, setSessionsLoading] = useState(false);
  const [documents, setDocuments] = useState<AccessibleDocument[]>([]);
  const [documentsLoading, setDocumentsLoading] = useState(false);
  const [selectedDocs, setSelectedDocs] = useState<string[]>([]);

  const [topK, setTopK] = useState<number>(() => {
    const stored = Number(localStorage.getItem("lawtech_chat_top_k"));
    if (Number.isFinite(stored) && stored >= 1 && stored <= 20) {
      return Math.floor(stored);
    }
    return 5;
  });

  useEffect(() => {
    localStorage.setItem("lawtech_chat_top_k", String(topK));
  }, [topK]);

  const [messages, setMessages] = useState<ConversationMessage[]>([]);
  const [sources, setSources] = useState<VectorSearchMatch[]>([]);

  // Refs to avoid stale closures in stable callbacks without adding them to deps
  const isNewChatModeRef = useRef(false);
  const activeSessionIdRef = useRef<string | undefined>(undefined);
  const [activeSessionId, setActiveSessionId] = useState<string | undefined>(undefined);
  const [isNewChatMode, setIsNewChatMode] = useState(false);

  // Keep refs in sync so stable callbacks can read current values
  useEffect(() => { activeSessionIdRef.current = activeSessionId; }, [activeSessionId]);
  useEffect(() => { isNewChatModeRef.current = isNewChatMode; }, [isNewChatMode]);

  const [sending, setSending] = useState(false);
  const [isTyping, setIsTyping] = useState(false);

  const [uploadDialogOpen, setUploadDialogOpen] = useState(false);
  const [adminPanelOpen, setAdminPanelOpen] = useState(false);
  const [diagnosticsOpen, setDiagnosticsOpen] = useState(false);
  const [spaceAdminOpen, setSpaceAdminOpen] = useState(false);
  const [spaceAdminInitialTab, setSpaceAdminInitialTab] = useState<string | null>(null);
  const [superAdminOpen, setSuperAdminOpen] = useState(false);
  const [passwordDialogOpen, setPasswordDialogOpen] = useState(false);
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [summaryDialogOpen, setSummaryDialogOpen] = useState(false);
  const [summaryText, setSummaryText] = useState("");
  const [loadingSummary, setLoadingSummary] = useState(false);
  const [usageDialogOpen, setUsageDialogOpen] = useState(false);
  const [usageSummary, setUsageSummary] = useState<UsageSummary | null>(null);
  const [usageEvents, setUsageEvents] = useState<UsageEvent[]>([]);
  const [usageInvoice, setUsageInvoice] = useState<UsageInvoice | null>(null);
  const [usageLoading, setUsageLoading] = useState(false);
  const [models, setModels] = useState<string[]>([]);
  const [modelsError, setModelsError] = useState<string | null>(null);
  const [selectedModel, setSelectedModel] = useState<string>(() => {
    // Migrate legacy key on first load
    const legacy = localStorage.getItem("Lex-Tech_chat_model");
    if (legacy) {
      localStorage.setItem("lawtech_chat_model", legacy);
      localStorage.removeItem("Lex-Tech_chat_model");
      return legacy;
    }
    return localStorage.getItem("lawtech_chat_model") ?? "";
  });
  const [modelPricing, setModelPricing] = useState<Record<string, ModelPricingEntry>>({});
  const [modelAliases, setModelAliases] = useState<Record<string, string>>({});
  const [snackbar, setSnackbar] = useState<{ severity: AlertColor; message: string } | null>(null);
  const [editingMessageId, setEditingMessageId] = useState<string | null>(null);
  const [editText, setEditText] = useState("");
  const [spaceBusy, setSpaceBusy] = useState(false);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [deleteConfirmSpaceId, setDeleteConfirmSpaceId] = useState<string | null>(null);
  const [deleteConfirmBusy, setDeleteConfirmBusy] = useState(false);

  const [isOffline, setIsOffline] = useState(!navigator.onLine);
  const [installPrompt, setInstallPrompt] = useState<BeforeInstallPromptEvent | null>(null);

  const activeSession = useMemo(
    () => sessions.find((session) => session.id === activeSessionId),
    [sessions, activeSessionId],
  );

  useEffect(() => {
    const handleOnline = () => setIsOffline(false);
    const handleOffline = () => setIsOffline(true);
    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);
    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, []);

  useEffect(() => {
    const handler = (event: Event) => {
      event.preventDefault();
      setInstallPrompt(event as BeforeInstallPromptEvent);
    };
    window.addEventListener("beforeinstallprompt", handler as EventListener);
    return () => window.removeEventListener("beforeinstallprompt", handler as EventListener);
  }, []);

  const totalToolRequests = useMemo(() => {
    return (usageInvoice?.tool_usage ?? []).reduce((acc, item) => acc + (item.requests ?? 0), 0);
  }, [usageInvoice]);

  const resolvedModelPricing = useMemo(() => {
    if (!selectedModel) return null;
    const direct = modelPricing[selectedModel];
    if (direct) return direct;
    const alias = modelAliases[selectedModel];
    if (alias && modelPricing[alias]) return modelPricing[alias];
    return null;
  }, [modelAliases, modelPricing, selectedModel]);

  const selectedModelTier = useMemo(() => {
    if (!resolvedModelPricing) return null;
    const perMillion = Math.max(resolvedModelPricing.input ?? 0, resolvedModelPricing.output ?? 0);
    return getPriceTier(perMillion);
  }, [resolvedModelPricing]);

  const tokenUsagePercent = getUsagePercent(usageSummary?.total_tokens ?? 0, usageInvoice?.limits?.monthly_token_limit);
  const requestUsagePercent = getUsagePercent(
    usageSummary?.total_requests ?? 0,
    usageInvoice?.limits?.monthly_request_limit,
  );
  const toolUsagePercent = getUsagePercent(totalToolRequests, usageInvoice?.limits?.monthly_tool_request_limit);

  useEffect(() => {
    if (selectedModel) {
      localStorage.setItem("lawtech_chat_model", selectedModel);
    } else {
      localStorage.removeItem("lawtech_chat_model");
    }
  }, [selectedModel]);

  useEffect(() => {
    if (!isReady || !activeSpaceId) {
      setCanUpload(false);
      setSpaceRole("");
      return;
    }
    getMyMembership(activeSpaceId)
      .then(({ data }) => {
        const role = (data.role ?? "").toLowerCase();
        setSpaceRole(role);
        setCanUpload(role === "admin" || Boolean(data.can_upload_documents));
      })
      .catch(() => {
        setSpaceRole("");
        setCanUpload(false);
      });
  }, [isReady, activeSpaceId]);

  const isSpaceAdmin = spaceRole === "admin";

  const extractErrorMessage = useCallback((error: unknown, fallback: string) => {
    if (isAxiosError(error)) {
      const data = error.response?.data as Record<string, unknown> | undefined;
      const detail = typeof data?.detail === "string" ? data.detail : undefined;
      const message = typeof data?.message === "string" ? data.message : undefined;
      return detail || message || fallback;
    }
    return fallback;
  }, []);

  const loadDocuments = useCallback(async () => {
    if (!isReady || !activeSpaceId) {
      setDocuments([]);
      return;
    }
    setDocumentsLoading(true);
    try {
      const { data } = await fetchAccessibleDocuments(activeSpaceId ?? undefined);
      setDocuments(data);
    } catch (error) {
      setSnackbar({ severity: "error", message: extractErrorMessage(error, "Unable to load documents.") });
    } finally {
      setDocumentsLoading(false);
    }
  }, [activeSpaceId, extractErrorMessage, isReady]);

  const loadSession = useCallback(
    async (sessionId: string) => {
      try {
        const { data } = await getChatSession(sessionId);
        setActiveSessionId(sessionId);
        setIsNewChatMode(false);
        setMessages(data.history);
        setSources([]);
      } catch (error) {
        setSnackbar({ severity: "error", message: extractErrorMessage(error, "Unable to load conversation.") });
      }
    },
    [extractErrorMessage],
  );

  const loadSessions = useCallback(async (options?: { forceNewChat?: boolean }) => {
    const forceNewChat = Boolean(options?.forceNewChat);
    if (!isReady || !activeSpaceId) {
      setSessions([]);
      setActiveSessionId(undefined);
      setIsNewChatMode(false);
      setMessages([]);
      setSources([]);
      return;
    }
    setSessionsLoading(true);
    try {
      const { data } = await listChatSessions();
      setSessions(data);

      // Read refs to avoid making activeSessionId/isNewChatMode deps (which would destabilize the callback)
      const currentSessionId = activeSessionIdRef.current;
      const currentIsNewChat = isNewChatModeRef.current;
      const hasActive = currentSessionId ? data.some((session) => session.id === currentSessionId) : false;
      if (forceNewChat) {
        setActiveSessionId(undefined);
        setMessages([]);
        setSources([]);
      } else if (!hasActive) {
        if (currentIsNewChat) {
          // User explicitly asked for a blank new chat; don't auto-jump to an old session.
          setActiveSessionId(undefined);
          setMessages([]);
          setSources([]);
        } else {
          const nextSessionId = data[0]?.id;
          if (nextSessionId) {
            await loadSession(nextSessionId);
          } else {
            setActiveSessionId(undefined);
            setMessages([]);
            setSources([]);
          }
        }
      }
    } catch (error) {
      setSnackbar({ severity: "error", message: extractErrorMessage(error, "Unable to load chat sessions.") });
    } finally {
      setSessionsLoading(false);
    }
  // Stable: no activeSessionId/isNewChatMode — read via refs instead
  }, [isReady, activeSpaceId, extractErrorMessage, loadSession]); // eslint-disable-line react-hooks/exhaustive-deps

  // Lightweight refresh: only update the session list sidebar, never touch messages/activeSessionId.
  // Used after a successful send so streaming content is not wiped.
  const refreshSessionList = useCallback(async () => {
    if (!isReady || !activeSpaceId) return;
    try {
      const { data } = await listChatSessions();
      setSessions(data);
    } catch {
      // Non-critical — sidebar list just won't update until next full load
    }
  }, [isReady, activeSpaceId]);

  useEffect(() => {
    if (!isReady) {
      refreshSpaces().catch((error) => {
        setSnackbar({ severity: "error", message: extractErrorMessage(error, "Unable to load spaces.") });
      });
    }
  }, [isReady, refreshSpaces, extractErrorMessage]);

  useEffect(() => {
    if (!isReady || !activeSpaceId) {
      setModels([]);
      setModelsError(null);
      return;
    }

    Promise.all([listChatModels(), listChatModelPricing()])
      .then(([modelsResp, pricingResp]) => {
        const data = mergeModelCatalog(
          modelsResp.data,
          activeSpace?.policy?.allowed_models ?? [],
          selectedModel ? [selectedModel] : [],
        );
        setModels(data);
        if (!data || data.length === 0) {
          setModelsError("Using server default model");
        } else {
          setModelsError(null);
        }
        const pricingPayload = pricingResp.data as ModelPricingResponse | null;
        setModelPricing(pricingPayload?.pricing ?? {});
        setModelAliases(pricingPayload?.aliases ?? {});
      })
      .catch(() => {
        setModels([]);
        setModelsError("Using server default model");
        setModelPricing({});
        setModelAliases({});
      });
  }, [isReady, activeSpaceId, activeSpace?.policy?.allowed_models]);

  const refreshModels = useCallback(async () => {
    if (!isReady || !activeSpaceId) return;
    try {
      const [modelsResp, pricingResp] = await Promise.all([
        listChatModels(),
        listChatModelPricing(),
      ]);
      setModels(
        mergeModelCatalog(
          modelsResp.data,
          activeSpace?.policy?.allowed_models ?? [],
          selectedModel ? [selectedModel] : [],
        ),
      );
      setModelPricing(pricingResp.data.pricing ?? {});
      setModelAliases(pricingResp.data.aliases ?? {});
      setModelsError(null);
    } catch {
      // Keep prior state; Chat send will surface policy errors if any.
      setModelsError("Unable to load available models.");
    }
  }, [activeSpace?.policy?.allowed_models, activeSpaceId, isReady, selectedModel]);

  const PREFERRED_DEFAULT_MODEL = "gemini-2.0-flash-lite";

  useEffect(() => {
    if (models.length === 0) return;
    if (!selectedModel) {
      // Auto-select preferred default, or first available model
      const preferred = models.includes(PREFERRED_DEFAULT_MODEL) ? PREFERRED_DEFAULT_MODEL : models[0];
      setSelectedModel(preferred);
    } else if (!models.includes(selectedModel)) {
      // Reset if current selection is no longer available
      const preferred = models.includes(PREFERRED_DEFAULT_MODEL) ? PREFERRED_DEFAULT_MODEL : models[0];
      setSelectedModel(preferred ?? "");
    }
  }, [models]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!isReady || !activeSpaceId) {
      setSessions([]);
      setDocuments([]);
      setSelectedDocs([]);
      setActiveSessionId(undefined);
      setIsNewChatMode(false);
      setMessages([]);
      setSources([]);
      return;
    }
    setSelectedDocs([]);
    loadDocuments();
    void loadSessions(); // isNewChatModeRef is read inside loadSessions
  }, [isReady, activeSpaceId]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleToggleDocument = (documentId: string) => {
    setSelectedDocs((prev) => (prev.includes(documentId) ? prev.filter((id) => id !== documentId) : [...prev, documentId]));
  };

  const handleSend = useCallback(
    async (rawMessage: string, webSearchEnabled = false) => {
      const message = rawMessage.trim();
      if (!message) return;
      if (!activeSpaceId) {
        setSnackbar({ severity: "error", message: "Select a space before starting a chat." });
        return;
      }
      if (sending) return;

      const timestamp = Date.now();
      const userMessage: ConversationMessage = {
        id: `user-${timestamp}`,
        role: "user",
        content: message,
        created_at: new Date().toISOString(),
      };
      const assistantMessageId = `assistant-${timestamp}`;
      const assistantMessage: ConversationMessage = {
        id: assistantMessageId,
        role: "assistant",
        content: "",
        created_at: new Date().toISOString(),
      };

      setMessages((prev) => [...prev, userMessage]);
      setSources([]);
      setSending(true);
      setIsTyping(true);

      let streamedSessionId = activeSessionId;
      let assistantMessageAdded = false;

      const payload: ChatQueryPayload = { message };
      if (activeSessionId) payload.session_id = activeSessionId;
      if (selectedDocs.length) payload.document_ids = selectedDocs;
      payload.top_k = topK;
      if (selectedModel && models.includes(selectedModel)) payload.model = selectedModel;
      payload.use_web_search = webSearchEnabled;

      try {
        await streamChatMessage(payload, {
          onMeta: (meta) => {
            streamedSessionId = meta.session_id;
            setActiveSessionId(meta.session_id);
            setIsNewChatMode(false);
            if (meta.sources) {
              setSources(meta.sources);
            }
          },
          onDelta: (text) => {
            if (!assistantMessageAdded) {
              // Add assistant message on first content chunk
              setMessages((prev) => [...prev, assistantMessage]);
              assistantMessageAdded = true;
            }
            setMessages((prev) =>
              prev.map((msg) => (msg.id === assistantMessageId ? { ...msg, content: msg.content + text } : msg)),
            );
          },
          onError: (detail) => {
            setSnackbar({ severity: "error", message: detail || "Chat stream failed." });
          },
          onDone: async () => {
            setIsTyping(false);
            // Don't reload messages from DB here — the streamed content is already correct.
            // Only refresh the session list to update titles/timestamps.
          },
        });
        setIsTyping(false);
        await refreshSessionList();
      } catch (error) {
        setIsTyping(false);
        setMessages((prev) => prev.filter((msg) => msg.id !== assistantMessageId && msg.id !== userMessage.id));
        setSnackbar({ severity: "error", message: extractErrorMessage(error, "Chat request failed. Please try again.") });
      } finally {
        setSending(false);
      }
    },
    [activeSpaceId, activeSessionId, selectedDocs, topK, selectedModel, sending, refreshSessionList, extractErrorMessage],
  );

  const handleRegenerateResponse = async (messageId: string) => {
    const index = messages.findIndex((message) => message.id === messageId);
    if (index <= 0) return;
    const userMessage = messages[index - 1];
    setMessages((prev) => prev.slice(0, index));
    await handleSend(userMessage.content);
  };

  const handleEditMessage = async (messageId: string, newContent: string) => {
    const index = messages.findIndex((message) => message.id === messageId);
    if (index < 0) return;
    setMessages((prev) => prev.slice(0, index));
    setEditingMessageId(null);
    setEditText("");
    await handleSend(newContent);
  };

  const handleShareConversation = async () => {
    if (!activeSessionId) return;
    try {
      const { shareConversation } = await import("../api/share");
      const { data } = await shareConversation(activeSessionId);
      const shareUrl = `${window.location.origin}/api/v1${data.share_url}`;
      await navigator.clipboard.writeText(shareUrl);
      setSnackbar({ severity: "success", message: "تم نسخ رابط المشاركة إلى الحافظة." });
    } catch (error) {
      setSnackbar({ severity: "error", message: extractErrorMessage(error, "Failed to create share link.") });
    }
  };

  const handleBranchFromMessage = async (messageId: string) => {
    if (!activeSessionId) return;
    try {
      const { data } = await branchChatSession(activeSessionId, messageId);
      await loadSessions();
      await loadSession(data.session_id);
      setSnackbar({ severity: "success", message: "تم إنشاء فرع محادثة جديد." });
    } catch (error) {
      setSnackbar({ severity: "error", message: extractErrorMessage(error, "Failed to branch conversation.") });
    }
  };

  const handleReact = async (messageId: string, reaction: "up" | "down") => {
    try {
      await reactToMessage(messageId, reaction);
      setSnackbar({ severity: "success", message: "Thanks for the feedback." });
    } catch {
      setSnackbar({ severity: "error", message: "Failed to record reaction." });
    }
  };

  const handleExport = async (format: "json" | "md" = "md") => {
    if (!activeSessionId) return;
    try {
      const blob = await exportChatSession(activeSessionId, format);
      const url = window.URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = `conversation-${activeSessionId}.${format === "md" ? "md" : "json"}`;
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      window.URL.revokeObjectURL(url);
    } catch (error) {
      setSnackbar({ severity: "error", message: extractErrorMessage(error, "Failed to export conversation.") });
    }
  };

  const handleNewChat = async () => {
    setActiveSessionId(undefined);
    setIsNewChatMode(true);
    setMessages([]);
    setSources([]);
    try {
      await loadSessions({ forceNewChat: true });
    } catch {
      // Ignore refresh errors for blank chat UX
    }
  };

  const handleUpload = async (file: File) => {
    if (!canUpload) {
      setSnackbar({ severity: "error", message: "You don't have permission to upload documents." });
      return;
    }
    try {
      await uploadAndVectorizeDocument(file, activeSpaceId ?? undefined);
      await loadDocuments();
      setSnackbar({ severity: "success", message: "Document indexed successfully." });
    } catch (error) {
      const unauthorized = isAxiosError(error) && error.response?.status === 403;
      setSnackbar({
        severity: "error",
        message: unauthorized ? "You don't have permission to upload documents." : "Upload failed.",
      });
    }
  };

  const handlePasswordUpdate = async () => {
    try {
      setPasswordError(null);
      if (!currentPassword.trim()) {
        setPasswordError("Enter your current password.");
        return;
      }
      if (!newPassword.trim()) {
        setPasswordError("Enter a new password.");
        return;
      }
      if (newPassword !== confirmPassword) {
        setPasswordError("New passwords do not match.");
        return;
      }
      await changePassword(currentPassword, newPassword);
      setSnackbar({ severity: "success", message: "Password updated." });
      setPasswordDialogOpen(false);
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
    } catch (error) {
      setSnackbar({ severity: "error", message: extractErrorMessage(error, "Unable to update password.") });
    }
  };

  const handleGenerateSummary = async () => {
    if (!activeSessionId) {
      setSnackbar({ severity: "error", message: "No active session to summarize." });
      return;
    }
    setSummaryText("");
    setSummaryDialogOpen(true);
    setLoadingSummary(true);
    try {
      const { data } = await getSessionSummary(activeSessionId);
      setSummaryText(data.summary);
    } catch (error) {
      const message = extractErrorMessage(error, "Unable to generate summary.");
      setSummaryText(message);
      setSnackbar({ severity: "error", message });
    } finally {
      setLoadingSummary(false);
    }
  };

  const handleOpenUsage = async () => {
    setUsageDialogOpen(true);
    setUsageLoading(true);
    try {
      const [summaryResponse, eventsResponse, invoiceResponse] = await Promise.all([
        getUsageSummary({ days: 30, session_id: activeSessionId }),
        listUsageEvents({ limit: 50, session_id: activeSessionId }),
        getUsageInvoice({ days: 30 }),
      ]);
      setUsageSummary(summaryResponse.data);
      setUsageEvents(eventsResponse.data);
      setUsageInvoice(invoiceResponse.data);
    } catch (error) {
      setUsageSummary(null);
      setUsageEvents([]);
      setUsageInvoice(null);
      setSnackbar({ severity: "error", message: extractErrorMessage(error, "Unable to load usage history.") });
    } finally {
      setUsageLoading(false);
    }
  };

  const handleDownloadInvoice = async () => {
    try {
      const blob = await downloadUsageInvoicePdf(30);
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "usage-invoice.pdf";
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    } catch (error) {
      setSnackbar({ severity: "error", message: extractErrorMessage(error, "Unable to download invoice.") });
    }
  };

  const handleInstallPwa = async () => {
    if (!installPrompt) return;
    await installPrompt.prompt();
    await installPrompt.userChoice;
    setInstallPrompt(null);
  };

  const handleCreateSpaceFromSidebar = async (name: string) => {
    const trimmed = name.trim();
    if (trimmed.length < 2) {
      const message = "Space name must be at least 2 characters.";
      setSnackbar({ severity: "error", message });
      throw new Error(message);
    }
    setSpaceBusy(true);
    try {
      const created = await createSpaceInContext({ name: trimmed });
      setSnackbar({ severity: "success", message: `Space ${created.name} created.` });
      selectSpace(created.id);
      setMobileDrawerOpen(false);
      await refreshSpaces();
    } catch (error) {
      const message = extractErrorMessage(error, "Failed to create space.");
      setSnackbar({ severity: "error", message });
      throw new Error(message);
    } finally {
      setSpaceBusy(false);
    }
  };

  const handleAcceptInviteFromSidebar = async (token: string) => {
    const trimmed = token.trim();
    if (!trimmed) {
      const message = "Invite token is required.";
      setSnackbar({ severity: "error", message });
      throw new Error(message);
    }
    setSpaceBusy(true);
    try {
      const { data } = await acceptInvite({ token: trimmed });
      await refreshSpaces();
      if (data.space_id) {
        selectSpace(data.space_id);
      }
      setSnackbar({ severity: "success", message: "Invite accepted." });
    } catch (error) {
      const message = extractErrorMessage(error, "Failed to accept invite token.");
      setSnackbar({ severity: "error", message });
      throw new Error(message);
    } finally {
      setSpaceBusy(false);
    }
  };

  const handleDeleteSpaceFromSidebar = async (spaceId: string) => {
    setDeleteConfirmSpaceId(spaceId);
    setDeleteConfirmOpen(true);
  };

  const handleConfirmDeleteSpace = async () => {
    if (!deleteConfirmSpaceId) return;
    setDeleteConfirmBusy(true);
    setSpaceBusy(true);
    try {
      await deleteSpace(deleteConfirmSpaceId);
      setSnackbar({ severity: "success", message: "Space deleted." });
      setDeleteConfirmOpen(false);
      setDeleteConfirmSpaceId(null);
      await refreshSpaces();
    } catch (error) {
      const message = extractErrorMessage(error, "Failed to delete space.");
      setSnackbar({ severity: "error", message });
      throw new Error(message);
    } finally {
      setDeleteConfirmBusy(false);
      setSpaceBusy(false);
    }
  };

  return (
    <Box
      sx={{
        // Full-screen chat app using 100dvh for proper mobile viewport handling
        height: "100dvh",
        minHeight: "100dvh",
        bgcolor: "background.default",
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      {/* Minimal header - only essential navigation */}
      <AppHeader
        email={user?.email}
        role={user?.role}
        spaceName={activeSpace?.name}
        onLogout={logout}
        onChangePassword={() => setPasswordDialogOpen(true)}
        onToggleTheme={toggleTheme}
        onInstallPwa={handleInstallPwa}
        canInstall={Boolean(installPrompt)}
        isOffline={isOffline}
        onOpenAnalytics={() => {
          setSpaceAdminInitialTab(isSpaceAdmin ? "usage" : "requests");
          setSpaceAdminOpen(true);
        }}
        onOpenUsage={handleOpenUsage}
        onOpenSpaceAdmin={() => {
          setSpaceAdminInitialTab("members");
          setSpaceAdminOpen(true);
        }}
        onOpenSpaceOptions={() => {
          setSpaceAdminInitialTab("settings");
          setSpaceAdminOpen(true);
        }}
        onOpenDangerZone={() => {
          setSpaceAdminInitialTab("settings");
          setSpaceAdminOpen(true);
        }}
        onToggleSidebar={() => setMobileDrawerOpen(!mobileDrawerOpen)}
        onOpenSpaces={handleOpenSpaces}
        onOpenLaws={() => navigate("/laws")}
      />

      {/* Main chat container - fills remaining height */}
      <Box
        component="main"
        sx={{
          display: "flex",
          flex: 1,
          minHeight: 0,
          overflow: "hidden",
        }}
      >
        {!isReady ? (
          <Stack spacing={2} alignItems="center" justifyContent="center" sx={{ flex: 1, px: 3 }}>
            <CircularProgress />
            <Typography variant="body1">جارٍ تحضير منصة LawTech...</Typography>
            <Typography variant="body2" color="text.secondary">
              جارٍ تحميل جلساتك ونشاط استشاراتك القانونية.
            </Typography>
          </Stack>
        ) : !activeSpaceId ? (
          <Stack spacing={2} alignItems="center" justifyContent="center" sx={{ flex: 1, px: 3 }}>
            <Typography variant="h6" fontWeight={700}>
              اختر جلسة قضية للبدء
            </Typography>
            <Typography variant="body2" color="text.secondary">
              اختر جلسة قضية من القائمة أو أنشئ جلسة جديدة.
            </Typography>
          </Stack>
        ) : (
          <Box sx={{ display: "flex", flex: 1, minHeight: 0, width: "100%" }}>
            {/* Desktop: Optional right sidebar for documents/sessions */}
            {!isMobile && rightPanelOpen && (
              <Stack
                spacing={2}
                sx={{
                  width: 320,
                  flexShrink: 0,
                  borderRight: "none",
                  overflowY: "auto",
                  bgcolor: "background.paper",
                  p: 2,
                }}
              >
                <Box sx={{ mb: 2 }}>
                  <Typography variant="subtitle2" fontWeight={600} gutterBottom>
                    ملفات القضية
                  </Typography>
                  {documentsLoading ? (
                    <Stack spacing={1} alignItems="center" sx={{ py: 3 }}>
                      <CircularProgress size={20} />
                      <Typography variant="caption" color="text.secondary">
                        Loading...
                      </Typography>
                    </Stack>
                  ) : (
                    <Box sx={{ maxHeight: 300, overflowY: "auto" }}>
                      <DocumentSelector
                        documents={documents}
                        selected={selectedDocs}
                        onToggle={handleToggleDocument}
                        onUploadClick={() => setUploadDialogOpen(true)}
                        canUpload={canUpload}
                        canManagePermissions={isSpaceAdmin}
                        onManagePermissions={() => setAdminPanelOpen(true)}
                      />
                    </Box>
                  )}
                  <Stack direction="row" spacing={1} alignItems="center" sx={{ mt: 2 }}>
                    <Typography variant="caption" color="text.secondary">عمق البحث:</Typography>
                    <TextField
                      size="small"
                      type="number"
                      value={topK}
                      onChange={(event) => setTopK(clampTopK(Number(event.target.value)))}
                      inputProps={{ min: 1, max: 20 }}
                      sx={{ width: 80 }}
                    />
                  </Stack>
                </Box>

                <Divider />

                <Box sx={{ mt: 2 }}>
                  <Stack direction="row" alignItems="center" justifyContent="space-between" mb={1}>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <HistoryRoundedIcon fontSize="small" color="primary" />
                      <Typography variant="subtitle2" fontWeight={600}>
                        سجل الاستشارات
                      </Typography>
                    </Stack>
                    <IconButton size="small" onClick={() => void loadSessions()} disabled={sessionsLoading}>
                      <RefreshIcon fontSize="small" />
                    </IconButton>
                  </Stack>

                  {sessionsLoading ? (
                    <Stack spacing={1} alignItems="center" sx={{ py: 3 }}>
                      <CircularProgress size={20} />
                    </Stack>
                  ) : sessions.length ? (
                    <List disablePadding sx={{ maxHeight: 400, overflowY: "auto" }}>
                      {sessions.map((session) => (
                        <ListItemButton
                          key={session.id}
                          selected={session.id === activeSessionId}
                          onClick={() => loadSession(session.id)}
                          sx={{ borderRadius: ThemeConfig.borderRadius, mb: 0.5 }}
                        >
                          <ListItemText
                            primary={session.title || "Untitled"}
                            secondary={new Date(session.updated_at).toLocaleTimeString()}
                            primaryTypographyProps={{ noWrap: true, variant: "body2" }}
                            secondaryTypographyProps={{ noWrap: true, variant: "caption" }}
                          />
                        </ListItemButton>
                      ))}
                    </List>
                  ) : (
                    <Typography variant="caption" color="text.secondary">
                      لا توجد استشارات بعد.
                    </Typography>
                  )}
                </Box>
              </Stack>
            )}
            {!isMobile ? (
              <Box
                sx={{
                  width: 32,
                  flexShrink: 0,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  borderRight: "1px solid",
                  borderColor: "divider",
                  bgcolor: "background.paper",
                }}
              >
                <Tooltip title={rightPanelOpen ? "إخفاء لوحة الملفات" : "عرض لوحة الملفات"}>
                  <IconButton
                    size="small"
                    onClick={() => setRightPanelOpen((prev) => !prev)}
                    aria-label={rightPanelOpen ? "إخفاء لوحة الملفات" : "عرض لوحة الملفات"}
                  >
                    {rightPanelOpen ? <KeyboardDoubleArrowRightRoundedIcon /> : <KeyboardDoubleArrowLeftRoundedIcon />}
                  </IconButton>
                </Tooltip>
              </Box>
            ) : null}

            {/* Main chat area - full screen on mobile, fills remaining space on desktop */}
            <Box
              sx={{
                display: "flex",
                flexDirection: "column",
                flex: 1,
                minHeight: 0,
                overflow: "hidden",
              }}
            >
              {/* Simplified header bar - minimal on mobile, compact on desktop */}
              <Stack
                direction="row"
                alignItems="center"
                spacing={1}
                sx={{
                  px: { xs: 2, md: 3 },
                  py: 1.5,
                  borderBottom: "1px solid",
                  borderColor: "divider",
                  bgcolor: "background.paper",
                  flexShrink: 0,
                }}
              >
                <IconButton onClick={handleNewChat} size="small">
                  <AutoFixHighRoundedIcon />
                </IconButton>
                <Typography variant="subtitle1" fontWeight={600} noWrap sx={{ flex: 1 }}>
                  {activeSession?.title || "استشارة جديدة"}
                </Typography>
                {!isMobile && (
                  <>
                    <Box sx={{ width: 200 }}>
                      <ModelSelector
                        models={models}
                        value={selectedModel}
                        onChange={setSelectedModel}
                        pricing={resolvedModelPricing}
                        tier={selectedModelTier}
                        errorText={modelsError}
                        disabled={sending}
                      />
                    </Box>
                  </>
                )}
              </Stack>

              {/* Messages list - fills remaining height with flex:1 */}
              <ChatMessageList
                messages={messages}
                sources={sources}
                onRegenerate={handleRegenerateResponse}
                onEdit={(id) => {
                  const target = messages.find((message) => message.id === id);
                  if (target) {
                    setEditingMessageId(id);
                    setEditText(target.content);
                  }
                }}
                onShare={handleShareConversation}
                onBranch={handleBranchFromMessage}
                onReact={handleReact}
                isTyping={isTyping}
                suggestedPrompts={messages.length === 0 ? SUGGESTED_PROMPTS : undefined}
                onPromptClick={handleSend}
              />

              {/* Input bar - anchored to bottom */}
              <Box
                sx={{
                  flexShrink: 0,
                  px: { xs: 2, md: 3 },
                  py: 2,
                  borderTop: "1px solid",
                  borderColor: "divider",
                  bgcolor: "background.paper",
                }}
              >
                <ChatComposer onSend={handleSend} disabled={sending || !activeSpaceId} availableModels={models} />
              </Box>
            </Box>

            {/* Legal workspace panel toggle strip */}
            {!isMobile && (
              <Box
                sx={{
                  width: 32,
                  flexShrink: 0,
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  justifyContent: "center",
                  borderLeft: "1px solid",
                  borderColor: "divider",
                  bgcolor: "background.paper",
                  gap: 1,
                }}
              >
                <Tooltip title={legalPanelOpen ? "إخفاء لوحة الأدوات القانونية" : "أدوات المحامي"} placement="right">
                  <IconButton
                    size="small"
                    onClick={() => setLegalPanelOpen((prev) => !prev)}
                    sx={{ color: legalPanelOpen ? "primary.main" : "text.secondary" }}
                  >
                    <GavelRoundedIcon fontSize="small" />
                  </IconButton>
                </Tooltip>
              </Box>
            )}

            {/* Legal workspace panel */}
            {!isMobile && legalPanelOpen && (
              <Box
                sx={{
                  width: 300,
                  flexShrink: 0,
                  overflowY: "auto",
                  borderLeft: "1px solid",
                  borderColor: "divider",
                  bgcolor: "background.paper",
                }}
              >
                <LegalCasePanel onPromptSelect={handleSend} />
              </Box>
            )}
          </Box>
        )}
      </Box>

      <Popover
        open={spacesOpen}
        anchorEl={spacesAnchorEl}
        onClose={handleCloseSpaces}
        anchorOrigin={{
            vertical: 'bottom',
            horizontal: 'right',
        }}
        transformOrigin={{
            vertical: 'top',
            horizontal: 'right',
        }}
        slotProps={{
            paper: {
                sx: { maxHeight: '80vh' } // Limit height
            }
        }}
      >
        <SpaceSidebar
            spaces={spaces}
            activeSpaceId={activeSpaceId ?? null}
            onSelect={(id) => {
              selectSpace(id);
              handleCloseSpaces();
            }}
            onRefresh={refreshSpaces}
            onCreateSpace={handleCreateSpaceFromSidebar}
            onAcceptInvite={handleAcceptInviteFromSidebar}
            onDeleteSpace={handleDeleteSpaceFromSidebar}
            canManage={user?.role === "admin" || user?.role === "super_admin"}
            busy={!isReady || spaceBusy}
        />
      </Popover>

      <FileUploadDialog
        open={uploadDialogOpen}
        onClose={() => setUploadDialogOpen(false)}
        onUpload={handleUpload}
      />

      <Dialog
        open={deleteConfirmOpen}
        onClose={() => {
          if (!deleteConfirmBusy) {
            setDeleteConfirmOpen(false);
            setDeleteConfirmSpaceId(null);
          }
        }}
        maxWidth="xs"
        fullWidth
      >
        <DialogTitle>حذف الجلسة؟</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary">
            سيتم غلق هذه الجلسة وإخفاؤها عن الأعضاء.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button
            onClick={() => {
              setDeleteConfirmOpen(false);
              setDeleteConfirmSpaceId(null);
            }}
            disabled={deleteConfirmBusy}
          >
            إلغاء
          </Button>
          <Button color="error" variant="contained" onClick={handleConfirmDeleteSpace} disabled={deleteConfirmBusy}>
            {deleteConfirmBusy ? "جارٍ الحذف..." : "حذف الجلسة"}
          </Button>
        </DialogActions>
      </Dialog>

      {activeSpace && user ? (
        <SpaceAdminDialog
          open={spaceAdminOpen}
          onClose={() => {
            setSpaceAdminOpen(false);
            setSpaceAdminInitialTab(null);
            // After closing admin dialog, refresh models in case approvals/policy changed.
            void refreshModels();
          }}
          space={activeSpace}
          currentUserId={user.id}
          onUpdate={async () => {
            await refreshSpaces();
            await refreshModels();
          }}
          initialTab={spaceAdminInitialTab ?? undefined}
        />
      ) : null}

      {user?.role === "super_admin" ? (
        <SuperAdminDialog
          open={superAdminOpen}
          onClose={() => setSuperAdminOpen(false)}
          onOpenSpace={(spaceId) => {
            selectSpace(spaceId);
            setSuperAdminOpen(false);
          }}
        />
      ) : null}
      <AdminDocumentsPanel open={adminPanelOpen} onClose={() => setAdminPanelOpen(false)} />
      <RetrievalDiagnostics open={diagnosticsOpen} onClose={() => setDiagnosticsOpen(false)} sources={sources} />

      <Dialog open={passwordDialogOpen} onClose={() => setPasswordDialogOpen(false)}>
        <DialogTitle>تغيير كلمة المرور</DialogTitle>
        <DialogContent>
          {passwordError ? (
            <Alert severity="error" sx={{ mt: 1 }}>
              {passwordError}
            </Alert>
          ) : null}
          <TextField
            label="كلمة المرور الحالية"
            type="password"
            fullWidth
            margin="normal"
            value={currentPassword}
            onChange={(event) => setCurrentPassword(event.target.value)}
          />
          <TextField
            label="كلمة المرور الجديدة"
            type="password"
            fullWidth
            margin="normal"
            value={newPassword}
            onChange={(event) => setNewPassword(event.target.value)}
          />
          <TextField
            label="تأكيد كلمة المرور الجديدة"
            type="password"
            fullWidth
            margin="normal"
            value={confirmPassword}
            onChange={(event) => setConfirmPassword(event.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPasswordDialogOpen(false)}>إلغاء</Button>
          <Button onClick={handlePasswordUpdate} disabled={!currentPassword.trim() || !newPassword.trim() || !confirmPassword.trim()}>
            تحديث
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={summaryDialogOpen} onClose={() => setSummaryDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>ملخص الجلسة القانونية</DialogTitle>
        <DialogContent dividers>
          {loadingSummary ? (
            <Stack spacing={1} alignItems="center" justifyContent="center" sx={{ py: 4 }}>
              <CircularProgress size={20} />
              <Typography variant="body2" color="text.secondary">
                جارٍ إنشاء الملخص...
              </Typography>
            </Stack>
          ) : (
            <Box sx={{ "& p": { margin: 0 }, "& p + p": { marginTop: 1 } }}>
              <ReactMarkdown>{summaryText || "لا يوجد ملخص متاح."}</ReactMarkdown>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setSummaryDialogOpen(false)}>إغلاق</Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={usageDialogOpen}
        onClose={() => setUsageDialogOpen(false)}
        maxWidth="md"
        fullWidth
        PaperProps={{
          sx: {
            // Give mobile some breathing room and ensure the bottom rows aren't clipped.
            m: { xs: 1, sm: 3 },
            width: { xs: "calc(100% - 16px)", sm: "auto" },
            maxHeight: { xs: "calc(100% - 16px)", sm: "calc(100% - 48px)" },
          },
        }}
      >
        <DialogTitle>الاستخدام والتكلفة</DialogTitle>
        <DialogContent dividers sx={{ pb: 6 }}>
          {usageLoading ? (
            <Stack spacing={1} alignItems="center" justifyContent="center" sx={{ py: 4 }}>
              <CircularProgress size={20} />
              <Typography variant="body2" color="text.secondary">
                جارٍ تحميل سجل الاستخدام...
              </Typography>
            </Stack>
          ) : (
            <Stack spacing={3}>
              {usageInvoice?.alerts?.length ? (
                <Alert severity="warning">
                  <Stack spacing={0.5}>
                    {usageInvoice.alerts.map((alert, idx) => (
                      <Typography variant="body2" key={`${alert}-${idx}`}>
                        {alert}
                      </Typography>
                    ))}
                  </Stack>
                </Alert>
              ) : null}

              <Box>
                <Typography variant="subtitle2" gutterBottom>
                  Usage limits (monthly)
                </Typography>
                <Stack spacing={2}>
                  <Box>
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2">Tokens</Typography>
                      <Typography variant="caption" color="text.secondary">
                        {usageSummary?.total_tokens ?? 0} / {usageInvoice?.limits?.monthly_token_limit ?? "—"}
                      </Typography>
                    </Stack>
                    <LinearProgress
                      variant="determinate"
                      value={tokenUsagePercent}
                      color={tokenUsagePercent >= 90 ? "error" : tokenUsagePercent >= 70 ? "warning" : "success"}
                      sx={{ height: 8, borderRadius: 999 }}
                    />
                  </Box>
                  <Box>
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2">Requests</Typography>
                      <Typography variant="caption" color="text.secondary">
                        {usageSummary?.total_requests ?? 0} / {usageInvoice?.limits?.monthly_request_limit ?? "—"}
                      </Typography>
                    </Stack>
                    <LinearProgress
                      variant="determinate"
                      value={requestUsagePercent}
                      color={requestUsagePercent >= 90 ? "error" : requestUsagePercent >= 70 ? "warning" : "success"}
                      sx={{ height: 8, borderRadius: 999 }}
                    />
                  </Box>
                  <Box>
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="body2">Tool requests</Typography>
                      <Typography variant="caption" color="text.secondary">
                        {totalToolRequests} / {usageInvoice?.limits?.monthly_tool_request_limit ?? "—"}
                      </Typography>
                    </Stack>
                    <LinearProgress
                      variant="determinate"
                      value={toolUsagePercent}
                      color={toolUsagePercent >= 90 ? "error" : toolUsagePercent >= 70 ? "warning" : "success"}
                      sx={{ height: 8, borderRadius: 999 }}
                    />
                  </Box>
                </Stack>
              </Box>

              <Box>
                <Typography variant="body2" color="text.secondary">
                  Last 30 days{activeSessionId ? " (this session only)" : ""}
                </Typography>
                <Typography variant="body1" sx={{ mt: 1 }}>
                  Tokens: {usageSummary?.total_tokens ?? 0} (in {usageSummary?.total_input_tokens ?? 0} / out {usageSummary?.total_output_tokens ?? 0})
                </Typography>
                <Typography variant="body1">
                  Requests: {usageSummary?.total_requests ?? 0}
                </Typography>
                <Typography variant="body1">
                  Cost: {usageSummary?.total_cost_usd != null ? formatUsdCost(usageSummary.total_cost_usd) : "Not available"}
                </Typography>
              </Box>

              <Box>
                <Typography variant="subtitle2" gutterBottom>
                  By model
                </Typography>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Model</TableCell>
                      <TableCell align="right">Requests</TableCell>
                      <TableCell align="right">Tokens</TableCell>
                      <TableCell align="right">Cost</TableCell>
                      <TableCell align="right">Price tier</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {(usageSummary?.by_model ?? []).map((row) => (
                      <TableRow key={row.model}>
                        <TableCell>{row.model}</TableCell>
                        <TableCell align="right">{row.requests}</TableCell>
                        <TableCell align="right">{row.total_tokens}</TableCell>
                        <TableCell align="right">
                          {row.cost_usd != null ? formatUsdCost(row.cost_usd) : "Not priced"}
                        </TableCell>
                        <TableCell align="right">
                          {row.cost_usd != null && row.total_tokens > 0 ? (() => {
                            const perMillion = (row.cost_usd / row.total_tokens) * 1_000_000;
                            const tier = getPriceTier(perMillion);
                            const color = tier === "high" ? "error" : tier === "medium" ? "warning" : "success";
                            return (
                              <Chip
                                size="small"
                                color={color}
                                label={`${tier} ($${perMillion.toFixed(2)}/1M)`}
                                variant="outlined"
                              />
                            );
                          })() : (
                            "—"
                          )}
                        </TableCell>
                      </TableRow>
                    ))}
                    {!usageSummary?.by_model?.length ? (
                      <TableRow>
                        <TableCell colSpan={5} align="center">
                          <Typography variant="body2" color="text.secondary">
                            No usage recorded.
                          </Typography>
                        </TableCell>
                      </TableRow>
                    ) : null}
                  </TableBody>
                </Table>
              </Box>

              {usageInvoice?.tool_usage?.length ? (
                <Box>
                  <Typography variant="subtitle2" gutterBottom>
                    Tool usage
                  </Typography>
                  <UsageCard
                    title="Tool usage"
                    rows={usageInvoice.tool_usage.map((row) => ({
                      key: row.tool,
                      label: formatToolName(row.tool),
                      costUsd: row.cost_usd,
                      category: row.tool.includes("web_search") ? "web" : "tool",
                    }))}
                  />
                </Box>
              ) : null}

              <Box>
                <Typography variant="subtitle2" gutterBottom>
                  Recent events
                </Typography>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>When</TableCell>
                      <TableCell>Endpoint</TableCell>
                      <TableCell>Model</TableCell>
                      <TableCell align="right">Tokens</TableCell>
                      <TableCell align="right">Cost</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {usageEvents.map((event) => (
                      <TableRow key={event.id}>
                        <TableCell>{new Date(event.created_at).toLocaleString()}</TableCell>
                        <TableCell>{event.endpoint}</TableCell>
                        <TableCell>{event.model ?? "-"}</TableCell>
                        <TableCell align="right">{event.total_tokens}</TableCell>
                        <TableCell align="right">
                          {event.cost_usd != null ? formatUsdCost(event.cost_usd) : "Not priced"}
                        </TableCell>
                      </TableRow>
                    ))}
                    {!usageEvents.length ? (
                      <TableRow>
                        <TableCell colSpan={5} align="center">
                          <Typography variant="body2" color="text.secondary">
                            No events recorded.
                          </Typography>
                        </TableCell>
                      </TableRow>
                    ) : null}
                  </TableBody>
                </Table>
              </Box>
            </Stack>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleDownloadInvoice} disabled={!usageInvoice || usageLoading}>
            Download PDF invoice
          </Button>
          <Button onClick={() => setUsageDialogOpen(false)}>Close</Button>
        </DialogActions>
      </Dialog>

      <EditMessageDialog
        key={editingMessageId ?? "edit-dialog"}
        open={editingMessageId !== null}
        message={editText}
        onClose={() => {
          setEditingMessageId(null);
          setEditText("");
        }}
        onSave={(updated) => {
          if (editingMessageId) {
            handleEditMessage(editingMessageId, updated);
          }
        }}
      />

      <MobileDrawer
        open={mobileDrawerOpen}
        onClose={() => setMobileDrawerOpen(false)}
        models={models}
        selectedModel={selectedModel}
        onModelChange={setSelectedModel}
        modelPricing={resolvedModelPricing}
        modelTier={selectedModelTier}
        modelsError={modelsError}
        modelDisabled={sending}
        onNewChat={handleNewChat}
        onManageAccess={isSpaceAdmin ? () => setAdminPanelOpen(true) : undefined}
        onSpaceAdmin={() => {
          setSpaceAdminInitialTab("members");
          setSpaceAdminOpen(true);
        }}
        onSpaceOptions={() => {
          setSpaceAdminInitialTab("settings");
          setSpaceAdminOpen(true);
        }}
        onDangerZone={() => {
          setSpaceAdminInitialTab("settings");
          setSpaceAdminOpen(true);
        }}
        onSuperAdmin={user?.role === "super_admin" ? () => setSuperAdminOpen(true) : undefined}
        onDiagnostics={() => setDiagnosticsOpen(true)}
        onSummary={handleGenerateSummary}
        onUsage={handleOpenUsage}
        onExport={() => handleExport("md")}
        isSuperAdmin={user?.role === "super_admin"}
        sourcesCount={sources.length}
        hasMessages={messages.length > 0}
        hasActiveSession={Boolean(activeSessionId)}
        activeSpace={activeSpace}
      />

      {snackbar ? (
        <Snackbar
          open
          autoHideDuration={4000}
          onClose={() => setSnackbar(null)}
          anchorOrigin={{ vertical: "top", horizontal: "center" }}
          sx={{ mt: { xs: 8, sm: 10 } }}
        >
          <Alert severity={snackbar.severity}>{snackbar.message}</Alert>
        </Snackbar>
      ) : null}
    </Box>
  );
};

export default ChatPage;
