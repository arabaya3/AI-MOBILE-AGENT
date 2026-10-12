import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/forms.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/auth_controller.dart';
import '../data/auth_models.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _company = TextEditingController();
  final _jobTitle = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [
      _email,
      _password,
      _confirm,
      _firstName,
      _lastName,
      _company,
      _jobTitle,
    ]) {
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
    final data = SignUpData(
      email: _email.text.trim(),
      password: _password.text,
      firstName: _firstName.text,
      lastName: _lastName.text,
      company: _company.text,
      jobTitle: _jobTitle.text,
      preferredLanguage: Localizations.localeOf(context).languageCode,
    );
    try {
      await ref.read(authApiProvider).signUp(data);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e;
        });
      }
      return;
    }
    // The account exists now; sign in once with the same credentials (no retry).
    final loginError = await ref
        .read(authControllerProvider.notifier)
        .login(data.email, data.password);
    if (!mounted) return;
    _password.clear();
    _confirm.clear();
    if (loginError != null) {
      context.go(
        '/login',
        extra: AppLocalizations.of(context).registeredSignInFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = _error;
    return FormPage(
      title: l10n.registerTitle,
      showBack: true,
      children: [
        if (error != null)
          NoticeBanner(
            tone: StatusTone.error,
            text: error is ConflictException
                ? l10n.errorEmailTaken
                : authErrorMessage(l10n, error),
          ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EmailField(
                controller: _email,
                enabled: !_busy,
                errorText: serverFieldError(l10n, error, 'email'),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _password,
                label: l10n.passwordLabel,
                helperText: l10n.passwordHelper,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: (v) => validateNewPassword(l10n, v),
                errorText: serverFieldError(l10n, error, 'password'),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _confirm,
                label: l10n.confirmPasswordLabel,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == _password.text ? null : l10n.validationPasswordMatch,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.optionalDetails,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _OptionalField(
                controller: _firstName,
                label: l10n.firstNameLabel,
                hints: const [AutofillHints.givenName],
                enabled: !_busy,
              ),
              _OptionalField(
                controller: _lastName,
                label: l10n.lastNameLabel,
                hints: const [AutofillHints.familyName],
                enabled: !_busy,
              ),
              _OptionalField(
                controller: _company,
                label: l10n.companyLabel,
                hints: const [AutofillHints.organizationName],
                enabled: !_busy,
              ),
              _OptionalField(
                controller: _jobTitle,
                label: l10n.jobTitleLabel,
                hints: const [AutofillHints.jobTitle],
                enabled: !_busy,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SubmitButton(
          label: l10n.registerAction,
          busy: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _busy ? null : () => context.go('/login'),
          child: Text(l10n.haveAccountLink),
        ),
      ],
    );
  }
}

class _OptionalField extends StatelessWidget {
  const _OptionalField({
    required this.controller,
    required this.label,
    required this.hints,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final List<String> hints;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      autofillHints: hints,
      maxLength: 100,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
}
