import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../requests/data/requests_api.dart' show RequestStatus;
import '../../spaces/application/space_controller.dart';
import '../application/admin_access.dart';
import '../data/admin_api.dart';
import 'admin_widgets.dart';

/// "Manage space": overview, settings and the way into each administration area.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final space = ref.watch(adminSpaceProvider);
    final members = ref.watch(adminMembersProvider).value;
    final requests = ref.watch(adminRequestsProvider).value;
    final invites = ref.watch(adminInvitesProvider).value;

    Future<void> refresh() async {
      ref.invalidate(adminSpaceProvider);
      ref.invalidate(adminMembersProvider);
      ref.invalidate(adminRequestsProvider);
      ref.invalidate(adminInvitesProvider);
      await ref.read(spaceControllerProvider.notifier).revalidate();
    }

    final pendingRequests = requests
        ?.where((r) => r.status == RequestStatus.pending)
        .length;
    final openInvites = invites
        ?.where((i) => i.status == InviteStatus.pending)
        .length;
    final activeMembers = members?.where((m) => m.isActive).length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.manageSpaceTitle)),
      body: SafeArea(
        child: AdminAsyncBody<AdminSpace?>(
          value: space,
          onRefresh: refresh,
          builder: (data) => [
            if (data != null) _Overview(space: data),
            const SizedBox(height: AppSpacing.md),
            _Destination(
              key: const ValueKey('admin-members'),
              icon: Icons.group_outlined,
              label: l10n.adminMembersTitle,
              count: activeMembers,
              route: '/admin/members',
            ),
            _Destination(
              key: const ValueKey('admin-invites'),
              icon: Icons.mail_outline,
              label: l10n.adminInvitesTitle,
              count: openInvites,
              route: '/admin/invites',
            ),
            _Destination(
              key: const ValueKey('admin-requests'),
              icon: Icons.inbox_outlined,
              label: l10n.adminRequestsTitle,
              count: pendingRequests,
              highlight: (pendingRequests ?? 0) > 0,
              route: '/admin/requests',
            ),
            _Destination(
              key: const ValueKey('admin-models'),
              icon: Icons.tune,
              label: l10n.adminModelsToolsTitle,
              route: '/admin/models',
            ),
            _Destination(
              key: const ValueKey('admin-limits'),
              icon: Icons.speed_outlined,
              label: l10n.adminLimitsTitle,
              route: '/admin/limits',
            ),
            _Destination(
              key: const ValueKey('admin-documents'),
              icon: Icons.folder_shared_outlined,
              label: l10n.adminDocumentsTitle,
              route: '/admin/documents',
            ),
            _Destination(
              key: const ValueKey('admin-usage'),
              icon: Icons.insights_outlined,
              label: l10n.adminUsageTitle,
              route: '/admin/usage',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.adminWebOnlyNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Overview extends ConsumerStatefulWidget {
  const _Overview({required this.space});

  final AdminSpace space;

  @override
  ConsumerState<_Overview> createState() => _OverviewState();
}

class _OverviewState extends ConsumerState<_Overview> {
  bool _saving = false;

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameSpaceDialog(initial: widget.space.name),
    );
    if (name == null || name == widget.space.name || _saving || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await runAdminFromWidget(
        ref,
        (api, id) => api.rename(id, name),
      );
      if (!mounted || updated == null) return;
      ref.invalidate(adminSpaceProvider);
      // The home screen and space switcher show the name too.
      ref
          .read(spaceControllerProvider.notifier)
          .applyRename(updated.id, updated.name);
      showAdminMessage(context, l10n.adminSaved);
    } catch (e) {
      if (!mounted) return;
      if (isUncertain(e)) ref.invalidate(adminSpaceProvider);
      showAdminMessage(context, describeAdminError(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Section(
      title: l10n.adminOverviewTitle,
      children: [
        Row(
          children: [
            Expanded(
              child: BidiText(
                widget.space.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              key: const ValueKey('rename-space'),
              tooltip: l10n.renameSpaceAction,
              onPressed: _saving ? null : _rename,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

class _RenameSpaceDialog extends StatefulWidget {
  const _RenameSpaceDialog({required this.initial});

  final String initial;

  @override
  State<_RenameSpaceDialog> createState() => _RenameSpaceDialogState();
}

class _RenameSpaceDialogState extends State<_RenameSpaceDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2 || name.length > 80) {
      setState(() => _error = AppLocalizations.of(context).spaceNameInvalid);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.renameSpaceAction),
      content: TextField(
        key: const ValueKey('space-name'),
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: InputDecoration(
          labelText: l10n.spaceNameLabel,
          errorText: _error,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.saveAction)),
      ],
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    super.key,
    required this.icon,
    required this.label,
    required this.route,
    this.count,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String route;
  final int? count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count != null)
              StatusPill(formatCount(context, count!), emphasis: highlight),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push(route),
      ),
    );
  }
}
