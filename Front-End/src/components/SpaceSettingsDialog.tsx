import { 
  Dialog, 
  DialogContent, 
  DialogTitle, 
  IconButton, 
  Tab, 
  Tabs, 
  Typography, 
  Box,
  Paper,
  Button,
  alpha
} from "@mui/material";
import CloseIcon from "@mui/icons-material/Close";
import DeleteForeverIcon from '@mui/icons-material/DeleteForever';
import { useState, type SyntheticEvent } from "react";
import type { SpaceSummary } from "../api/spaces";

interface SpaceSettingsDialogProps {
  open: boolean;
  onClose: () => void;
  space: SpaceSummary;
  activeTab?: string;
}

export const SpaceSettingsDialog = ({ open, onClose, space, activeTab = 'general' }: SpaceSettingsDialogProps) => {
  const [tab, setTab] = useState(activeTab);

  const handleTabChange = (_event: SyntheticEvent, newValue: string) => {
    setTab(newValue);
  };

  return (
    <Dialog 
      open={open} 
      onClose={onClose} 
      maxWidth="md" 
      fullWidth
      PaperProps={{
        sx: { minHeight: '60vh', maxHeight: '90vh' }
      }}
    >
      <DialogTitle sx={{ m: 0, p: 2, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Typography variant="h6" component="div" fontWeight={700}>
          Space Settings: {space?.name}
        </Typography>
        <IconButton
          aria-label="close"
          onClick={onClose}
          sx={{
            color: (theme) => theme.palette.grey[500],
          }}
        >
          <CloseIcon />
        </IconButton>
      </DialogTitle>
      
      <Box sx={{ borderBottom: 1, borderColor: 'divider', px: 2 }}>
        <Tabs value={tab} onChange={handleTabChange} aria-label="space settings tabs">
          <Tab label="عام" value="general" />
          <Tab label="أعضاء" value="members" />
          <Tab label="بيانات" value="data" />
          <Tab label="منطقة الخطر" value="danger" sx={{ color: 'error.main' }} />
        </Tabs>
      </Box>

      <DialogContent sx={{ p: 3 }}>
        {tab === 'general' && (
          <Box>
            <Typography variant="h6" gutterBottom>إعدادات عامة</Typography>
            <Typography variant="body2" color="text.secondary">
              ضبط إعدادات الجلسة الأساسية.
            </Typography>
            {/* Add General controls here */}
          </Box>
        )}

        {tab === 'members' && (
          <Box>
            <Typography variant="h6" gutterBottom>الأعضاء</Typography>
            {/* Add Member management table here */}
          </Box>
        )}

        {tab === 'data' && (
          <Box>
             <Typography variant="h6" gutterBottom>البيانات والملفات</Typography>
             {/* Add Data controls here */}
          </Box>
        )}

        {tab === 'danger' && (
          <Box>
            <Typography variant="h6" color="error" gutterBottom>منطقة الخطر</Typography>
            <Paper 
              variant="outlined" 
              sx={{ 
                p: 3, 
                borderColor: 'error.main', 
                bgcolor: (theme) => alpha(theme.palette.error.main, 0.05),
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between'
              }}
            >
              <Box>
                <Typography variant="subtitle1" fontWeight={700} color="error">
                  حذف هذه الجلسة
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  عند حذف الجلسة لا يمكن التراجع. تأكد تماماً من قرارك.
                </Typography>
              </Box>
              <Button 
                variant="outlined" 
                color="error" 
                startIcon={<DeleteForeverIcon />}
              >
                حذف الجلسة
              </Button>
            </Paper>
          </Box>
        )}
      </DialogContent>
    </Dialog>
  );
};
