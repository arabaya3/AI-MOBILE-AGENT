import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/section.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../documents/data/documents_api.dart';
import '../application/admin_access.dart';
import 'admin_widgets.dart';

/// Who can read each document: hidden documents are visible to admins only; otherwise members
/// see what they uploaded or were granted.
class AdminDocumentsScreen extends ConsumerWidget {
  const AdminDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final docs = ref.watch(adminDocumentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminDocumentsTitle)),
      body: SafeArea(
        child: AdminAsyncBody<List<DocumentItem>>(
          value: docs,
          onRefresh: () => ref.refresh(adminDocumentsProvider.future),
          builder: (data) => [
            Text(
              l10n.adminDocumentsExplain,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (data.isEmpty)
              EmptyView(
                title: l10n.documentsEmptyTitle,
                message: l10n.adminDocumentsEmpty,
                icon: Icons.folder_open_outlined,
              ),
            for (final doc in data)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  key: ValueKey('admin-doc-${doc.id}'),
                  leading: Icon(
                    doc.isHidden
                        ? Icons.visibility_off_outlined
                        : Icons.description_outlined,
                  ),
                  title: BidiText(doc.filename),
                  subtitle: doc.isHidden ? Text(l10n.documentHidden) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => DocumentAccessSheet(documentId: doc.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final _grantsProvider = FutureProvider.autoDispose.family<Set<String>, String>((
  ref,
  documentId,
) async {
  ref.watch(adminScopeProvider);
  final result = await runAdmin(ref, (api, _) => api.grantedUsers(documentId));
  if (result == null) throw const AdminAccessLost();
  return result;
}, retry: (_, _) => null);

class DocumentAccessSheet extends ConsumerStatefulWidget {
  const DocumentAccessSheet({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<DocumentAccessSheet> createState() =>
      _DocumentAccessSheetState();
}

class _DocumentAccessSheetState extends ConsumerState<DocumentAccessSheet> {
  String? _busy;

  Future<void> _run(String what, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = what);
    final l10n = AppLocalizations.of(context);
    try {
      await action();
    } catch (e) {
      if (mounted) showAdminMessage(context, describeAdminError(l10n, e));
    } finally {
      ref.invalidate(adminDocumentsProvider);
      ref.invalidate(_grantsProvider(widget.documentId));
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _setHidden(bool hidden) async {
    final l10n = AppLocalizations.of(context);
    if (hidden &&
        !await confirmAdminAction(
          context,
          title: l10n.hideDocumentTitle,
          body: l10n.hideDocumentBody,
          confirmLabel: l10n.hideDocumentAction,
        )) {
      return;
    }
    await _run(
      'hidden',
      () => runAdminFromWidget(
        ref,
        (api, _) => api.setHidden(widget.documentId, hidden),
      ),
    );
  }

  Future<void> _setAccess(String userId, String email, bool granted) async {
    final l10n = AppLocalizations.of(context);
    if (!granted &&
        !await confirmAdminAction(
          context,
          title: l10n.removeDocAccessTitle,
          body: l10n.removeDocAccessBody(email),
          confirmLabel: l10n.removeDocAccessAction,
        )) {
      return;
    }
    await _run(
      userId,
      () => runAdminFromWidget(
        ref,
        (api, _) => api.setAccess(widget.documentId, userId, granted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final doc = ref
        .watch(adminDocumentsProvider)
        .value
        ?.where((d) => d.id == widget.documentId)
        .firstOrNull;
    final members = ref.watch(adminMembersProvider);
    final grants = ref.watch(_grantsProvider(widget.documentId));
    if (doc == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(l10n.documentGone),
        ),
      );
    }
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            BidiText(
              doc.filename,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              key: const ValueKey('doc-hidden'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.documentHiddenSwitch),
              subtitle: Text(l10n.documentHiddenExplain),
              value: doc.isHidden,
              onChanged: _busy == null ? _setHidden : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Section(
              title: l10n.documentAccessTitle,
              subtitle: l10n.documentAccessExplain,
              children: switch ((members, grants)) {
                (AsyncValue(value: final m?), AsyncValue(value: final g?)) => [
                  for (final member in m.where((x) => x.isActive && !x.isAdmin))
                    CheckboxListTile(
                      key: ValueKey('doc-access-${member.userId}'),
                      contentPadding: EdgeInsets.zero,
                      title: BidiText(member.email),
                      subtitle: member.userId == doc.uploadedByUserId
                          ? Text(l10n.documentUploader)
                          : null,
                      value:
                          member.userId == doc.uploadedByUserId ||
                          g.contains(member.userId),
                      onChanged:
                          _busy != null || member.userId == doc.uploadedByUserId
                          ? null
                          : (v) => _setAccess(
                              member.userId,
                              member.email,
                              v == true,
                            ),
                    ),
                  if (m.every((x) => !x.isActive || x.isAdmin))
                    Text(l10n.documentNoMembers),
                ],
                (AsyncValue(error: final Object e), _) ||
                (_, AsyncValue(error: final Object e)) => [
                  ErrorView(
                    message: describeAdminError(l10n, e),
                    onRetry: () {
                      ref.invalidate(adminMembersProvider);
                      ref.invalidate(_grantsProvider(widget.documentId));
                    },
                  ),
                ],
                _ => const [LoadingView()],
              },
            ),
          ],
        ),
      ),
    );
  }
}
