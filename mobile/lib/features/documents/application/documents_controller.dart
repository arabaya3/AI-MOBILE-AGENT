import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../spaces/application/space_controller.dart';
import '../../spaces/data/spaces_api.dart';
import '../data/documents_api.dart';

/// A file chosen by the user, read as a stream so it is never fully loaded into memory.
class UploadSource {
  const UploadSource({
    required this.name,
    required this.length,
    required this.open,
  });

  final String name;
  final int length;
  final Stream<List<int>> Function() open;
}

enum UploadPhase {
  /// Bytes are being sent; [UploadTask.sent] is real progress.
  sending,

  /// All bytes sent; the server is extracting and indexing (no percentage exists).
  processing,

  /// The request failed in a way that leaves the outcome unknown; being checked with the server.
  checking,
  done,
  failed,

  /// Stopped on this device. The server may still have received and processed the file.
  cancelled,

  /// The server never received this upload (found after a failure or restart).
  notReceived,
}

class UploadTask {
  const UploadTask({
    required this.uploadId,
    required this.filename,
    required this.size,
    required this.phase,
    this.sent = 0,
    this.document,
    this.error,
  });

  final String uploadId;
  final String filename;
  final int size;
  final UploadPhase phase;
  final int sent;
  final DocumentItem? document;
  final ApiException? error;

  bool get active =>
      phase == UploadPhase.sending ||
      phase == UploadPhase.processing ||
      phase == UploadPhase.checking;

  UploadTask copyWith({
    UploadPhase? phase,
    int? sent,
    DocumentItem? document,
    ApiException? error,
  }) => UploadTask(
    uploadId: uploadId,
    filename: filename,
    size: size,
    phase: phase ?? this.phase,
    sent: sent ?? this.sent,
    document: document ?? this.document,
    error: error ?? this.error,
  );
}

enum LocalRejection { unsupportedType, tooLarge, empty }

class DocumentsState {
  const DocumentsState({
    this.items,
    this.loading = false,
    this.error,
    this.uploads = const [],
  });

  /// Null until the first successful load.
  final List<DocumentItem>? items;
  final bool loading;
  final ApiException? error;
  final List<UploadTask> uploads;

  bool get needsPolling =>
      (items ?? const []).any((d) => d.state.active) ||
      uploads.any((u) => u.phase == UploadPhase.processing);

  DocumentsState copyWith({
    List<DocumentItem>? items,
    bool? loading,
    ApiException? error,
    bool clearError = false,
    List<UploadTask>? uploads,
  }) => DocumentsState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    uploads: uploads ?? this.uploads,
  );
}

String newUploadId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

LocalRejection? checkLocally(UploadSource source) {
  final ext = p.extension(source.name).replaceFirst('.', '').toLowerCase();
  if (!supportedExtensions.contains(ext)) return LocalRejection.unsupportedType;
  if (source.length <= 0) return LocalRejection.empty;
  if (source.length > maxUploadBytes) return LocalRejection.tooLarge;
  return null;
}

/// Documents of the selected space: listing, status polling and uploads.
///
/// Everything is tied to one account+space scope. A sign-out, account change or space switch
/// rebuilds this controller: timers stop, requests are cancelled and late results are dropped.
class DocumentsController extends Notifier<DocumentsState> {
  static const pollDelays = [2, 3, 5, 8, 13, 20, 30];

  String? _scope;
  int _generation = 0;
  int _pollStep = 0;
  Timer? _timer;
  final _uploadTokens = <String, CancelToken>{};

  DocumentsApi get _api => ref.read(documentsApiProvider);

  bool get _inScope => ref.mounted && ref.read(spaceScopeProvider) == _scope;

  @override
  DocumentsState build() {
    _scope = ref.watch(spaceScopeProvider);
    ref.listen(appForegroundProvider, (_, foreground) {
      if (foreground) {
        _pollStep = 0;
        unawaited(refresh(silent: true));
      } else {
        _timer?.cancel();
      }
    });
    ref.onDispose(() {
      _generation++;
      _timer?.cancel();
      for (final token in _uploadTokens.values) {
        token.cancel();
      }
      _uploadTokens.clear();
    });
    if (_scope == null) return const DocumentsState(items: []);
    Future.microtask(() async {
      await refresh();
      await _restorePendingUploads();
    });
    return const DocumentsState(loading: true);
  }

  Future<void> refresh({bool silent = false}) async {
    if (!_inScope) return;
    final generation = ++_generation;
    if (!silent) state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await _api.list();
      if (generation != _generation || !_inScope) return;
      state = state.copyWith(items: items, loading: false, clearError: true);
    } on ApiException catch (e) {
      if (generation != _generation ||
          !_inScope ||
          e is RequestCancelledException) {
        return;
      }
      state = state.copyWith(loading: false, error: e);
    }
    _schedulePoll();
  }

  void _schedulePoll() {
    _timer?.cancel();
    if (!_inScope || !state.needsPolling || !ref.read(appForegroundProvider)) {
      if (!state.needsPolling) _pollStep = 0;
      return;
    }
    final delay = pollDelays[min(_pollStep, pollDelays.length - 1)];
    _pollStep++;
    _timer = Timer(Duration(seconds: delay), () => refresh(silent: true));
  }

  // Uploads -----------------------------------------------------------------

  String get _pendingKey => 'pending_uploads.$_scope';

  List<Map<String, dynamic>> _readPending() {
    final raw = ref.read(sharedPreferencesProvider).getString(_pendingKey);
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          Map<String, dynamic>.from(e as Map),
      ];
    } on FormatException {
      return [];
    }
  }

  Future<void> _writePending(List<Map<String, dynamic>> entries) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (entries.isEmpty) {
      await prefs.remove(_pendingKey);
    } else {
      await prefs.setString(_pendingKey, jsonEncode(entries));
    }
  }

  Future<void> _forgetPending(String uploadId) =>
      _writePending(_readPending().where((e) => e['id'] != uploadId).toList());

  void _updateUpload(String uploadId, UploadTask Function(UploadTask) change) {
    state = state.copyWith(
      uploads: [
        for (final u in state.uploads) u.uploadId == uploadId ? change(u) : u,
      ],
    );
  }

  /// Validates locally, then sends. Never retried automatically.
  Future<LocalRejection?> upload(UploadSource source) async {
    final rejection = checkLocally(source);
    if (rejection != null || !_inScope) return rejection;
    final uploadId = newUploadId();
    final token = CancelToken();
    _uploadTokens[uploadId] = token;
    // Recorded before sending so a restart can ask the server what happened.
    await _writePending([
      ..._readPending(),
      {'id': uploadId, 'name': source.name, 'size': source.length},
    ]);
    state = state.copyWith(
      uploads: [
        UploadTask(
          uploadId: uploadId,
          filename: source.name,
          size: source.length,
          phase: UploadPhase.sending,
        ),
        ...state.uploads,
      ],
    );
    try {
      final document = await _api.upload(
        uploadId: uploadId,
        filename: source.name,
        body: source.open(),
        length: source.length,
        cancelToken: token,
        onProgress: (sent, _) {
          if (!_inScope) return;
          _updateUpload(
            uploadId,
            (u) => u.copyWith(
              sent: sent,
              phase: sent >= u.size
                  ? UploadPhase.processing
                  : UploadPhase.sending,
            ),
          );
        },
      );
      if (!_inScope) return null;
      await _forgetPending(uploadId);
      _updateUpload(
        uploadId,
        (u) => u.copyWith(
          phase: UploadPhase.done,
          document: document,
          sent: u.size,
        ),
      );
      unawaited(refresh(silent: true));
    } on ApiException catch (e) {
      if (!_inScope) return null;
      if (e is RequestCancelledException) {
        _updateUpload(
          uploadId,
          (u) => u.copyWith(phase: UploadPhase.cancelled),
        );
        await _reconcile(uploadId, cancelled: true);
      } else if (_isDefinitive(e)) {
        await _forgetPending(uploadId);
        _updateUpload(
          uploadId,
          (u) => u.copyWith(phase: UploadPhase.failed, error: e),
        );
      } else {
        _updateUpload(
          uploadId,
          (u) => u.copyWith(phase: UploadPhase.checking, error: e),
        );
        await _reconcile(uploadId);
      }
    } finally {
      _uploadTokens.remove(uploadId);
    }
    return null;
  }

  /// The server answered and refused the file; resending the same file would fail the same way.
  static bool _isDefinitive(ApiException e) =>
      e is PayloadTooLargeException ||
      e is UnsupportedMediaException ||
      e is ValidationException ||
      e is ForbiddenException ||
      e is BadRequestException;

  /// Asks the server whether an upload arrived. Uses the upload ID, so it never creates a duplicate.
  Future<void> _reconcile(String uploadId, {bool cancelled = false}) async {
    try {
      final document = await _api.findUpload(uploadId);
      if (!_inScope) return;
      await _forgetPending(uploadId);
      if (document != null) {
        _updateUpload(
          uploadId,
          (u) => u.copyWith(phase: UploadPhase.done, document: document),
        );
        unawaited(refresh(silent: true));
      } else if (!cancelled) {
        _updateUpload(
          uploadId,
          (u) => u.copyWith(phase: UploadPhase.notReceived),
        );
      }
    } on ApiException catch (e) {
      // Still unknown (offline). The pending record stays, so the next start checks again.
      if (!_inScope) return;
      if (!cancelled) {
        _updateUpload(
          uploadId,
          (u) => u.copyWith(phase: UploadPhase.checking, error: e),
        );
      }
    }
  }

  Future<void> checkAgain(String uploadId) => _reconcile(uploadId);

  /// Stops this device's request. Processing on the server cannot be cancelled.
  void cancelUpload(String uploadId) => _uploadTokens[uploadId]?.cancel();

  void dismissUpload(String uploadId) {
    state = state.copyWith(
      uploads: state.uploads
          .where((u) => u.uploadId != uploadId || u.active)
          .toList(),
    );
  }

  Future<void> _restorePendingUploads() async {
    if (!_inScope) return;
    final pending = _readPending();
    if (pending.isEmpty) return;
    state = state.copyWith(
      uploads: [
        for (final entry in pending)
          if (!state.uploads.any((u) => u.uploadId == entry['id']))
            UploadTask(
              uploadId: '${entry['id']}',
              filename: '${entry['name'] ?? ''}',
              size: (entry['size'] as num?)?.toInt() ?? 0,
              phase: UploadPhase.checking,
            ),
        ...state.uploads,
      ],
    );
    for (final entry in pending) {
      await _reconcile('${entry['id']}');
    }
  }

  Future<DocumentItem?> retry(String documentId) async {
    final generation = _generation;
    final document = await _api.retry(documentId);
    if (!_inScope || generation != _generation) return null;
    unawaited(refresh(silent: true));
    return document;
  }
}

final documentsControllerProvider =
    NotifierProvider<DocumentsController, DocumentsState>(
      DocumentsController.new,
    );

/// Space admins and members granted upload rights may upload; the server enforces the same rule.
final canUploadDocumentsProvider = Provider<bool>((ref) {
  final space = ref.watch(spaceControllerProvider);
  return space is SpaceSelected &&
      (space.membership.role == SpaceRole.admin ||
          space.membership.canUploadDocuments);
});

/// Documents that may be selected for chat: listed for the user and ready.
final readyDocumentsProvider = Provider<List<DocumentItem>>((ref) {
  final items =
      ref.watch(documentsControllerProvider.select((s) => s.items)) ?? const [];
  return items.where((d) => d.isReady).toList();
});
