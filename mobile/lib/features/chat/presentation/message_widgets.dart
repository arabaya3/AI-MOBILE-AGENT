import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/chat_api.dart';
import '../data/chat_stream_event.dart';

/// Opens only http(s) links, after the user confirms the destination.
Future<void> openExternalLink(BuildContext context, String? href) async {
  final uri = href == null ? null : Uri.tryParse(href);
  if (uri == null ||
      !(uri.scheme == 'https' || uri.scheme == 'http') ||
      uri.host.isEmpty) {
    return;
  }
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.openLinkTitle),
      content: Text(l10n.openLinkBody(uri.host)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.openAction),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.openLinkFailed)));
  }
}

/// Images in model or document text are never fetched automatically: they could track the reader
/// or load untrusted content. The placeholder offers the link, which still asks before opening.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder(this.uri, this.alt);

  final Uri uri;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final web =
        (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              (alt?.trim().isNotEmpty ?? false)
                  ? '${alt!.trim()} · ${l10n.imageNotLoaded}'
                  : l10n.imageNotLoaded,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (web)
            TextButton(
              onPressed: () => openExternalLink(context, uri.toString()),
              child: Text(l10n.openAction),
            ),
        ],
      ),
    );
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copied)),
    );
}

/// Markdown in the direction of its own content, selectable, with confirmed links.
class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: detectTextDirection(
        text,
        fallback: Directionality.of(context),
      ),
      child: MarkdownBody(
        data: text,
        selectable: true,
        softLineBreak: true,
        onTapLink: (_, href, _) => openExternalLink(context, href),
        imageBuilder: (uri, _, alt) => _ImagePlaceholder(uri, alt),
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: theme.textTheme.bodyLarge,
          code: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          codeblockDecoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
    );
  }
}

class UserBubble extends StatelessWidget {
  const UserBubble(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: GestureDetector(
          onLongPress: () => copyText(context, text),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: Directionality(
                textDirection: detectTextDirection(
                  text,
                  fallback: Directionality.of(context),
                ),
                child: SelectableText(
                  text,
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AssistantBubble extends StatelessWidget {
  const AssistantBubble({
    super.key,
    required this.message,
    required this.sources,
    required this.reaction,
    required this.onReact,
    required this.onBranch,
  });

  final ChatMessage message;
  final List<Citation> sources;
  final Reaction? reaction;
  final ValueChanged<Reaction> onReact;
  final VoidCallback onBranch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (message.isStoredProviderError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(
          l10n.storedReplyFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarkdownMessage(message.content),
        if (sources.isNotEmpty) SourcesRow(sources: sources),
        Wrap(
          children: [
            IconButton(
              tooltip: l10n.copyAction,
              icon: const Icon(Icons.copy_outlined, size: 20),
              onPressed: () => copyText(context, message.content),
            ),
            IconButton(
              tooltip: l10n.helpful,
              isSelected: reaction == Reaction.up,
              selectedIcon: const Icon(Icons.thumb_up, size: 20),
              icon: const Icon(Icons.thumb_up_outlined, size: 20),
              onPressed: () => onReact(Reaction.up),
            ),
            IconButton(
              tooltip: l10n.notHelpful,
              isSelected: reaction == Reaction.down,
              selectedIcon: const Icon(Icons.thumb_down, size: 20),
              icon: const Icon(Icons.thumb_down_outlined, size: 20),
              onPressed: () => onReact(Reaction.down),
            ),
            IconButton(
              tooltip: l10n.branchAction,
              icon: const Icon(Icons.call_split, size: 20),
              onPressed: onBranch,
            ),
          ],
        ),
      ],
    );
  }
}

class SourcesRow extends StatelessWidget {
  const SourcesRow({super.key, required this.sources});

  final List<Citation> sources;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final (i, source) in sources.indexed)
            ActionChip(
              avatar: Icon(
                source.available
                    ? Icons.description_outlined
                    : Icons.lock_outline,
                size: 18,
              ),
              label: Text(_label(l10n, source, i)),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => _SourceSheet(source: source, index: i),
              ),
            ),
        ],
      ),
    );
  }

  static String _label(AppLocalizations l10n, Citation source, int index) {
    if (!source.available) return l10n.sourceUnavailable;
    final name = source.filename.isEmpty
        ? l10n.sourceExcerpt(index + 1)
        : source.filename;
    return source.page == null
        ? name
        : '$name · ${l10n.pageNumber(source.page!)}';
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.source, required this.index});

  final Citation source;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
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
            if (!source.available) ...[
              Text(l10n.sourceUnavailable, style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.sourceUnavailableBody),
            ] else ...[
              BidiText(
                source.filename.isEmpty
                    ? l10n.sourceExcerpt(index + 1)
                    : source.filename,
                style: textTheme.titleMedium,
              ),
              Text(
                [
                  if (source.page != null) l10n.pageNumber(source.page!),
                  if (source.chunkIndex != null)
                    l10n.sourceExcerpt(source.chunkIndex! + 1),
                ].join(' · '),
                style: textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: SingleChildScrollView(child: BidiText(source.text)),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.sourceSavedNote, style: textTheme.bodySmall),
              if (source.documentId.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(
                      '/documents/${Uri.encodeComponent(source.documentId)}',
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.openDocumentAction),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
