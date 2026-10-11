export interface AuthUser {
  id: string;
  email: string;
  role: "admin" | "viewer" | string;
  /** Legal first name */
  first_name?: string;
  /** Legal last name */
  last_name?: string;
  /** ISO-8601 date string, e.g. "1990-05-20" */
  date_of_birth?: string;
  /** Phone number (E.164 or local format) */
  phone_number?: string;
  /** ISO-3166-1 country name or code */
  country?: string;
  /** Job title / position */
  job_title?: string;
  /** Employer / organisation name */
  company?: string;
  /** User's professional industry context for AI personalisation */
  industry?: string;
  /** User's preferred response language for AI personalisation */
  preferred_language?: string;
}
