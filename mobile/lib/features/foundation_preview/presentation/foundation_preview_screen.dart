import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/appearance_settings.dart';
import '../../../core/widgets/section.dart';
import '../../../l10n/gen/app_localizations.dart';

class FoundationPreviewScreen extends ConsumerWidget {
  const FoundationPreviewScreen({super.key});

  static const lastSectionKey = ValueKey('upcoming-space-admin');

  static const mixedSamples = [
    'مرحبًا، كيف يمكنني مساعدتك اليوم؟',
    'Summarize the key risks in the Q3 report.',
    'يرجى مراجعة ملف contract_v2.pdf قبل اجتماع يوم الأحد.',
    'The client asked: "هل العقد ساري المفعول؟"',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final showDeveloper = config.isDev && !kReleaseMode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.previewTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.previewIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppearanceSettings(),
            const SizedBox(height: AppSpacing.md),
            const _ComponentsSection(),
            const SizedBox(height: AppSpacing.md),
            Section(
              title: l10n.sectionStates,
              children: [
                const SizedBox(height: 72, child: LoadingView()),
                EmptyView(title: l10n.emptyTitle, message: l10n.emptyBody),
                ErrorView(
                  message: l10n.errorNetwork,
                  onRetry: () => _showSampleNotice(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Section(
              title: l10n.sectionMixedText,
              subtitle: l10n.mixedTextNote,
              children: [
                for (final sample in mixedSamples)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: BidiText(sample),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Section(
              title: l10n.sectionUpcoming,
              children: [
                UnavailableDestination(
                  icon: Icons.chat_bubble_outline,
                  label: l10n.upcomingChat,
                  statusLabel: l10n.notAvailableYet,
                ),
                UnavailableDestination(
                  icon: Icons.description_outlined,
                  label: l10n.upcomingDocuments,
                  statusLabel: l10n.notAvailableYet,
                ),
                UnavailableDestination(
                  icon: Icons.notifications_none,
                  label: l10n.upcomingNotifications,
                  statusLabel: l10n.notAvailableYet,
                ),
                UnavailableDestination(
                  key: lastSectionKey,
                  icon: Icons.admin_panel_settings_outlined,
                  label: l10n.upcomingSpaceAdmin,
                  statusLabel: l10n.notAvailableYet,
                ),
              ],
            ),
            if (showDeveloper) ...[
              const SizedBox(height: AppSpacing.md),
              Section(
                title: l10n.sectionDeveloper,
                children: [
                  _KeyValue(
                    label: l10n.developerEnvironment,
                    value: config.environment.name,
                  ),
                  _KeyValue(
                    label: l10n.developerApiBase,
                    value: config.apiBaseUrl.toString(),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

void _showSampleNotice(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).componentsNote)),
    );
}

class _ComponentsSection extends StatelessWidget {
  const _ComponentsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void sample() => _showSampleNotice(context);

    return Section(
      title: l10n.sectionComponents,
      subtitle: l10n.componentsNote,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton(
              onPressed: sample,
              child: Text(l10n.sampleFilledButton),
            ),
            OutlinedButton(
              onPressed: sample,
              child: Text(l10n.sampleOutlinedButton),
            ),
            TextButton(onPressed: sample, child: Text(l10n.sampleTextButton)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const _DirectionAwareField(),
        const SizedBox(height: AppSpacing.md),
        StatusBanner(
          tone: StatusTone.info,
          title: l10n.bannerInfoTitle,
          message: l10n.bannerInfoBody,
        ),
        const SizedBox(height: AppSpacing.sm),
        StatusBanner(
          tone: StatusTone.success,
          title: l10n.bannerSuccessTitle,
          message: l10n.bannerSuccessBody,
        ),
        const SizedBox(height: AppSpacing.sm),
        StatusBanner(
          tone: StatusTone.warning,
          title: l10n.bannerWarningTitle,
          message: l10n.bannerWarningBody,
        ),
        const SizedBox(height: AppSpacing.sm),
        StatusBanner(
          tone: StatusTone.error,
          title: l10n.bannerErrorTitle,
          message: l10n.bannerErrorBody,
        ),
      ],
    );
  }
}

class _DirectionAwareField extends StatefulWidget {
  const _DirectionAwareField();

  @override
  State<_DirectionAwareField> createState() => _DirectionAwareFieldState();
}

class _DirectionAwareFieldState extends State<_DirectionAwareField> {
  final _controller = TextEditingController();
  TextDirection? _direction;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: _controller,
      textDirection: _direction,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.newline,
      onChanged: (text) {
        final next = text.isEmpty
            ? null
            : detectTextDirection(text, fallback: Directionality.of(context));
        if (next != _direction) setState(() => _direction = next);
      },
      decoration: InputDecoration(
        labelText: l10n.sampleFieldLabel,
        hintText: l10n.sampleFieldHint,
        helperText: l10n.sampleFieldHelper,
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }
}
