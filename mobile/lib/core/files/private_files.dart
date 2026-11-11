import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../features/documents/application/document_files.dart';
import '../../features/spaces/application/space_controller.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../providers.dart';

/// Files the app creates to hand to other apps (exports, invoices). They live in one random folder
/// per account and space, deleted when either changes, and on the next start otherwise.
class PrivateFiles {
  PrivateFiles(this._client, this._root) {
    unawaited(_removeStale());
  }

  static const folder = 'teia-exports';

  final ApiClient _client;
  final Future<Directory> _root;
  final _session = List.generate(
    12,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();
  final _tokens = <CancelToken>{};
  bool _disposed = false;

  Future<Directory> _dir() async {
    final dir = Directory(p.join((await _root).path, folder, _session));
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _removeStale() async {
    try {
      final base = Directory(p.join((await _root).path, folder));
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

  Future<String> writeText(String name, String text) async {
    if (_disposed) throw const RequestCancelledException();
    final file = File(p.join((await _dir()).path, safeLocalFilename(name)));
    await file.writeAsString(text, encoding: utf8, flush: true);
    return file.path;
  }

  /// Authenticated download through the API (redirects refused).
  Future<String> download(
    String apiPath,
    String name, {
    Map<String, dynamic>? query,
  }) async {
    if (_disposed) throw const RequestCancelledException();
    final target = p.join((await _dir()).path, safeLocalFilename(name));
    final token = CancelToken();
    _tokens.add(token);
    try {
      final uri = query == null
          ? apiPath
          : Uri(
              path: apiPath,
              queryParameters: query.map((k, v) => MapEntry(k, '$v')),
            ).toString();
      await _client.download(uri, target, cancelToken: token);
      if (_disposed) throw const RequestCancelledException();
      return target;
    } finally {
      _tokens.remove(token);
    }
  }

  void dispose() {
    _disposed = true;
    for (final token in _tokens) {
      token.cancel();
    }
    unawaited(() async {
      try {
        final dir = Directory(p.join((await _root).path, folder, _session));
        if (await dir.exists()) await dir.delete(recursive: true);
      } on FileSystemException {
        // Best effort.
      }
    }());
  }
}

final privateFilesProvider = Provider<PrivateFiles>((ref) {
  ref.watch(spaceScopeProvider);
  final files = PrivateFiles(
    ref.watch(apiClientProvider),
    ref.watch(documentsCacheRootProvider),
  );
  ref.onDispose(files.dispose);
  return files;
});

enum ShareOutcome { shared, dismissed, unavailable }

/// Opens the system share sheet for a local file; overridden in tests.
final shareFileProvider =
    Provider<
      Future<ShareOutcome> Function(
        String path,
        String mimeType,
        String subject,
      )
    >(
      (ref) => (path, mimeType, subject) async {
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path, mimeType: mimeType)],
            subject: subject,
          ),
        );
        return switch (result.status) {
          ShareResultStatus.success => ShareOutcome.shared,
          ShareResultStatus.dismissed => ShareOutcome.dismissed,
          ShareResultStatus.unavailable => ShareOutcome.unavailable,
        };
      },
    );
