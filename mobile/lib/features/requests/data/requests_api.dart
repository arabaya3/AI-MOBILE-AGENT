import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/util/server_time.dart';

enum RequestStatus {
  pending,
  approved,
  declined;

  static RequestStatus parse(Object? value) => switch (value) {
    'approved' => approved,
    'declined' => declined,
    _ => pending,
  };
}

/// A request the user made in a space (join, access, quota, upload rights, other).
class UserSpaceRequest {
  const UserSpaceRequest({
    required this.id,
    required this.spaceId,
    required this.type,
    required this.status,
    required this.createdAt,
    this.payload = const {},
    this.reviewNote,
    this.reviewedAt,
  });

  factory UserSpaceRequest.fromJson(Map<String, dynamic> json) =>
      UserSpaceRequest(
        id: '${json['id']}',
        spaceId: '${json['space_id']}',
        type: '${json['type']}',
        status: RequestStatus.parse(json['status']),
        createdAt:
            parseServerTime(json['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : const {},
        reviewNote: json['review_note'] as String?,
        reviewedAt: parseServerTime(json['reviewed_at']),
      );

  final String id;
  final String spaceId;
  final String type;
  final RequestStatus status;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  /// Shown to the requester; only reviewers can write it.
  final String? reviewNote;
  final DateTime? reviewedAt;
}

/// An account-level request reviewed by platform administrators (shown read-only on mobile).
class AccountRequest {
  const AccountRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.response,
  });

  factory AccountRequest.fromJson(Map<String, dynamic> json) => AccountRequest(
    id: '${json['id']}',
    type: '${json['request_type']}',
    status: RequestStatus.parse(json['status']),
    createdAt:
        parseServerTime(json['created_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    response: json['admin_response'] as String?,
  );

  final String id;
  final String type;
  final RequestStatus status;
  final DateTime createdAt;
  final String? response;
}

class RequestsApi {
  RequestsApi(this._client);

  final ApiClient _client;

  Future<List<UserSpaceRequest>> mySpaceRequests() async {
    final response = await _client.request<List<dynamic>>(
      '/spaces/requests/mine',
      includeSpace: false,
    );
    return [
      for (final r in response.data ?? const [])
        UserSpaceRequest.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// Platform admins receive every user's requests from this route; keep only the caller's.
  Future<List<AccountRequest>> myAccountRequests(String userId) async {
    final response = await _client.request<List<dynamic>>(
      '/requests/',
      includeSpace: false,
    );
    return [
      for (final r in response.data ?? const [])
        if ((r as Map)['user_id'] == userId)
          AccountRequest.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  /// The server returns the pending request when the same one already exists, so resubmitting is safe.
  Future<UserSpaceRequest> create(
    String spaceId,
    String type,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/spaces/${Uri.encodeComponent(spaceId)}/requests',
      method: 'POST',
      includeSpace: false,
      data: {'type': type, 'payload': payload},
    );
    return UserSpaceRequest.fromJson(response.data!);
  }

  /// Tool identifiers this deployment supports (the space catalog).
  Future<List<String>> tools(String spaceId) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/spaces/${Uri.encodeComponent(spaceId)}/catalog',
      includeSpace: false,
    );
    return [
      for (final t in response.data!['tools'] as List? ?? const [])
        '${(t as Map)['id']}',
    ];
  }

  /// Models the space offers in principle, and those the user may use now.
  Future<({List<String> all, List<String> allowed})> models() async {
    final all = await _client.request<List<dynamic>>('/chat/models/all');
    final allowed = await _client.request<List<dynamic>>('/chat/models');
    return (
      all: [for (final m in all.data ?? const []) '$m'],
      allowed: [for (final m in allowed.data ?? const []) '$m'],
    );
  }
}

final requestsApiProvider = Provider<RequestsApi>(
  (ref) => RequestsApi(ref.watch(apiClientProvider)),
);
