import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Divider,
  IconButton,
  Paper,
  Snackbar,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tooltip,
  Typography,
  useTheme,
} from "@mui/material";
import ArrowForwardRoundedIcon from "@mui/icons-material/ArrowForwardRounded";
import DeleteRoundedIcon from "@mui/icons-material/DeleteRounded";
import GavelRoundedIcon from "@mui/icons-material/GavelRounded";
import UploadFileRoundedIcon from "@mui/icons-material/UploadFileRounded";

import { useAuth } from "../context/AuthContext";
import { deleteGlobalLaw, fetchGlobalLaws, uploadGlobalLaw, type AccessibleDocument } from "../api/documents";

interface SnackbarState {
  open: boolean;
  severity: "success" | "error" | "info";
  message: string;
}

export default function PalestinianLawsPage() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const theme = useTheme();
  const isSuperAdmin = user?.role === "super_admin";

  const [laws, setLaws] = useState<AccessibleDocument[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [snackbar, setSnackbar] = useState<SnackbarState>({ open: false, severity: "info", message: "" });
  const fileInputRef = useRef<HTMLInputElement>(null);

  const showSnack = (severity: SnackbarState["severity"], message: string) =>
    setSnackbar({ open: true, severity, message });

  const loadLaws = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await fetchGlobalLaws();
      setLaws(data);
    } catch {
      showSnack("error", "تعذّر تحميل قائمة القوانين.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadLaws();
  }, [loadLaws]);

  const handleUploadClick = () => fileInputRef.current?.click();

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    e.target.value = "";
    setUploading(true);
    try {
      await uploadGlobalLaw(file);
      showSnack("success", `تمّ رفع وفهرسة "${file.name}" بنجاح.`);
      await loadLaws();
    } catch {
      showSnack("error", `فشل رفع الملف "${file.name}". تحقّق من نوع الملف والصلاحيات.`);
    } finally {
      setUploading(false);
    }
  };

  const handleDelete = async (doc: AccessibleDocument) => {
    setDeletingId(doc.id);
    try {
      await deleteGlobalLaw(doc.id);
      showSnack("success", `تمّ حذف "${doc.filename}" من المكتبة.`);
      setLaws((prev) => prev.filter((d) => d.id !== doc.id));
    } catch {
      showSnack("error", `فشل حذف "${doc.filename}".`);
    } finally {
      setDeletingId(null);
    }
  };

  const formatDate = (iso?: string | null) => {
    if (!iso) return "—";
    try {
      return new Intl.DateTimeFormat("ar-EG", { year: "numeric", month: "short", day: "numeric" }).format(new Date(iso));
    } catch {
      return iso;
    }
  };

  return (
    <Box sx={{ minHeight: "100dvh", bgcolor: "background.default", display: "flex", flexDirection: "column" }}>
      {/* Header */}
      <Box
        sx={{
          bgcolor: theme.palette.mode === "dark" ? "rgba(10,26,12,0.97)" : "background.paper",
          borderBottom: `1px solid ${theme.palette.divider}`,
          px: { xs: 2, sm: 4 },
          py: 2,
          display: "flex",
          alignItems: "center",
          gap: 2,
          position: "sticky",
          top: 0,
          zIndex: 1100,
        }}
      >
        <Tooltip title="العودة إلى المحادثة">
          <IconButton onClick={() => navigate("/")} size="small" sx={{ border: "1px solid", borderColor: "divider" }}>
            <ArrowForwardRoundedIcon fontSize="small" />
          </IconButton>
        </Tooltip>
        <GavelRoundedIcon color="primary" />
        <Stack spacing={0}>
          <Typography variant="h6" fontWeight={700}>
            مكتبة القوانين الفلسطينية
          </Typography>
          <Typography variant="caption" color="text.secondary">
            وثائق قانونية مشتركة متاحة لجميع المستخدمين في كل الجلسات
          </Typography>
        </Stack>
        {isSuperAdmin && (
          <Box sx={{ ml: "auto" }}>
            <Button
              variant="contained"
              startIcon={uploading ? <CircularProgress size={16} color="inherit" /> : <UploadFileRoundedIcon />}
              onClick={handleUploadClick}
              disabled={uploading}
            >
              رفع وثيقة قانونية
            </Button>
            <input
              ref={fileInputRef}
              type="file"
              accept=".pdf,.docx,.txt,.md,.html"
              style={{ display: "none" }}
              onChange={handleFileChange}
            />
          </Box>
        )}
      </Box>

      {/* Content */}
      <Box sx={{ flex: 1, p: { xs: 2, sm: 4 }, maxWidth: 1100, mx: "auto", width: "100%" }}>
        {!isSuperAdmin && (
          <Alert severity="info" sx={{ mb: 3 }}>
            هذه الوثائق متاحة تلقائياً لجميع المستخدمين ضمن كل جلسة قضائية.
          </Alert>
        )}

        <Paper elevation={0} variant="outlined">
          <Box sx={{ p: 2.5, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <Typography variant="subtitle1" fontWeight={700}>
              الوثائق المحفوظة
            </Typography>
            <Chip label={`${laws.length} وثيقة`} size="small" color="primary" variant="outlined" />
          </Box>
          <Divider />

          {loading ? (
            <Stack alignItems="center" justifyContent="center" sx={{ py: 8 }}>
              <CircularProgress />
              <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
                جارٍ تحميل القوانين...
              </Typography>
            </Stack>
          ) : laws.length === 0 ? (
            <Stack alignItems="center" justifyContent="center" sx={{ py: 10 }}>
              <GavelRoundedIcon sx={{ fontSize: 64, color: "text.disabled", mb: 2 }} />
              <Typography variant="h6" color="text.secondary" fontWeight={600}>
                لا توجد وثائق قانونية بعد
              </Typography>
              {isSuperAdmin && (
                <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                  ارفع وثيقة قانونية لتكون متاحة لجميع المستخدمين.
                </Typography>
              )}
            </Stack>
          ) : (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell sx={{ fontWeight: 700 }}>اسم الوثيقة</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>النوع</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>تاريخ الرفع</TableCell>
                    {isSuperAdmin && <TableCell align="center" sx={{ fontWeight: 700 }}>إجراءات</TableCell>}
                  </TableRow>
                </TableHead>
                <TableBody>
                  {laws.map((doc) => (
                    <TableRow key={doc.id} hover>
                      <TableCell>
                        <Typography variant="body2" fontWeight={500} noWrap sx={{ maxWidth: 400 }}>
                          {doc.filename}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        <Chip label={(doc.file_type || "—").toUpperCase()} size="small" variant="outlined" />
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2" color="text.secondary">
                          {formatDate(doc.uploaded_at)}
                        </Typography>
                      </TableCell>
                      {isSuperAdmin && (
                        <TableCell align="center">
                          <Tooltip title="حذف الوثيقة">
                            <span>
                              <IconButton
                                size="small"
                                color="error"
                                disabled={deletingId === doc.id}
                                onClick={() => handleDelete(doc)}
                              >
                                {deletingId === doc.id ? (
                                  <CircularProgress size={16} color="inherit" />
                                ) : (
                                  <DeleteRoundedIcon fontSize="small" />
                                )}
                              </IconButton>
                            </span>
                          </Tooltip>
                        </TableCell>
                      )}
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </Paper>
      </Box>

      <Snackbar
        open={snackbar.open}
        autoHideDuration={5000}
        onClose={() => setSnackbar((s) => ({ ...s, open: false }))}
        anchorOrigin={{ vertical: "bottom", horizontal: "center" }}
      >
        <Alert severity={snackbar.severity} onClose={() => setSnackbar((s) => ({ ...s, open: false }))} variant="filled">
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
}
