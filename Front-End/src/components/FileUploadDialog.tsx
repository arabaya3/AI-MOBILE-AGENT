import CloudUploadRoundedIcon from "@mui/icons-material/CloudUploadRounded";
import {
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Typography,
  LinearProgress,
} from "@mui/material";
import { useRef, useState } from "react";

interface FileUploadDialogProps {
  open: boolean;
  onClose: () => void;
  onUpload: (file: File) => Promise<void>;
}

export const FileUploadDialog = ({ open, onClose, onUpload }: FileUploadDialogProps) => {
  const inputRef = useRef<HTMLInputElement | null>(null);
  const [fileName, setFileName] = useState<string>("");
  const [uploading, setUploading] = useState(false);

  const handleSelectFile = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    setFileName(file?.name ?? "");
  };

  const handleUpload = async () => {
    const file = inputRef.current?.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      await onUpload(file);
      setFileName("");
      onClose();
    } finally {
      setUploading(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>Add to Knowledge Base</DialogTitle>
      <DialogContent>
        <Box
          sx={{
            border: "1px dashed",
            borderColor: "divider",
            borderRadius: 2,
            p: 3,
            textAlign: "center",
          }}
        >
          <input
            ref={inputRef}
            type="file"
            accept=".pdf,.docx,.xlsx,.csv,.pptx,.txt"
            hidden
            onChange={handleSelectFile}
          />
          <Typography variant="body2" color="text.secondary" mb={2}>
            Supported formats: PDF, Word, Excel, CSV, PowerPoint, TXT
          </Typography>
          <Button
            variant="contained"
            startIcon={<CloudUploadRoundedIcon />}
            onClick={() => inputRef.current?.click()}
            size="small"
            disableElevation
            sx={{ height: 36, px: 2, fontWeight: 600 }}
          >
            Choose file
          </Button>
          {fileName && (
            <Typography variant="subtitle2" mt={2}>
              {fileName}
            </Typography>
          )}
          {uploading && (
            <Box sx={{ width: '100%', mt: 2 }}>
              <LinearProgress />
              <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                Processing and extracting knowledge...
              </Typography>
            </Box>
          )}
        </Box>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} size="small" sx={{ height: 34, px: 1.75, fontWeight: 600 }}>
          Cancel
        </Button>
        <Button
          variant="contained"
          onClick={handleUpload}
          disabled={!fileName || uploading}
          size="small"
          disableElevation
          sx={{ height: 36, px: 2, fontWeight: 600 }}
        >
          {uploading ? "Uploading..." : "Upload"}
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default FileUploadDialog;
