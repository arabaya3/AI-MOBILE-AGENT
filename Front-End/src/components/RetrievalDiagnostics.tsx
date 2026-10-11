import React, { useState } from "react";
import {
  Drawer,
  Box,
  Typography,
  List,
  ListItem,
  ListItemText,
  IconButton,
  Chip,
  Stack,
  Divider,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
} from "@mui/material";
import CloseIcon from "@mui/icons-material/Close";
import VisibilityIcon from "@mui/icons-material/Visibility";

export interface VectorSearchMatch {
  chunk_id: string;
  score: number;
  document_id: string;
  filename: string;
  file_type: string;
  chunk_index: number;
  text: string;
  metadata: Record<string, any>;
}

interface RetrievalDiagnosticsProps {
  open: boolean;
  onClose: () => void;
  sources: VectorSearchMatch[];
}

export const RetrievalDiagnostics: React.FC<RetrievalDiagnosticsProps> = ({
  open,
  onClose,
  sources,
}) => {
  const [selectedChunk, setSelectedChunk] = useState<VectorSearchMatch | null>(null);
  const [viewChunkOpen, setViewChunkOpen] = useState(false);

  const handleViewChunk = (chunk: VectorSearchMatch) => {
    setSelectedChunk(chunk);
    setViewChunkOpen(true);
  };

  const handleCloseChunkView = () => {
    setViewChunkOpen(false);
    setSelectedChunk(null);
  };

  return (
    <>
      <Drawer anchor="right" open={open} onClose={onClose}>
        <Box sx={{ width: 500, p: 3 }}>
          <Stack direction="row" justifyContent="space-between" alignItems="center" mb={2}>
            <Typography variant="h6">المقاطع المسترجعة ({sources.length})</Typography>
            <IconButton onClick={onClose} size="small">
              <CloseIcon />
            </IconButton>
          </Stack>

          <Divider sx={{ mb: 2 }} />

          {sources.length === 0 ? (
            <Typography color="text.secondary">لا توجد مقاطع مسترجعة</Typography>
          ) : (
            <List>
              {sources.map((source, idx) => (
                <React.Fragment key={source.chunk_id}>
                  <ListItem
                    sx={{
                      flexDirection: "column",
                      alignItems: "flex-start",
                      border: 1,
                      borderColor: "divider",
                      borderRadius: 1,
                      mb: 1,
                    }}
                  >
                    <Stack direction="row" justifyContent="space-between" width="100%" mb={1}>
                      <Typography variant="subtitle2" fontWeight="bold">
                        مقطع #{idx + 1}
                      </Typography>
                      <Chip
                        label={`درجة: ${source.score.toFixed(4)}`}
                        size="small"
                        color={source.score > 0.8 ? "success" : "default"}
                      />
                    </Stack>

                    <ListItemText
                      primary={source.filename}
                      secondary={
                        <>
                          <Typography variant="caption" display="block">
                            النوع: {source.file_type} • المؤشر: {source.chunk_index}
                          </Typography>
                          <Typography variant="caption" display="block" noWrap>
                            المعرّف: {source.chunk_id}
                          </Typography>
                        </>
                      }
                    />

                    <Typography variant="body2" color="text.secondary" mt={1} noWrap width="100%">
                      {source.text.substring(0, 100)}...
                    </Typography>

                    <Button
                      startIcon={<VisibilityIcon />}
                      size="small"
                      onClick={() => handleViewChunk(source)}
                      sx={{ mt: 1 }}
                    >
                      عرض المقطع كاملاً
                    </Button>
                  </ListItem>
                </React.Fragment>
              ))}
            </List>
          )}
        </Box>
      </Drawer>

      <Dialog
        open={viewChunkOpen}
        onClose={handleCloseChunkView}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>
          <Stack direction="row" justifyContent="space-between" alignItems="center">
            <Typography variant="h6">تفاصيل المقطع</Typography>
            <IconButton onClick={handleCloseChunkView} size="small">
              <CloseIcon />
            </IconButton>
          </Stack>
        </DialogTitle>
        <DialogContent dividers>
          {selectedChunk && (
            <Box>
              <Stack spacing={2}>
                <Box>
                  <Typography variant="subtitle2" color="primary">
                    اسم الملف
                  </Typography>
                  <Typography>{selectedChunk.filename}</Typography>
                </Box>

                <Box>
                  <Typography variant="subtitle2" color="primary">
                    معلومات المقطع
                  </Typography>
                  <Typography variant="body2">
                    المؤشر: {selectedChunk.chunk_index} • الدرجة: {selectedChunk.score.toFixed(4)}
                  </Typography>
                  <Typography variant="body2">المعرّف: {selectedChunk.chunk_id}</Typography>
                </Box>

                <Box>
                  <Typography variant="subtitle2" color="primary" gutterBottom>
                    النص الكامل
                  </Typography>
                  <Box
                    sx={{
                      p: 2,
                      bgcolor: "grey.100",
                      borderRadius: 1,
                      maxHeight: 400,
                      overflow: "auto",
                    }}
                  >
                    <Typography variant="body2" whiteSpace="pre-wrap">
                      {selectedChunk.text}
                    </Typography>
                  </Box>
                </Box>

                {selectedChunk.metadata && Object.keys(selectedChunk.metadata).length > 0 && (
                  <Box>
                    <Typography variant="subtitle2" color="primary" gutterBottom>
                      بيانات وصفية
                    </Typography>
                    <Box
                      component="pre"
                      sx={{
                        p: 2,
                        bgcolor: "grey.100",
                        borderRadius: 1,
                        overflow: "auto",
                        fontSize: "0.8rem",
                      }}
                    >
                      {JSON.stringify(selectedChunk.metadata, null, 2)}
                    </Box>
                  </Box>
                )}
              </Stack>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseChunkView}>إغلاق</Button>
        </DialogActions>
      </Dialog>
    </>
  );
};
