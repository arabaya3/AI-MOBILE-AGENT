import { useState } from "react";
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Button,
} from "@mui/material";

interface EditMessageDialogProps {
  open: boolean;
  message: string;
  onClose: () => void;
  onSave: (newMessage: string) => void;
}

export default function EditMessageDialog({
  open,
  message,
  onClose,
  onSave,
}: EditMessageDialogProps) {
  const [editedMessage, setEditedMessage] = useState(message);

  const handleSave = () => {
    if (editedMessage.trim()) {
      onSave(editedMessage);
      onClose();
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>تعديل الرسالة</DialogTitle>
      <DialogContent>
        <TextField
          autoFocus
          multiline
          rows={4}
          fullWidth
          value={editedMessage}
          onChange={(e) => setEditedMessage(e.target.value)}
          placeholder="أدخل رسالتك..."
          sx={{ mt: 1 }}
        />
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>إلغاء</Button>
        <Button
          onClick={handleSave}
          variant="contained"
          disabled={!editedMessage.trim()}
        >
          حفظ وإرسال
        </Button>
      </DialogActions>
    </Dialog>
  );
}
