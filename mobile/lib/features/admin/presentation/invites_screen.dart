import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/l10n/text_direction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/forms.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/admin_access.dart';
import '../data/admin_api.dart';
import 'admin_widgets.dart';

/// Invitations are emailed by the server; the app never sees or shows the link.
class InvitesScreen extends ConsumerWidget {
  const InvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final invites = ref.watch(adminInvitesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminInvitesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-invite'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const _InviteSheet(),
        ),
        icon: const Icon(Icons.person_add_alt),
        label: Text(l10n.inviteMemberAction),
      ),
      body: SafeArea(
        child: AdminAsyncBody<List<SpaceInviteInfo>>(
          value: invites,
          onRefresh: () => ref.refresh(adminInvitesProvider.future),
          builder: (data) => [
            Text(
              l10n.invitesExplain,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (data.isEmpty)
              EmptyView(
                title: l10n.invitesEmptyTitle,
                message: l10n.invitesEmptyBody,
                icon: Icons.mail_outline,
              ),
            for (final invite in data) _InviteTile(invite: invite),
          ],
        ),
      ),
    );
  }
}

String inviteStatusLabel(AppLocalizations l10n, InviteStatus status) =>
    switch (status) {
      InviteStatus.pending => l10n.inviteStatusPending,
      InviteStatus.accepted => l10n.inviteStatusAccepted,
      InviteStatus.revoked => l10n.inviteStatusRevoked,
      InviteStatus.expired => l10n.inviteStatusExpired,
    };

class _InviteTile extends ConsumerStatefulWidget {
  const _InviteTile({required this.invite});

  final SpaceInviteInfo invite;

  @override
  ConsumerState<_InviteTile> createState() => _InviteTileState();
}

class _InviteTileState extends ConsumerState<_InviteTile> {
  bool _busy = false;

  Future<void> _act(bool resend) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    if (!resend &&
        !await confirmAdminAction(
          context,
          title: l10n.revokeInviteTitle,
          body: l10n.revokeInviteBody(widget.invite.email),
          confirmLabel: l10n.revokeInviteAction,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final result = await runAdminFromWidget(
        ref,
        (api, id) => resend
            ? api.resendInvite(id, widget.invite.id)
            : api.revokeInvite(id, widget.invite.id),
      );
      if (!mounted || result == null) return;
      showAdminMessage(
        context,
        resend ? l10n.inviteResent(result.email) : l10n.inviteRevoked,
      );
    } catch (e) {
      if (mounted) showAdminMessage(context, describeAdminError(l10n, e));
    } finally {
      // Reloaded either way: after an uncertain failure the list shows what actually happened.
      ref.invalidate(adminInvitesProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invite = widget.invite;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final expires = invite.expiresAt == null
        ? null
        : DateFormat.yMMMd(locale).format(invite.expiresAt!.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        key: ValueKey('invite-${invite.id}'),
        title: BidiText(invite.email),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(
                inviteStatusLabel(l10n, invite.status),
                emphasis: invite.status == InviteStatus.pending,
              ),
              if (invite.status == InviteStatus.pending && expires != null)
                Text(l10n.inviteExpires(expires)),
              if (invite.sendCount > 1)
                Text(l10n.inviteSentTimes(invite.sendCount)),
            ],
          ),
        ),
        trailing: _busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : (invite.canResend || invite.canRevoke)
            ? PopupMenuButton<bool>(
                key: ValueKey('invite-menu-${invite.id}'),
                tooltip: l10n.moreActions,
                onSelected: _act,
                itemBuilder: (_) => [
                  if (invite.canResend)
                    PopupMenuItem(
                      value: true,
                      child: Text(l10n.resendInviteAction),
                    ),
                  if (invite.canRevoke)
                    PopupMenuItem(
                      value: false,
                      child: Text(l10n.revokeInviteAction),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet();

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !(_form.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final invite = await runAdminFromWidget(
        ref,
        (api, id) => api.invite(id, _email.text.trim()),
      );
      if (!mounted || invite == null) return;
      Navigator.of(context).pop();
      showAdminMessage(context, l10n.inviteSent(invite.email));
    } catch (e) {
      // Sending again is safe (the open invitation is reused), but say what is known.
      if (mounted) setState(() => _error = describeAdminError(l10n, e));
    } finally {
      ref.invalidate(adminInvitesProvider);
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.inviteMemberTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.inviteExplain),
                const SizedBox(height: AppSpacing.md),
                EmailField(controller: _email, onSubmitted: (_) => _send()),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  NoticeBanner(tone: StatusTone.error, text: _error!),
                ],
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  key: const ValueKey('send-invite'),
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.sendInviteAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
