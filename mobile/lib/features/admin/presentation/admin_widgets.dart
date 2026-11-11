import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/admin_access.dart';

/// User-facing text for an admin failure; known server rules get their own wording.
String describeAdminError(AppLocalizations l10n, Object error) {
  if (error is AdminAccessLost) return l10n.adminAccessLost;
  if (error is! ApiException) return l10n.errorUnexpected;
  final detail = error.message ?? '';
  if (error is ConflictException) {
    if (detail.contains('at least one active admin')) {
      return l10n.adminLastAdmin;
    }
    if (detail.contains('Already a member')) return l10n.inviteAlreadyMember;
    if (detail.contains('already reviewed')) return l10n.reviewAlreadyDone;
    if (detail.contains('not active')) return l10n.adminSpaceInactive;
    if (detail.contains('newer invitation')) return l10n.inviteNewerOpen;
  }
  if (error is ForbiddenException && detail.contains('own request')) {
    return l10n.reviewOwnRequest;
  }
  if (error is ServerException && error.statusCode == 503) {
    return l10n.inviteEmailFailed;
  }
  if (error is ValidationException || error is BadRequestException) {
    if (detail.startsWith('Unsupported')) return l10n.adminUnsupportedChoice;
    return l10n.adminInvalidValue;
  }
  if (isUncertain(error)) return l10n.adminUncertain;
  return describeApiException(l10n, error);
}

String formatCount(BuildContext context, int value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value);

/// How a limit reads: unlimited, blocked (0), or a number. Member overrides that are not set
/// say which space default they inherit.
String describeLimit(
  BuildContext context, {
  required int? value,
  bool inherited = false,
  int? spaceDefault,
}) {
  final l10n = AppLocalizations.of(context);
  String plain(int? v) => v == null
      ? l10n.limitUnlimited
      : v == 0
      ? l10n.limitBlocked
      : formatCount(context, v);
  if (inherited) return l10n.limitInherited(plain(spaceDefault));
  return plain(value);
}

String limitLabel(AppLocalizations l10n, String key) => switch (key) {
  'daily_token_limit' => l10n.quotaDailyTokens,
  'monthly_token_limit' => l10n.quotaMonthlyTokens,
  'daily_request_limit' => l10n.quotaDailyConversations,
  'monthly_request_limit' => l10n.quotaMonthlyConversations,
  'daily_tool_request_limit' => l10n.quotaDailyToolRequests,
  _ => l10n.quotaMonthlyToolRequests,
};

/// Result of the limit dialog: [clear] means unlimited (space) or inherit (member).
typedef LimitChoice = ({bool clear, int? value});

/// Edits one limit. Returns null when cancelled.
Future<LimitChoice?> showLimitDialog(
  BuildContext context, {
  required String label,
  required int? current,
  required bool forMember,
}) => showDialog<LimitChoice>(
  context: context,
  builder: (_) =>
      _LimitDialog(label: label, current: current, forMember: forMember),
);

class _LimitDialog extends StatefulWidget {
  const _LimitDialog({
    required this.label,
    required this.current,
    required this.forMember,
  });

  final String label;
  final int? current;
  final bool forMember;

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  late bool _clear = widget.current == null;
  late final _value = TextEditingController(
    text: widget.current?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    if (_clear) {
      Navigator.of(context).pop((clear: true, value: null));
      return;
    }
    final value = int.tryParse(_value.text.trim());
    if (value == null || value < 0 || value > 1000000000) {
      setState(() => _error = l10n.limitInvalid);
      return;
    }
    Navigator.of(context).pop((clear: false, value: value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.label),
      scrollable: true,
      content: RadioGroup<bool>(
        groupValue: _clear,
        onChanged: (v) => setState(() => _clear = v ?? _clear),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioListTile<bool>(
              key: const ValueKey('limit-clear'),
              contentPadding: EdgeInsets.zero,
              value: true,
              title: Text(
                widget.forMember ? l10n.limitUseDefault : l10n.limitUnlimited,
              ),
            ),
            RadioListTile<bool>(
              key: const ValueKey('limit-set'),
              contentPadding: EdgeInsets.zero,
              value: false,
              title: Text(l10n.limitSetValue),
            ),
            if (!_clear)
              TextField(
                key: const ValueKey('limit-value'),
                controller: _value,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: widget.label,
                  helperText: l10n.limitZeroBlocks,
                  helperMaxLines: 3,
                  errorText: _error,
                ),
                onSubmitted: (_) => _save(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          key: const ValueKey('limit-save'),
          onPressed: _save,
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}

/// A destructive or access-changing confirmation. Returns true only on explicit confirmation.
Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(dialogContext).cancelAction),
          ),
          FilledButton(
            key: const ValueKey('confirm-action'),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

void showAdminMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

/// Standard loading / error / content body for an admin list, with pull-to-refresh.
class AdminAsyncBody<T> extends StatelessWidget {
  const AdminAsyncBody({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.builder,
  });

  final AsyncValue<T> value;
  final Future<void> Function() onRefresh;
  final List<Widget> Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = switch (value) {
      AsyncValue(value: final T data, hasValue: true) => builder(data),
      AsyncValue(error: final Object e) => [
        ErrorView(message: describeAdminError(l10n, e), onRetry: onRefresh),
      ],
      _ => const [LoadingView()],
    };
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          96,
        ),
        children: children,
      ),
    );
  }
}

/// A short status label in a tinted pill.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.emphasis = false});

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: emphasis
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: emphasis ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
