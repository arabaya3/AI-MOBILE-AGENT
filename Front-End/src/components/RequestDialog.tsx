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
            setError(e.message || "Failed to submit request");
        } finally {
            setLoading(false);
        }
    };

    return (
        <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
            <DialogTitle>Request Access / Quota</DialogTitle>
            <DialogContent>
                {success && <Alert severity="success" sx={{mb: 2}}>Request submitted successfully!</Alert>}
                {error && <Alert severity="error" sx={{mb: 2}}>{error}</Alert>}
                
                <FormControl fullWidth margin="normal">
                    <InputLabel>Request Type</InputLabel>
                    <Select value={type} label="Request Type" onChange={(e) => setType(e.target.value)}>
                        <MenuItem value="quota_increase">Quota Increase</MenuItem>
                        <MenuItem value="model_access">Model Access</MenuItem>
                        <MenuItem value="other">Other</MenuItem>
                    </Select>
                </FormControl>
                
                <TextField
                    margin="normal"
                    label="Details / Reason"
                    fullWidth
                    multiline
                    rows={4}
                    value={details}
                    onChange={(e) => setDetails(e.target.value)}
                    placeholder="Please explain why you need this..."
                />
            </DialogContent>
            <DialogActions>
                <Button onClick={onClose}>Cancel</Button>
                <Button onClick={handleSubmit} variant="contained" disabled={loading || !details}>
                    {loading ? 'Submitting...' : 'Submit Request'}
                </Button>
            </DialogActions>
        </Dialog>
    );
};
