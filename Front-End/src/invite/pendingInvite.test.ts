// @vitest-environment jsdom
import { afterEach, describe, expect, it } from "vitest";

import { captureInviteFromLocation, clearPendingInvite, hasPendingInvite, peekPendingInvite } from "./pendingInvite";

const TOKEN = "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8S9t0U1v";

afterEach(() => {
  clearPendingInvite();
  window.history.replaceState(null, "", "/");
  localStorage.clear();
  sessionStorage.clear();
});

describe("captureInviteFromLocation", () => {
  it("keeps the token in memory only and removes it from the address bar", () => {
    window.history.replaceState(null, "", `/join-space?token=${TOKEN}`);
    captureInviteFromLocation();
    expect(peekPendingInvite()).toBe(TOKEN);
    expect(window.location.href).not.toContain(TOKEN);
    expect(window.location.pathname).toBe("/join-space");
    expect(JSON.stringify({ ...localStorage })).not.toContain(TOKEN);
    expect(JSON.stringify({ ...sessionStorage })).not.toContain(TOKEN);
  });

  it("ignores other paths and malformed or repeated tokens, but still strips them", () => {
    window.history.replaceState(null, "", `/auth?token=${TOKEN}`);
    captureInviteFromLocation();
    expect(hasPendingInvite()).toBe(false);
    expect(window.location.search).toBe(`?token=${TOKEN}`); // the reset-password page owns this one

    window.history.replaceState(null, "", "/join-space?token=<script>");
    captureInviteFromLocation();
    expect(hasPendingInvite()).toBe(false);
    expect(window.location.search).toBe("");

    window.history.replaceState(null, "", `/join-space?token=${TOKEN}&token=${TOKEN}`);
    captureInviteFromLocation();
    expect(hasPendingInvite()).toBe(false);
  });

  it("is forgotten when cleared", () => {
    window.history.replaceState(null, "", `/join-space?token=${TOKEN}`);
    captureInviteFromLocation();
    clearPendingInvite();
    expect(hasPendingInvite()).toBe(false);
  });
});
