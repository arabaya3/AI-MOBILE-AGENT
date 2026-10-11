import { useState } from 'react';
import { 
    Dialog, 
    DialogTitle, 
    DialogContent, 
    TextField, 
    DialogActions, 
    Button, 
    FormControl, 
    InputLabel, 
    Select, 
    MenuItem,
    Alert 
} from '@mui/material';
import { createRequest } from '../api/requests';

interface RequestDialogProps {
  open: boolean;
  onClose: () => void;
}

export const RequestDialog = ({ open, onClose }: RequestDialogProps) => {
    const [type, setType] = useState('quota_increase');
    const [details, setDetails] = useState('');
    const [loading, setLoading] = useState(false);
    const [success, setSuccess] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const handleSubmit = async () => {
        if (!details) return;
        setLoading(true);
        setError(null);
        try {
            await createRequest({
                request_type: type as any,
                payload: { details }
            });
            setSuccess(true);
            setTimeout(() => {
                setSuccess(false);
                setDetails('');
                onClose();
            }, 1000);
        } catch (e: any) {
            setError(e.message || "تعذّر إرسال الطلب");
        } finally {
            setLoading(false);
        }
    };

    return (
        <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
            <DialogTitle>طلب وصول / زيادة حصة</DialogTitle>
            <DialogContent>
                {success && <Alert severity="success" sx={{mb: 2}}>تم إرسال الطلب بنجاح!</Alert>}
                {error && <Alert severity="error" sx={{mb: 2}}>{error}</Alert>}
                
                <FormControl fullWidth margin="normal">
                    <InputLabel>نوع الطلب</InputLabel>
                    <Select value={type} label="نوع الطلب" onChange={(e) => setType(e.target.value)}>
                        <MenuItem value="quota_increase">زيادة الحصة</MenuItem>
                        <MenuItem value="model_access">صلاحية النموذج</MenuItem>
                        <MenuItem value="other">أخرى</MenuItem>
                    </Select>
                </FormControl>
                
                <TextField
                    margin="normal"
                    label="التفاصيل / السبب"
                    fullWidth
                    multiline
                    rows={4}
                    value={details}
                    onChange={(e) => setDetails(e.target.value)}
                    placeholder="فضلاً اشرح سبب طلبك..."
                />
            </DialogContent>
            <DialogActions>
                <Button onClick={onClose}>إلغاء</Button>
                <Button onClick={handleSubmit} variant="contained" disabled={loading || !details}>
                    {loading ? 'جارٍ الإرسال...' : 'إرسال الطلب'}
                </Button>
            </DialogActions>
        </Dialog>
    );
};
