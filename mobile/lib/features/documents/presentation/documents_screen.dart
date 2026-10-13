import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/documents_controller.dart';
import '../data/documents_api.dart';

typedef PickDocument = Future<UploadSource?> Function();

/// System file picker (no storage permission); overridden in tests.
final pickDocumentProvider = Provider<PickDocument>(
  (ref) => () async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
    );
    if (file == null) return null;
    final length = file.lengthSync() ?? await file.length() ?? -1;
    return UploadSource(
      name: file.name,
      length: length,
      open: file.readAsByteStream,
    );
  },
);

String formatBytes(BuildContext context, int bytes) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final l10n = AppLocalizations.of(context);
  if (bytes >= 1024 * 1024) {
    return l10n.sizeMegabytes(
      NumberFormat('0.0', locale).format(bytes / (1024 * 1024)),
    );
  }
  return l10n.sizeKilobytes(
    NumberFormat('0', locale).format((bytes / 1024).ceil()),
  );
}

String documentStateLabel(AppLocalizations l10n, DocumentState state) =>
    switch (state) {
      DocumentState.ready => l10n.docStateReady,
      DocumentState.failed => l10n.docStateFailed,
      DocumentState.uploaded ||
      DocumentState.processing => l10n.docStateProcessing,
      DocumentState.indexing => l10n.docStateIndexing,
    };

String documentErrorText(AppLocalizations l10n, String? code) => switch (code) {
  'encrypted' => l10n.docErrorEncrypted,
  'corrupt' || 'invalid_content' => l10n.docErrorCorrupt,
  'no_text' => l10n.docErrorNoText,
  'too_complex' => l10n.docErrorTooComplex,
  'unsupported_type' || 'unsupported_encoding' => l10n.docErrorUnsupported,
  'too_large' => l10n.docErrorTooLarge,
  'empty' => l10n.docErrorEmpty,
  'timeout' => l10n.docErrorTimeout,
  'interrupted' => l10n.docErrorInterrupted,
  'storage_failed' => l10n.docErrorStorage,
  _ => l10n.docErrorGeneric,
};

class DocumentStateChip extends StatelessWidget {
  const DocumentStateChip(this.state, {super.key});

  final DocumentState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (state) {
      DocumentState.ready => (scheme.primary, Icons.check_circle_outline),
      DocumentState.failed => (scheme.error, Icons.error_outline),
      _ => (scheme.tertiary, Icons.hourglass_top),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          documentStateLabel(l10n, state),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

enum _Filter { all, ready, processing, failed }

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String _query = '';
  _Filter _filter = _Filter.all;
  bool _picking = false;

  Future<void> _pickAndUpload() async {
    if (_picking) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _picking = true);
    try {
      final source = await ref.read(pickDocumentProvider)();
      if (source == null || !mounted) return;
      final rejection = await ref
          .read(documentsControllerProvider.notifier)
          .upload(source);
      final message = switch (rejection) {
        LocalRejection.unsupportedType => l10n.docErrorUnsupported,
        LocalRejection.tooLarge => l10n.docErrorTooLarge,
        LocalRejection.empty => l10n.docErrorEmpty,
        null => null,
      };
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  bool _matches(DocumentItem doc) {
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty && !doc.filename.toLowerCase().contains(query)) {
      return false;
    }
    return switch (_filter) {
      _Filter.all => true,
      _Filter.ready => doc.isReady,
      _Filter.processing => doc.state.active,
      _Filter.failed => doc.state == DocumentState.failed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(documentsControllerProvider);
    final canUpload = ref.watch(canUploadDocumentsProvider);
    final controller = ref.read(documentsControllerProvider.notifier);
    final items = state.items;
    final visible = items?.where(_matches).toList() ?? const <DocumentItem>[];

    final header = <Widget>[
      Text(
        l10n.documentsChatExplain,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: l10n.searchDocumentsHint,
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final (filter, label) in [
            (_Filter.all, l10n.filterAll),
            (_Filter.ready, l10n.docStateReady),
            (_Filter.processing, l10n.filterInProgress),
            (_Filter.failed, l10n.docStateFailed),
          ])
            ChoiceChip(
              label: Text(label),
              selected: _filter == filter,
              onSelected: (_) => setState(() => _filter = filter),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
    ];

    final List<Widget> content;
    if (items == null && state.error != null) {
      content = [
        ErrorView(
          message: describeApiException(l10n, state.error!),
          onRetry: controller.refresh,
        ),
      ];
    } else if (items == null) {
      content = const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else {
      content = [
        if (state.error != null)
          NoticeBanner(
            tone: StatusTone.warning,
            text: describeApiException(l10n, state.error!),
          ),
        for (final upload in state.uploads) _UploadCard(upload: upload),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: EmptyView(
              title: l10n.documentsEmptyTitle,
              message: canUpload
                  ? l10n.documentsEmptyUploader
                  : l10n.documentsEmptyReader,
              icon: Icons.folder_open,
            ),
          )
        else if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(l10n.noMatchingDocuments, textAlign: TextAlign.center),
          )
        else
          for (final doc in visible) _DocumentTile(doc),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentsTitle)),
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              onPressed: _picking ? null : _pickAndUpload,
              icon: const Icon(Icons.upload_file),
              label: Text(l10n.uploadAction),
            )
          : null,
      // One scrollable column so large text and an open keyboard never overflow.
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              96,
            ),
            children: [...header, ...content],
          ),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile(this.doc);

  final DocumentItem doc;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final details = [
      if (doc.fileSize != null) formatBytes(context, doc.fileSize!),
      if (doc.uploadedAt != null)
        DateFormat.yMMMd(locale).format(doc.uploadedAt!.toLocal()),
      if (doc.isHidden) l10n.documentHidden,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined),
      title: BidiText(doc.filename, maxLines: 2),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DocumentStateChip(doc.state),
          if (details.isNotEmpty) Text(details),
        ],
      ),
      onTap: () => context.push('/documents/${Uri.encodeComponent(doc.id)}'),
    );
  }
}

class _UploadCard extends ConsumerWidget {
  const _UploadCard({required this.upload});

  final UploadTask upload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(documentsControllerProvider.notifier);
    final document = upload.document;
    final (String text, StatusTone tone) = switch (upload.phase) {
      UploadPhase.sending => (
        l10n.uploadSending(
          formatBytes(context, upload.sent),
          formatBytes(context, upload.size),
        ),
        StatusTone.info,
      ),
      UploadPhase.processing => (l10n.uploadProcessing, StatusTone.info),
      UploadPhase.checking => (l10n.uploadChecking, StatusTone.warning),
      UploadPhase.done when document?.state == DocumentState.failed => (
        documentErrorText(l10n, document?.errorCode),
        StatusTone.error,
      ),
      UploadPhase.done when document?.isReady ?? false => (
        l10n.uploadReady,
        StatusTone.success,
      ),
      UploadPhase.done => (l10n.uploadReceived, StatusTone.info),
      UploadPhase.failed => (
        upload.error == null
            ? l10n.docErrorGeneric
            : describeApiException(l10n, upload.error!),
        StatusTone.error,
      ),
      UploadPhase.cancelled => (l10n.uploadCancelled, StatusTone.warning),
      UploadPhase.notReceived => (l10n.uploadNotReceived, StatusTone.error),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BidiText(
              upload.filename,
              maxLines: 2,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (upload.phase == UploadPhase.sending)
              LinearProgressIndicator(
                value: upload.size > 0 ? upload.sent / upload.size : null,
              )
            else if (upload.phase == UploadPhase.processing ||
                upload.phase == UploadPhase.checking)
              const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
            NoticeBanner(tone: tone, text: text),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (upload.phase == UploadPhase.sending ||
                    upload.phase == UploadPhase.processing)
                  TextButton(
                    onPressed: () => controller.cancelUpload(upload.uploadId),
                    child: Text(
                      upload.phase == UploadPhase.sending
                          ? l10n.cancelUploadAction
                          : l10n.stopWaitingAction,
                    ),
                  ),
                if (upload.phase == UploadPhase.checking)
                  TextButton(
                    onPressed: () => controller.checkAgain(upload.uploadId),
                    child: Text(l10n.checkAgainAction),
                  ),
                if (document != null)
                  TextButton(
                    onPressed: () => context.push(
                      '/documents/${Uri.encodeComponent(document.id)}',
                    ),
                    child: Text(l10n.viewDetailsAction),
                  ),
                if (!upload.active)
                  TextButton(
                    onPressed: () => controller.dismissUpload(upload.uploadId),
                    child: Text(l10n.dismissAction),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
