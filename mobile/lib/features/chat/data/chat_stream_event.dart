import 'dart:async';
import 'dart:convert';

import '../../../core/network/sse/sse_parser.dart';

class ChatStreamProtocolException implements Exception {
  const ChatStreamProtocolException(this.message);

  final String message;

  @override
  String toString() => 'ChatStreamProtocolException: $message';
}

class Citation {
  const Citation({
    required this.chunkId,
    required this.documentId,
    required this.filename,
    required this.text,
    this.score,
    this.fileType,
    this.chunkIndex,
  });

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
    chunkId: '${json['chunk_id'] ?? ''}',
    documentId: '${json['document_id'] ?? ''}',
    filename: '${json['filename'] ?? ''}',
    text: '${json['text'] ?? ''}',
    score: (json['score'] as num?)?.toDouble(),
    fileType: json['file_type'] as String?,
    chunkIndex: (json['chunk_index'] as num?)?.toInt(),
  );

  final String chunkId;
  final String documentId;
  final String filename;
  final String text;
  final double? score;
  final String? fileType;
  final int? chunkIndex;
}

/// Events of `POST /api/v1/chat/query/stream` (see docs/mobile/MOBILE_DISCOVERY.md §3).
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatStreamMeta extends ChatStreamEvent {
  const ChatStreamMeta({required this.sessionId, required this.sources});

  final String sessionId;
  final List<Citation> sources;
}

class ChatStreamDelta extends ChatStreamEvent {
  const ChatStreamDelta(this.text);

  static const providerErrorMarker = '[stream_error]';

  final String text;

  /// The backend reports provider failures as delta text containing this marker.
  bool get isProviderError => text.contains(providerErrorMarker);
}

class ChatStreamDone extends ChatStreamEvent {
  const ChatStreamDone();
}

class ChatStreamError extends ChatStreamEvent {
  const ChatStreamError(this.detail);

  final String detail;

  /// Quota failures arrive as stringified HTTP errors such as "429: Daily token limit reached".
  bool get isQuotaExceeded => detail.trimLeft().startsWith('429');
}

class ChatStreamDecoder
    extends StreamTransformerBase<SseEvent, ChatStreamEvent> {
  const ChatStreamDecoder();

  @override
  Stream<ChatStreamEvent> bind(Stream<SseEvent> stream) async* {
    await for (final event in stream) {
      final decoded = decode(event);
      if (decoded != null) yield decoded;
    }
  }

  /// Returns null for unknown event names so newer servers stay compatible.
  static ChatStreamEvent? decode(SseEvent event) {
    switch (event.event) {
      case 'meta':
        final json = _object(event);
        final sessionId = json['session_id'];
        if (sessionId is! String || sessionId.isEmpty) {
          throw const ChatStreamProtocolException(
            'meta event without session_id',
          );
        }
        final sources = json['sources'];
        return ChatStreamMeta(
          sessionId: sessionId,
          sources: [
            if (sources is List)
              for (final s in sources)
                if (s is Map<String, dynamic>) Citation.fromJson(s),
          ],
        );
      case 'delta':
        final text = _object(event)['text'];
        if (text is! String) {
          throw const ChatStreamProtocolException('delta event without text');
        }
        return ChatStreamDelta(text);
      case 'done':
        return const ChatStreamDone();
      case 'error':
        final detail = _object(event)['detail'];
        return ChatStreamError(
          detail is String && detail.isNotEmpty ? detail : 'Unknown error',
        );
    }
    return null;
  }

  static Map<String, dynamic> _object(SseEvent event) {
    try {
      final value = jsonDecode(event.data);
      if (value is Map<String, dynamic>) return value;
    } on FormatException {
      // Reported below.
    }
    throw ChatStreamProtocolException(
      '${event.event} event data is not a JSON object',
    );
  }
}
