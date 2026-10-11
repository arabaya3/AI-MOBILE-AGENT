import axios from "axios";

// Determine API URL based on current host to avoid browser security blocks
const getCurrentApiUrl = () => {
  // If explicitly set in env, use it
  if (import.meta.env.VITE_API_BASE_URL) {
    return import.meta.env.VITE_API_BASE_URL;
  }

  // Get current host (e.g., 87.106.87.218:5174)
  const currentHost = window.location.hostname;
  const apiPort = "8001";

  // Always use current hostname for backend to avoid loopback/public IP conflicts
  return `http://${currentHost}:${apiPort}/api/v1`;
};

export const API_BASE_URL = getCurrentApiUrl();

// Migrate stale keys from old branding (Lex-Tech_*) to current (lawtech_*)
// so users are never silently logged out after a rebranding deploy.
const LEGACY_KEYS: Record<string, string> = {
  "Lex-Tech_access_token": "lawtech_access_token",
  "Lex-Tech_user_profile": "lawtech_user_profile",
  "Lex-Tech_active_space_id": "lawtech_active_space_id",
};
Object.entries(LEGACY_KEYS).forEach(([oldKey, newKey]) => {
  const value = localStorage.getItem(oldKey);
  if (value !== null) {
    if (!localStorage.getItem(newKey)) localStorage.setItem(newKey, value);
    localStorage.removeItem(oldKey);
  }
});

const SPACE_KEY = "lawtech_active_space_id";

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
});

apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem("lawtech_access_token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }

  const spaceId = localStorage.getItem(SPACE_KEY);
  if (spaceId) {
    config.headers["X-Space-Id"] = spaceId;
  }
  return config;
});

apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem("lawtech_access_token");
      localStorage.removeItem("lawtech_user_profile");
      localStorage.removeItem(SPACE_KEY);
      delete apiClient.defaults.headers.common["X-Space-Id"];
      window.dispatchEvent(new CustomEvent("lawtech-auth-changed"));
    }
    return Promise.reject(error);
  },
);
