import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/section.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../spaces/application/space_controller.dart';
import '../application/document_files.dart';
import '../application/document_selection.dart';
import '../application/documents_controller.dart';
import '../data/documents_api.dart';
import 'documents_screen.dart';

/// Hands a local file to another app; returns false when no app could open it. Overridden in tests.
final openLocalFileProvider = Provider<Future<bool> Function(String path)>(
  (ref) =>
      (path) async => (await OpenFilex.open(path)).type == ResultType.done,
);

/// Fresh, access-checked details of one document. Reloaded on every visit, never cached across spaces.
final documentDetailsProvider = FutureProvider.autoDispose
    .family<DocumentItem, String>(
      (ref, id) async {
        ref.watch(spaceScopeProvider);
        // Follow list polling so state changes show here as well.
        ref.watch(
          documentsControllerProvider.select(
            (s) => s.items?.where((d) => d.id == id).firstOrNull?.state,
          ),
        );
        return ref.read(documentsApiProvider).get(id);
      },
      // Access decisions (404/403) are final; the screen offers its own retry for other errors.
      retry: (_, _) => null,
    );

class DocumentDetailsScreen extends ConsumerStatefulWidget {
  const DocumentDetailsScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<DocumentDetailsScreen> createState() =>
      _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends ConsumerState<DocumentDetailsScreen> {
  double? _downloadProgress;
  bool _downloading = false;
  bool _retrying = false;

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _open(DocumentItem doc) async {
    if (_downloading) return;
    final l10n = AppLocalizations.of(context);
    final scope = ref.read(spaceScopeProvider);
    setState(() {
      _downloading = true;
      _downloadProgress = null;
    });
    try {
      final path = await ref
          .read(documentFilesProvider)
          .fetch(
            doc,
            onProgress: (received, total) {
              if (mounted && total > 0) {
                setState(() => _downloadProgress = received / total);
              }
            },
          );
      // A late download after a sign-out or space switch is discarded.
      if (!mounted || ref.read(spaceScopeProvider) != scope) return;
      final opened = await ref.read(openLocalFileProvider)(path);
      if (!opened && mounted) _say(l10n.openFileFailed);
    } on ApiException catch (e) {
      if (mounted && e is! RequestCancelledException) {
        _say(describeApiException(l10n, e));
      }
    } on Exception {
      if (mounted) _say(l10n.openFileFailed);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _retry(DocumentItem doc) async {
    if (_retrying) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _retrying = true);
    try {
      await ref.read(documentsControllerProvider.notifier).retry(doc.id);
      ref.invalidate(documentDetailsProvider(doc.id));
    } on ApiException catch (e) {
      if (mounted) _say(describeApiException(l10n, e));
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final details = ref.watch(documentDetailsProvider(widget.documentId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentDetailsTitle)),
      body: SafeArea(
        child: switch (details) {
          AsyncValue(value: final doc?) => _body(context, doc),
          AsyncValue(error: final NotFoundException _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: EmptyView(
              title: l10n.documentUnavailableTitle,
              message: l10n.documentUnavailableBody,
              icon: Icons.lock_outline,
            ),
          ),
          AsyncValue(error: final ApiException e) => Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ErrorView(
              message: describeApiException(l10n, e),
              onRetry: () =>
                  ref.invalidate(documentDetailsProvider(widget.documentId)),
            ),
          ),
          _ => const LoadingView(),
        },
      ),
    );
  }

  Widget _body(BuildContext context, DocumentItem doc) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final selected = ref.watch(
      documentSelectionProvider.select((s) => s.ids.contains(doc.id)),
    );
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        BidiText(doc.filename, style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        DocumentStateChip(doc.state),
        const SizedBox(height: AppSpacing.md),
        if (doc.state.active) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.docProcessingExplain),
        ],
        if (doc.state == DocumentState.failed)
          NoticeBanner(
            tone: StatusTone.error,
            text: documentErrorText(l10n, doc.errorCode),
            action: doc.canRetry
                ? OutlinedButton(
                    onPressed: _retrying ? null : () => _retry(doc),
                    child: Text(l10n.retryProcessingAction),
                  )
                : null,
          ),
        Section(
          title: l10n.documentInfoTitle,
          children: [
            _InfoRow(
              label: l10n.fileTypeLabel,
              value: doc.fileType.toUpperCase(),
            ),
            if (doc.fileSize != null)
              _InfoRow(
                label: l10n.fileSizeLabel,
                value: formatBytes(context, doc.fileSize!),
              ),
            if (doc.uploadedAt != null)
              _InfoRow(
                label: l10n.uploadedLabel,
                value: DateFormat.yMMMd(
                  locale,
                ).add_jm().format(doc.uploadedAt!.toLocal()),
              ),
            if (doc.isReady)
              _InfoRow(
                label: l10n.sectionsLabel,
                value: NumberFormat.decimalPattern(
                  locale,
                ).format(doc.chunksCount),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (doc.isReady)
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(documentSelectionProvider.notifier).toggle(doc),
            icon: Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            label: Text(selected ? l10n.selectedForChat : l10n.useInChatAction),
          ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: _downloading ? null : () => _open(doc),
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.openDocumentAction),
        ),
        if (_downloading) ...[
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(value: _downloadProgress),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.localCopyExplain, style: textTheme.bodySmall),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          Text(value, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}
