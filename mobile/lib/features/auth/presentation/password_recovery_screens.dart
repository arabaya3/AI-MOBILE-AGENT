import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/forms.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../links/pending_link.dart';
import '../application/auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).forgotPassword(_email.text);
      if (mounted) {
        setState(() {
          _busy = false;
          _sent = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FormPage(
      title: l10n.forgotTitle,
      subtitle: l10n.forgotBody,
      showBack: true,
      children: [
        // The same message is shown whether or not the account exists.
        if (_sent)
          NoticeBanner(tone: StatusTone.success, text: l10n.forgotSent),
        if (_error != null)
          NoticeBanner(
            tone: StatusTone.error,
            text: describeApiException(l10n, _error!),
          ),
        Form(
          key: _formKey,
          child: EmailField(
            controller: _email,
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SubmitButton(
          label: l10n.sendResetLink,
          busy: _busy,
          onPressed: _sent ? null : _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => context.go('/reset-password'),
          child: Text(l10n.haveResetLink),
        ),
        TextButton(
          onPressed: () => context.go('/login'),
          child: Text(l10n.backToSignIn),
        ),
      ],
    );
  }
}

enum _TokenStatus { none, checking, valid, invalid }

/// The reset token lives only in this screen's memory: it arrives from a
/// pending link or a pasted link and never enters routes, logs or storage.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pasted = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _token;
  _TokenStatus _status = _TokenStatus.none;
  String? _pasteError;
  bool _busy = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    // Providers may not change during build; consume the link after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final token = ref
          .read(pendingLinkProvider.notifier)
          .take(LinkKind.resetPassword);
      if (token != null) _check(token);
    });
  }

  @override
  void dispose() {
    _token = null;
    for (final c in [_pasted, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _check(String token) async {
    setState(() {
      _token = token;
      _status = _TokenStatus.checking;
      _error = null;
    });
    try {
      final valid = await ref.read(authApiProvider).validateResetToken(token);
      if (!mounted || _token != token) return;
      setState(
        () => _status = valid ? _TokenStatus.valid : _TokenStatus.invalid,
      );
      if (!valid) _token = null;
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _status = _TokenStatus.none;
          _error = e;
        });
      }
    }
  }

  void _usePasted() {
    final l10n = AppLocalizations.of(context);
    final token = tokenFromPastedText(_pasted.text, LinkKind.resetPassword);
    _pasted.clear();
    if (token == null) {
      setState(() => _pasteError = l10n.resetCodeInvalid);
      return;
    }
    setState(() => _pasteError = null);
    _check(token);
  }

  Future<void> _submit() async {
    final token = _token;
    if (_busy ||
        token == null ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).resetPassword(token, _password.text);
      _token = null;
      if (!mounted) return;
      _password.clear();
      _confirm.clear();
      context.go('/login', extra: AppLocalizations.of(context).resetDone);
    } on ApiException catch (e) {
      if (!mounted) return;
      final expired = e is BadRequestException;
      setState(() {
        _busy = false;
        _error = expired ? null : e;
        if (expired) {
          _token = null;
          _status = _TokenStatus.invalid;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FormPage(
      title: l10n.resetTitle,
      showBack: true,
      children: [
        if (_error != null)
          NoticeBanner(
            tone: StatusTone.error,
            text: describeApiException(l10n, _error!),
          ),
        if (_status == _TokenStatus.invalid)
          NoticeBanner(
            tone: StatusTone.warning,
            text: l10n.resetLinkExpired,
            action: OutlinedButton(
              onPressed: () => context.go('/forgot-password'),
              child: Text(l10n.requestNewLink),
            ),
          ),
        if (_status == _TokenStatus.checking) const LoadingView(),
        if (_status == _TokenStatus.none ||
            _status == _TokenStatus.invalid) ...[
          TextField(
            controller: _pasted,
            autocorrect: false,
            enableSuggestions: false,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.resetCodeLabel,
              helperText: l10n.resetCodeHelper,
              errorText: _pasteError,
            ),
            onSubmitted: (_) => _usePasted(),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: _usePasted,
            child: Text(l10n.continueAction),
          ),
        ],
        if (_status == _TokenStatus.valid)
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NoticeBanner(tone: StatusTone.info, text: l10n.resetLinkReady),
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
                const SizedBox(height: AppSpacing.lg),
                SubmitButton(
                  label: l10n.resetAction,
                  busy: _busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => context.go('/login'),
          child: Text(l10n.backToSignIn),
        ),
      ],
    );
  }
}
