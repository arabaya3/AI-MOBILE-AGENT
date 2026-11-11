import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/l10n/text_direction.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../notifications/presentation/notifications_screen.dart'
    show requestTypeLabel;
import '../../requests/data/requests_api.dart' show RequestStatus;
import '../../requests/presentation/requests_screen.dart' show statusLabel;
import '../application/admin_access.dart';
import '../data/admin_api.dart';
import 'admin_widgets.dart';

class AdminRequestsScreen extends ConsumerWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final requests = ref.watch(adminRequestsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.adminRequestsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.requestsPendingTab),
              Tab(text: l10n.requestsHistoryTab),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              for (final pending in [true, false])
                AdminAsyncBody<List<ReviewableRequest>>(
                  value: requests,
                  onRefresh: () => ref.refresh(adminRequestsProvider.future),
                  builder: (data) {
                    final shown = [
                      for (final r in data)
                        if ((r.status == RequestStatus.pending) == pending) r,
                    ];
                    if (shown.isEmpty) {
                      return [
                        EmptyView(
                          title: pending
                              ? l10n.noPendingRequestsTitle
                              : l10n.noReviewedRequestsTitle,
                          message: pending
                              ? l10n.noPendingRequestsBody
                              : l10n.noReviewedRequestsBody,
                          icon: Icons.inbox_outlined,
                        ),
                      ];
                    }
                    return [for (final r in shown) _RequestTile(request: r)];
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the requester asked for, in words (never raw payload keys).
String requestSummary(BuildContext context, ReviewableRequest r) {
  final l10n = AppLocalizations.of(context);
  final p = r.payload;
  return switch (r.type) {
    'model_access' => l10n.requestSummaryModel('${p['model'] ?? ''}'),
    'tool_access' => l10n.requestSummaryTool('${p['tool'] ?? ''}'),
    'upload_access' => l10n.requestSummaryUpload,
    'quota_change' => [
      for (final key in limitKeys)
        if (p[key] is num)
          '${limitLabel(l10n, key)}: ${formatCount(context, (p[key] as num).toInt())}',
    ].join('\n'),
    'join' => l10n.requestSummaryJoin,
    _ => '',
  };
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final ReviewableRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(request.createdAt.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        key: ValueKey('admin-request-${request.id}'),
        title: Text(requestTypeLabel(l10n, request.type)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [BidiText(request.userEmail), Text(date)],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => ReviewSheet(request: request),
        ),
      ),
    );
  }
}

class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({super.key, required this.request});

  final ReviewableRequest request;

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide(bool approve) async {
    if (_sending) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await runAdminFromWidget(
        ref,
        (api, id) => api.review(
          id,
          widget.request.id,
          approve: approve,
          note: _note.text,
        ),
      );
      if (!mounted || result == null) return;
      Navigator.of(context).pop();
      showAdminMessage(
        context,
        approve ? l10n.requestApprovedDone : l10n.requestDeclinedDone,
      );
    } catch (e) {
      if (mounted) setState(() => _error = describeAdminError(l10n, e));
    } finally {
      // Approvals change members and policy; reload what they affect.
      ref.invalidate(adminRequestsProvider);
      ref.invalidate(adminMembersProvider);
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = widget.request;
    final summary = requestSummary(context, r);
    final reason = r.payload['reason'];
    final own = r.userId == ref.watch(currentUserProvider)?.id;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                requestTypeLabel(l10n, r.type),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              BidiText(r.userEmail),
              const SizedBox(height: AppSpacing.md),
              if (summary.isNotEmpty) BidiText(summary),
              if (reason is String && reason.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.requestReasonLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                BidiText(reason),
              ],
              const SizedBox(height: AppSpacing.md),
              if (r.status != RequestStatus.pending) ...[
                StatusPill(statusLabel(l10n, r.status)),
                if (r.reviewNote != null && r.reviewNote!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  BidiText(r.reviewNote!),
                ],
              ] else if (own)
                NoticeBanner(tone: StatusTone.info, text: l10n.reviewOwnRequest)
              else ...[
                TextField(
                  key: const ValueKey('review-note'),
                  controller: _note,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: l10n.reviewNoteLabel),
                ),
                if (_error != null)
                  NoticeBanner(tone: StatusTone.error, text: _error!),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('decline-request'),
                        onPressed: _sending ? null : () => _decide(false),
                        child: Text(l10n.declineAction),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('approve-request'),
                        onPressed: _sending ? null : () => _decide(true),
                        child: _sending
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.approveAction),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
