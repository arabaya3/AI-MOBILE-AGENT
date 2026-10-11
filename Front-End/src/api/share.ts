import { API_BASE_URL, apiClient } from "./client";

export interface ShareCreatedResponse {
  share_id: string;
  token: string;
  share_url: string;
  expires_at: string;
}

export interface ShareSummary {
  share_id: string;
  created_at: string;
  expires_at: string;
  revoked_at: string | null;
  active: boolean;
}

export interface SharedConversation {
  title: string;
  shared_at: string;
  expires_at: string;
  messages: { role: "user" | "assistant"; content: string; created_at: string }[];
}

export async function shareConversation(sessionId: string, expiresInHours?: number) {
  const body = expiresInHours ? { expires_in_hours: expiresInHours } : undefined;
  return apiClient.post<ShareCreatedResponse>(`/chat/sessions/${sessionId}/share`, body);
}

export async function listConversationShares(sessionId: string) {
  return apiClient.get<ShareSummary[]>(`/chat/sessions/${sessionId}/shares`);
}

export async function revokeConversationShare(shareId: string) {
  return apiClient.delete<ShareSummary>(`/chat/shares/${shareId}`);
}

export async function getSharedConversation(token: string) {
  return apiClient.get<SharedConversation>(`/chat/shared/${encodeURIComponent(token)}`);
}

export function buildShareUrl(token: string): string {
  return new URL(`${API_BASE_URL}/chat/shared/${encodeURIComponent(token)}`, window.location.origin).toString();
}
