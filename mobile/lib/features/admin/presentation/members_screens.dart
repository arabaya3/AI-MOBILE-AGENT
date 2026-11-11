import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/section.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../application/admin_access.dart';
import '../data/admin_api.dart';
import 'admin_widgets.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(adminMembersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminMembersTitle)),
      body: SafeArea(
        child: AdminAsyncBody<List<SpaceMemberInfo>>(
          value: members,
          onRefresh: () => ref.refresh(adminMembersProvider.future),
          builder: (data) {
            final q = _query.trim().toLowerCase();
            final shown = [
              for (final m in data)
                if (q.isEmpty || m.email.toLowerCase().contains(q)) m,
            ]..sort((a, b) => _rank(a).compareTo(_rank(b)));
            return [
              TextField(
                key: const ValueKey('member-search'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: l10n.memberSearchLabel,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.md),
              if (shown.isEmpty)
                EmptyView(
                  title: l10n.membersEmptyTitle,
                  message: q.isEmpty
                      ? l10n.membersEmptyBody
                      : l10n.membersNoMatch,
                  icon: Icons.group_outlined,
                ),
              for (final m in shown) _MemberTile(member: m),
            ];
          },
        ),
      ),
    );
  }

  static int _rank(SpaceMemberInfo m) =>
      (m.isActive ? 0 : 2) + (m.isAdmin ? 0 : 1);
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final SpaceMemberInfo member;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        key: ValueKey('member-${member.userId}'),
        title: BidiText(member.email),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusPill(
                member.isAdmin ? l10n.spaceRoleAdmin : l10n.spaceRoleMember,
                emphasis: member.isAdmin,
              ),
              if (!member.isActive) StatusPill(l10n.memberStatusRevoked),
              if (member.canUpload && !member.isAdmin)
                StatusPill(l10n.uploadsAllowed),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/admin/members/${member.userId}'),
      ),
    );
  }
}

/// One member: role, access, upload rights, limit overrides and approved additions.
class MemberDetailScreen extends ConsumerStatefulWidget {
  const MemberDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  String? _busy;

  Future<void> _update(
    String what,
    Map<String, Object?> changes, {
    String? confirmTitle,
    String? confirmBody,
    String? confirmLabel,
    bool destructive = true,
  }) async {
    if (_busy != null) return;
    final l10n = AppLocalizations.of(context);
    if (confirmTitle != null &&
        !await confirmAdminAction(
          context,
          title: confirmTitle,
          body: confirmBody!,
          confirmLabel: confirmLabel!,
          destructive: destructive,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = what);
    try {
      final updated = await runAdminFromWidget(
        ref,
        (api, id) => api.updateMember(id, widget.userId, changes),
      );
      if (!mounted || updated == null) return;
      ref.invalidate(adminMembersProvider);
      showAdminMessage(context, l10n.adminSaved);
    } catch (e) {
      if (!mounted) return;
      ref.invalidate(adminMembersProvider);
      showAdminMessage(context, describeAdminError(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _editLimit(SpaceMemberInfo member, String key) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showLimitDialog(
      context,
      label: limitLabel(l10n, key),
      current: member.overrides.limit(key),
      forMember: true,
    );
    if (choice == null || !mounted) return;
    await _update(key, {
      'overrides': {key: choice.clear ? null : choice.value},
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(adminMembersProvider);
    final space = ref.watch(adminSpaceProvider).value;
    final selfId = ref.watch(currentUserProvider)?.id;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.memberDetailTitle)),
      body: SafeArea(
        child: AdminAsyncBody<List<SpaceMemberInfo>>(
          value: members,
          onRefresh: () async {
            ref.invalidate(adminSpaceProvider);
            ref.invalidate(adminMembersProvider);
            await ref.read(adminMembersProvider.future);
          },
          builder: (data) {
            final member = data
                .where((m) => m.userId == widget.userId)
                .firstOrNull;
            if (member == null) {
              return [
                EmptyView(
                  title: l10n.memberGoneTitle,
                  message: l10n.memberGoneBody,
                  icon: Icons.person_off_outlined,
                ),
              ];
            }
            final isSelf = member.userId == selfId;
            return [
              BidiText(
                member.email,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (isSelf)
                Text(
                  l10n.memberIsYou,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpacing.md),
              Section(
                title: l10n.memberAccessTitle,
                children: [
                  SwitchListTile(
                    key: const ValueKey('member-admin'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.memberAdminRole),
                    subtitle: Text(l10n.memberAdminRoleExplain),
                    value: member.isAdmin,
                    onChanged: _busy != null || !member.isActive
                        ? null
                        : (makeAdmin) => _update(
                            'role',
                            {'role': makeAdmin ? 'admin' : 'member'},
                            confirmTitle: makeAdmin
                                ? l10n.makeAdminTitle
                                : (isSelf
                                      ? l10n.removeOwnAdminTitle
                                      : l10n.removeAdminTitle),
                            confirmBody: makeAdmin
                                ? l10n.makeAdminBody
                                : (isSelf
                                      ? l10n.removeOwnAdminBody
                                      : l10n.removeAdminBody),
                            confirmLabel: makeAdmin
                                ? l10n.makeAdminAction
                                : l10n.removeAdminAction,
                            destructive: !makeAdmin,
                          ),
                  ),
                  SwitchListTile(
                    key: const ValueKey('member-upload'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.memberCanUpload),
                    subtitle: member.isAdmin
                        ? Text(l10n.memberAdminsCanUpload)
                        : null,
                    value: member.canUpload || member.isAdmin,
                    onChanged:
                        _busy != null || member.isAdmin || !member.isActive
                        ? null
                        : (allow) => _update('upload', {
                            'can_upload_documents': allow,
                          }),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (member.isActive)
                    OutlinedButton.icon(
                      key: const ValueKey('member-revoke'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: _busy != null
                          ? null
                          : () => _update(
                              'status',
                              {'status': 'revoked'},
                              confirmTitle: isSelf
                                  ? l10n.revokeOwnAccessTitle
                                  : l10n.revokeAccessTitle,
                              confirmBody: l10n.revokeAccessBody,
                              confirmLabel: l10n.revokeAccessAction,
                            ),
                      icon: const Icon(Icons.person_remove_outlined),
                      label: Text(l10n.revokeAccessAction),
                    )
                  else
                    OutlinedButton.icon(
                      key: const ValueKey('member-restore'),
                      onPressed: _busy != null
                          ? null
                          : () => _update(
                              'status',
                              {'status': 'active'},
                              confirmTitle: l10n.restoreAccessTitle,
                              confirmBody: l10n.restoreAccessBody,
                              confirmLabel: l10n.restoreAccessAction,
                              destructive: false,
                            ),
                      icon: const Icon(Icons.person_add_alt),
                      label: Text(l10n.restoreAccessAction),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Section(
                title: l10n.memberLimitsTitle,
                subtitle: l10n.memberLimitsExplain,
                children: [
                  for (final key in limitKeys)
                    ListTile(
                      key: ValueKey('member-limit-$key'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(limitLabel(l10n, key)),
                      subtitle: Text(
                        describeLimit(
                          context,
                          value: member.overrides.limit(key),
                          inherited: member.overrides.limit(key) == null,
                          spaceDefault: space?.policy.limit(key),
                        ),
                      ),
                      trailing: _busy == key
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              member.overrides.limit(key) == null
                                  ? Icons.link
                                  : Icons.edit_outlined,
                              semanticLabel: member.overrides.limit(key) == null
                                  ? l10n.limitInheritedShort
                                  : l10n.limitExplicitShort,
                            ),
                      onTap: _busy != null
                          ? null
                          : () => _editLimit(member, key),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Additions(
                title: l10n.memberExtraModelsTitle,
                items: member.overrides.allowedModels ?? const [],
                field: 'allowed_models',
                busy: _busy != null,
                onRemove: (items) => _update(
                  'allowed_models',
                  {
                    'overrides': {'allowed_models': items},
                  },
                  confirmTitle: l10n.removeGrantTitle,
                  confirmBody: l10n.removeGrantBody,
                  confirmLabel: l10n.removeGrantAction,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _Additions(
                title: l10n.memberExtraToolsTitle,
                items: member.overrides.allowedTools ?? const [],
                field: 'allowed_tools',
                busy: _busy != null,
                onRemove: (items) => _update(
                  'allowed_tools',
                  {
                    'overrides': {'allowed_tools': items},
                  },
                  confirmTitle: l10n.removeGrantTitle,
                  confirmBody: l10n.removeGrantBody,
                  confirmLabel: l10n.removeGrantAction,
                ),
              ),
            ];
          },
        ),
      ),
    );
  }
}

/// Models or tools granted to this member on top of the space policy (approved requests).
class _Additions extends StatelessWidget {
  const _Additions({
    required this.title,
    required this.items,
    required this.field,
    required this.busy,
    required this.onRemove,
  });

  final String title;
  final List<String> items;
  final String field;
  final bool busy;
  final void Function(List<String> remaining) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Section(
      title: title,
      subtitle: l10n.memberAdditionsExplain,
      children: [
        if (items.isEmpty)
          Text(l10n.memberNoAdditions)
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final item in items)
                InputChip(
                  key: ValueKey('$field-$item'),
                  label: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(item),
                  ),
                  onDeleted: busy
                      ? null
                      : () => onRemove([
                          for (final i in items)
                            if (i != item) i,
                        ]),
                  deleteButtonTooltipMessage: l10n.removeGrantAction,
                ),
            ],
          ),
      ],
    );
  }
}
