import AutoFixHighRoundedIcon from "@mui/icons-material/AutoFixHighRounded";
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
import { useCallback, useEffect, useMemo, useState } from "react";
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
  listChatSessions,
  listUsageEvents,
  reactToMessage,
  citationsToSources,
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
import { ModelSelector } from "../components/ModelSelector";
import { MobileDrawer } from "../components/MobileDrawer";
import { UsageCard } from "../components/UsageCard";
import { UserProfileSettingsDialog } from "../components/UserProfileSettingsDialog";
import { useAuth } from "../context/AuthContext";
import { useSpace } from "../context/SpaceContext";
import { ThemeConfig } from "../styles/ThemeConfig";
import { formatToolName, formatUsdCost } from "../utils/formatters";

const SUGGESTED_PROMPTS = [
  "Summarize the documents I selected.",
  "Find where our policy mentions refunds and deadlines.",
  "Draft a professional email based on this conversation.",
  "Explain this error log and propose a fix.",
];

import type { IndustryPalette } from "../styles/theme";

interface ChatPageProps {
  toggleTheme?: () => void;
  currentPalette?: IndustryPalette;
  onChangePalette?: (key: IndustryPalette) => void;
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

/**
 * Choose a sensible default model from the available catalog.
 * Priority: gpt-5-nano → gpt-5-mini → anything containing "nano" or "mini"
 * → first alphabetical entry. GPT-4o mini is explicitly de-prioritised.
 */
const pickDefaultModel = (catalog: string[]): string => {
  if (!catalog.length) return "";
  const preferred = ["gpt-5-nano", "gpt-5-mini"];
  for (const candidate of preferred) {
    if (catalog.includes(candidate)) return candidate;
  }
  // Fuzzy fallback: any nano or mini variant (prefer nano)
  const nano = catalog.find((m) => m.toLowerCase().includes("nano"));
  if (nano) return nano;
  const mini = catalog.find((m) => m.toLowerCase().includes("mini") && !m.toLowerCase().includes("4o"));
  if (mini) return mini;
  return catalog[0];
};

const mergeModelCatalog = (...modelGroups: Array<string[] | undefined | null>) =>
  Array.from(new Set(modelGroups.flatMap((group) => (group ?? []).map((model) => model.trim()).filter(Boolean))))
    .sort((a, b) => a.localeCompare(b));

const ChatPage = ({ toggleTheme, currentPalette: _currentPalette, onChangePalette: _onChangePalette }: ChatPageProps) => {
  const { user, logout, changePassword } = useAuth();
  const { spaces, activeSpaceId, selectSpace, refreshSpaces, createSpace: createSpaceInContext, isReady } = useSpace();
  const theme = useTheme();
  // Mobile breakpoint matches sidebar drawer logic
  const isMobile = useMediaQuery(theme.breakpoints.down("lg"));
  
  const [spacesDialogOpen, setSpacesDialogOpen] = useState(false);
  const handleOpenSpaces = (_event?: React.MouseEvent<HTMLElement>) => {
    // Open the Space Admin dialog on the "spaces" tab instead of the standalone popup
    setSpaceAdminInitialTab("spaces");
    setSpaceAdminOpen(true);
  };
  const handleCloseSpaces = () => setSpacesDialogOpen(false);
  const spacesOpen = spacesDialogOpen;

  const [rightPanelOpen, setRightPanelOpen] = useState(true);
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
    const stored = Number(localStorage.getItem("teia_chat_top_k"));
    if (Number.isFinite(stored) && stored >= 1 && stored <= 20) {
      return Math.floor(stored);
    }
    return 5;
  });

  useEffect(() => {
    localStorage.setItem("teia_chat_top_k", String(topK));
  }, [topK]);

  const [messages, setMessages] = useState<ConversationMessage[]>([]);
  const [sources, setSources] = useState<VectorSearchMatch[]>([]);
  const [activeSessionId, setActiveSessionId] = useState<string | undefined>(undefined);
  const [isNewChatMode, setIsNewChatMode] = useState(false);

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
  const [selectedModel, setSelectedModel] = useState<string>(() => localStorage.getItem("teia_chat_model") ?? "");
  const [snackbar, setSnackbar] = useState<{ severity: AlertColor; message: string } | null>(null);
  const [editingMessageId, setEditingMessageId] = useState<string | null>(null);
  const [editText, setEditText] = useState("");
  const [spaceBusy, setSpaceBusy] = useState(false);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [deleteConfirmSpaceId, setDeleteConfirmSpaceId] = useState<string | null>(null);
  const [deleteConfirmBusy, setDeleteConfirmBusy] = useState(false);
  const [deleteConfirmName, setDeleteConfirmName] = useState("");
  const [userProfileOpen, setUserProfileOpen] = useState(false);

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

  const tokenUsagePercent = getUsagePercent(usageSummary?.total_tokens ?? 0, usageInvoice?.limits?.monthly_token_limit);
  const requestUsagePercent = getUsagePercent(
    usageSummary?.total_requests ?? 0,
    usageInvoice?.limits?.monthly_request_limit,
  );
  const toolUsagePercent = getUsagePercent(totalToolRequests, usageInvoice?.limits?.monthly_tool_request_limit);

  useEffect(() => {
    if (selectedModel) {
      localStorage.setItem("teia_chat_model", selectedModel);
    } else {
      localStorage.removeItem("teia_chat_model");
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
        if (data.history.some((msg) => msg.citations?.length)) {
          setSources([]);
          setMessages(
            data.history.map((msg) => (msg.citations?.length ? { ...msg, sources: citationsToSources(msg.citations) } : msg)),
          );
          return;
        }
        // Older answers have no stored citations; fall back to sources kept in this browser tab.
        const storedRaw = sessionStorage.getItem(`teia_sources_${sessionId}`);
        const storedSources: VectorSearchMatch[] = storedRaw ? (JSON.parse(storedRaw) as VectorSearchMatch[]) : [];
        setSources(storedSources);
        if (storedSources.length > 0) {
          // Attach sources to the last assistant message so chips are visible
          const history = data.history.map((msg, idx, arr) => {
            const isLastAssistant =
              msg.role === "assistant" && arr.slice(idx + 1).every((m) => m.role !== "assistant");
            return isLastAssistant ? { ...msg, sources: storedSources } : msg;
          });
          setMessages(history);
        } else {
          setMessages(data.history);
        }
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

      const hasActive = activeSessionId ? data.some((session) => session.id === activeSessionId) : false;
      if (forceNewChat) {
        setActiveSessionId(undefined);
        setMessages([]);
        setSources([]);
      } else if (!hasActive) {
        if (isNewChatMode) {
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
  }, [isReady, activeSpaceId, activeSessionId, isNewChatMode, extractErrorMessage, loadSession]);

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

    Promise.all([listChatModels()])
      .then(([modelsResp]) => {
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
          // Auto-select a default if the user has nothing stored or stored model is unavailable.
          setSelectedModel((current) => {
            if (current && data.includes(current)) return current;
            const stored = localStorage.getItem("teia_chat_model");
            if (stored && data.includes(stored)) return stored;
            return pickDefaultModel(data);
          });
        }
      })
      .catch(() => {
        setModels([]);
        setModelsError("Using server default model");
      });
  }, [isReady, activeSpaceId, activeSpace?.policy?.allowed_models, selectedModel]);

  const refreshModels = useCallback(async () => {
    if (!isReady || !activeSpaceId) return;
    try {
      const modelsResp = await listChatModels();
      setModels(
        mergeModelCatalog(
          modelsResp.data,
          activeSpace?.policy?.allowed_models ?? [],
          selectedModel ? [selectedModel] : [],
        ),
      );
      setModelsError(null);
    } catch {
      // Keep prior state; Chat send will surface policy errors if any.
      setModelsError("Unable to load available models.");
    }
  }, [activeSpace?.policy?.allowed_models, activeSpaceId, isReady, selectedModel]);

  useEffect(() => {
    if (!selectedModel) return;
    if (!models.length || !models.includes(selectedModel)) {
      setSelectedModel("");
    }
  }, [models, selectedModel]);

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
    if (isNewChatMode) {
      void loadSessions({ forceNewChat: true });
    } else {
      void loadSessions();
    }
  }, [isReady, activeSpaceId, loadDocuments, loadSessions, isNewChatMode]);

  const handleToggleDocument = (documentId: string) => {
    setSelectedDocs((prev) => (prev.includes(documentId) ? prev.filter((id) => id !== documentId) : [...prev, documentId]));
  };

  const handleSend = useCallback(
    async (rawMessage: string) => {
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

      let assistantMessageAdded = false;

      const payload: ChatQueryPayload = { message };
      if (activeSessionId) payload.session_id = activeSessionId;
      if (selectedDocs.length) payload.document_ids = selectedDocs;
      payload.top_k = topK;
      if (selectedModel && models.includes(selectedModel)) payload.model = selectedModel;
      // Inject user profile context for system-prompt personalisation.
      // Always pass language so the backend can enforce it (including en default).
      if (user?.industry) payload.user_industry = user.industry;
      if (user?.preferred_language) payload.user_language = user.preferred_language;

      let currentSources: VectorSearchMatch[] = [];

      try {
        await streamChatMessage(payload, {
          onMeta: (meta) => {
            setActiveSessionId(meta.session_id);
            setIsNewChatMode(false);
            if (meta.sources && meta.sources.length > 0) {
              currentSources = meta.sources;
              setSources(meta.sources);
              // Persist so they survive a manual page refresh
              sessionStorage.setItem(`teia_sources_${meta.session_id}`, JSON.stringify(meta.sources));
              // Update message if already added to state
              if (assistantMessageAdded) {
                setMessages((prev) =>
                  prev.map((msg) => (msg.id === assistantMessageId ? { ...msg, sources: meta.sources } : msg))
                );
              }
            }
          },
          onDelta: (text) => {
            if (!assistantMessageAdded) {
              // Add assistant message on first content chunk with any sources we have
              setMessages((prev) => [...prev, { ...assistantMessage, sources: currentSources }]);
              assistantMessageAdded = true;
            }
            setMessages((prev) =>
              prev.map((msg) => (msg.id === assistantMessageId ? { ...msg, content: msg.content + text, sources: currentSources.length ? currentSources : msg.sources } : msg))
            );
          },
          onError: (detail) => {
            setSnackbar({ severity: "error", message: detail || "Chat stream failed." });
          },
          onDone: async (ids) => {
            setIsTyping(false);
            // Swap temporary IDs for the persisted ones so reactions and branching work immediately.
            if (ids.message_id || ids.user_message_id) {
              setMessages((prev) =>
                prev.map((msg) => {
                  if (msg.id === assistantMessageId && ids.message_id) return { ...msg, id: ids.message_id };
                  if (msg.id === userMessage.id && ids.user_message_id) return { ...msg, id: ids.user_message_id };
                  return msg;
                }),
              );
            }
            // Do not overwrite messages from server here to prevent losing sources 
            // and voiding the smooth streaming experience.
            // We only refresh the session list sidebar.
          },
        });
        setIsTyping(false);
        await loadSessions();
      } catch (error) {
        setIsTyping(false);
        setMessages((prev) => prev.filter((msg) => msg.id !== assistantMessageId && msg.id !== userMessage.id));
        setSnackbar({ severity: "error", message: extractErrorMessage(error, "Chat request failed. Please try again.") });
      } finally {
        setSending(false);
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [activeSpaceId, activeSessionId, selectedDocs, topK, selectedModel, models, sending, loadSessions, extractErrorMessage, user],
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
      const { buildShareUrl, shareConversation } = await import("../api/share");
      const { data } = await shareConversation(activeSessionId);
      await navigator.clipboard.writeText(buildShareUrl(data.token));
      const expires = new Date(data.expires_at).toLocaleDateString();
      setSnackbar({ severity: "success", message: `Share link copied. It expires on ${expires}.` });
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
      setSnackbar({ severity: "success", message: "Branched into a new chat." });
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
    setDeleteConfirmName("");
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
        onOpenUserProfile={() => setUserProfileOpen(true)}
        onToggleSidebar={() => setMobileDrawerOpen(!mobileDrawerOpen)}
        onOpenSpaces={handleOpenSpaces}
        modelSelector={
          <ModelSelector
            models={models}
            value={selectedModel}
            onChange={setSelectedModel}
            errorText={modelsError}
            disabled={sending}
            compact
          />
        }
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
            <Typography variant="body1">Preparing your workspace...</Typography>
            <Typography variant="body2" color="text.secondary">
              Fetching your spaces and recent activity.
            </Typography>
          </Stack>
        ) : !activeSpaceId ? (
          <Stack spacing={2} alignItems="center" justifyContent="center" sx={{ flex: 1, px: 3 }}>
            <Typography variant="h6" fontWeight={700}>
              Pick a space to begin
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Choose a space from the menu or create a new one.
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
                <Box sx={{ mb: 2, height: "100%", display: "flex", flexDirection: "column" }}>
                  {documentsLoading ? (
                    <Stack spacing={1} alignItems="center" sx={{ py: 3 }}>
                      <CircularProgress size={20} />
                      <Typography variant="caption" color="text.secondary">
                        Loading...
                      </Typography>
                    </Stack>
                  ) : (
                    <Box sx={{ flex: 1, minHeight: 0 }}>
                      <DocumentSelector
                        documents={documents}
                        selected={selectedDocs}
                        onToggle={handleToggleDocument}
                        onUploadClick={() => setUploadDialogOpen(true)}
                        canUpload={canUpload}
                        canManagePermissions={isSpaceAdmin}
                        onManagePermissions={() => setAdminPanelOpen(true)}
                        topK={topK}
                        onTopKChange={(val) => setTopK(clampTopK(val))}
                      />
                    </Box>
                  )}
                </Box>

                <Divider />

                <Box sx={{ mt: 2 }}>
                  <Stack direction="row" alignItems="center" justifyContent="space-between" mb={1}>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <HistoryRoundedIcon fontSize="small" color="primary" />
                      <Typography variant="subtitle2" fontWeight={600}>
                        Sessions
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
                      No sessions yet.
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
                <Tooltip title={rightPanelOpen ? "Collapse documents panel" : "Open documents panel"}>
                  <IconButton
                    size="small"
                    onClick={() => setRightPanelOpen((prev) => !prev)}
                    aria-label={rightPanelOpen ? "Collapse documents panel" : "Open documents panel"}
                  >
                    {rightPanelOpen ? <KeyboardDoubleArrowLeftRoundedIcon /> : <KeyboardDoubleArrowRightRoundedIcon />}
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
                <Tooltip title="Start a new conversation">
                  <Button
                    onClick={handleNewChat}
                    size="small"
                    variant="outlined"
                    startIcon={<AutoFixHighRoundedIcon fontSize="small" />}
                    sx={{
                      display: { xs: "none", sm: "inline-flex" },
                      borderRadius: 2,
                      textTransform: "none",
                      fontWeight: 600,
                      px: 1.5,
                    }}
                  >
                    New chat
                  </Button>
                </Tooltip>
                <Tooltip title="Start a new conversation">
                  <IconButton
                    onClick={handleNewChat}
                    size="small"
                    sx={{ display: { xs: "inline-flex", sm: "none" } }}
                    aria-label="New conversation"
                  >
                    <AutoFixHighRoundedIcon />
                  </IconButton>
                </Tooltip>
                <Typography variant="subtitle1" fontWeight={600} noWrap sx={{ flex: 1 }}>
                  {activeSession?.title || "New conversation"}
                </Typography>
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
          </Box>
        )}
      </Box>

      <Dialog
        open={spacesOpen}
        onClose={handleCloseSpaces}
        maxWidth="xs"
        fullWidth
        PaperProps={{
          sx: {
            maxHeight: '85vh',
            m: { xs: 2, sm: 3 },
            width: { xs: 'calc(100% - 32px)', sm: 380 },
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
      </Dialog>

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
            setDeleteConfirmName("");
          }
        }}
        maxWidth="xs"
        fullWidth
      >
        <DialogTitle sx={{ color: "error.main", fontWeight: 700 }}>Delete Space?</DialogTitle>
        <DialogContent>
          <Stack spacing={2}>
            <Alert severity="error" variant="outlined">
              This action is <strong>irreversible</strong>. The space and all associated data will be permanently deleted.
            </Alert>
            <Typography variant="body2" color="text.secondary">
              To confirm, type the name of the space: <strong>{spaces.find(s => s.id === deleteConfirmSpaceId)?.name ?? ""}</strong>
            </Typography>
            <TextField
              fullWidth
              size="small"
              placeholder="Type space name to confirm"
              value={deleteConfirmName}
              onChange={(e) => setDeleteConfirmName(e.target.value)}
              autoFocus
              error={deleteConfirmName.length > 0 && deleteConfirmName !== (spaces.find(s => s.id === deleteConfirmSpaceId)?.name ?? "")}
              aria-label="Type space name to confirm deletion"
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button
            onClick={() => {
              setDeleteConfirmOpen(false);
              setDeleteConfirmSpaceId(null);
              setDeleteConfirmName("");
            }}
            disabled={deleteConfirmBusy}
          >
            Cancel
          </Button>
          <Button
            color="error"
            variant="contained"
            onClick={handleConfirmDeleteSpace}
            disabled={
              deleteConfirmBusy ||
              deleteConfirmName !== (spaces.find(s => s.id === deleteConfirmSpaceId)?.name ?? "")
            }
          >
            {deleteConfirmBusy ? "Deleting..." : "Delete Space"}
          </Button>
        </DialogActions>
      </Dialog>

      {user ? (
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
          onDeleteSpace={handleDeleteSpaceFromSidebar}
          allSpaces={spaces}
          activeSpaceId={activeSpaceId}
          onSelectSpace={(id) => { selectSpace(id); setSpaceAdminOpen(false); }}
          onRefreshSpaces={refreshSpaces}
          onCreateSpace={handleCreateSpaceFromSidebar}
          onAcceptInvite={handleAcceptInviteFromSidebar}
          canManageSpaces={user?.role === "admin" || user?.role === "super_admin"}
          spaceBusy={!isReady || spaceBusy}
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
        <DialogTitle>Change Password</DialogTitle>
        <DialogContent>
          {passwordError ? (
            <Alert severity="error" sx={{ mt: 1 }}>
              {passwordError}
            </Alert>
          ) : null}
          <TextField
            label="Current password"
            type="password"
            fullWidth
            margin="normal"
            value={currentPassword}
            onChange={(event) => setCurrentPassword(event.target.value)}
          />
          <TextField
            label="New password"
            type="password"
            fullWidth
            margin="normal"
            value={newPassword}
            onChange={(event) => setNewPassword(event.target.value)}
          />
          <TextField
            label="Confirm new password"
            type="password"
            fullWidth
            margin="normal"
            value={confirmPassword}
            onChange={(event) => setConfirmPassword(event.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPasswordDialogOpen(false)}>Cancel</Button>
          <Button onClick={handlePasswordUpdate} disabled={!currentPassword.trim() || !newPassword.trim() || !confirmPassword.trim()}>
            Update
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={summaryDialogOpen} onClose={() => setSummaryDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Session Summary</DialogTitle>
        <DialogContent dividers>
          {loadingSummary ? (
            <Stack spacing={1} alignItems="center" justifyContent="center" sx={{ py: 4 }}>
              <CircularProgress size={20} />
              <Typography variant="body2" color="text.secondary">
                Generating summary...
              </Typography>
            </Stack>
          ) : (
            <Box sx={{ "& p": { margin: 0 }, "& p + p": { marginTop: 1 } }}>
              <ReactMarkdown>{summaryText || "No summary available."}</ReactMarkdown>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setSummaryDialogOpen(false)}>Close</Button>
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
        <DialogTitle>Usage & Cost</DialogTitle>
        <DialogContent dividers sx={{ pb: 6 }}>
          {usageLoading ? (
            <Stack spacing={1} alignItems="center" justifyContent="center" sx={{ py: 4 }}>
              <CircularProgress size={20} />
              <Typography variant="body2" color="text.secondary">
                Loading usage history...
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

      <UserProfileSettingsDialog
        open={userProfileOpen}
        onClose={() => setUserProfileOpen(false)}
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
