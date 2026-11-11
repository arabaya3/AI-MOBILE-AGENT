import { API_BASE_URL } from "./client";
import type { Notification } from "./notifications";

const TOKEN_KEY = "teia_access_token";

export interface StreamHandlers {
  onNotification: (payload: unknown) => void;
  /** Called after every (re)connect, so the caller can reload the authoritative list. */
  onConnected: () => void;
  /** The server rejected the token; the caller should stop (the session is over). */
  onUnauthorized: () => void;
}

export interface StreamOptions {
  fetchImpl?: typeof fetch;
  minDelayMs?: number;
  maxDelayMs?: number;
}

/** Newest first, one entry per id (live events and list reloads can overlap). */
export function mergeNotification(list: Notification[], incoming: Notification): Notification[] {
  return [incoming, ...list.filter((n) => n.id !== incoming.id)];
}

interface SseEvent {
  event: string;
  data: string;
}

/** Incremental `text/event-stream` parser: feed it decoded text, get complete events back. */
export function createSseParser() {
  let buffer = "";
  return (chunk: string): SseEvent[] => {
    buffer += chunk.replace(/\r\n?/g, "\n");
    const events: SseEvent[] = [];
    let end = buffer.indexOf("\n\n");
    while (end !== -1) {
      const block = buffer.slice(0, end);
      buffer = buffer.slice(end + 2);
      let event = "message";
      const data: string[] = [];
      for (const line of block.split("\n")) {
        if (line.startsWith(":")) continue;
        const colon = line.indexOf(":");
        const field = colon === -1 ? line : line.slice(0, colon);
        const value = colon === -1 ? "" : line.slice(colon + 1).replace(/^ /, "");
        if (field === "event") event = value;
        else if (field === "data") data.push(value);
      }
      if (data.length > 0 || event !== "message") events.push({ event, data: data.join("\n") });
      end = buffer.indexOf("\n\n");
    }
    return events;
  };
}

/**
 * Opens the notifications stream with the bearer token in a header (EventSource cannot send
 * headers, and the API does not accept tokens in URLs). Reconnects with bounded backoff until
 * `close()` is called, the token disappears, or the server answers 401/403.
 */
export function openNotificationStream(handlers: StreamHandlers, options: StreamOptions = {}) {
  const fetchImpl = options.fetchImpl ?? fetch.bind(window);
  const minDelay = options.minDelayMs ?? 1000;
  const maxDelay = options.maxDelayMs ?? 30000;
  let closed = false;
  let controller: AbortController | null = null;
  let timer: ReturnType<typeof setTimeout> | null = null;
  let delay = minDelay;

  const schedule = () => {
    if (closed) return;
    timer = setTimeout(run, delay);
    delay = Math.min(delay * 2, maxDelay);
  };

  async function run() {
    timer = null;
    const token = localStorage.getItem(TOKEN_KEY);
    if (closed || !token) return;
    controller = new AbortController();
    try {
      const response = await fetchImpl(`${API_BASE_URL}/notifications/stream`, {
        headers: { Authorization: `Bearer ${token}`, Accept: "text/event-stream" },
        cache: "no-store",
        signal: controller.signal,
      });
      if (response.status === 401 || response.status === 403) {
        closed = true;
        handlers.onUnauthorized();
        return;
      }
      if (!response.ok || !response.body) throw new Error(`stream status ${response.status}`);
      delay = minDelay;
      handlers.onConnected();
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      const parse = createSseParser();
      for (;;) {
        const { done, value } = await reader.read();
        if (done || closed) break;
        for (const event of parse(decoder.decode(value, { stream: true }))) {
          if (event.event !== "notification") continue;
          try {
            handlers.onNotification(JSON.parse(event.data));
          } catch {
            // A malformed event is skipped; the list reload on reconnect stays authoritative.
          }
        }
      }
    } catch {
      // Aborted by close(), or a network error: reconnect below unless closed.
    } finally {
      controller = null;
    }
    schedule();
  }

  void run();
  return {
    close() {
      closed = true;
      if (timer) clearTimeout(timer);
      controller?.abort();
    },
  };
}
