import { apiClient } from "./client";

export interface Notification {
  id: string;
  user_id: string;
  space_id?: string;
  type: string;
  title: string;
  message: string;
  link?: string;
  metadata: Record<string, any>;
  read: boolean;
  created_at: string;
}

export interface UnreadCountResponse {
  count: number;
}

export const getNotifications = (params?: { unread_only?: boolean; limit?: number; offset?: number }) =>
  apiClient.get<Notification[]>("/notifications", { params });

export const getUnreadCount = () =>
  apiClient.get<UnreadCountResponse>("/notifications/unread-count");

export const markNotificationRead = (notificationId: string) =>
  apiClient.post(`/notifications/${notificationId}/read`);

export const markAllNotificationsRead = () =>
  apiClient.post("/notifications/mark-all-read");

export const deleteNotification = (notificationId: string) =>
  apiClient.delete(`/notifications/${notificationId}`);

// Server-Sent Events stream for real-time notifications
export const connectNotificationStream = (onNotification: (notification: any) => void, onError?: (error: Error) => void) => {
  const token = localStorage.getItem("auth_token") || localStorage.getItem("token"); // Try both keys
  if (!token) {
    // Silently fail or log debug instead of error to avoid console noise on initial load
    console.debug("No authentication token found, skipping notification stream connection");
    return null;
  }

  // EventSource doesn't support custom headers, so we pass token as query param
  const url = new URL(`${apiClient.defaults.baseURL}/notifications/stream`);
  url.searchParams.set("token", token);

  const eventSource = new EventSource(url.toString());

  eventSource.addEventListener("notification", (event) => {
    try {
      const data = JSON.parse(event.data);
      onNotification(data);
    } catch (error) {
      console.error("Failed to parse notification:", error);
    }
  });

  eventSource.addEventListener("connected", () => {
    console.log("✓ Connected to notification stream");
  });

  eventSource.onerror = (error) => {
    console.error("Notification stream error:", error);
    if (onError) {
      onError(new Error("Notification stream connection failed"));
    }
  };

  return eventSource;
};
