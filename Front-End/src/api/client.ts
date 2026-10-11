import axios from "axios";

// Determine API URL based on environment / current host
const getCurrentApiUrl = () => {
  // Highest priority: explicit env override (set in .env.development / .env.production)
  if (import.meta.env.VITE_API_BASE_URL) {
    return import.meta.env.VITE_API_BASE_URL;
  }

  const host = window.location.hostname;
  const apiPort = "8001";

  // When served from a CDN/CloudFront domain, we can't reach port 8001 on it —
  // route directly to the backend server instead.
  const isCdnHost =
    host.includes("cloudfront.net") ||
    host.includes("cloudflare") ||
    (!host.includes("localhost") &&
      !host.includes("127.0.0.1") &&
      !host.match(/^\d+\.\d+\.\d+\.\d+$/)); // not a raw IP

  if (isCdnHost) {
    // Point straight to the backend server.
    // Match the page protocol so HTTPS CloudFront pages don't trigger Safari's
    // mixed-content block when the backend is HTTP-only.
    const protocol = window.location.protocol; // 'https:' or 'http:'
    return `${protocol}//87.106.87.218:${apiPort}/api/v1`;
  }

  // localhost, 127.0.0.1 or direct-IP access: use current hostname
  return `http://${host}:${apiPort}/api/v1`;
};

export const API_BASE_URL = getCurrentApiUrl();

const SPACE_KEY = "teia_active_space_id";

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
});

apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem("teia_access_token");
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
      localStorage.removeItem("teia_access_token");
      localStorage.removeItem("teia_user_profile");
      localStorage.removeItem(SPACE_KEY);
      delete apiClient.defaults.headers.common["X-Space-Id"];
      window.dispatchEvent(new CustomEvent("teia-auth-changed"));
    }
    return Promise.reject(error);
  },
);
