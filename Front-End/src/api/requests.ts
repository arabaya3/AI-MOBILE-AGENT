import { apiClient as client } from "./client";

export interface CreateRequestPayload {
  request_type: "quota_increase" | "model_access";
  payload: Record<string, any>;
}

export interface UpdateRequestStatus {
  status: "approved" | "rejected" | "pending";
  admin_response?: string;
}

export interface RequestResponse {
  id: string;
  user_id: string;
  request_type: string;
  status: string;
  payload: Record<string, any>;
  admin_response?: string;
  created_at: string;
  updated_at: string;
}

export const listRequests = () => client.get<RequestResponse[]>("/requests/");
export const createRequest = (data: CreateRequestPayload) => client.post<RequestResponse>("/requests/", data);
export const updateRequest = (requestId: string, data: UpdateRequestStatus) => client.put<RequestResponse>(`/requests/${requestId}`, data);
