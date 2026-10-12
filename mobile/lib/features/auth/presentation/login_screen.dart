import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/forms.dart';
import '../../../core/widgets/language_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/auth_controller.dart';

String authErrorMessage(AppLocalizations l10n, ApiException error) =>
    switch (error) {
      InvalidCredentialsException() => l10n.errorInvalidCredentials,
      ForbiddenException(message: 'Inactive account') =>
        l10n.errorInactiveAccount,
      _ => describeApiException(l10n, error),
    };

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.notice});

  /// One-off message from another flow (for example a completed password reset).
  final String? notice;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(authControllerProvider.notifier)
        .login(_email.text, _password.text);
    if (!mounted) return;
    if (error != null) _password.clear();
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final reason = auth is AuthSignedOut ? auth.reason : SessionEndReason.none;

    return Stack(
      children: [
        FormPage(
          title: l10n.signInTitle,
          subtitle: l10n.signInSubtitle,
          children: [
            if (widget.notice != null)
              NoticeBanner(tone: StatusTone.success, text: widget.notice!)
            else if (reason == SessionEndReason.expired)
              NoticeBanner(
                tone: StatusTone.warning,
                text: l10n.sessionExpiredMessage,
              )
            else if (reason == SessionEndReason.signedOut)
              NoticeBanner(tone: StatusTone.info, text: l10n.signedOutNotice),
            if (_error != null)
              NoticeBanner(
                tone: StatusTone.error,
                text: authErrorMessage(l10n, _error!),
              ),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EmailField(
                    controller: _email,
                    enabled: !_busy,
                    errorText: serverFieldError(l10n, _error, 'email'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PasswordField(
                    controller: _password,
                    label: l10n.passwordLabel,
                    enabled: !_busy,
                    validator: (v) => (v == null || v.isEmpty)
                        ? l10n.validationRequired
                        : null,
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SubmitButton(
              label: l10n.signInAction,
              busy: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _busy ? null : () => context.push('/forgot-password'),
              child: Text(l10n.forgotPasswordLink),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => context.push('/register'),
              child: Text(l10n.createAccountLink),
            ),
          ],
        ),
        const PositionedDirectional(
          top: 0,
          end: AppSpacing.sm,
          child: SafeArea(child: LanguageButton()),
        ),
      ],
    );
  }
}
