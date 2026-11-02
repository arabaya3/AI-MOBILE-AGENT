import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/util/server_time.dart';

int _int(Object? value) => (value as num?)?.toInt() ?? 0;
double? _double(Object? value) => (value as num?)?.toDouble();

class UsageLimit {
  const UsageLimit({
    required this.key,
    required this.unit,
    required this.windowHours,
    required this.used,
    this.limit,
    this.remaining,
    this.reservedForUnknown = 0,
  });

  factory UsageLimit.fromJson(Map<String, dynamic> json) => UsageLimit(
    key: '${json['key']}',
    unit: '${json['unit']}',
    windowHours: _int(json['window_hours']),
    used: _int(json['used']),
    limit: (json['limit'] as num?)?.toInt(),
    remaining: (json['remaining'] as num?)?.toInt(),
    reservedForUnknown: _int(json['reserved_for_unknown']),
  );

  final String key;
  final String unit;
  final int windowHours;
  final int used;

  /// Null means no limit applies.
  final int? limit;
  final int? remaining;

  /// Part of [used] that is a fixed charge for replies whose usage was never reported.
  final int reservedForUnknown;

  bool get unlimited => limit == null;
}

class UsageModelRow {
  const UsageModelRow({
    required this.model,
    required this.requests,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    required this.costComplete,
    this.costUsd,
  });

  factory UsageModelRow.fromJson(Map<String, dynamic> json) => UsageModelRow(
    model: '${json['model']}',
    requests: _int(json['requests']),
    inputTokens: _int(json['input_tokens']),
    outputTokens: _int(json['output_tokens']),
    totalTokens: _int(json['total_tokens']),
    costComplete: json['cost_complete'] == true,
    costUsd: _double(json['cost_usd']),
  );

  final String model;
  final int requests;
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final bool costComplete;
  final double? costUsd;
}

class UsageToolRow {
  const UsageToolRow({
    required this.tool,
    required this.requests,
    this.costUsd,
  });

  factory UsageToolRow.fromJson(Map<String, dynamic> json) => UsageToolRow(
    tool: '${json['tool']}',
    requests: _int(json['requests']),
    costUsd: _double(json['cost_usd']),
  );

  final String tool;
  final int requests;
  final double? costUsd;
}

class UsageOverview {
  const UsageOverview({
    required this.start,
    required this.end,
    required this.days,
    required this.totalRequests,
    required this.reportedRequests,
    required this.unknownRequests,
    required this.unknownBreakdown,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    required this.costBasis,
    required this.currency,
    required this.costComplete,
    required this.requestsWithoutCost,
    required this.byModel,
    required this.tools,
    required this.limits,
    this.costAmount,
  });

  factory UsageOverview.fromJson(Map<String, dynamic> json) {
    final window = Map<String, dynamic>.from(json['window'] as Map);
    final requests = Map<String, dynamic>.from(json['requests'] as Map);
    final tokens = Map<String, dynamic>.from(json['tokens'] as Map);
    final cost = Map<String, dynamic>.from(json['cost'] as Map);
    return UsageOverview(
      start: parseServerTime(window['start'])!,
      end: parseServerTime(window['end'])!,
      days: _int(window['days']),
      totalRequests: _int(requests['total']),
      reportedRequests: _int(requests['with_reported_usage']),
      unknownRequests: _int(requests['with_unknown_usage']),
      unknownBreakdown: {
        for (final e in Map<String, dynamic>.from(
          requests['unknown_breakdown'] as Map? ?? const {},
        ).entries)
          e.key: _int(e.value),
      },
      inputTokens: _int(tokens['input']),
      outputTokens: _int(tokens['output']),
      totalTokens: _int(tokens['total']),
      costBasis: '${cost['basis']}',
      currency: '${cost['currency'] ?? 'USD'}',
      costAmount: _double(cost['amount']),
      costComplete: cost['complete'] == true,
      requestsWithoutCost: _int(cost['requests_without_cost']),
      byModel: [
        for (final r in json['by_model'] as List? ?? const [])
          UsageModelRow.fromJson(Map<String, dynamic>.from(r as Map)),
      ],
      tools: [
        for (final r in json['tools'] as List? ?? const [])
          UsageToolRow.fromJson(Map<String, dynamic>.from(r as Map)),
      ],
      limits: [
        for (final r in json['limits'] as List? ?? const [])
          UsageLimit.fromJson(Map<String, dynamic>.from(r as Map)),
      ],
    );
  }

  /// Window boundaries in UTC (the server uses rolling windows ending now).
  final DateTime start;
  final DateTime end;
  final int days;
  final int totalRequests;
  final int reportedRequests;
  final int unknownRequests;
  final Map<String, int> unknownBreakdown;
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;

  /// "estimated": derived from list prices, not a provider invoice.
  final String costBasis;
  final String currency;

  /// Null when no request in the window has a known cost; never a stand-in for zero.
  final double? costAmount;
  final bool costComplete;
  final int requestsWithoutCost;
  final List<UsageModelRow> byModel;
  final List<UsageToolRow> tools;
  final List<UsageLimit> limits;
}

class UsageApi {
  UsageApi(this._client);

  final ApiClient _client;

  Future<UsageOverview> overview(int days) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/chat/usage/overview',
      queryParameters: {'days': days},
    );
    return UsageOverview.fromJson(response.data!);
  }
}

final usageApiProvider = Provider<UsageApi>(
  (ref) => UsageApi(ref.watch(apiClientProvider)),
);
