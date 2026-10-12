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

/// Events of `POST /api/v1/chat/query/stream` (see docs/mobile/MOBILE_DISCOVERY.md §3 and §9).
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatStreamMeta extends ChatStreamEvent {
  const ChatStreamMeta({
    required this.sessionId,
    required this.sources,
    this.userMessageId,
  });

  final String sessionId;
  final List<Citation> sources;
  final String? userMessageId;
}

class ChatStreamDelta extends ChatStreamEvent {
  const ChatStreamDelta(this.text);

  static const providerErrorMarker = '[stream_error]';

  final String text;

  /// Older backends report provider failures as delta text containing this marker.
  bool get isProviderError => text.contains(providerErrorMarker);
}

/// IDs are absent on backends older than Phase 2.
class ChatStreamDone extends ChatStreamEvent {
  const ChatStreamDone({this.sessionId, this.userMessageId, this.messageId});

  final String? sessionId;
  final String? userMessageId;
  final String? messageId;
}

enum ChatErrorKind {
  quota,
  policy,
  provider,
  sessionNotFound,
  documentAccess,
  forbidden,
  other,
}

class ChatStreamError extends ChatStreamEvent {
  const ChatStreamError(this.detail, {this.code, this.partial = false});

  final String detail;
  final String? code;

  /// Some text was streamed before the provider failed.
  final bool partial;

  /// Quota failures from older backends arrive as "429: Daily token limit reached".
  bool get isQuotaExceeded => kind == ChatErrorKind.quota;

  ChatErrorKind get kind => switch (code) {
    'quota_exceeded' => ChatErrorKind.quota,
    'policy' => ChatErrorKind.policy,
    'provider_error' => ChatErrorKind.provider,
    'session_not_found' || 'not_found' => ChatErrorKind.sessionNotFound,
    'document_access_denied' => ChatErrorKind.documentAccess,
    'forbidden' => ChatErrorKind.forbidden,
    null when detail.trimLeft().startsWith('429') => ChatErrorKind.quota,
    _ => ChatErrorKind.other,
  };
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
        final userMessageId = json['user_message_id'];
        return ChatStreamMeta(
          sessionId: sessionId,
          userMessageId: userMessageId is String ? userMessageId : null,
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
        // Older backends send `{}`; anything unparsable still means "finished".
        final json = _tryObject(event) ?? const <String, dynamic>{};
        String? id(String key) =>
            json[key] is String ? json[key] as String : null;
        return ChatStreamDone(
          sessionId: id('session_id'),
          userMessageId: id('user_message_id'),
          messageId: id('message_id'),
        );
      case 'error':
        final json = _object(event);
        final detail = json['detail'];
        final code = json['code'];
        return ChatStreamError(
          detail is String && detail.isNotEmpty ? detail : 'Unknown error',
          code: code is String ? code : null,
          partial: json['partial'] == true,
        );
    }
    return null;
  }

  static Map<String, dynamic>? _tryObject(SseEvent event) {
    try {
      final value = jsonDecode(event.data);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
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
