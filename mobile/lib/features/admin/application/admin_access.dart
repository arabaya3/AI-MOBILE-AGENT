import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../documents/data/documents_api.dart';
import '../../spaces/application/space_controller.dart';
import '../../spaces/data/spaces_api.dart';
import '../data/admin_api.dart';

final adminApiProvider = Provider<AdminApi>(
  (ref) => AdminApi(ref.watch(apiClientProvider)),
);

/// `account/space` while the selected space's membership is an active admin; null otherwise.
/// Every admin provider watches it, so losing the role (or switching account or space) drops
/// all admin state at once.
final adminScopeProvider = Provider<String?>((ref) {
  final scope = ref.watch(spaceScopeProvider);
  final space = ref.watch(spaceControllerProvider);
  return scope != null &&
          space is SpaceSelected &&
          space.membership.isActive &&
          space.membership.role == SpaceRole.admin
      ? scope
      : null;
});

class AdminAccessLost implements Exception {
  const AdminAccessLost();
}

/// The administered space id for [scope], or throws when admin access is gone.
String adminSpaceId(String? scope) {
  if (scope == null) throw const AdminAccessLost();
  return scope.substring(scope.lastIndexOf('/') + 1);
}

typedef _Read = T Function<T>(ProviderListenable<T> provider);

Future<T?> _runAdmin<T>(
  _Read read,
  bool Function() alive,
  Future<T> Function(AdminApi api, String spaceId) call,
) async {
  final scope = read(adminScopeProvider);
  final spaceId = adminSpaceId(scope);
  final spaces = read(spaceControllerProvider.notifier);
  try {
    final result = await call(read(adminApiProvider), spaceId);
    return alive() && read(adminScopeProvider) == scope ? result : null;
  } on ForbiddenException {
    unawaited(spaces.revalidate());
    rethrow;
  }
}

/// Runs an admin call. A 403 means the role may have changed, so membership is re-checked
/// (which closes the admin screens if it did). Returns null when the scope changed meanwhile,
/// so a late result is never applied to another account or space.
Future<T?> runAdmin<T>(
  Ref ref,
  Future<T> Function(AdminApi api, String spaceId) call,
) => _runAdmin(ref.read, () => ref.mounted, call);

/// Same as [runAdmin] for widgets; safe if the widget is gone when the call returns.
Future<T?> runAdminFromWidget<T>(
  WidgetRef ref,
  Future<T> Function(AdminApi api, String spaceId) call,
) {
  final container = ProviderScope.containerOf(ref.context, listen: false);
  return _runAdmin(container.read, () => true, call);
}

FutureProvider<T> _adminData<T>(
  Future<T> Function(AdminApi api, String spaceId) load,
) => FutureProvider.autoDispose<T>((ref) async {
  ref.watch(adminScopeProvider);
  final result = await runAdmin(ref, load);
  if (result == null) throw const AdminAccessLost();
  return result;
}, retry: (_, _) => null);

final adminSpaceProvider = _adminData<AdminSpace?>((api, id) => api.space(id));
final adminMembersProvider = _adminData<List<SpaceMemberInfo>>(
  (api, id) => api.members(id),
);
final adminInvitesProvider = _adminData<List<SpaceInviteInfo>>(
  (api, id) => api.invites(id),
);
final adminRequestsProvider = _adminData<List<ReviewableRequest>>(
  (api, id) => api.requests(id),
);
final adminCatalogProvider = _adminData<SpaceCatalog>(
  (api, id) => api.catalog(id),
);
final adminDocumentsProvider = _adminData<List<DocumentItem>>(
  (api, _) => api.documents(),
);

/// Space usage for a period of days.
final adminUsageProvider = FutureProvider.autoDispose.family<SpaceUsage, int>((
  ref,
  days,
) async {
  ref.watch(adminScopeProvider);
  final result = await runAdmin(ref, (api, id) => api.usage(id, days: days));
  if (result == null) throw const AdminAccessLost();
  return result;
}, retry: (_, _) => null);

/// Whether an error leaves the outcome of a mutation unknown (it may or may not have applied).
bool isUncertain(Object error) =>
    error is NetworkUnavailableException ||
    error is RequestTimeoutException ||
    (error is ServerException && error.statusCode != 503);
