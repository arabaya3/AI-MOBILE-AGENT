import React, { useState } from "react";
import {
  Box,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TablePagination,
  Chip,
  IconButton,
  Tooltip,
  Typography,
  Stack,
  TextField,
  InputAdornment,
} from "@mui/material";
import SearchIcon from "@mui/icons-material/Search";
import OpenInNewRoundedIcon from "@mui/icons-material/OpenInNewRounded";
import type { AccessibleDocument } from "../api/documents";
import { downloadDocument } from "../api/documents";

interface DocumentsTableProps {
  documents: AccessibleDocument[];
  selectedIds: string[];
  onToggleSelection: (id: string) => void;
  onToggleVisibility?: (id: string, isHidden: boolean) => void;
  visibilityLoading?: boolean;
}

export const DocumentsTable: React.FC<DocumentsTableProps> = ({
  documents,
  selectedIds,
  onToggleSelection,
  onToggleVisibility,
  visibilityLoading = false,
}) => {
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [searchQuery, setSearchQuery] = useState("");
  const [openingId, setOpeningId] = useState<string | null>(null);

  const handleOpen = async (doc: AccessibleDocument) => {
    setOpeningId(doc.id);
    try {
      const response = await downloadDocument(doc.id);
      const blob = response.data;
      const url = window.URL.createObjectURL(blob);
      window.open(url, "_blank", "noopener,noreferrer");
      window.setTimeout(() => window.URL.revokeObjectURL(url), 30_000);
    } catch (error) {
      // Keep this silent in the table; callers already have global snackbars.
      console.error("Failed to open document", error);
    } finally {
      setOpeningId(null);
    }
  };

  const filteredDocuments = documents.filter((doc) =>
    doc.filename.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const paginatedDocuments = filteredDocuments.slice(
    page * rowsPerPage,
    page * rowsPerPage + rowsPerPage
  );

  const handleChangePage = (_: unknown, newPage: number) => {
    setPage(newPage);
  };

  const handleChangeRowsPerPage = (event: React.ChangeEvent<HTMLInputElement>) => {
    setRowsPerPage(parseInt(event.target.value, 10));
    setPage(0);
  };

  return (
    <Box>
      <TextField
        fullWidth
        size="small"
        placeholder="Search documents..."
        value={searchQuery}
        onChange={(e) => setSearchQuery(e.target.value)}
        InputProps={{
          startAdornment: (
            <InputAdornment position="start">
              <SearchIcon />
            </InputAdornment>
          ),
        }}
        sx={{ mb: 2 }}
      />

      <TableContainer component={Paper} sx={{ maxHeight: 400 }}>
        <Table stickyHeader size="small">
          <TableHead>
            <TableRow>
              <TableCell>Filename</TableCell>
              <TableCell>Type</TableCell>
              <TableCell>Uploaded</TableCell>
              <TableCell align="center">Visibility</TableCell>
              <TableCell align="center">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {paginatedDocuments.map((doc) => (
              <TableRow
                key={doc.id}
                hover
                selected={selectedIds.includes(doc.id)}
                sx={{ cursor: "pointer" }}
                onClick={() => onToggleSelection(doc.id)}
              >
                <TableCell>
                  <Typography variant="body2" noWrap>
                    {doc.filename}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Chip label={doc.file_type.toUpperCase()} size="small" variant="outlined" />
                </TableCell>
                <TableCell>
                  <Typography variant="caption">
                    {doc.uploaded_at
                      ? new Date(doc.uploaded_at).toLocaleDateString()
                      : "Unknown"}
                  </Typography>
                </TableCell>
                <TableCell align="center">
                  <Chip
                    size="small"
                    variant={doc.is_hidden ? "filled" : "outlined"}
                    color={doc.is_hidden ? "warning" : "success"}
                    label={doc.is_hidden ? "Hidden" : "Visible"}
                    onClick={(e) => {
                      e.stopPropagation();
                      onToggleVisibility?.(doc.id, !doc.is_hidden);
                    }}
                    disabled={!onToggleVisibility || visibilityLoading}
                  />
                </TableCell>
                <TableCell align="center">
                  <Stack direction="row" spacing={1} justifyContent="center">
                    <Tooltip title="Open document">
                      <span>
                        <IconButton
                          size="small"
                          onClick={(e) => {
                            e.stopPropagation();
                            void handleOpen(doc);
                          }}
                          disabled={openingId === doc.id}
                        >
                          <OpenInNewRoundedIcon fontSize="small" />
                        </IconButton>
                      </span>
                    </Tooltip>
                  </Stack>
                </TableCell>
              </TableRow>
            ))}
            {paginatedDocuments.length === 0 && (
              <TableRow>
                <TableCell colSpan={5} align="center">
                  <Typography variant="body2" color="text.secondary" py={3}>
                    {searchQuery ? "No documents match your search" : "No documents available"}
                  </Typography>
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>

      <TablePagination
        rowsPerPageOptions={[5, 10, 25, 50]}
        component="div"
        count={filteredDocuments.length}
        rowsPerPage={rowsPerPage}
        page={page}
        onPageChange={handleChangePage}
        onRowsPerPageChange={handleChangeRowsPerPage}
      />
    </Box>
  );
};
