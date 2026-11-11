// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { Notification } from "./notifications";
import { createSseParser, mergeNotification, openNotificationStream } from "./notificationStream";

const encoder = new TextEncoder();

/** A fetch whose responses stream the given chunks, then stay open until aborted. */
function streamingFetch(chunksPerConnection: string[][], statuses: number[] = []) {
  const calls: RequestInit[] = [];
  let index = 0;
  const impl = vi.fn(async (_url: string, init: RequestInit) => {
    calls.push(init);
    const status = statuses[index] ?? 200;
    const chunks = chunksPerConnection[index] ?? [];
    index += 1;
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        for (const chunk of chunks) controller.enqueue(encoder.encode(chunk));
        if (chunks.length === 0) controller.close();
        init.signal?.addEventListener("abort", () => controller.error(new DOMException("aborted", "AbortError")));
      },
    });
    return new Response(status === 200 ? body : null, { status });
  });
  return { impl: impl as unknown as typeof fetch, calls };
}

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("createSseParser", () => {
  it("joins events split across chunks and ignores comments", () => {
    const parse = createSseParser();
    expect(parse(": ping\n\nevent: notif")).toEqual([]);
    expect(parse('ication\ndata: {"id":"1"}\r\n\r\nevent: connected\ndata: {}\n\n')).toEqual([
      { event: "notification", data: '{"id":"1"}' },
      { event: "connected", data: "{}" },
    ]);
  });
});

describe("openNotificationStream", () => {
  beforeEach(() => localStorage.setItem("teia_access_token", "secret-token"));
  afterEach(() => {
    localStorage.clear();
    vi.useRealTimers();
  });

  it("sends the token only in the Authorization header", async () => {
    const { impl, calls } = streamingFetch([['event: notification\ndata: {"id":"n1"}\n\n']]);
    const received: unknown[] = [];
    const stream = openNotificationStream(
      { onNotification: (n) => received.push(n), onConnected: () => {}, onUnauthorized: () => {} },
      { fetchImpl: impl },
    );
    await flush();
    await flush();
    const [url] = (impl as unknown as ReturnType<typeof vi.fn>).mock.calls[0];
    expect(String(url)).not.toContain("secret-token");
    expect(String(url)).not.toContain("token=");
    expect((calls[0].headers as Record<string, string>).Authorization).toBe("Bearer secret-token");
    expect(received).toEqual([{ id: "n1" }]);
    stream.close();
  });

  it("reconnects with backoff and reloads the list after every connect", async () => {
    vi.useFakeTimers();
    const { impl } = streamingFetch([[], [], []], [500, 200, 200]);
    const connected = vi.fn();
    const stream = openNotificationStream(
      { onNotification: () => {}, onConnected: connected, onUnauthorized: () => {} },
      { fetchImpl: impl, minDelayMs: 100, maxDelayMs: 400 },
    );
    await vi.advanceTimersByTimeAsync(0);
    expect(impl).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(100);
    expect(impl).toHaveBeenCalledTimes(2);
    expect(connected).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(100);
    expect(impl).toHaveBeenCalledTimes(3);
    expect(connected).toHaveBeenCalledTimes(2);
    stream.close();
    await vi.advanceTimersByTimeAsync(1000);
    expect(impl).toHaveBeenCalledTimes(3);
  });

  it("stops on 401 and does not connect without a token", async () => {
    const unauthorized = vi.fn();
    const { impl } = streamingFetch([[]], [401]);
    openNotificationStream({ onNotification: () => {}, onConnected: () => {}, onUnauthorized: unauthorized }, { fetchImpl: impl });
    await flush();
    expect(unauthorized).toHaveBeenCalledTimes(1);

    localStorage.clear();
    const idle = streamingFetch([[]]);
    openNotificationStream({ onNotification: () => {}, onConnected: () => {}, onUnauthorized: () => {} }, { fetchImpl: idle.impl });
    await flush();
    expect(idle.impl).not.toHaveBeenCalled();
  });

  it("close() aborts an open stream (logout)", async () => {
    const { impl, calls } = streamingFetch([['event: connected\ndata: {}\n\n']]);
    const stream = openNotificationStream({ onNotification: () => {}, onConnected: () => {}, onUnauthorized: () => {} }, { fetchImpl: impl });
    await flush();
    stream.close();
    expect(calls[0].signal?.aborted).toBe(true);
  });
});

describe("mergeNotification", () => {
  it("keeps one entry per id, newest first", () => {
    const n = (id: string, title = id) => ({ id, title }) as Notification;
    const list = mergeNotification(mergeNotification([n("a"), n("b")], n("c")), n("a", "updated"));
    expect(list.map((x) => [x.id, x.title])).toEqual([["a", "updated"], ["c", "c"], ["b", "b"]]);
  });
});
