import { useState, useEffect } from 'react';
import { 
    Box, 
    Typography, 
    Table, 
    TableBody, 
    TableCell, 
    TableContainer, 
    TableHead, 
    TableRow, 
    Paper, 
    Chip, 
    IconButton, 
    Dialog, 
    DialogTitle, 
    DialogContent, 
    DialogActions, 
    Button, 
    TextField 
} from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import CancelIcon from '@mui/icons-material/Cancel';
import { listRequests, updateRequest, type RequestResponse } from '../api/requests';

export const RequestsManagement = () => {
    const [requests, setRequests] = useState<RequestResponse[]>([]);
    const [selectedRequest, setSelectedRequest] = useState<RequestResponse | null>(null);
    const [actionDialog, setActionDialog] = useState<"approve" | "reject" | null>(null);
    const [adminResponse, setAdminResponse] = useState("");

    const refresh = () => {
        listRequests().then(({ data }) => setRequests(data)).catch(console.error);
    };

    useEffect(() => {
        refresh();
    }, []);

    const handleAction = async () => {
        if (!selectedRequest || !actionDialog) return;
        try {
            await updateRequest(selectedRequest.id, {
                status: actionDialog === "approve" ? "approved" : "rejected",
                admin_response: adminResponse
            });
            refresh();
            setActionDialog(null);
            setSelectedRequest(null);
            setAdminResponse("");
        } catch (e) {
            console.error(e);
        }
    };

    return (
        <Box sx={{ mt: 3 }}>
            <Typography variant="h6" gutterBottom>طلبات المستخدمين</Typography>
            <TableContainer component={Paper} variant="outlined">
                <Table size="small">
                    <TableHead>
                        <TableRow>
                            <TableCell>النوع</TableCell>
                            <TableCell>الحالة</TableCell>
                            <TableCell>التفاصيل</TableCell>
                            <TableCell>التاريخ</TableCell>
                            <TableCell align="right">إجراءات</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {requests.map((req) => (
                            <TableRow key={req.id}>
                                <TableCell>{req.request_type}</TableCell>
                                <TableCell>
                                    <Chip 
                                        size="small" 
                                        label={req.status} 
                                        color={req.status === 'approved' ? 'success' : req.status === 'rejected' ? 'error' : 'warning'} 
                                        variant="outlined"
                                    />
                                </TableCell>
                                <TableCell>
                                    {JSON.stringify(req.payload)}
                                    {req.admin_response && <Typography variant="caption" display="block" color="text.secondary">المشرف: {req.admin_response}</Typography>}
                                </TableCell>
                                <TableCell>{new Date(req.created_at).toLocaleDateString()}</TableCell>
                                <TableCell align="right">
                                    {req.status === 'pending' && (
                                        <>
                                            <IconButton size="small" color="success" onClick={() => { setSelectedRequest(req); setActionDialog("approve"); }}>
                                                <CheckCircleIcon />
                                            </IconButton>
                                            <IconButton size="small" color="error" onClick={() => { setSelectedRequest(req); setActionDialog("reject"); }}>
                                                <CancelIcon />
                                            </IconButton>
                                        </>
                                    )}
                                </TableCell>
                            </TableRow>
                        ))}
                        {requests.length === 0 && <TableRow><TableCell colSpan={5} align="center">لا توجد طلبات</TableCell></TableRow>}
                    </TableBody>
                </Table>
            </TableContainer>

            <Dialog open={!!actionDialog} onClose={() => setActionDialog(null)}>
                <DialogTitle>{actionDialog === 'approve' ? 'قبول' : 'رفض'} الطلب</DialogTitle>
                <DialogContent>
                    <TextField
                        autoFocus
                        margin="dense"
                        label="رد المشرف / ملاحظة"
                        fullWidth
                        multiline
                        rows={3}
                        value={adminResponse}
                        onChange={(e) => setAdminResponse(e.target.value)}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setActionDialog(null)}>إلغاء</Button>
                    <Button onClick={handleAction} variant="contained" color={actionDialog === 'approve' ? 'primary' : 'error'}>
                        تأكيد
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};
