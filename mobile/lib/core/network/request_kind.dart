enum RequestKind {
  /// Sends the bearer token; a 401 means the session expired.
  authenticated,

  /// No bearer token (login, sign-up, password recovery); a 401 means bad credentials.
  public,

  /// Sends the bearer token, but a 401 means a credential check failed
  /// (for example a wrong current password), not that the session expired.
  credentialCheck,
}
