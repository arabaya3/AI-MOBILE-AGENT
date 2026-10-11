import {
  Alert,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import { useEffect, useMemo, useState, type ChangeEvent } from "react";

import type { SuperAdminUsageRow } from "../api/spaces";
import { superadminUsage } from "../api/spaces";
import { AdminAnalyticsDashboard } from "./AdminAnalyticsDashboard";
import { RequestsManagement } from "./RequestsManagement";
import type { SystemPrompts } from "../api/systemPrompts";
import { getSystemPrompts, updateSystemPrompts } from "../api/systemPrompts";

interface SuperAdminDialogProps {
  open: boolean;
  onClose: () => void;
  onOpenSpace: (spaceId: string) => void;
}

export const SuperAdminDialog = ({ open, onClose, onOpenSpace }: SuperAdminDialogProps) => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [rows, setRows] = useState<SuperAdminUsageRow[]>([]);
  const [promptsLoading, setPromptsLoading] = useState(false);
  const [promptsError, setPromptsError] = useState<string | null>(null);
  const [promptsSaving, setPromptsSaving] = useState(false);
  const [prompts, setPrompts] = useState<SystemPrompts | null>(null);
  const [draftPrompts, setDraftPrompts] = useState<SystemPrompts | null>(null);
  const [promptsSaved, setPromptsSaved] = useState(false);

  const sorted = useMemo(() => {
    return [...rows].sort((a, b) => a.space_name.localeCompare(b.space_name));
  }, [rows]);

  useEffect(() => {
    if (!open) return;
    setLoading(true);
    setError(null);
    superadminUsage(30)
      .then(({ data }) => setRows(data))
      .catch(() => setError("Unable to load super admin analytics."))
      .finally(() => setLoading(false));
  }, [open]);

  useEffect(() => {
    if (!open) return;
    setPromptsLoading(true);
    setPromptsError(null);
    setPromptsSaved(false);
    getSystemPrompts()
      .then(({ data }) => {
        setPrompts(data);
        setDraftPrompts(data);
      })
      .catch(() => setPromptsError("Unable to load system prompts."))
      .finally(() => setPromptsLoading(false));
  }, [open]);

  const handlePromptChange = (field: keyof SystemPrompts) => (event: ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value;
    setDraftPrompts((prev) => (prev ? { ...prev, [field]: value } : prev));
    setPromptsSaved(false);
  };

  const handleSavePrompts = () => {
    if (!draftPrompts) return;
    setPromptsSaving(true);
    setPromptsError(null);
    updateSystemPrompts(draftPrompts)
      .then(({ data }) => {
        setPrompts(data);
        setDraftPrompts(data);
        setPromptsSaved(true);
      })
      .catch(() => setPromptsError("Unable to save system prompts."))
      .finally(() => setPromptsSaving(false));
  };

  const handleResetPrompts = () => {
    if (prompts) {
      setDraftPrompts(prompts);
      setPromptsSaved(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle>
        <Stack spacing={0.5}>
          <Typography variant="h6" fontWeight={700}>
            لوحة الإدارة العليا
          </Typography>
          <Typography variant="body2" color="text.secondary">
            نظرة شاملة على المنصة (آخر 30 يوماً)
          </Typography>
        </Stack>
      </DialogTitle>
      <DialogContent dividers>
        {error ? (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        ) : null}

        <Card variant="outlined" sx={{ mb: 2 }}>
          <CardContent>
            <Stack spacing={1.5}>
              <Stack spacing={0.25}>
                <Typography fontWeight={700}>نصوص المساعد القانوني</Typography>
                <Typography variant="body2" color="text.secondary">
                  تعديل نصوص المساعد القانوني المستخدمة في جميع الجلسات. التغييرات تُطبَّق فوراً.
                </Typography>
              </Stack>

              {promptsError ? (
                <Alert severity="error">{promptsError}</Alert>
              ) : null}

              {promptsLoading || !draftPrompts ? (
                <Stack direction="row" spacing={1} alignItems="center">
                  <CircularProgress size={18} />
                  <Typography variant="body2" color="text.secondary">
                    جارٍ تحميل النصوص…
                  </Typography>
                </Stack>
              ) : (
                <Stack spacing={1.5}>
                  <TextField
                    label="نص أدوات المساعد"
                    multiline
                    minRows={5}
                    value={draftPrompts.tools_system_prompt}
                    onChange={handlePromptChange("tools_system_prompt")}
                    fullWidth
                  />
                  <TextField
                    label="نص البحث على الويب"
                    multiline
                    minRows={4}
                    value={draftPrompts.web_search_decision_prompt}
                    onChange={handlePromptChange("web_search_decision_prompt")}
                    fullWidth
                  />
                  <TextField
                    label="نص الذاكرة"
                    multiline
                    minRows={4}
                    value={draftPrompts.memory_system_prompt}
                    onChange={handlePromptChange("memory_system_prompt")}
                    fullWidth
                  />
                  <TextField
                    label="نص البث المباشر"
                    multiline
                    minRows={4}
                    value={draftPrompts.stream_system_prompt}
                    onChange={handlePromptChange("stream_system_prompt")}
                    fullWidth
                  />
                  <TextField
                    label="نص الإجابة عن الأسئلة"
                    multiline
                    minRows={4}
                    value={draftPrompts.answer_question_system_prompt}
                    onChange={handlePromptChange("answer_question_system_prompt")}
                    fullWidth
                  />
                  <Stack direction={{ xs: "column", sm: "row" }} spacing={1} justifyContent="flex-end">
                    <Button variant="outlined" onClick={handleResetPrompts} disabled={!prompts || promptsSaving}>
                      استعادة التغييرات
                    </Button>
                    <Button variant="contained" onClick={handleSavePrompts} disabled={promptsSaving}>
                      {promptsSaving ? "جارٍ الحفظ…" : "حفظ النصوص"}
                    </Button>
                  </Stack>
                  {promptsSaved ? <Alert severity="success">تم حفظ النصوص.</Alert> : null}
                </Stack>
              )}
            </Stack>
          </CardContent>
        </Card>

        <Card variant="outlined" sx={{ mb: 2 }}>
          <CardContent>
            <RequestsManagement />
          </CardContent>
        </Card>

        {loading ? (
          <Stack direction="row" spacing={1} alignItems="center" justifyContent="center" sx={{ py: 6 }}>
            <CircularProgress size={22} />
            <Typography color="text.secondary">Loading…</Typography>
          </Stack>
        ) : sorted.length > 0 ? (
           <AdminAnalyticsDashboard data={sorted} loading={loading} onOpenSpace={onOpenSpace} />
        ) : (
          <Stack spacing={1.5}>
            <Typography color="text.secondary">لا توجد بيانات استخدام.</Typography>
          </Stack>
        )}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>إغلاق</Button>
      </DialogActions>
    </Dialog>
  );
};

export default SuperAdminDialog;
