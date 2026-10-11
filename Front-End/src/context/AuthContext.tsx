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
  /** Persist user profile fields locally */
  updateUserProfile: (patch: Partial<Pick<AuthUser, "first_name" | "last_name" | "date_of_birth" | "phone_number" | "country" | "job_title" | "company" | "industry" | "preferred_language">>) => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

const TOKEN_KEY = "teia_access_token";
const USER_KEY = "teia_user_profile";
const SPACE_KEY = "teia_active_space_id";

const decodeUser = (
  token: string,
  fallbackEmail: string,
  extra?: Partial<Pick<AuthUser, "first_name" | "last_name" | "date_of_birth" | "phone_number" | "country" | "job_title" | "company" | "industry" | "preferred_language">>
): AuthUser => {
  const decoded = jwtDecode<DecodedToken>(token);
  const primaryScope = decoded.scopes?.[0] ?? "viewer";
  return {
    id: decoded.sub,
    email: fallbackEmail,
    role: primaryScope,
    first_name: extra?.first_name,
    last_name: extra?.last_name,
    date_of_birth: extra?.date_of_birth,
    phone_number: extra?.phone_number,
    country: extra?.country,
    job_title: extra?.job_title,
    company: extra?.company,
    industry: extra?.industry,
    preferred_language: extra?.preferred_language,
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
    window.addEventListener("teia-auth-changed", handleAuthChanged as EventListener);

    // Also sync once on mount in case storage was mutated before provider initialized.
    syncFromStorage();

    return () => window.removeEventListener("teia-auth-changed", handleAuthChanged as EventListener);
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
    window.dispatchEvent(new CustomEvent("teia-auth-changed"));
  };

  const signup = async (payload: SignUpRequest) => {
    localStorage.removeItem(SPACE_KEY);
    delete apiClient.defaults.headers.common["X-Space-Id"];
    await signupApi(payload);
    // After registering, immediately log in to get the JWT
    await login({ email: payload.email, password: payload.password });
    // Persist all extra profile fields locally (they are not in the JWT)
    const profilePatch: Partial<AuthUser> = {};
    if (payload.first_name)         profilePatch.first_name         = payload.first_name;
    if (payload.last_name)          profilePatch.last_name          = payload.last_name;
    if (payload.date_of_birth)      profilePatch.date_of_birth      = payload.date_of_birth;
    if (payload.phone_number)       profilePatch.phone_number       = payload.phone_number;
    if (payload.country)            profilePatch.country            = payload.country;
    if (payload.job_title)          profilePatch.job_title          = payload.job_title;
    if (payload.company)            profilePatch.company            = payload.company;
    if (payload.industry)           profilePatch.industry           = payload.industry;
    if (payload.preferred_language) profilePatch.preferred_language = payload.preferred_language;
    if (Object.keys(profilePatch).length > 0) {
      setUser((prev) => {
        if (!prev) return prev;
        const updated: AuthUser = { ...prev, ...profilePatch };
        localStorage.setItem(USER_KEY, JSON.stringify(updated));
        return updated;
      });
    }
  };

  const logout = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    localStorage.removeItem(SPACE_KEY);
    delete apiClient.defaults.headers.common["X-Space-Id"];
    window.dispatchEvent(new CustomEvent("teia-auth-changed"));
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

  const updateUserProfile = (patch: Partial<Pick<AuthUser, "first_name" | "last_name" | "date_of_birth" | "phone_number" | "country" | "job_title" | "company" | "industry" | "preferred_language">>) => {
    setUser((prev) => {
      if (!prev) return prev;
      const updated: AuthUser = { ...prev, ...patch };
      localStorage.setItem(USER_KEY, JSON.stringify(updated));
      return updated;
    });
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
      updateUserProfile,
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
