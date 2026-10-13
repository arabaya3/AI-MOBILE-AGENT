import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'chat_stream_event.dart';

class ChatSessionSummary {
  const ChatSessionSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  factory ChatSessionSummary.fromJson(Map<String, dynamic> json) =>
      ChatSessionSummary(
        id: json['id'] as String,
        title: json['title'] as String?,
        updatedAt:
            DateTime.tryParse('${json['updated_at']}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  final String id;
  final String? title;
  final DateTime updatedAt;
}

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.citations = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    role: json['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
    content: '${json['content'] ?? ''}',
    createdAt:
        DateTime.tryParse('${json['created_at']}') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    citations: [
      for (final c in json['citations'] as List? ?? const [])
        if (c is Map) Citation.persisted(Map<String, dynamic>.from(c)),
    ],
  );

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  /// Sources stored with this answer, already filtered by the reader's current access.
  final List<Citation> citations;

  /// Older backends stored provider failures as assistant text; never show them as answers.
  bool get isStoredProviderError =>
      role == ChatRole.assistant &&
      content.contains(ChatStreamDelta.providerErrorMarker);
}

class ChatSessionDetail {
  const ChatSessionDetail({required this.session, required this.history});

  factory ChatSessionDetail.fromJson(Map<String, dynamic> json) =>
      ChatSessionDetail(
        session: ChatSessionSummary.fromJson(
          json['session'] as Map<String, dynamic>,
        ),
        history: [
          for (final m in json['history'] as List? ?? const [])
            ChatMessage.fromJson(m as Map<String, dynamic>),
        ],
      );

  final ChatSessionSummary session;
  final List<ChatMessage> history;
}

class ShareLink {
  const ShareLink({
    required this.shareId,
    required this.token,
    required this.expiresAt,
  });

  final String shareId;
  final String token;
  final DateTime expiresAt;
}

class ShareSummary {
  const ShareSummary({
    required this.shareId,
    required this.expiresAt,
    required this.active,
  });

  factory ShareSummary.fromJson(Map<String, dynamic> json) => ShareSummary(
    shareId: json['share_id'] as String,
    expiresAt:
        DateTime.tryParse('${json['expires_at']}') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    active: json['active'] == true,
  );

  final String shareId;
  final DateTime expiresAt;
  final bool active;
}

enum Reaction { up, down }

/// `/api/v1/chat/*`. Space-scoped routes send the validated `X-Space-Id`.
class ChatApi {
  const ChatApi(this._client);

  final ApiClient _client;

  Future<List<ChatSessionSummary>> listSessions() async {
    final response = await _client.request<List<dynamic>>('/chat/sessions');
    return [
      for (final s in response.data ?? const [])
        ChatSessionSummary.fromJson(s as Map<String, dynamic>),
    ];
  }

  Future<ChatSessionDetail> getSession(
    String sessionId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/chat/sessions/${Uri.encodeComponent(sessionId)}',
      cancelToken: cancelToken,
    );
    return ChatSessionDetail.fromJson(response.data!);
  }

  Future<List<String>> listModels() async {
    final response = await _client.request<List<dynamic>>('/chat/models');
    return [for (final m in response.data ?? const []) '$m'];
  }

  /// Never retried automatically: a dropped connection may already have stored the prompt.
  Stream<ChatStreamEvent> stream({
    required String message,
    String? sessionId,
    String? model,
    String? language,
    List<String> documentIds = const [],
    CancelToken? cancelToken,
  }) => _client
      .postEventStream(
        '/chat/query/stream',
        cancelToken: cancelToken,
        data: {
          'message': message,
          'session_id': ?sessionId,
          'model': ?model,
          'user_language': ?language,
          if (documentIds.isNotEmpty) 'document_ids': documentIds,
        },
      )
      .transform(const ChatStreamDecoder());

  Future<void> react(String messageId, Reaction reaction) =>
      _client.request<Object>(
        '/chat/messages/${Uri.encodeComponent(messageId)}/reaction',
        method: 'POST',
        data: {'reaction': reaction.name},
      );

  /// Returns the new session id.
  Future<String> branch(String sessionId, String fromMessageId) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/chat/sessions/${Uri.encodeComponent(sessionId)}/branch',
      method: 'POST',
      data: {'from_message_id': fromMessageId},
    );
    return response.data!['session_id'] as String;
  }

  Future<String> exportMarkdown(String sessionId) async {
    final response = await _client.request<String>(
      '/chat/sessions/${Uri.encodeComponent(sessionId)}/export',
      queryParameters: {'format': 'md'},
      responseType: ResponseType.plain,
    );
    return response.data ?? '';
  }

  /// Uses the model and counts against the space quota.
  Future<String> summary(String sessionId) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/chat/sessions/${Uri.encodeComponent(sessionId)}/summary',
      receiveTimeout: const Duration(minutes: 2),
    );
    return '${response.data?['summary'] ?? ''}';
  }

  Future<ShareLink> createShare(String sessionId) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/chat/sessions/${Uri.encodeComponent(sessionId)}/share',
      method: 'POST',
    );
    final data = response.data!;
    return ShareLink(
      shareId: data['share_id'] as String,
      token: data['token'] as String,
      expiresAt: DateTime.tryParse('${data['expires_at']}') ?? DateTime.now(),
    );
  }

  Future<List<ShareSummary>> listShares(String sessionId) async {
    final response = await _client.request<List<dynamic>>(
      '/chat/sessions/${Uri.encodeComponent(sessionId)}/shares',
    );
    return [
      for (final s in response.data ?? const [])
        ShareSummary.fromJson(s as Map<String, dynamic>),
    ];
  }

  Future<void> revokeShare(String shareId) => _client.request<Object>(
    '/chat/shares/${Uri.encodeComponent(shareId)}',
    method: 'DELETE',
  );
}
