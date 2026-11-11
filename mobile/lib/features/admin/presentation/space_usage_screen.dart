import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../usage/presentation/usage_screen.dart' show formatUsd;
import '../application/admin_access.dart';
import '../data/admin_api.dart';
import 'admin_widgets.dart';

/// Space-wide usage from recorded usage events. Costs are estimates from list prices.
class SpaceUsageScreen extends ConsumerStatefulWidget {
  const SpaceUsageScreen({super.key});

  @override
  ConsumerState<SpaceUsageScreen> createState() => _SpaceUsageScreenState();
}

class _SpaceUsageScreenState extends ConsumerState<SpaceUsageScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usage = ref.watch(adminUsageProvider(_days));
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminUsageTitle)),
      body: SafeArea(
        child: AdminAsyncBody<SpaceUsage>(
          value: usage,
          onRefresh: () => ref.refresh(adminUsageProvider(_days).future),
          builder: (data) {
            final date = DateFormat.yMMMd(locale);
            String cost(double? v) =>
                v == null ? l10n.usageCostUnavailable : formatUsd(locale, v);
            return [
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final days in const [1, 7, 30, 90])
                    ChoiceChip(
                      key: ValueKey('space-usage-$days'),
                      label: Text(
                        days == 1 ? l10n.periodDay : l10n.periodDays(days),
                      ),
                      selected: _days == days,
                      onSelected: (_) => setState(() => _days = days),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.usageWindow(
                  date.format(data.start.toLocal()),
                  date.format(data.end.toLocal()),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Section(
                title: l10n.spaceTotalsTitle,
                subtitle: l10n.spaceUsageExplain,
                children: [
                  _Row(
                    l10n.usageRequests,
                    formatCount(context, data.totals.requests),
                  ),
                  _Row(
                    l10n.usageTotalTokens,
                    formatCount(context, data.totals.totalTokens),
                  ),
                  _Row(l10n.usageCostTitle, cost(data.totals.costUsd)),
                  if (data.totals.requestsWithoutCost > 0)
                    Text(
                      l10n.usageCostIncomplete(data.totals.requestsWithoutCost),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Section(
                title: l10n.usageByModel,
                children: [
                  if (data.byModel.isEmpty) Text(l10n.usageNoRequests),
                  for (final entry in data.byModel.entries)
                    _Row(
                      entry.key,
                      '${formatCount(context, entry.value.totalTokens)} · ${cost(entry.value.costUsd)}',
                      ltrLabel: true,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton(
                    onPressed: () => context.push('/admin/limits'),
                    child: Text(l10n.adminLimitsTitle),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push('/admin/members'),
                    child: Text(l10n.adminMembersTitle),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push('/usage'),
                    child: Text(l10n.myUsageAction),
                  ),
                ],
              ),
            ];
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.ltrLabel = false});

  final String label;
  final String value;
  final bool ltrLabel;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: Theme.of(context).textTheme.bodyMedium);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ltrLabel
                ? Directionality(
                    textDirection: TextDirection.ltr,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: text,
                    ),
                  )
                : text,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
