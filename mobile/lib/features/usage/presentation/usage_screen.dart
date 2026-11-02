import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/files/private_files.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/section.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../spaces/application/space_controller.dart';
import '../data/usage_api.dart';

const usagePeriods = [1, 7, 30, 90];

final usageOverviewProvider = FutureProvider.autoDispose
    .family<UsageOverview, int>((ref, days) {
      ref.watch(spaceScopeProvider);
      return ref.read(usageApiProvider).overview(days);
    }, retry: (_, _) => null);

String formatUsd(String locale, double amount) => NumberFormat.currency(
  locale: locale,
  name: 'USD',
  symbol: 'US\$',
  decimalDigits: amount != 0 && amount.abs() < 1 ? 4 : 2,
).format(amount);

class UsageScreen extends ConsumerStatefulWidget {
  const UsageScreen({super.key});

  @override
  ConsumerState<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends ConsumerState<UsageScreen> {
  int _days = 30;
  bool _exporting = false;

  Future<void> _invoice() async {
    if (_exporting) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final scope = ref.read(spaceScopeProvider);
    setState(() => _exporting = true);
    try {
      final path = await ref
          .read(privateFilesProvider)
          .download(
            '/chat/usage/invoice/pdf',
            'teia-usage-${_days}d.pdf',
            query: {'days': _days},
          );
      if (!mounted || ref.read(spaceScopeProvider) != scope) return;
      final outcome = await ref.read(shareFileProvider)(
        path,
        'application/pdf',
        l10n.invoiceShareSubject,
      );
      if (outcome == ShareOutcome.unavailable) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.shareUnavailable)));
      }
    } on ApiException catch (e) {
      if (mounted && e is! RequestCancelledException) {
        messenger.showSnackBar(
          SnackBar(content: Text(describeApiException(l10n, e))),
        );
      }
    } on Exception {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.shareUnavailable)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(usageOverviewProvider(_days));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.usageTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(usageOverviewProvider(_days).future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final days in usagePeriods)
                    ChoiceChip(
                      label: Text(
                        days == 1 ? l10n.periodDay : l10n.periodDays(days),
                      ),
                      selected: _days == days,
                      onSelected: (_) => setState(() => _days = days),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              switch (overview) {
                AsyncValue(value: final data?) => _UsageBody(data: data),
                AsyncValue(error: final ApiException e) => ErrorView(
                  message: describeApiException(l10n, e),
                  onRetry: () => ref.invalidate(usageOverviewProvider(_days)),
                ),
                _ => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              },
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                key: const ValueKey('usage-invoice'),
                onPressed: _exporting ? null : _invoice,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(l10n.invoiceAction),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.invoiceExplain,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageBody extends StatelessWidget {
  const _UsageBody({required this.data});

  final UsageOverview data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final number = NumberFormat.decimalPattern(locale);
    final date = DateFormat.yMMMd(locale).add_jm();
    final textTheme = Theme.of(context).textTheme;
    final cost = data.costAmount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.usageWindow(
            date.format(data.start.toLocal()),
            date.format(data.end.toLocal()),
          ),
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Section(
          title: l10n.usageSummaryTitle,
          children: [
            _Row(l10n.usageRequests, number.format(data.totalRequests)),
            if (data.unknownRequests > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  l10n.usageUnknownRequests(data.unknownRequests),
                  style: textTheme.bodySmall,
                ),
              ),
            _Row(l10n.usageInputTokens, number.format(data.inputTokens)),
            _Row(l10n.usageOutputTokens, number.format(data.outputTokens)),
            _Row(l10n.usageTotalTokens, number.format(data.totalTokens)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Section(
          title: l10n.usageCostTitle,
          subtitle: l10n.usageCostBasis,
          children: [
            Text(
              cost == null
                  ? l10n.usageCostUnavailable
                  : formatUsd(locale, cost),
              key: const ValueKey('usage-cost'),
              style: textTheme.headlineSmall,
            ),
            if (!data.costComplete && cost != null)
              NoticeBanner(
                tone: StatusTone.warning,
                text: l10n.usageCostIncomplete(data.requestsWithoutCost),
              ),
            if (cost == null && data.totalRequests > 0)
              NoticeBanner(tone: StatusTone.info, text: l10n.usageCostNone),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Section(
          title: l10n.usageLimitsTitle,
          subtitle: l10n.usageLimitsExplain,
          children: [for (final limit in data.limits) _LimitRow(limit)],
        ),
        if (data.byModel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Section(
            title: l10n.usageByModel,
            children: [
              for (final row in data.byModel)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(row.model, textAlign: TextAlign.start),
                  ),
                  subtitle: Text(
                    l10n.usageModelLine(
                      number.format(row.requests),
                      number.format(row.totalTokens),
                    ),
                  ),
                  trailing: Text(
                    row.costUsd == null
                        ? '—'
                        : formatUsd(locale, row.costUsd!) +
                              (row.costComplete ? '' : ' *'),
                  ),
                ),
            ],
          ),
        ],
        if (data.tools.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Section(
            title: l10n.usageTools,
            children: [
              for (final tool in data.tools)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(tool.tool, textAlign: TextAlign.start),
                  ),
                  subtitle: Text(
                    l10n.usageToolCalls(number.format(tool.requests)),
                  ),
                  trailing: Text(
                    tool.costUsd == null
                        ? '—'
                        : formatUsd(locale, tool.costUsd!),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _LimitRow extends StatelessWidget {
  const _LimitRow(this.limit);

  final UsageLimit limit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final what = switch (limit.unit) {
      'tokens' => l10n.limitTokens,
      'conversations' => l10n.limitConversations,
      _ => l10n.limitToolRequests,
    };
    final window = limit.windowHours <= 24
        ? l10n.limitLast24h
        : l10n.limitLast30d;
    final value = limit.unlimited
        ? l10n.limitNone(number.format(limit.used))
        : l10n.limitValue(
            number.format(limit.used),
            number.format(limit.limit),
            number.format(limit.remaining ?? 0),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$what · $window',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(value),
          if (!limit.unlimited && (limit.limit ?? 0) > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(
              value: (limit.used / limit.limit!).clamp(0, 1).toDouble(),
            ),
          ],
          if (limit.reservedForUnknown > 0)
            Text(
              l10n.limitReserved(number.format(limit.reservedForUnknown)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
