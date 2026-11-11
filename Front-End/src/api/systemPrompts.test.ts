// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from "vitest";

import { apiClient } from "./client";
import { getSystemPrompts, updateSystemPrompts } from "./systemPrompts";

afterEach(() => vi.restoreAllMocks());

describe("system prompt calls", () => {
  it("use the super-admin global endpoint, never the removed combined one", async () => {
    const get = vi.spyOn(apiClient, "get").mockResolvedValue({ data: {} });
    const put = vi.spyOn(apiClient, "put").mockResolvedValue({ data: {} });
    await getSystemPrompts();
    await updateSystemPrompts({ stream_system_prompt: "x" });
    expect(get).toHaveBeenCalledWith("/system-prompts/global");
    expect(put).toHaveBeenCalledWith("/system-prompts/global", { stream_system_prompt: "x" });
  });
});
