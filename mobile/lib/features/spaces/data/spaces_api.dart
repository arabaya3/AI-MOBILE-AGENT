import '../../../core/network/api_client.dart';

class Space {
  const Space({
    required this.id,
    required this.name,
    required this.isActive,
    this.allowedModels = const [],
  });

  factory Space.fromJson(Map<String, dynamic> json) {
    final policy = json['policy'];
    return Space(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      allowedModels: [
        if (policy is Map && policy['allowed_models'] is List)
          for (final m in policy['allowed_models'] as List) '$m',
      ],
    );
  }

  final String id;
  final String name;
  final bool isActive;
  final List<String> allowedModels;
}

enum SpaceRole { admin, member }

/// `GET /spaces/{id}/me`.
class SpaceMembership {
  const SpaceMembership({
    required this.spaceId,
    required this.role,
    required this.status,
    required this.canUploadDocuments,
  });

  factory SpaceMembership.fromJson(Map<String, dynamic> json) =>
      SpaceMembership(
        spaceId: json['space_id'] as String,
        role: json['role'] == 'admin' ? SpaceRole.admin : SpaceRole.member,
        status: '${json['status']}',
        canUploadDocuments: json['can_upload_documents'] as bool? ?? false,
      );

  final String spaceId;
  final SpaceRole role;
  final String status;
  final bool canUploadDocuments;

  bool get isActive => status == 'active';
}

class SpaceAccessRequest {
  const SpaceAccessRequest({
    required this.id,
    required this.spaceId,
    required this.type,
    required this.status,
  });

  factory SpaceAccessRequest.fromJson(Map<String, dynamic> json) =>
      SpaceAccessRequest(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        type: '${json['type']}',
        status: '${json['status']}',
      );

  final String id;
  final String spaceId;
  final String type;
  final String status;

  bool get isPendingJoin => type == 'join' && status == 'pending';
}

/// Space routes take the space from the path, so none of them send `X-Space-Id`.
class SpacesApi {
  const SpacesApi(this._client);

  final ApiClient _client;

  Future<List<Space>> listMine() => _list('/spaces', Space.fromJson);

  Future<List<Space>> listAvailable() =>
      _list('/spaces/available', Space.fromJson);

  Future<List<SpaceAccessRequest>> myRequests() =>
      _list('/spaces/requests/mine', SpaceAccessRequest.fromJson);

  Future<SpaceMembership> membership(String spaceId) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/spaces/${Uri.encodeComponent(spaceId)}/me',
      includeSpace: false,
    );
    return SpaceMembership.fromJson(response.data!);
  }

  Future<SpaceAccessRequest> requestToJoin(String spaceId) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/spaces/${Uri.encodeComponent(spaceId)}/requests',
      method: 'POST',
      includeSpace: false,
      data: {'type': 'join', 'payload': <String, dynamic>{}},
    );
    return SpaceAccessRequest.fromJson(response.data!);
  }

  /// Returns the joined space id.
  Future<String> acceptInvite(String token) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/spaces/invites/accept',
      method: 'POST',
      includeSpace: false,
      data: {'token': token},
    );
    return response.data!['space_id'] as String;
  }

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final response = await _client.request<List<dynamic>>(
      path,
      includeSpace: false,
    );
    return [
      for (final item in response.data ?? const [])
        parse(item as Map<String, dynamic>),
    ];
  }
}
