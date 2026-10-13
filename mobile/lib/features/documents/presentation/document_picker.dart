import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/document_selection.dart';
import '../application/documents_controller.dart';

Future<void> showDocumentPickerSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _DocumentPickerSheet(),
    );

/// Composer button; the badge counts explicitly selected documents.
class DocumentSelectButton extends ConsumerWidget {
  const DocumentSelectButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final count = ref.watch(
      documentSelectionProvider.select((s) => s.ids.length),
    );
    return IconButton(
      tooltip: l10n.chooseDocumentsAction,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.description_outlined),
      ),
      onPressed: () => showDocumentPickerSheet(context),
    );
  }
}

/// States what the next question will search, and explains selection changes.
class DocumentScopeBar extends ConsumerWidget {
  const DocumentScopeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(documentSelectionProvider);
    final ready = ref.watch(readyDocumentsProvider);
    final textTheme = Theme.of(context).textTheme;
    final children = <Widget>[
      if (selection.removed.isNotEmpty)
        NoticeBanner(
          tone: StatusTone.warning,
          text: l10n.selectionPruned(
            selection.removed
                .where((n) => n.isNotEmpty)
                .join(l10n.listSeparator),
            selection.ids.isEmpty
                ? l10n.scopeAllDocuments
                : l10n.scopeSelectedDocuments(selection.ids.length),
          ),
          action: TextButton(
            onPressed: ref
                .read(documentSelectionProvider.notifier)
                .acknowledgeRemoval,
            child: Text(l10n.dismissAction),
          ),
        ),
      if (selection.ids.isNotEmpty)
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final id in selection.ids)
              InputChip(
                avatar: const Icon(Icons.description_outlined, size: 18),
                label: BidiText(selection.names[id] ?? '', maxLines: 1),
                deleteButtonTooltipMessage: l10n.removeFromSelection,
                onDeleted: () =>
                    ref.read(documentSelectionProvider.notifier).remove(id),
              ),
          ],
        )
      else if (ready.isNotEmpty)
        Text(l10n.scopeAllDocuments, style: textTheme.bodySmall),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _DocumentPickerSheet extends ConsumerStatefulWidget {
  const _DocumentPickerSheet();

  @override
  ConsumerState<_DocumentPickerSheet> createState() =>
      _DocumentPickerSheetState();
}

class _DocumentPickerSheetState extends ConsumerState<_DocumentPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final docs = ref.watch(documentsControllerProvider);
    final selection = ref.watch(documentSelectionProvider);
    final ready = ref.watch(readyDocumentsProvider);
    final notReady = (docs.items ?? const []).where((d) => !d.isReady).length;
    final query = _query.trim().toLowerCase();
    final visible = ready
        .where((d) => query.isEmpty || d.filename.toLowerCase().contains(query))
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.chooseDocumentsTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(l10n.chooseDocumentsExplain),
                    if (notReady > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.documentsNotReadyHidden(notReady),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.searchDocumentsHint,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: switch (docs) {
                  DocumentsState(items: null, error: final error?) => Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: ErrorView(
                      message: describeApiException(l10n, error),
                      onRetry: ref
                          .read(documentsControllerProvider.notifier)
                          .refresh,
                    ),
                  ),
                  DocumentsState(items: null) => const LoadingView(),
                  _ when visible.isEmpty => Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      ready.isEmpty
                          ? l10n.noReadyDocuments
                          : l10n.noMatchingDocuments,
                    ),
                  ),
                  _ => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final doc in visible)
                        CheckboxListTile(
                          value: selection.ids.contains(doc.id),
                          onChanged: (_) => ref
                              .read(documentSelectionProvider.notifier)
                              .toggle(doc),
                          title: BidiText(doc.filename, maxLines: 2),
                          secondary: const Icon(Icons.description_outlined),
                        ),
                    ],
                  ),
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selection.ids.isEmpty
                            ? l10n.scopeAllDocuments
                            : l10n.scopeSelectedDocuments(selection.ids.length),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (selection.ids.isNotEmpty)
                      TextButton(
                        onPressed: ref
                            .read(documentSelectionProvider.notifier)
                            .clear,
                        child: Text(l10n.clearSelection),
                      ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.doneAction),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
