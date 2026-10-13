import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';

/// Hard per-file limit; the server enforces the same value while reading the body.
const maxUploadBytes = 25 * 1024 * 1024;

const supportedExtensions = [
  'pdf',
  'docx',
  'xlsx',
  'pptx',
  'csv',
  'txt',
  'md',
  'markdown',
  'json',
  'jsonl',
  'html',
  'htm',
];

enum DocumentState {
  uploaded,
  processing,
  indexing,
  ready,
  failed;

  static DocumentState parse(Object? value) => switch (value) {
    'uploaded' => uploaded,
    'processing' => processing,
    'indexing' => indexing,
    'failed' => failed,
    // Rows from before processing states existed are only listed once complete.
    _ => ready,
  };

  bool get active => this == uploaded || this == processing || this == indexing;
}

class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.filename,
    required this.fileType,
    required this.state,
    this.fileSize,
    this.errorCode,
    this.chunksCount = 0,
    this.uploadedAt,
    this.stateUpdatedAt,
    this.canRetry = false,
    this.isHidden = false,
    this.uploadedByUserId,
  });

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
    id: json['id'] as String,
    filename: json['filename'] as String? ?? '',
    fileType: json['file_type'] as String? ?? '',
    state: DocumentState.parse(json['state']),
    fileSize: (json['file_size'] as num?)?.toInt(),
    errorCode: json['error_code'] as String?,
    chunksCount: (json['chunks_count'] as num?)?.toInt() ?? 0,
    uploadedAt: DateTime.tryParse(json['uploaded_at'] as String? ?? ''),
    stateUpdatedAt: DateTime.tryParse(
      json['state_updated_at'] as String? ?? '',
    ),
    canRetry: json['can_retry'] == true,
    isHidden: json['is_hidden'] == true,
    uploadedByUserId: json['uploaded_by_user_id'] as String?,
  );

  final String id;
  final String filename;
  final String fileType;
  final DocumentState state;
  final int? fileSize;
  final String? errorCode;
  final int chunksCount;
  final DateTime? uploadedAt;
  final DateTime? stateUpdatedAt;
  final bool canRetry;
  final bool isHidden;
  final String? uploadedByUserId;

  bool get isReady => state == DocumentState.ready;
}

class DocumentsApi {
  DocumentsApi(this._client);

  final ApiClient _client;

  Future<List<DocumentItem>> list() async {
    final response = await _client.request<List<dynamic>>(
      '/documents/accessible',
    );
    return [
      for (final item in response.data ?? const [])
        DocumentItem.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<DocumentItem> get(String id) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/documents/${Uri.encodeComponent(id)}',
    );
    return DocumentItem.fromJson(response.data!);
  }

  /// The uploader's own upload by its client ID, or null if the server never received it.
  Future<DocumentItem?> findUpload(String uploadId) async {
    try {
      final response = await _client.request<Map<String, dynamic>>(
        '/documents/uploads/${Uri.encodeComponent(uploadId)}',
      );
      return DocumentItem.fromJson(response.data!);
    } on NotFoundException {
      return null;
    }
  }

  /// Sends the raw file. The server processes it before answering, so the response is the final state.
  Future<DocumentItem> upload({
    required String uploadId,
    required String filename,
    required Stream<List<int>> body,
    required int length,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/documents/uploads/${Uri.encodeComponent(uploadId)}',
      method: 'PUT',
      data: body,
      queryParameters: {'filename': filename},
      headers: {
        Headers.contentTypeHeader: 'application/octet-stream',
        Headers.contentLengthHeader: length,
      },
      onSendProgress: onProgress,
      cancelToken: cancelToken,
      followRedirects: false,
      sendTimeout: const Duration(minutes: 10),
      // Covers server-side processing (up to 5 minutes) after the last byte.
      receiveTimeout: const Duration(minutes: 7),
    );
    return DocumentItem.fromJson(response.data!);
  }

  Future<DocumentItem> retry(String id) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/documents/${Uri.encodeComponent(id)}/retry',
      method: 'POST',
      receiveTimeout: const Duration(minutes: 7),
    );
    return DocumentItem.fromJson(response.data!);
  }

  Future<void> download(
    String id,
    String savePath, {
    CancelToken? cancelToken,
    ProgressCallback? onProgress,
  }) => _client.download(
    '/documents/${Uri.encodeComponent(id)}/download',
    savePath,
    cancelToken: cancelToken,
    onReceiveProgress: onProgress,
  );
}

final documentsApiProvider = Provider<DocumentsApi>(
  (ref) => DocumentsApi(ref.watch(apiClientProvider)),
);
