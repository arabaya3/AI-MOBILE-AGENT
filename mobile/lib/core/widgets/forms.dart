import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../network/api_exception.dart';
import '../theme/app_theme.dart';

/// Centered, scrollable, keyboard-aware column for single-purpose screens.
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: theme.textTheme.headlineSmall),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.autofillHints = const [AutofillHints.password],
    this.validator,
    this.errorText,
    this.helperText,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final Iterable<String> autofillHints;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final String? helperText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscured,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          tooltip: _obscured ? l10n.showPassword : l10n.hidePassword,
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}

class EmailField extends StatelessWidget {
  const EmailField({
    super.key,
    required this.controller,
    this.errorText,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email, AutofillHints.username],
      autocorrect: false,
      textInputAction: TextInputAction.next,
      textDirection: TextDirection.ltr,
      onFieldSubmitted: onSubmitted,
      validator: (value) => validateEmail(l10n, value),
      decoration: InputDecoration(
        labelText: l10n.emailLabel,
        errorText: errorText,
      ),
    );
  }
}

/// Primary action that shows progress and ignores taps while [busy].
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? Semantics(
              label: AppLocalizations.of(context).loadingLabel,
              child: const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Text(label),
    );
  }
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(AppLocalizations l10n, String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return l10n.validationRequired;
  return _emailPattern.hasMatch(v) ? null : l10n.validationEmail;
}

String? validateNewPassword(AppLocalizations l10n, String? value) {
  if (value == null || value.isEmpty) return l10n.validationRequired;
  return value.length < 8 ? l10n.validationPasswordLength : null;
}

/// Localized message for a field the backend rejected (FastAPI messages are English-only).
String? serverFieldError(
  AppLocalizations l10n,
  ApiException? error,
  String field,
) {
  if (error is! ValidationException) return null;
  final issue = error.issues.where((i) => i.field == field).firstOrNull;
  if (issue == null) return null;
  return switch (field) {
    'email' => l10n.validationEmail,
    'password' || 'new_password' when issue.type == 'string_too_short' =>
      l10n.validationPasswordLength,
    _ => l10n.errorValidation,
  };
}
