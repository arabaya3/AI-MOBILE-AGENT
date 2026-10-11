import { apiClient } from "./client";

export interface AccessibleDocument {
  id: string;
  filename: string;
  file_type: string;
  uploaded_at?: string | null;
  uploaded_by_user_id?: string | null;
  is_hidden?: boolean;
}

export interface DocumentUploadResponse {
  document_id: string;
  filename: string;
  status: string;
  message: string;
}

export const fetchAccessibleDocuments = (spaceId?: string) =>
  apiClient.get<AccessibleDocument[]>("/documents/accessible", {
    params: spaceId ? { space_id: spaceId } : undefined,
    headers: spaceId ? { "X-Space-Id": spaceId } : undefined,
  });

export const uploadAndVectorizeDocument = (file: File, spaceId?: string) => {
  const formData = new FormData();
  formData.append("file", file);
  return apiClient.post<DocumentUploadResponse>("/documents/upload-and-vectorize", formData, {
    headers: {
      "Content-Type": "multipart/form-data",
      ...(spaceId ? { "X-Space-Id": spaceId } : {}),
    },
    params: spaceId ? { space_id: spaceId } : undefined,
  });
};

export interface ChunkDetail {
  chunk_id: string;
  chunk_index: number;
  text: string;
  metadata: Record<string, any>;
}

export interface DocumentChunksResponse {
  document_id: string;
  filename: string;
  chunks: ChunkDetail[];
}

export const fetchDocumentChunks = (documentId: string) =>
  apiClient.get<DocumentChunksResponse>(`/documents/${documentId}/chunks`);

export const downloadDocument = (documentId: string) =>
  apiClient.get<Blob>(`/documents/${documentId}/download`, { responseType: "blob" });

export interface DocumentVisibilityUpdateRequest {
  is_hidden: boolean;
}

export interface DocumentVisibilityUpdateResponse {
  document_id: string;
  is_hidden: boolean;
  message: string;
}

export const updateDocumentVisibility = (documentId: string, payload: DocumentVisibilityUpdateRequest) =>
  apiClient.patch<DocumentVisibilityUpdateResponse>(`/documents/${documentId}/visibility`, payload);

export interface GrantPermissionRequest {
  user_id: string;
  document_ids: string[];
}

export interface RevokePermissionRequest {
  user_id: string;
  document_ids: string[];
}

export const grantDocumentPermissions = (payload: GrantPermissionRequest) =>
  apiClient.post("/documents/permissions", payload);

export const revokeDocumentPermissions = (payload: RevokePermissionRequest) =>
  apiClient.delete("/documents/permissions", { data: payload });

export interface DocumentPermissionStatusResponse {
  any_user_ids: string[];
  all_user_ids: string[];
}

export const fetchDocumentPermissionStatus = (documentIds: string[]) =>
  apiClient.post<DocumentPermissionStatusResponse>("/documents/permissions/status", {
    document_ids: documentIds,
  });
