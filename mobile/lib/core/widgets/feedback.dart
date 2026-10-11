import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../network/api_exception.dart';
import '../theme/app_theme.dart';

enum StatusTone { info, success, warning, error }

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.tone,
    required this.title,
    required this.message,
    this.action,
  });

  final StatusTone tone;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (Color fg, IconData icon) = switch (tone) {
      StatusTone.info => (scheme.onSurfaceVariant, Icons.info_outline),
      StatusTone.success => (
        isDark ? const Color(0xFF8BD8A6) : const Color(0xFF1E6B3A),
        Icons.check_circle_outline,
      ),
      StatusTone.warning => (
        isDark ? const Color(0xFFF2C46B) : const Color(0xFF7A4F00),
        Icons.warning_amber_outlined,
      ),
      StatusTone.error => (scheme.error, Icons.error_outline),
    };

    return Semantics(
      container: true,
      liveRegion: tone == StatusTone.error || tone == StatusTone.warning,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: BorderDirectional(start: BorderSide(color: fg, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon, color: fg)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: fg),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (action != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      action!,
                    ],
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

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).loadingLabel;
    return Center(
      child: Semantics(
        label: label,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              icon,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StatusBanner(
      tone: StatusTone.error,
      title: l10n.errorTitle,
      message: message,
      action: onRetry == null
          ? null
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(
                onPressed: onRetry,
                child: Text(l10n.retryLabel),
              ),
            ),
    );
  }
}

/// User-facing text for an [ApiException]; never exposes raw server internals.
String describeApiException(AppLocalizations l10n, ApiException error) =>
    switch (error) {
      NetworkUnavailableException() => l10n.errorNetwork,
      RequestTimeoutException() => l10n.errorTimeout,
      RequestCancelledException() => l10n.errorCancelled,
      InsecureConnectionException() => l10n.errorInsecure,
      SessionExpiredException() => l10n.errorSessionExpired,
      InvalidCredentialsException() => l10n.errorInvalidCredentials,
      ForbiddenException() => l10n.errorForbidden,
      NotFoundException() => l10n.errorNotFound,
      ConflictException() => l10n.errorConflict,
      PayloadTooLargeException() => l10n.errorTooLarge,
      ValidationException() => l10n.errorValidation,
      RateLimitedException() => l10n.errorRateLimited,
      QuotaExceededException() => l10n.errorQuota,
      ServerException() => l10n.errorServer,
      BadRequestException() ||
      UnexpectedResponseException() => l10n.errorUnexpected,
    };
