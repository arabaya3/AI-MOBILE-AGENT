import { apiClient } from "./client";

export interface SystemPrompts {
  tools_system_prompt: string;
  web_search_decision_prompt: string;
  memory_system_prompt: string;
  stream_system_prompt: string;
  answer_question_system_prompt: string;
}

export const getSystemPrompts = () => apiClient.get<SystemPrompts>("/system-prompts");

export const updateSystemPrompts = (payload: Partial<SystemPrompts>) =>
  apiClient.put<SystemPrompts>("/system-prompts", payload);
