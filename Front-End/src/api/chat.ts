import { apiClient, API_BASE_URL } from "./client";

export interface VectorSearchMatch {
  chunk_id: string;
  score: number;
  document_id: string;
  filename: string;
  file_type: string;
  chunk_index: number;
  text: string;
  metadata: Record<string, unknown>;
}

export interface ConversationMessage {
  id: string;
  role: "user" | "assistant";
  content: string;
  created_at: string;
}

export interface ChatSessionSummary {
  id: string;
  title?: string | null;
  created_at: string;
  updated_at: string;
}

export interface ChatSessionDetail {
  session: ChatSessionSummary;
  history: ConversationMessage[];
}

export interface ChatQueryPayload {
  message: string;
  session_id?: string;
  document_ids?: string[];
  top_k?: number;
  model?: string;
  use_web_search?: boolean;
}

export interface ChatQueryResponse {
  session_id: string;
  reply: string;
  sources: VectorSearchMatch[];
  history: ConversationMessage[];
}

export const sendChatMessage = (payload: ChatQueryPayload) =>
  apiClient.post<ChatQueryResponse>("/chat/query", payload);

export const listChatModels = () => apiClient.get<string[]>("/chat/models");

export const listAllChatModels = () => apiClient.get<string[]>("/chat/models/all");

export const listChatModelPricing = () => apiClient.get<ModelPricingResponse>("/chat/models/pricing");

type StreamEvent =
  | { type: "meta"; data: { session_id: string; sources: VectorSearchMatch[] } }
  | { type: "delta"; data: { text: string } }
  | { type: "done" }
  | { type: "error"; data: { detail?: string } };

const parseSseEvent = (raw: string): StreamEvent | null => {
  const lines = raw.split("\n").map((line) => line.trimEnd());
  const eventLine = lines.find((line) => line.startsWith("event:"));
  const dataLines = lines.filter((line) => line.startsWith("data:")).map((line) => line.slice(5).trim());
  if (!eventLine) return null;

  const eventName = eventLine.slice(6).trim();
  const dataText = dataLines.join("\n");

  if (eventName === "done") return { type: "done" };

  let data: any = undefined;
  if (dataText) {
    try {
      data = JSON.parse(dataText);
    } catch {
      data = { detail: dataText };
    }
  }

  if (eventName === "meta") return { type: "meta", data };
  if (eventName === "delta") return { type: "delta", data };
  if (eventName === "error") return { type: "error", data };
  return null;
};

export async function streamChatMessage(
  payload: ChatQueryPayload,
  handlers: {
    onMeta?: (meta: { session_id: string; sources: VectorSearchMatch[] }) => void;
    onDelta?: (text: string) => void;
    onError?: (detail?: string) => void;
    onDone?: () => void;
  },
) {
  const baseUrl = API_BASE_URL;

  const token = localStorage.getItem("lawtech_access_token");
  const spaceId = localStorage.getItem("lawtech_active_space_id");

  const response = await fetch(`${baseUrl}/chat/query/stream`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(spaceId ? { "X-Space-Id": spaceId } : {}),
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok || !response.body) {
    let detail: string | undefined;
    try {
      const data = await response.json();
      detail = data?.detail ?? JSON.stringify(data);
    } catch {
      detail = `Request failed (${response.status})`;
    }
    handlers.onError?.(detail);
    return;
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder("utf-8");
  let buffer = "";

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    while (true) {
      const idx = buffer.indexOf("\n\n");
      if (idx === -1) break;
      const raw = buffer.slice(0, idx);
      buffer = buffer.slice(idx + 2);
      const evt = parseSseEvent(raw);
      if (!evt) continue;
      if (evt.type === "meta") handlers.onMeta?.(evt.data);
      if (evt.type === "delta") handlers.onDelta?.(evt.data.text);
      if (evt.type === "error") handlers.onError?.(evt.data.detail);
      if (evt.type === "done") handlers.onDone?.();
    }
  }
}

export const listChatSessions = () => apiClient.get<ChatSessionSummary[]>("/chat/sessions");

export const getChatSession = (sessionId: string) =>
  apiClient.get<ChatSessionDetail>(`/chat/sessions/${sessionId}`);

export const branchChatSession = (sessionId: string, fromMessageId: string) =>
  apiClient.post<{ session_id: string }>(`/chat/sessions/${sessionId}/branch`, { from_message_id: fromMessageId });

export async function exportChatSession(sessionId: string, format: "json" | "md" = "json") {
  const baseUrl = API_BASE_URL;
  const token = localStorage.getItem("lawtech_access_token");
  const spaceId = localStorage.getItem("lawtech_active_space_id");

  const response = await fetch(`${baseUrl}/chat/sessions/${sessionId}/export?format=${encodeURIComponent(format)}`, {
    method: "GET",
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(spaceId ? { "X-Space-Id": spaceId } : {}),
    },
  });

  if (!response.ok) {
    let detail: string | undefined;
    try {
      const data = await response.json();
      detail = data?.detail ?? JSON.stringify(data);
    } catch {
      detail = `Export failed (${response.status})`;
    }
    throw new Error(detail);
  }

  const blob = await response.blob();
  return blob;
}

export interface SessionSummaryResponse {
  session_id: string;
  summary: string;
  message_count: number;
}

export const getSessionSummary = (sessionId: string) =>
  apiClient.get<SessionSummaryResponse>(`/chat/sessions/${sessionId}/summary`);

export interface UsageEvent {
  id: string;
  created_at: string;
  session_id?: string | null;
  endpoint: string;
  model?: string | null;
  request_count?: number;
  input_tokens: number;
  output_tokens: number;
  total_tokens: number;
  cost_usd?: number | null;
}

export interface UsageSummaryRow {
  model: string;
  requests: number;
  input_tokens: number;
  output_tokens: number;
  total_tokens: number;
  cost_usd?: number | null;
}

export interface UsageSummary {
  start: string;
  end: string;
  total_requests: number;
  total_input_tokens: number;
  total_output_tokens: number;
  total_tokens: number;
  total_cost_usd?: number | null;
  by_model: UsageSummaryRow[];
}

export interface ToolUsageSummary {
  tool: string;
  requests: number;
  cost_usd?: number | null;
}

export interface ModelPricingEntry {
  input: number;
  output: number;
}

export interface ModelPricingResponse {
  pricing: Record<string, ModelPricingEntry>;
  aliases: Record<string, string>;
}

export interface UsageLimits {
  allowed_models: string[];
  allowed_tools: string[];
  daily_token_limit?: number | null;
  monthly_token_limit?: number | null;
  daily_request_limit?: number | null;
  monthly_request_limit?: number | null;
  daily_tool_request_limit?: number | null;
  monthly_tool_request_limit?: number | null;
}

export interface UsageInvoice {
  start: string;
  end: string;
  totals: UsageSummaryRow;
  by_model: UsageSummaryRow[];
  tool_usage: ToolUsageSummary[];
  limits: UsageLimits;
  alerts: string[];
}

export const listUsageEvents = (params?: { limit?: number; session_id?: string }) =>
  apiClient.get<UsageEvent[]>("/chat/usage", { params });

export const getUsageSummary = (params?: { days?: number; session_id?: string }) =>
  apiClient.get<UsageSummary>("/chat/usage/summary", { params });

export const getUsageInvoice = (params?: { days?: number }) =>
  apiClient.get<UsageInvoice>("/chat/usage/invoice", { params });

export async function downloadUsageInvoicePdf(days = 30) {
  const baseUrl = API_BASE_URL;

  const token = localStorage.getItem("lawtech_access_token");
  const spaceId = localStorage.getItem("lawtech_active_space_id");

  const response = await fetch(`${baseUrl}/chat/usage/invoice/pdf?days=${encodeURIComponent(days)}`, {
    method: "GET",
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(spaceId ? { "X-Space-Id": spaceId } : {}),
    },
  });

  if (!response.ok) {
    let detail: string | undefined;
    try {
      const data = await response.json();
      detail = data?.detail ?? JSON.stringify(data);
    } catch {
      detail = `Invoice download failed (${response.status})`;
    }
    throw new Error(detail);
  }

  return response.blob();
}

export const reactToMessage = (messageId: string, reaction: "up" | "down") =>
  apiClient.post<{ success: boolean }>(`/chat/messages/${messageId}/reaction`, { reaction });
