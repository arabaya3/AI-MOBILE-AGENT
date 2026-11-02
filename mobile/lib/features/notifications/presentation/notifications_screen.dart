import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../chat/application/conversation_controller.dart';
import '../../spaces/application/space_controller.dart';
import '../application/notifications_controller.dart';
import '../data/notifications_api.dart';

String requestTypeLabel(AppLocalizations l10n, String? type) => switch (type) {
  'join' => l10n.requestTypeJoin,
  'model_access' => l10n.requestTypeModel,
  'tool_access' => l10n.requestTypeTool,
  'quota_change' => l10n.requestTypeQuota,
  'upload_access' => l10n.requestTypeUpload,
  _ => l10n.requestTypeOther,
};

/// Localized text from the notification's structured details; the server's English text is the fallback.
({String title, String body}) notificationText(
  AppLocalizations l10n,
  AppNotification n,
) {
  final space = n.spaceName;
  if (space == null) return (title: n.title, body: n.message);
  final type = requestTypeLabel(l10n, n.requestType);
  return switch (n.type) {
    'request_approved' => (
      title: l10n.notifApprovedTitle,
      body: l10n.notifApprovedBody(type, space),
    ),
    'request_declined' => (
      title: l10n.notifDeclinedTitle,
      body: n.note == null || n.note!.isEmpty
          ? l10n.notifDeclinedBody(type, space)
          : l10n.notifDeclinedBodyNote(type, space, n.note!),
    ),
    'policy_updated' => (
      title: l10n.notifPolicyTitle,
      body: l10n.notifPolicyBody(space),
    ),
    'space_invite' => (
      title: l10n.notifInviteTitle,
      body: l10n.notifInviteBody(space),
    ),
    'quota_warning' => (
      title: l10n.notifQuotaTitle,
      body: l10n.notifQuotaBody(space),
    ),
    _ => (title: n.title, body: n.message),
  };
}

/// Opens what a notification refers to. Access is re-checked with the server first; targets the user
/// can no longer reach are explained instead of opened.
Future<void> openNotification(
  BuildContext context,
  WidgetRef ref,
  AppNotification n,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  unawaited(
    ref
        .read(notificationsControllerProvider.notifier)
        .markRead(n.id)
        .catchError((_) {}),
  );

  Future<bool> enterSpace() async {
    final spaceId = n.spaceId;
    if (spaceId == null) return false;
    await ref.read(spaceControllerProvider.notifier).refresh(prefer: spaceId);
    final state = ref.read(spaceControllerProvider);
    return state is SpaceSelected && state.space.id == spaceId;
  }

  switch (n.type) {
    case 'request_approved' || 'request_declined':
      if (n.type == 'request_approved' && n.spaceId != null) {
        // Approvals change permissions: reload membership and the models offered in chat.
        await ref
            .read(spaceControllerProvider.notifier)
            .refresh(prefer: n.spaceId);
        ref.invalidate(chatModelsProvider);
      }
      unawaited(router.push('/requests'));
    case 'quota_warning':
      if (await enterSpace()) {
        unawaited(router.push('/usage'));
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.notificationTargetUnavailable)),
        );
      }
    case 'policy_updated':
      if (await enterSpace()) {
        ref.invalidate(chatModelsProvider);
        router.go('/home');
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.notificationTargetUnavailable)),
        );
      }
    case 'space_invite':
      unawaited(router.push('/spaces'));
    default:
      break;
  }
}

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unread = ref.watch(
      notificationsControllerProvider.select((s) => s.unread),
    );
    final locale = Localizations.localeOf(context).toLanguageTag();
    return IconButton(
      key: const ValueKey('notifications-bell'),
      tooltip: unread > 0
          ? l10n.notificationsUnread(unread)
          : l10n.notificationsTitle,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(
          unread > 99
              ? '99+'
              : NumberFormat.decimalPattern(locale).format(unread),
        ),
        child: const Icon(Icons.notifications_none),
      ),
      onPressed: () => context.push('/notifications'),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final items = state.items;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if (state.unread > 0)
            TextButton(
              onPressed: () async {
                try {
                  await controller.markAllRead();
                } on ApiException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(describeApiException(l10n, e))),
                    );
                  }
                }
              },
              child: Text(l10n.markAllReadAction),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (state.live == LiveStatus.waiting)
                NoticeBanner(
                  tone: StatusTone.warning,
                  text: l10n.notificationsReconnecting,
                ),
              if (state.error != null && items != null)
                NoticeBanner(
                  tone: StatusTone.warning,
                  text: describeApiException(l10n, state.error!),
                ),
              if (items == null && state.error != null)
                ErrorView(
                  message: describeApiException(l10n, state.error!),
                  onRetry: controller.refresh,
                )
              else if (items == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                EmptyView(
                  title: l10n.notificationsEmptyTitle,
                  message: l10n.notificationsEmptyBody,
                  icon: Icons.notifications_none,
                )
              else
                for (final n in items) _NotificationTile(n),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile(this.notification);

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = notificationText(l10n, notification);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        notification.read
            ? Icons.notifications_none
            : Icons.notifications_active,
        color: notification.read ? scheme.onSurfaceVariant : scheme.primary,
      ),
      title: BidiText(
        text.title,
        style: notification.read
            ? null
            : const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BidiText(text.body),
          Text(
            DateFormat.yMMMd(
              locale,
            ).add_jm().format(notification.createdAt.toLocal()),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      onTap: () => openNotification(context, ref, notification),
    );
  }
}
