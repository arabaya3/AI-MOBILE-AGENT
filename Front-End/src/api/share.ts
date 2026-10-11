import { apiClient } from "./client";

export async function shareConversation(sessionId: string) {
  return apiClient.post(`/chat/sessions/${sessionId}/share`);
}

export async function getSharedConversation(shareId: string) {
  return apiClient.get(`/chat/shared/${shareId}`);
}
