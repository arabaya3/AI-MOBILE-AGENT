import '../../../core/network/api_client.dart';
import '../../../core/util/server_time.dart';
import '../../documents/data/documents_api.dart';
import '../../requests/data/requests_api.dart' show RequestStatus;

/// The six limit fields shared by space defaults and member overrides.
const limitKeys = [
  'daily_token_limit',
  'monthly_token_limit',
  'daily_request_limit',
  'monthly_request_limit',
  'daily_tool_request_limit',
  'monthly_tool_request_limit',
];

/// Space defaults: null means unlimited. Member overrides: null means "use the space default".
/// Zero blocks use in both.
class Policy {
  const Policy({this.allowedModels, this.allowedTools, this.limits = const {}});

  factory Policy.fromJson(Map<String, dynamic>? json) {
    final source = json ?? const {};
    List<String>? list(String key) => source[key] is List
        ? [for (final v in source[key] as List) '$v']
        : null;
    return Policy(
      allowedModels: list('allowed_models'),
      allowedTools: list('allowed_tools'),
      limits: {
        for (final key in limitKeys) key: (source[key] as num?)?.toInt(),
      },
    );
  }

  final List<String>? allowedModels;
  final List<String>? allowedTools;
  final Map<String, int?> limits;

  int? limit(String key) => limits[key];
}

class AdminSpace {
  const AdminSpace({
    required this.id,
    required this.name,
    required this.isActive,
    required this.policy,
  });

  factory AdminSpace.fromJson(Map<String, dynamic> json) => AdminSpace(
    id: '${json['id']}',
    name: '${json['name']}',
    isActive: json['is_active'] as bool? ?? true,
    policy: Policy.fromJson(json['policy'] as Map<String, dynamic>?),
  );

  final String id;
  final String name;
  final bool isActive;
  final Policy policy;
}

class SpaceMemberInfo {
  const SpaceMemberInfo({
    required this.userId,
    required this.email,
    required this.isAdmin,
    required this.isActive,
    required this.canUpload,
    required this.overrides,
  });

  factory SpaceMemberInfo.fromJson(Map<String, dynamic> json) =>
      SpaceMemberInfo(
        userId: '${json['user_id']}',
        email: json['email'] as String? ?? '',
        isAdmin: json['role'] == 'admin',
        isActive: json['status'] == 'active',
        canUpload: json['can_upload_documents'] == true,
        overrides: Policy.fromJson(json['overrides'] as Map<String, dynamic>?),
      );

  final String userId;
  final String email;
  final bool isAdmin;
  final bool isActive;
  final bool canUpload;
  final Policy overrides;
}

enum InviteStatus {
  pending,
  accepted,
  revoked,
  expired;

  static InviteStatus parse(Object? value) => switch (value) {
    'accepted' => accepted,
    'revoked' => revoked,
    'expired' => expired,
    _ => pending,
  };
}

class SpaceInviteInfo {
  const SpaceInviteInfo({
    required this.id,
    required this.email,
    required this.status,
    required this.sendCount,
    this.expiresAt,
    this.lastSentAt,
  });

  factory SpaceInviteInfo.fromJson(Map<String, dynamic> json) =>
      SpaceInviteInfo(
        id: '${json['id']}',
        email: '${json['email']}',
        status: InviteStatus.parse(json['status']),
        sendCount: (json['send_count'] as num?)?.toInt() ?? 1,
        expiresAt: parseServerTime(json['expires_at']),
        lastSentAt: parseServerTime(json['last_sent_at']),
      );

  final String id;
  final String email;
  final InviteStatus status;
  final int sendCount;
  final DateTime? expiresAt;
  final DateTime? lastSentAt;

  bool get canResend =>
      status == InviteStatus.pending || status == InviteStatus.expired;
  bool get canRevoke => status == InviteStatus.pending;
}

class ReviewableRequest {
  const ReviewableRequest({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.type,
    required this.status,
    required this.createdAt,
    this.payload = const {},
    this.reviewNote,
  });

  factory ReviewableRequest.fromJson(Map<String, dynamic> json) =>
      ReviewableRequest(
        id: '${json['id']}',
        userId: '${json['user_id']}',
        userEmail: json['user_email'] as String? ?? '',
        type: '${json['type']}',
        status: RequestStatus.parse(json['status']),
        createdAt:
            parseServerTime(json['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : const {},
        reviewNote: json['review_note'] as String?,
      );

  final String id;
  final String userId;
  final String userEmail;
  final String type;
  final RequestStatus status;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
  final String? reviewNote;
}

class SpaceCatalog {
  const SpaceCatalog({required this.models, required this.tools});

  factory SpaceCatalog.fromJson(Map<String, dynamic> json) {
    List<String> ids(String key) => [
      for (final item in json[key] as List? ?? const [])
        '${(item as Map)['id']}',
    ];
    return SpaceCatalog(models: ids('models'), tools: ids('tools'));
  }

  final List<String> models;
  final List<String> tools;
}

class UsageTotals {
  const UsageTotals({
    required this.totalTokens,
    required this.requests,
    this.costUsd,
    this.requestsWithoutCost = 0,
  });

  factory UsageTotals.fromJson(Map<String, dynamic> json) => UsageTotals(
    totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
    requests: (json['requests'] as num?)?.toInt() ?? 0,
    costUsd: (json['cost_usd'] as num?)?.toDouble(),
    requestsWithoutCost: (json['requests_without_cost'] as num?)?.toInt() ?? 0,
  );

  final int totalTokens;
  final int requests;
  final double? costUsd;

  /// Requests not included in [costUsd] because their price is unknown.
  final int requestsWithoutCost;
}

class SpaceUsage {
  const SpaceUsage({
    required this.start,
    required this.end,
    required this.totals,
    required this.byModel,
  });

  factory SpaceUsage.fromJson(Map<String, dynamic> json) => SpaceUsage(
    start: parseServerTime(json['start']) ?? DateTime.now().toUtc(),
    end: parseServerTime(json['end']) ?? DateTime.now().toUtc(),
    totals: UsageTotals.fromJson(json['totals'] as Map<String, dynamic>),
    byModel: {
      for (final entry
          in (json['by_model'] as Map<String, dynamic>? ?? const {}).entries)
        entry.key: UsageTotals.fromJson(entry.value as Map<String, dynamic>),
    },
  );

  final DateTime start;
  final DateTime end;
  final UsageTotals totals;
  final Map<String, UsageTotals> byModel;
}

/// Space administration routes. Every call is authorized again by the server; the space is
/// always named in the path (or header) so a result can be matched to the space it belongs to.
class AdminApi {
  AdminApi(this._client);

  final ApiClient _client;

  String _space(String id) => '/spaces/${Uri.encodeComponent(id)}';

  Future<T> _get<T>(String path, T Function(Object? data) parse) async {
    final response = await _client.request<Object>(path, includeSpace: false);
    return parse(response.data);
  }

  List<T> _list<T>(Object? data, T Function(Map<String, dynamic>) parse) => [
    for (final item in data as List? ?? const [])
      parse(Map<String, dynamic>.from(item as Map)),
  ];

  Future<AdminSpace?> space(String spaceId) => _get(
    '/spaces',
    (data) => _list(
      data,
      AdminSpace.fromJson,
    ).where((s) => s.id == spaceId).firstOrNull,
  );

  Future<AdminSpace> rename(String spaceId, String name) async {
    final response = await _client.request<Map<String, dynamic>>(
      _space(spaceId),
      method: 'PATCH',
      includeSpace: false,
      data: {'name': name},
    );
    return AdminSpace.fromJson(response.data!);
  }

  /// Only the given keys change; a null value clears the limit (unlimited).
  Future<AdminSpace> updatePolicy(
    String spaceId,
    Map<String, Object?> changes,
  ) async {
    final response = await _client.request<Map<String, dynamic>>(
      '${_space(spaceId)}/policy',
      method: 'PATCH',
      includeSpace: false,
      data: changes,
    );
    return AdminSpace.fromJson(response.data!);
  }

  Future<List<SpaceMemberInfo>> members(String spaceId) => _get(
    '${_space(spaceId)}/members',
    (data) => _list(data, SpaceMemberInfo.fromJson),
  );

  /// `role`, `status`, `can_upload_documents`, or `overrides` (a null override = inherit).
  Future<SpaceMemberInfo> updateMember(
    String spaceId,
    String userId,
    Map<String, Object?> changes,
  ) async {
    final response = await _client.request<Map<String, dynamic>>(
      '${_space(spaceId)}/members/${Uri.encodeComponent(userId)}',
      method: 'PATCH',
      includeSpace: false,
      data: changes,
    );
    return SpaceMemberInfo.fromJson(response.data!);
  }

  Future<List<SpaceInviteInfo>> invites(String spaceId) => _get(
    '${_space(spaceId)}/invites',
    (data) => _list(data, SpaceInviteInfo.fromJson),
  );

  Future<SpaceInviteInfo> invite(String spaceId, String email) =>
      _inviteCall('${_space(spaceId)}/invites', {'email': email});

  Future<SpaceInviteInfo> resendInvite(String spaceId, String inviteId) =>
      _inviteCall(
        '${_space(spaceId)}/invites/${Uri.encodeComponent(inviteId)}/resend',
        null,
      );

  Future<SpaceInviteInfo> revokeInvite(String spaceId, String inviteId) =>
      _inviteCall(
        '${_space(spaceId)}/invites/${Uri.encodeComponent(inviteId)}/revoke',
        null,
      );

  Future<SpaceInviteInfo> _inviteCall(String path, Object? data) async {
    final response = await _client.request<Map<String, dynamic>>(
      path,
      method: 'POST',
      includeSpace: false,
      data: data,
    );
    return SpaceInviteInfo.fromJson(response.data!);
  }

  Future<List<ReviewableRequest>> requests(String spaceId) => _get(
    '${_space(spaceId)}/requests',
    (data) => _list(data, ReviewableRequest.fromJson),
  );

  Future<ReviewableRequest> review(
    String spaceId,
    String requestId, {
    required bool approve,
    String? note,
  }) async {
    final response = await _client.request<Map<String, dynamic>>(
      '${_space(spaceId)}/requests/${Uri.encodeComponent(requestId)}/review',
      method: 'POST',
      includeSpace: false,
      data: {
        'decision': approve ? 'approved' : 'declined',
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return ReviewableRequest.fromJson(response.data!);
  }

  Future<SpaceCatalog> catalog(String spaceId) => _get(
    '${_space(spaceId)}/catalog',
    (data) => SpaceCatalog.fromJson(Map<String, dynamic>.from(data as Map)),
  );

  Future<SpaceUsage> usage(String spaceId, {int days = 30}) async {
    final response = await _client.request<Map<String, dynamic>>(
      '${_space(spaceId)}/usage',
      includeSpace: false,
      queryParameters: {'days': days},
    );
    return SpaceUsage.fromJson(response.data!);
  }

  // Document routes use the selected space header, which the space controller keeps validated.

  Future<List<DocumentItem>> documents() async {
    final response = await _client.request<List<dynamic>>(
      '/documents/accessible',
    );
    return [
      for (final item in response.data ?? const [])
        DocumentItem.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<void> setHidden(String documentId, bool hidden) => _client.request(
    '/documents/${Uri.encodeComponent(documentId)}/visibility',
    method: 'PATCH',
    data: {'is_hidden': hidden},
  );

  /// Members explicitly granted this document (uploaders and admins see it regardless).
  Future<Set<String>> grantedUsers(String documentId) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/documents/permissions/status',
      method: 'POST',
      data: {
        'document_ids': [documentId],
      },
    );
    return {for (final id in response.data!['all_user_ids'] as List) '$id'};
  }

  Future<void> setAccess(String documentId, String userId, bool granted) =>
      _client.request(
        '/documents/permissions',
        method: granted ? 'POST' : 'DELETE',
        data: {
          'user_id': userId,
          'document_ids': [documentId],
        },
      );
}
