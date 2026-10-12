import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
  if (confirmed == true) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
              avatar: const Icon(Icons.description_outlined, size: 18),
              label: Text(
                source.filename.isEmpty
                    ? l10n.sourceExcerpt(i + 1)
                    : source.filename,
              ),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (context) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.filename,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (source.chunkIndex != null)
                          Text(
                            l10n.sourceExcerpt(source.chunkIndex! + 1),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        const SizedBox(height: AppSpacing.md),
                        Flexible(
                          child: SingleChildScrollView(
                            child: BidiText(source.text),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.sourcesSessionOnly,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
