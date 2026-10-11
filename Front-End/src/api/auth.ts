import { apiClient } from "./client";

export interface LoginRequest {
  email: string;
  password: string;
}

export interface TokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
}

export interface SignUpRequest extends LoginRequest {
  role?: "admin" | "viewer";
}

export interface UserResponse {
  id: string;
  email: string;
  role: string;
}

export interface ForgotPasswordRequest {
  email: string;
}

export interface ForgotPasswordResponse {
  message: string;
  reset_token?: string;
}

export interface ResetPasswordRequest {
  token: string;
  new_password: string;
}

export interface ValidateResetTokenRequest {
  token: string;
}

export interface ValidateResetTokenResponse {
  valid: boolean;
}

export interface ChangePasswordRequest {
  current_password: string;
  new_password: string;
}

export const login = (payload: LoginRequest) => apiClient.post<TokenResponse>("/auth/login", payload);

export const signup = (payload: SignUpRequest) => apiClient.post<UserResponse>("/auth/signup", payload);

export const forgotPassword = (payload: ForgotPasswordRequest) =>
  apiClient.post<ForgotPasswordResponse>("/auth/forgot-password", payload);

export const resetPassword = (payload: ResetPasswordRequest) =>
  apiClient.post<{ message: string }>("/auth/reset-password", payload);

export const validateResetPasswordToken = (payload: ValidateResetTokenRequest) =>
  apiClient.post<ValidateResetTokenResponse>("/auth/reset-password/validate", payload);

export const changePassword = (payload: ChangePasswordRequest) =>
  apiClient.post<{ message: string }>("/auth/change-password", payload);

export interface UserListResponse {
  users: UserResponse[];
}

export const listUsers = () => apiClient.get<UserListResponse>("/auth/users");
