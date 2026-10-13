import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_exception.dart';
import '../../spaces/application/space_controller.dart';
import '../data/documents_api.dart';

/// App-private cache root; overridden in tests.
final documentsCacheRootProvider = Provider<Future<Directory>>(
  (ref) => getTemporaryDirectory(),
);

final _unsafeChars = RegExp(r'[\\/:*?"<>|\x00-\x1f]');

/// A display name that is safe as one path segment on any platform.
String safeLocalFilename(String name) {
  var value = name.replaceAll(_unsafeChars, '_').trim();
  value = value.replaceFirst(RegExp(r'^\.+'), '');
  if (value.isEmpty) value = 'document';
  if (value.length > 120) {
    final ext = p.extension(value);
    value = value.substring(0, 120 - ext.length) + ext;
  }
  return value;
}

/// Downloaded copies for the current account and space only. Each instance owns one random
/// directory under the cache root; it is deleted when the account or space changes, and leftovers
/// from earlier runs are removed on start. Files the user hands to another app are outside our control.
class DocumentFiles {
  DocumentFiles(this._api, this._root) {
    unawaited(_removeStale());
  }

  static const folder = 'teia-documents';

  final DocumentsApi _api;
  final Future<Directory> _root;
  final _session = List.generate(
    12,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();
  final _tokens = <CancelToken>{};
  bool _disposed = false;

  Future<Directory> _base() async =>
      Directory(p.join((await _root).path, folder));

  Future<void> _removeStale() async {
    try {
      final base = await _base();
      if (!await base.exists()) return;
      await for (final entry in base.list()) {
        if (p.basename(entry.path) != _session) {
          await entry.delete(recursive: true);
        }
      }
    } on FileSystemException {
      // Best effort; the OS also clears the cache directory.
    }
  }

  /// Downloads through the authenticated API and returns the local path.
  Future<String> fetch(
    DocumentItem document, {
    ProgressCallback? onProgress,
  }) async {
    if (_disposed) throw const RequestCancelledException();
    final dir = Directory(p.join((await _base()).path, _session, document.id));
    await dir.create(recursive: true);
    final target = p.join(dir.path, safeLocalFilename(document.filename));
    final partial = '$target.part';
    final token = CancelToken();
    _tokens.add(token);
    try {
      await _api.download(
        document.id,
        partial,
        cancelToken: token,
        onProgress: onProgress,
      );
      if (_disposed) throw const RequestCancelledException();
      return (await File(partial).rename(target)).path;
    } catch (_) {
      await File(partial).delete().catchError((_) => File(partial));
      rethrow;
    } finally {
      _tokens.remove(token);
    }
  }

  void dispose() {
    _disposed = true;
    for (final token in _tokens) {
      token.cancel();
    }
    _tokens.clear();
    unawaited(() async {
      try {
        final dir = Directory(p.join((await _base()).path, _session));
        if (await dir.exists()) await dir.delete(recursive: true);
      } on FileSystemException {
        // Best effort.
      }
    }());
  }
}

final documentFilesProvider = Provider<DocumentFiles>((ref) {
  // A new account or space gets a new, empty directory; the old one is deleted.
  ref.watch(spaceScopeProvider);
  final files = DocumentFiles(
    ref.watch(documentsApiProvider),
    ref.watch(documentsCacheRootProvider),
  );
  ref.onDispose(files.dispose);
  return files;
});
