import { apiClient } from "./client";

export interface SpacePolicy {
  allowed_models: string[];
  allowed_tools?: string[];
  daily_token_limit?: number | null;
  monthly_token_limit?: number | null;
  daily_request_limit?: number | null;
  monthly_request_limit?: number | null;
  daily_tool_request_limit?: number | null;
  monthly_tool_request_limit?: number | null;
}

export interface SpaceMemberSummary {
  user_id: string;
  email?: string | null;
  role: string;
  status: string;
  can_upload_documents?: boolean;
  created_at: string;
  updated_at: string;
  overrides: SpacePolicy;
}

export interface MySpaceMembership {
  space_id: string;
  user_id: string;
  role: string;
  status: string;
  can_upload_documents: boolean;
  overrides: SpacePolicy;
}

export interface SpaceRequestSummary {
  id: string;
  space_id: string;
  user_id: string;
  type: string;
  payload: Record<string, unknown>;
  status: string;
  review_note?: string | null;
  created_at: string;
  reviewed_at?: string | null;
}

export interface InviteMemberRequest {
  email: string;
}

export interface InviteMemberResponse {
  invite_token: string;
  status: string;
}

export interface AcceptInviteRequest {
  token: string;
}

export interface AcceptInviteResponse {
  space_id: string;
  status: string;
}

export interface UpdateMemberRequest {
  role?: string;
  status?: string;
  can_upload_documents?: boolean;
  overrides?: Partial<SpacePolicy>;
}

export interface UpdatePolicyRequest {
  allowed_models?: string[];
  allowed_tools?: string[];
  daily_token_limit?: number | null;
  monthly_token_limit?: number | null;
  daily_request_limit?: number | null;
  monthly_request_limit?: number | null;
  daily_tool_request_limit?: number | null;
  monthly_tool_request_limit?: number | null;
}

export interface SpaceRequestCreate {
  type: string;
  payload?: Record<string, unknown>;
}

export interface ReviewSpaceRequest {
  decision: string;
  note?: string;
}

export interface UsageTotals {
  input_tokens: number;
  output_tokens: number;
  total_tokens: number;
  requests: number;
  cost_usd?: number | null;
}

export interface SpaceUsageSummary {
  start: string;
  end: string;
  totals: UsageTotals;
  by_model: Record<string, UsageTotals>;
}

export interface SuperAdminUsageRow {
  space_id: string;
  space_name: string;
  start: string;
  end: string;
  totals: UsageTotals;
}

export interface SpaceSummary {
  id: string;
  name: string;
  s3_bucket: string;
  is_active: boolean;
  policy: SpacePolicy;
  created_at: string;
}

export interface CreateSpaceRequest {
  name: string;
}

export interface CreateSpaceResponse {
  space: SpaceSummary;
}

export const listMySpaces = () => apiClient.get<SpaceSummary[]>("/spaces");

export const listAvailableSpaces = () => apiClient.get<SpaceSummary[]>("/spaces/available");

export const createSpace = (payload: CreateSpaceRequest) => apiClient.post<CreateSpaceResponse>("/spaces", payload);

export const acceptInvite = (payload: AcceptInviteRequest) =>
  apiClient.post<AcceptInviteResponse>("/spaces/invites/accept", payload);

export const inviteMember = (spaceId: string, payload: InviteMemberRequest) =>
  apiClient.post<InviteMemberResponse>(`/spaces/${spaceId}/invites`, payload);

export const listMembers = (spaceId: string) => apiClient.get<SpaceMemberSummary[]>(`/spaces/${spaceId}/members`);

export const getMyMembership = (spaceId: string) => apiClient.get<MySpaceMembership>(`/spaces/${spaceId}/me`);

export const updateMember = (spaceId: string, userId: string, payload: UpdateMemberRequest) =>
  apiClient.patch<SpaceMemberSummary>(`/spaces/${spaceId}/members/${userId}`, payload);

export const updatePolicy = (spaceId: string, payload: UpdatePolicyRequest) =>
  apiClient.patch<SpaceSummary>(`/spaces/${spaceId}/policy`, payload);

export const deleteSpace = (spaceId: string) => apiClient.delete<SpaceSummary>(`/spaces/${spaceId}`);

export const createSpaceRequest = (spaceId: string, payload: SpaceRequestCreate) =>
  apiClient.post<SpaceRequestSummary>(`/spaces/${spaceId}/requests`, {
    ...payload,
    payload: payload.payload ?? {},
  });

export const listSpaceRequests = (spaceId: string, status?: string) =>
  apiClient.get<SpaceRequestSummary[]>(`/spaces/${spaceId}/requests`, {
    params: status ? { status } : undefined,
  });

export const reviewSpaceRequest = (spaceId: string, requestId: string, payload: ReviewSpaceRequest) =>
  apiClient.post<SpaceRequestSummary>(`/spaces/${spaceId}/requests/${requestId}/review`, payload);

export const spaceUsage = (spaceId: string, days = 30) =>
  apiClient.get<SpaceUsageSummary>(`/spaces/${spaceId}/usage`, { params: { days } });

export const superadminListSpaces = () => apiClient.get<SpaceSummary[]>("/spaces/_superadmin/spaces");

export const superadminUsage = (days = 30) => apiClient.get<SuperAdminUsageRow[]>("/spaces/_superadmin/usage", { params: { days } });

export interface TopModelStats {
  name: string;
  usage: number;
  cost: number;
}

export interface SpaceUsageStats {
  space_id: string;
  space_name: string;
  tokens: number;
  requests: number;
  cost: number;
}

export interface DailyUsageStats {
  date: string;
  tokens: number;
  requests: number;
  cost: number;
}

export interface ToolUsageStats {
  tool: string;
  count: number;
}

export interface DashboardStats {
  total_users: number;
  active_spaces: number;
  total_messages: number;
  total_sessions: number;
  total_documents: number;
  total_requests: number;
  new_users_30d: number;
  active_users_30d: number;
  admins_count: number;
  members_count: number;
  total_tokens: number;
  total_cost: number;
  avg_response_time: number;
  success_rate: number;
  top_models: TopModelStats[];
  usage_by_space: SpaceUsageStats[];
  daily_usage: DailyUsageStats[];
  tool_usage: ToolUsageStats[];
}

export const getAdminDashboardStats = async (): Promise<DashboardStats> => {
  const { data } = await apiClient.get<DashboardStats>("/spaces/admin/dashboard");
  return data;
};

export const getSpaceDashboardStats = async (spaceId: string): Promise<DashboardStats> => {
  const { data } = await apiClient.get<DashboardStats>(`/spaces/${spaceId}/dashboard`);
  return data;
};
