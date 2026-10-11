import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { jwtDecode } from "jwt-decode";

import type { ForgotPasswordResponse, LoginRequest, SignUpRequest } from "../api/auth";
import {
  changePassword as changePasswordApi,
  forgotPassword,
  login as loginApi,
  resetPassword,
  signup as signupApi,
  validateResetPasswordToken,
} from "../api/auth";
import { apiClient } from "../api/client";
import type { AuthUser } from "../types";

interface DecodedToken {
  sub: string;
  scopes?: string[];
  exp?: number;
}

interface AuthContextValue {
  user: AuthUser | null;
  token: string | null;
  isAuthenticated: boolean;
  login: (payload: LoginRequest) => Promise<void>;
  signup: (payload: SignUpRequest) => Promise<void>;
  logout: () => void;
  requestPasswordReset: (email: string) => Promise<ForgotPasswordResponse>;
  validatePasswordResetToken: (token: string) => Promise<boolean>;
  completePasswordReset: (token: string, newPassword: string) => Promise<void>;
  changePassword: (currentPassword: string, newPassword: string) => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

const TOKEN_KEY = "lawtech_access_token";
const USER_KEY = "lawtech_user_profile";
const SPACE_KEY = "lawtech_active_space_id";

const decodeUser = (token: string, fallbackEmail: string): AuthUser => {
  const decoded = jwtDecode<DecodedToken>(token);
  const primaryScope = decoded.scopes?.[0] ?? "viewer";
  return {
    id: decoded.sub,
    email: fallbackEmail,
    role: primaryScope,
  };
};

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [token, setToken] = useState<string | null>(() => localStorage.getItem(TOKEN_KEY));
  const [user, setUser] = useState<AuthUser | null>(() => {
    const stored = localStorage.getItem(USER_KEY);
    return stored ? (JSON.parse(stored) as AuthUser) : null;
  });

  // Keep React state in sync when other parts of the app mutate localStorage
  // (e.g., the axios interceptor clearing tokens on 401).
  useEffect(() => {
    const syncFromStorage = () => {
      const nextToken = localStorage.getItem(TOKEN_KEY);
      const storedUser = localStorage.getItem(USER_KEY);

      setToken(nextToken);
      setUser(storedUser ? (JSON.parse(storedUser) as AuthUser) : null);
    };

    const handleAuthChanged = () => syncFromStorage();
    window.addEventListener("lawtech-auth-changed", handleAuthChanged as EventListener);

    // Also sync once on mount in case storage was mutated before provider initialized.
    syncFromStorage();

    return () => window.removeEventListener("lawtech-auth-changed", handleAuthChanged as EventListener);
  }, []);

  const persist = (nextToken: string, profile: AuthUser) => {
    setToken(nextToken);
    setUser(profile);
    localStorage.setItem(TOKEN_KEY, nextToken);
    localStorage.setItem(USER_KEY, JSON.stringify(profile));
  };

  const login = async (payload: LoginRequest) => {
    setToken(null);
    setUser(null);
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    localStorage.removeItem(SPACE_KEY);
    delete apiClient.defaults.headers.common["X-Space-Id"];
    const { data } = await loginApi(payload);
    const profile = decodeUser(data.access_token, payload.email);
    persist(data.access_token, profile);
    window.dispatchEvent(new CustomEvent("lawtech-auth-changed"));
  };

  const signup = async (payload: SignUpRequest) => {
    localStorage.removeItem(SPACE_KEY);
    delete apiClient.defaults.headers.common["X-Space-Id"];
    await signupApi(payload);
    await login({ email: payload.email, password: payload.password });
  };

  const logout = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    localStorage.removeItem(SPACE_KEY);
    delete apiClient.defaults.headers.common["X-Space-Id"];
    window.dispatchEvent(new CustomEvent("lawtech-auth-changed"));
  };

  const requestPasswordReset = async (email: string) => {
    const { data } = await forgotPassword({ email });
    return data;
  };

  const validatePasswordResetToken = async (tokenValue: string) => {
    const trimmed = String(tokenValue ?? "").trim();
    if (!trimmed) return false;
    const { data } = await validateResetPasswordToken({ token: trimmed });
    return Boolean(data.valid);
  };

  const completePasswordReset = async (tokenValue: string, newPassword: string) => {
    await resetPassword({ token: tokenValue, new_password: newPassword });
  };

  const changePassword = async (currentPassword: string, newPassword: string) => {
    if (!user) {
      throw new Error("User not authenticated");
    }
    await changePasswordApi({ current_password: currentPassword, new_password: newPassword });
  };

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      token,
      isAuthenticated: Boolean(token),
      login,
      signup,
      logout,
      requestPasswordReset,
      validatePasswordResetToken,
      completePasswordReset,
      changePassword,
    }),
    [user, token],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return ctx;
};

export default AuthProvider;
