import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/sse/sse_parser.dart';
import '../../../core/providers.dart';
import '../../../core/util/server_time.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
    this.spaceId,
    this.metadata = const {},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: '${json['id']}',
        type: '${json['type'] ?? ''}',
        title: '${json['title'] ?? ''}',
        message: '${json['message'] ?? ''}',
        read: json['read'] == true,
        createdAt:
            parseServerTime(json['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        spaceId: json['space_id'] as String?,
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
      );

  final String id;
  final String type;
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;
  final String? spaceId;
  final Map<String, dynamic> metadata;

  String? get spaceName => metadata['space_name'] as String?;
  String? get requestType => metadata['request_type'] as String?;
  String? get note => metadata['note'] as String?;

  AppNotification markedRead() => AppNotification(
    id: id,
    type: type,
    title: title,
    message: message,
    read: true,
    createdAt: createdAt,
    spaceId: spaceId,
    metadata: metadata,
  );
}

/// Notifications belong to the user, not to a space, so these calls send no `X-Space-Id`.
class NotificationsApi {
  NotificationsApi(this._client);

  final ApiClient _client;

  Future<List<AppNotification>> list({int limit = 50}) async {
    final response = await _client.request<List<dynamic>>(
      '/notifications/',
      queryParameters: {'limit': limit},
      includeSpace: false,
    );
    return [
      for (final item in response.data ?? const [])
        AppNotification.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<int> unreadCount() async {
    final response = await _client.request<Map<String, dynamic>>(
      '/notifications/unread-count',
      includeSpace: false,
    );
    return (response.data?['count'] as num?)?.toInt() ?? 0;
  }

  Future<bool> markRead(String id) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/notifications/${Uri.encodeComponent(id)}/read',
      method: 'POST',
      includeSpace: false,
    );
    return response.data?['success'] == true;
  }

  Future<void> markAllRead() => _client.request<Object>(
    '/notifications/mark-all-read',
    method: 'POST',
    includeSpace: false,
  );

  /// Live events. The server sends a keepalive every 30 s, so silence for longer means a dead link.
  Stream<AppNotification> stream({
    CancelToken? cancelToken,
    void Function()? onConnected,
  }) => _client
      .eventStream(
        '/notifications/stream',
        includeSpace: false,
        cancelToken: cancelToken,
        receiveTimeout: const Duration(seconds: 75),
      )
      .where((event) {
        if (event.event == 'connected') onConnected?.call();
        return event.event == 'notification';
      })
      .map(
        (SseEvent event) => AppNotification.fromJson(
          jsonDecode(event.data) as Map<String, dynamic>,
        ),
      );
}

final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => NotificationsApi(ref.watch(apiClientProvider)),
);
