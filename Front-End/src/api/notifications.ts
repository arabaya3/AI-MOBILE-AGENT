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
