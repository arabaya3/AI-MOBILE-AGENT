import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/files/private_files.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/conversation_controller.dart';
import '../data/chat_api.dart';
import 'message_widgets.dart';

enum _MenuAction { rename, summary, exportFile, copy, share, delete }

class ConversationMenu extends ConsumerWidget {
  const ConversationMenu({
    super.key,
    required this.sessionId,
    required this.busy,
    this.title,
  });

  final String sessionId;
  final bool busy;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_MenuAction>(
      tooltip: l10n.moreActions,
      enabled: !busy,
      onSelected: (action) => switch (action) {
        _MenuAction.rename => _rename(context, ref),
        _MenuAction.summary => _showSummary(context, ref),
        _MenuAction.exportFile => _exportFile(context, ref),
        _MenuAction.copy => _export(context, ref),
        _MenuAction.share => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => ShareSheet(sessionId: sessionId),
        ),
        _MenuAction.delete => _delete(context, ref),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _MenuAction.rename,
          child: Text(l10n.renameAction),
        ),
        PopupMenuItem(
          value: _MenuAction.summary,
          child: Text(l10n.summaryAction),
        ),
        PopupMenuItem(
          value: _MenuAction.exportFile,
          child: Text(l10n.exportFileAction),
        ),
        PopupMenuItem(value: _MenuAction.copy, child: Text(l10n.exportAction)),
        PopupMenuItem(value: _MenuAction.share, child: Text(l10n.shareAction)),
        PopupMenuItem(
          value: _MenuAction.delete,
          child: Text(l10n.deleteConversationAction),
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: title ?? ''),
    );
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return;
    try {
      await ref.read(chatApiProvider).rename(sessionId, clean);
      ref.invalidate(chatSessionsProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeApiException(l10n, e))),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConversationTitle),
        content: Text(l10n.deleteConversationBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(chatApiProvider).delete(sessionId);
      ref.invalidate(chatSessionsProvider);
      router.go('/chat');
      messenger.showSnackBar(SnackBar(content: Text(l10n.conversationDeleted)));
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeApiException(l10n, e))),
      );
    }
  }

  /// Writes the Markdown export to the app's private folder and opens the system share sheet.
  Future<void> _exportFile(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final markdown = await ref
          .read(chatApiProvider)
          .exportMarkdown(sessionId);
      final name =
          '${(title ?? '').trim().isEmpty ? 'conversation' : title!.trim()}.md';
      final path = await ref
          .read(privateFilesProvider)
          .writeText(name, markdown);
      final outcome = await ref.read(shareFileProvider)(
        path,
        'text/markdown',
        title ?? l10n.untitledConversation,
      );
      if (outcome == ShareOutcome.unavailable) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.shareUnavailable)));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeApiException(l10n, e))),
      );
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.shareUnavailable)));
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final markdown = await ref
          .read(chatApiProvider)
          .exportMarkdown(sessionId);
      await Clipboard.setData(ClipboardData(text: markdown));
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone)));
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeApiException(l10n, e))),
      );
    }
  }

  Future<void> _showSummary(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _SummarySheet(sessionId: sessionId),
      );
}

class _SummarySheet extends ConsumerStatefulWidget {
  const _SummarySheet({required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends ConsumerState<_SummarySheet> {
  bool _busy = false;
  String? _summary;
  ApiException? _error;

  Future<void> _generate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final summary = await ref.read(chatApiProvider).summary(widget.sessionId);
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.summaryTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_summary == null) Text(l10n.summaryCost),
            if (_error != null)
              NoticeBanner(
                tone: StatusTone.error,
                text: describeApiException(l10n, _error!),
              ),
            if (_summary != null)
              Flexible(
                child: SingleChildScrollView(child: MarkdownMessage(_summary!)),
              )
            else ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _busy ? null : _generate,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.generateAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Creates and revokes share links. The token is shown once, never stored on the device.
class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  late Future<List<ShareSummary>> _shares = _load();
  bool _busy = false;
  ApiException? _error;

  Future<List<ShareSummary>> _load() =>
      ref.read(chatApiProvider).listShares(widget.sessionId);

  String _date(DateTime value) => DateFormat.yMMMd(
    Localizations.localeOf(context).languageCode,
  ).format(value.toLocal());

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) setState(() => _shares = _load());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() => _run(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final link = await ref.read(chatApiProvider).createShare(widget.sessionId);
    final base = ref.read(appConfigProvider).apiBaseUrl;
    final url = '$base/chat/shared/${Uri.encodeComponent(link.token)}';
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.shareCreated(_date(link.expiresAt)))),
    );
  });

  Future<void> _revoke(String shareId) => _run(() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(chatApiProvider).revokeShare(shareId);
    messenger.showSnackBar(SnackBar(content: Text(l10n.linkRevoked)));
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.shareTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              NoticeBanner(tone: StatusTone.warning, text: l10n.shareExplain),
              if (_error != null)
                NoticeBanner(
                  tone: StatusTone.error,
                  text: describeApiException(l10n, _error!),
                ),
              FilledButton.icon(
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.link),
                label: Text(l10n.createLinkAction),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.activeLinks,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              FutureBuilder<List<ShareSummary>>(
                future: _shares,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LoadingView();
                  final active = snapshot.data!.where((s) => s.active).toList();
                  if (active.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(l10n.noActiveLinks),
                    );
                  }
                  return Column(
                    children: [
                      for (final share in active)
                        ListTile(
                          leading: const Icon(Icons.link),
                          title: Text(l10n.expiresOn(_date(share.expiresAt))),
                          trailing: TextButton(
                            onPressed: _busy
                                ? null
                                : () => _revoke(share.shareId),
                            child: Text(l10n.revokeAction),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owns its text controller so it is disposed only after the dialog's exit animation.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.renameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        decoration: InputDecoration(labelText: l10n.conversationNameLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}
