import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/l10n/text_direction.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../auth/application/auth_controller.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../notifications/presentation/notifications_screen.dart'
    show requestTypeLabel;
import '../../spaces/application/space_controller.dart';
import '../../spaces/data/spaces_api.dart';
import '../data/requests_api.dart';

typedef MyRequests = ({
  List<UserSpaceRequest> space,
  List<AccountRequest> account,
});

final myRequestsProvider = FutureProvider.autoDispose<MyRequests>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return (
      space: const <UserSpaceRequest>[],
      account: const <AccountRequest>[],
    );
  }
  final api = ref.read(requestsApiProvider);
  final results = await Future.wait<Object>([
    api.mySpaceRequests(),
    api.myAccountRequests(user.id),
  ]);
  return (
    space: results[0] as List<UserSpaceRequest>,
    account: results[1] as List<AccountRequest>,
  );
}, retry: (_, _) => null);

String statusLabel(AppLocalizations l10n, RequestStatus status) =>
    switch (status) {
      RequestStatus.pending => l10n.requestPending,
      RequestStatus.approved => l10n.requestApproved,
      RequestStatus.declined => l10n.requestDeclined,
    };

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final requests = ref.watch(myRequestsProvider);
    final space = ref.watch(spaceControllerProvider);
    final names = {
      if (space is SpaceSelected)
        for (final s in space.spaces) s.id: s.name,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsTitle)),
      floatingActionButton: space is SpaceSelected
          ? FloatingActionButton.extended(
              key: const ValueKey('new-request'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => NewRequestSheet(space: space),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.newRequestAction),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(myRequestsProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              96,
            ),
            children: [
              Text(
                l10n.requestsExplain,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              switch (requests) {
                AsyncValue(value: final data?)
                    when data.space.isEmpty && data.account.isEmpty =>
                  EmptyView(
                    title: l10n.requestsEmptyTitle,
                    message: l10n.requestsEmptyBody,
                    icon: Icons.inbox_outlined,
                  ),
                AsyncValue(value: final data?) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in data.space)
                      _SpaceRequestTile(
                        request: r,
                        spaceName: names[r.spaceId],
                      ),
                    if (data.account.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.accountRequestsTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      for (final r in data.account)
                        _AccountRequestTile(request: r),
                    ],
                  ],
                ),
                AsyncValue(error: final ApiException e) => ErrorView(
                  message: describeApiException(l10n, e),
                  onRetry: () => ref.invalidate(myRequestsProvider),
                ),
                _ => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      RequestStatus.approved => scheme.primary,
      RequestStatus.declined => scheme.error,
      RequestStatus.pending => scheme.tertiary,
    };
    return Text(
      statusLabel(AppLocalizations.of(context), status),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
    );
  }
}

class _SpaceRequestTile extends StatelessWidget {
  const _SpaceRequestTile({required this.request, this.spaceName});

  final UserSpaceRequest request;
  final String? spaceName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final detail = request.payload['model'] ?? request.payload['tool'];
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    requestTypeLabel(l10n, request.type),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _StatusChip(request.status),
              ],
            ),
            if (spaceName != null) BidiText(spaceName!),
            if (detail != null)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text('$detail', textAlign: TextAlign.start),
              ),
            Text(
              l10n.requestSentOn(date.format(request.createdAt.toLocal())),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (request.reviewNote != null &&
                request.reviewNote!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.reviewerNote,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              BidiText(request.reviewNote!),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountRequestTile extends StatelessWidget {
  const _AccountRequestTile({required this.request});

  final AccountRequest request;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Directionality(
      textDirection: TextDirection.ltr,
      child: Text(request.type, textAlign: TextAlign.start),
    ),
    subtitle: request.response == null ? null : BidiText(request.response!),
    trailing: _StatusChip(request.status),
  );
}

enum _Kind { model, upload, quota, other }

class NewRequestSheet extends ConsumerStatefulWidget {
  const NewRequestSheet({super.key, required this.space});

  final SpaceSelected space;

  @override
  ConsumerState<NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends ConsumerState<NewRequestSheet> {
  late final Future<({List<String> all, List<String> allowed})> _models = ref
      .read(requestsApiProvider)
      .models();
  _Kind _kind = _Kind.other;
  String? _model;
  final _reason = TextEditingController();
  final _quota = {
    'daily_token_limit': TextEditingController(),
    'monthly_token_limit': TextEditingController(),
    'daily_request_limit': TextEditingController(),
    'monthly_request_limit': TextEditingController(),
  };
  bool _sending = false;
  String? _error;

  bool get _canUpload =>
      widget.space.membership.role == SpaceRole.admin ||
      widget.space.membership.canUploadDocuments;

  @override
  void dispose() {
    _reason.dispose();
    for (final c in _quota.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? _payload(AppLocalizations l10n) {
    final reason = _reason.text.trim();
    final withReason = {if (reason.isNotEmpty) 'reason': reason};
    switch (_kind) {
      case _Kind.model:
        if (_model == null) return _fail(l10n.requestChooseModel);
        return {'model': _model, ...withReason};
      case _Kind.upload:
        return withReason;
      case _Kind.quota:
        final limits = <String, int>{};
        for (final entry in _quota.entries) {
          final text = entry.value.text.trim();
          if (text.isEmpty) continue;
          final value = int.tryParse(text);
          if (value == null || value <= 0) {
            return _fail(l10n.requestQuotaInvalid);
          }
          limits[entry.key] = value;
        }
        if (limits.isEmpty) return _fail(l10n.requestQuotaInvalid);
        return {...limits, ...withReason};
      case _Kind.other:
        if (reason.isEmpty) return _fail(l10n.requestReasonRequired);
        return withReason;
    }
  }

  Map<String, dynamic>? _fail(String message) {
    setState(() => _error = message);
    return null;
  }

  Future<void> _submit() async {
    if (_sending) return;
    final l10n = AppLocalizations.of(context);
    final payload = _payload(l10n);
    if (payload == null) return;
    final type = switch (_kind) {
      _Kind.model => 'model_access',
      _Kind.upload => 'upload_access',
      _Kind.quota => 'quota_change',
      _Kind.other => 'other',
    };
    setState(() {
      _sending = true;
      _error = null;
    });
    final sentAt = DateTime.now().toUtc();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref
          .read(requestsApiProvider)
          .create(widget.space.space.id, type, payload);
      ref.invalidate(myRequestsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      final existing = created.createdAt.isBefore(
        sentAt.subtract(const Duration(seconds: 30)),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            existing ? l10n.requestAlreadyPending : l10n.requestSent,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final uncertain =
          e is NetworkUnavailableException ||
          e is RequestTimeoutException ||
          e is ServerException;
      if (uncertain) {
        // Not retried automatically: reload the list so the user can see whether it arrived.
        ref.invalidate(myRequestsProvider);
        setState(() => _error = l10n.requestUncertain);
      } else {
        setState(
          () => _error = e is ConflictException && e.message != null
              ? e.message
              : describeApiException(l10n, e),
        );
      }
    } finally {
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.newRequestTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              BidiText(widget.space.space.name),
              const SizedBox(height: AppSpacing.md),
              FutureBuilder(
                future: _models,
                builder: (context, snapshot) {
                  final models = snapshot.data;
                  final requestable = models == null
                      ? const <String>[]
                      : models.all
                            .where((m) => !models.allowed.contains(m))
                            .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<_Kind>(
                        segments: [
                          if (requestable.isNotEmpty)
                            ButtonSegment(
                              value: _Kind.model,
                              label: Text(l10n.requestTypeModel),
                            ),
                          if (!_canUpload)
                            ButtonSegment(
                              value: _Kind.upload,
                              label: Text(l10n.requestTypeUpload),
                            ),
                          ButtonSegment(
                            value: _Kind.quota,
                            label: Text(l10n.requestTypeQuota),
                          ),
                          ButtonSegment(
                            value: _Kind.other,
                            label: Text(l10n.requestTypeOther),
                          ),
                        ],
                        selected: {_kind},
                        onSelectionChanged: (v) => setState(() {
                          _kind = v.first;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_kind == _Kind.model)
                        DropdownButtonFormField<String>(
                          initialValue: _model,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.modelLabel,
                          ),
                          items: [
                            for (final m in requestable)
                              DropdownMenuItem(
                                value: m,
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(m),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _model = v),
                        ),
                      if (_kind == _Kind.upload)
                        Text(l10n.requestUploadExplain),
                      if (_kind == _Kind.quota)
                        for (final entry in _quota.entries)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: TextField(
                              controller: entry.value,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: _quotaLabel(l10n, entry.key),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _reason,
                maxLength: 500,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: _kind == _Kind.other
                      ? l10n.requestReason
                      : l10n.requestReasonOptional,
                ),
              ),
              if (_error != null)
                NoticeBanner(tone: StatusTone.error, text: _error!),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.sendRequestAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _quotaLabel(AppLocalizations l10n, String key) => switch (key) {
    'daily_token_limit' => l10n.quotaDailyTokens,
    'monthly_token_limit' => l10n.quotaMonthlyTokens,
    'daily_request_limit' => l10n.quotaDailyConversations,
    _ => l10n.quotaMonthlyConversations,
  };
}
