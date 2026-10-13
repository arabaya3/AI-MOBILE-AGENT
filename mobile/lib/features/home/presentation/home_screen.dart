import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/section.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../spaces/application/space_controller.dart';
import '../../spaces/data/spaces_api.dart';

/// Authenticated landing page. Features that are not built yet are shown as unavailable.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final space = ref.watch(spaceControllerProvider);
    if (user == null || space is! SpaceSelected) {
      return const Scaffold(body: LoadingView());
    }
    final isSpaceAdmin = space.membership.role == SpaceRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.accountTitle,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/account'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(spaceControllerProvider.notifier)
              .refresh(prefer: space.space.id),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.homeGreeting(user.displayName ?? user.email),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.homeSignedInAs(user.email),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Section(
                title: l10n.currentSpace,
                children: [
                  BidiText(
                    space.space.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Fact(
                    label: l10n.spaceRoleLabel,
                    value: isSpaceAdmin
                        ? l10n.spaceRoleAdmin
                        : l10n.spaceRoleMember,
                  ),
                  _Fact(
                    label: l10n.uploadsLabel,
                    value: space.membership.canUploadDocuments || isSpaceAdmin
                        ? l10n.uploadsAllowed
                        : l10n.uploadsNotAllowed,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(spaceControllerProvider.notifier)
                            .clearSelection();
                        context.go('/spaces');
                      },
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(l10n.switchSpace),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const ValueKey('open-chat'),
                onPressed: () => context.push('/chat'),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(l10n.openChat),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey('open-documents'),
                onPressed: () => context.push('/documents'),
                icon: const Icon(Icons.description_outlined),
                label: Text(l10n.openDocuments),
              ),
              const SizedBox(height: AppSpacing.md),
              Section(
                title: l10n.sectionUpcoming,
                children: [
                  UnavailableDestination(
                    icon: Icons.notifications_none,
                    label: l10n.upcomingNotifications,
                    statusLabel: l10n.notAvailableYet,
                  ),
                  if (isSpaceAdmin)
                    UnavailableDestination(
                      icon: Icons.admin_panel_settings_outlined,
                      label: l10n.upcomingSpaceAdmin,
                      statusLabel: l10n.notAvailableYet,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(value, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
