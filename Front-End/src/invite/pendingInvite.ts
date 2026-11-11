// The invitation token lives only in this module's memory: never in storage, a route, or a log.
// It survives in-app navigation through sign-in or sign-up, and is lost on a full reload
// (the recipient can open the emailed link again).
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{16,256}$/;

let pending: string | null = null;

export const JOIN_PATH = "/join-space";

/** Moves a `?token=` from the current URL into memory and removes it from the address bar. */
export function captureInviteFromLocation(): void {
  const url = new URL(window.location.href);
  if (url.pathname.replace(/\/$/, "") !== JOIN_PATH) return;
  const tokens = url.searchParams.getAll("token");
  if (tokens.length > 0) {
    if (tokens.length === 1 && TOKEN_PATTERN.test(tokens[0])) pending = tokens[0];
    window.history.replaceState(window.history.state, "", JOIN_PATH);
  }
}

export const hasPendingInvite = () => pending !== null;

export const peekPendingInvite = () => pending;

export function clearPendingInvite(): void {
  pending = null;
}
