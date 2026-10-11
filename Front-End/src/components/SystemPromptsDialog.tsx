import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
  CircularProgress,
  Alert,
} from "@mui/material";
import { useEffect, useState } from "react";
import { apiClient } from "../api/client";

interface SystemPrompts {
  tools_system_prompt: string;
  web_search_decision_prompt: string;
  memory_system_prompt: string;
  stream_system_prompt: string;
  answer_question_system_prompt: string;
}

interface SystemPromptsDialogProps {
  open: boolean;
  onClose: () => void;
}

export const SystemPromptsDialog = ({ open, onClose }: SystemPromptsDialogProps) => {
  const [prompts, setPrompts] = useState<SystemPrompts | null>(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      loadPrompts();
    }
  }, [open]);

  const loadPrompts = async () => {
    setLoading(true);
    setError(null);
    try {
      const { data } = await apiClient.get<SystemPrompts>("/system-prompts");
      setPrompts(data);
    } catch (err: any) {
      setError(err.response?.data?.detail || "Failed to load system prompts.");
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    if (!prompts) return;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await apiClient.put<SystemPrompts>("/system-prompts", prompts);
      setSuccess("Prompts updated successfully.");
    } catch (err: any) {
      setError(err.response?.data?.detail || "Failed to update system prompts.");
    } finally {
      setSaving(false);
    }
  };

  const handleChange = (key: keyof SystemPrompts, value: string) => {
    if (!prompts) return;
    setPrompts({ ...prompts, [key]: value });
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="lg" fullWidth>
      <DialogTitle>System Prompts Configuration</DialogTitle>
      <DialogContent dividers>
        {loading ? (
          <CircularProgress />
        ) : error && !prompts ? (
          <Alert severity="error">{error}</Alert>
        ) : prompts ? (
          <Stack spacing={3}>
            {error && <Alert severity="error">{error}</Alert>}
            {success && <Alert severity="success">{success}</Alert>}
            
            <TextField
              label="Tools Decision Prompt"
              multiline
              minRows={3}
              maxRows={10}
              fullWidth
              value={prompts.tools_system_prompt}
              onChange={(e) => handleChange("tools_system_prompt", e.target.value)}
              helperText="Instructions for the agent to decide which tool to use."
            />
             <TextField
              label="Web Search Decision Prompt"
              multiline
              minRows={3}
              maxRows={10}
              fullWidth
              value={prompts.web_search_decision_prompt}
              onChange={(e) => handleChange("web_search_decision_prompt", e.target.value)}
              helperText="Internal reasoning instructions for web search utility."
            />
             <TextField
              label="Memory System Prompt"
              multiline
              minRows={3}
              maxRows={10}
              fullWidth
              value={prompts.memory_system_prompt}
              onChange={(e) => handleChange("memory_system_prompt", e.target.value)}
              helperText="Context management instructions."
            />
             <TextField
              label="Stream System Prompt"
              multiline
              minRows={3}
              maxRows={10}
              fullWidth
              value={prompts.stream_system_prompt}
              onChange={(e) => handleChange("stream_system_prompt", e.target.value)}
              helperText="Controls the style and format of streamed responses."
            />
             <TextField
              label="Answer Question System Prompt"
              multiline
              minRows={3}
              maxRows={10}
              fullWidth
              value={prompts.answer_question_system_prompt}
              onChange={(e) => handleChange("answer_question_system_prompt", e.target.value)}
              helperText="Core instruction for answering user queries."
            />
          </Stack>
        ) : null}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Close</Button>
        <Button onClick={handleSave} variant="contained" disabled={loading || saving || !prompts}>
          {saving ? "Saving..." : "Save Changes"}
        </Button>
      </DialogActions>
    </Dialog>
  );
};
