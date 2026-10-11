import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";

import type { CreateSpaceRequest, SpaceSummary } from "../api/spaces";
import { createSpace as createSpaceApi, listMySpaces } from "../api/spaces";
import { apiClient } from "../api/client";

interface SpaceContextValue {
  spaces: SpaceSummary[];
  activeSpaceId: string | null;
  isReady: boolean;
  refreshSpaces: () => Promise<void>;
  selectSpace: (spaceId: string) => void;
  createSpace: (payload: CreateSpaceRequest) => Promise<SpaceSummary>;
  clearSpace: () => void;
}

const SpaceContext = createContext<SpaceContextValue | undefined>(undefined);

const SPACE_KEY = "lawtech_active_space_id";

export const SpaceProvider = ({ children }: { children: React.ReactNode }) => {
  const [spaces, setSpaces] = useState<SpaceSummary[]>([]);
  const [activeSpaceId, setActiveSpaceId] = useState<string | null>(() => {
    const stored = localStorage.getItem(SPACE_KEY);
    if (stored) {
      apiClient.defaults.headers.common["X-Space-Id"] = stored;
    }
    return stored;
  });
  const [isReady, setIsReady] = useState(false);
  const refreshInFlight = useRef(false);
  const lastRefreshAt = useRef(0);

  const selectSpace = (spaceId: string) => {
    setActiveSpaceId(spaceId);
    localStorage.setItem(SPACE_KEY, spaceId);
    apiClient.defaults.headers.common["X-Space-Id"] = spaceId;
  };

  const clearSpace = () => {
    setActiveSpaceId(null);
    setSpaces([]);
    localStorage.removeItem(SPACE_KEY);
    delete apiClient.defaults.headers.common["X-Space-Id"];
    setIsReady(false);
  };

  const refreshSpaces = useCallback(async () => {
    const now = Date.now();
    if (refreshInFlight.current || now - lastRefreshAt.current < 5000) {
      return;
    }
    refreshInFlight.current = true;
    try {
      const { data } = await listMySpaces();
      setSpaces(data);

      const stored = localStorage.getItem(SPACE_KEY);
      const stillValid = stored && data.some((s) => s.id === stored);
      if (!stillValid) {
        const next = data[0]?.id ?? null;
        setActiveSpaceId(next);
        if (next) {
          localStorage.setItem(SPACE_KEY, next);
          apiClient.defaults.headers.common["X-Space-Id"] = next;
        } else {
          localStorage.removeItem(SPACE_KEY);
          delete apiClient.defaults.headers.common["X-Space-Id"];
        }
      } else if (stored) {
        apiClient.defaults.headers.common["X-Space-Id"] = stored;
      }

      setIsReady(true);
      lastRefreshAt.current = Date.now();
    } finally {
      refreshInFlight.current = false;
    }
  }, []);

  useEffect(() => {
    const handleAuthChange = () => {
      const token = localStorage.getItem("lawtech_access_token");
      if (!token) {
        clearSpace();
        return;
      }
      setIsReady(false);
      refreshSpaces().catch(() => {
        setSpaces([]);
        setActiveSpaceId(null);
        setIsReady(true);
      });
    };

    window.addEventListener("lawtech-auth-changed", handleAuthChange);
    return () => window.removeEventListener("lawtech-auth-changed", handleAuthChange);
  }, [refreshSpaces]);

  useEffect(() => {
    const token = localStorage.getItem("lawtech_access_token");
    if (!token) return;

    const intervalId = window.setInterval(() => {
      refreshSpaces().catch(() => {
        // Ignore transient failures; keep last known policy.
      });
    }, 60000);

    return () => window.clearInterval(intervalId);
  }, [refreshSpaces]);

  const createSpace = async (payload: CreateSpaceRequest) => {
    const { data } = await createSpaceApi(payload);
    const created = data.space;
    setSpaces((prev) => [created, ...prev]);
    selectSpace(created.id);
    return created;
  };

  const value = useMemo<SpaceContextValue>(
    () => ({
      spaces,
      activeSpaceId,
      isReady,
      refreshSpaces,
      selectSpace,
      createSpace,
      clearSpace,
    }),
    [spaces, activeSpaceId, isReady],
  );

  return <SpaceContext.Provider value={value}>{children}</SpaceContext.Provider>;
};

export const useSpace = () => {
  const ctx = useContext(SpaceContext);
  if (!ctx) {
    throw new Error("useSpace must be used within a SpaceProvider");
  }
  return ctx;
};

export default SpaceProvider;
