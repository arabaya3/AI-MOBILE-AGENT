import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/appearance_settings.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/forms.dart';
import '../../../core/widgets/section.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/auth_controller.dart';
import '../data/auth_models.dart';

String roleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
  UserRole.viewer => l10n.roleViewer,
  UserRole.admin => l10n.roleAdmin,
  UserRole.superAdmin => l10n.roleSuperAdmin,
};

Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.signOutConfirmTitle),
      content: Text(l10n.signOutConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.signOutAction),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(authControllerProvider.notifier).signOut();
  }
}

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final persistenceFailed = ref.watch(
      sessionSnapshotProvider.select((s) => s.persistenceFailed),
    );
    final showDeveloper = ref.watch(appConfigProvider).isDev && !kReleaseMode;
    if (user == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (persistenceFailed)
              NoticeBanner(
                tone: StatusTone.warning,
                text: l10n.persistenceFailedNotice,
              ),
            Section(
              title: l10n.accountDetails,
              children: [
                if (user.displayName != null)
                  _Detail(label: l10n.nameLabel, value: user.displayName!),
                _Detail(label: l10n.emailLabel, value: user.email, ltr: true),
                _Detail(
                  label: l10n.roleLabel,
                  value: roleLabel(l10n, user.role),
                ),
                if (user.company != null)
                  _Detail(label: l10n.companyLabel, value: user.company!),
                if (user.jobTitle != null)
                  _Detail(label: l10n.jobTitleLabel, value: user.jobTitle!),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const AppearanceSettings(),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => context.push('/account/password'),
              icon: const Icon(Icons.password),
              label: Text(l10n.changePasswordAction),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonalIcon(
              onPressed: () => confirmSignOut(context, ref),
              icon: const Icon(Icons.logout),
              label: Text(l10n.signOutAction),
            ),
            if (showDeveloper) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.push('/dev/preview'),
                child: Text(l10n.designPreview),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value, this.ltr = false});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(value, style: theme.textTheme.bodyLarge);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            ltr
                ? Directionality(textDirection: TextDirection.ltr, child: text)
                : text,
          ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_current, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authApiProvider)
          .changePassword(_current.text, _password.text);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      _current.clear();
      setState(() {
        _busy = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = _error;
    final wrongCurrent =
        error is BadRequestException || error is InvalidCredentialsException;
    return FormPage(
      title: l10n.changePasswordTitle,
      showBack: true,
      children: [
        if (error != null && !wrongCurrent)
          NoticeBanner(
            tone: StatusTone.error,
            text: describeApiException(l10n, error),
          ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                controller: _current,
                label: l10n.currentPasswordLabel,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                errorText: wrongCurrent ? l10n.errorCurrentPassword : null,
                validator: (v) => validateNewPassword(l10n, v),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _password,
                label: l10n.newPasswordLabel,
                helperText: l10n.passwordHelper,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: (v) => validateNewPassword(l10n, v),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _confirm,
                label: l10n.confirmPasswordLabel,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) =>
                    v == _password.text ? null : l10n.validationPasswordMatch,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SubmitButton(
          label: l10n.changePasswordAction,
          busy: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class SessionProblemScreen extends ConsumerStatefulWidget {
  const SessionProblemScreen({super.key});

  @override
  ConsumerState<SessionProblemScreen> createState() =>
      _SessionProblemScreenState();
}

class _SessionProblemScreenState extends ConsumerState<SessionProblemScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final message = switch (auth) {
      AuthUnverified(storageUnavailable: true) => l10n.sessionProblemStorage,
      AuthUnverified(
        error: NetworkUnavailableException() || RequestTimeoutException(),
      ) =>
        l10n.sessionProblemOffline,
      _ => l10n.sessionProblemServer,
    };
    return FormPage(
      title: l10n.sessionProblemTitle,
      children: [
        NoticeBanner(tone: StatusTone.warning, text: message),
        SubmitButton(
          label: l10n.retryLabel,
          busy: _busy,
          onPressed: () => _run(controller.retry),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: _busy ? null : () => _run(controller.signOut),
          child: Text(l10n.signOutAction),
        ),
      ],
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SafeArea(child: LoadingView()));
}
