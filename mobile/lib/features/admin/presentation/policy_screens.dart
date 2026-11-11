import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/section.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/admin_access.dart';
import '../data/admin_api.dart';
import 'admin_widgets.dart';

/// Space-wide allowed models and tools, chosen from what this deployment supports.
class ModelsToolsScreen extends ConsumerStatefulWidget {
  const ModelsToolsScreen({super.key});

  @override
  ConsumerState<ModelsToolsScreen> createState() => _ModelsToolsScreenState();
}

class _ModelsToolsScreenState extends ConsumerState<ModelsToolsScreen> {
  Set<String>? _models;
  Set<String>? _tools;
  bool _saving = false;

  Future<void> _save(AdminSpace space) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final updated = await runAdminFromWidget(
        ref,
        (api, id) => api.updatePolicy(id, {
          if (_models != null) 'allowed_models': _models!.toList()..sort(),
          if (_tools != null) 'allowed_tools': _tools!.toList()..sort(),
        }),
      );
      if (!mounted || updated == null) return;
      setState(() {
        _models = null;
        _tools = null;
      });
      showAdminMessage(context, l10n.adminSaved);
    } catch (e) {
      if (mounted) showAdminMessage(context, describeAdminError(l10n, e));
    } finally {
      ref.invalidate(adminSpaceProvider);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final space = ref.watch(adminSpaceProvider);
    final catalog = ref.watch(adminCatalogProvider);
    final dirty = _models != null || _tools != null;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmAdminAction(
          context,
          title: l10n.discardChangesTitle,
          body: l10n.discardChangesBody,
          confirmLabel: l10n.discardAction,
        );
        if (leave && context.mounted) {
          setState(() {
            _models = null;
            _tools = null;
          });
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.adminModelsToolsTitle)),
        bottomNavigationBar: dirty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FilledButton(
                    key: const ValueKey('save-policy'),
                    onPressed: _saving || space.value == null
                        ? null
                        : () => _save(space.value!),
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.saveChangesAction),
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: AdminAsyncBody<AdminSpace?>(
            value: space,
            onRefresh: () async {
              ref.invalidate(adminCatalogProvider);
              ref.invalidate(adminSpaceProvider);
              await ref.read(adminSpaceProvider.future);
            },
            builder: (data) {
              final cat = catalog.value;
              if (data == null) return const [];
              if (catalog.hasError) {
                return [
                  ErrorView(
                    message: describeAdminError(l10n, catalog.error!),
                    onRetry: () => ref.invalidate(adminCatalogProvider),
                  ),
                ];
              }
              if (cat == null) return const [LoadingView()];
              final models = _models ?? {...?data.policy.allowedModels};
              final tools = _tools ?? {...?data.policy.allowedTools};
              return [
                _Choices(
                  title: l10n.allowedModelsTitle,
                  explain: l10n.allowedModelsExplain,
                  // Stored ids the catalog no longer lists stay visible so they can be removed.
                  options: {...cat.models, ...models}.toList()..sort(),
                  unsupported: models.difference(cat.models.toSet()),
                  selected: models,
                  keyPrefix: 'model',
                  onChanged: (next) => setState(() => _models = next),
                ),
                const SizedBox(height: AppSpacing.md),
                _Choices(
                  title: l10n.allowedToolsTitle,
                  explain: l10n.allowedToolsExplain,
                  options: {...cat.tools, ...tools}.toList()..sort(),
                  unsupported: tools.difference(cat.tools.toSet()),
                  selected: tools,
                  keyPrefix: 'tool',
                  onChanged: (next) => setState(() => _tools = next),
                ),
              ];
            },
          ),
        ),
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.title,
    required this.explain,
    required this.options,
    required this.unsupported,
    required this.selected,
    required this.keyPrefix,
    required this.onChanged,
  });

  final String title;
  final String explain;
  final List<String> options;
  final Set<String> unsupported;
  final Set<String> selected;
  final String keyPrefix;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Section(
      title: title,
      subtitle: explain,
      children: [
        if (options.isEmpty) Text(l10n.catalogEmpty),
        for (final option in options)
          CheckboxListTile(
            key: ValueKey('$keyPrefix-$option'),
            contentPadding: EdgeInsets.zero,
            value: selected.contains(option),
            title: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(option),
              ),
            ),
            subtitle: unsupported.contains(option)
                ? Text(l10n.catalogNoLongerSupported)
                : null,
            onChanged: (checked) => onChanged(
              checked == true
                  ? {...selected, option}
                  : ({...selected}..remove(option)),
            ),
          ),
      ],
    );
  }
}

/// Space default limits. Each row saves on its own, so there is no long form to lose.
class LimitsScreen extends ConsumerStatefulWidget {
  const LimitsScreen({super.key});

  @override
  ConsumerState<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends ConsumerState<LimitsScreen> {
  String? _busy;

  Future<void> _edit(AdminSpace space, String key) async {
    if (_busy != null) return;
    final l10n = AppLocalizations.of(context);
    final choice = await showLimitDialog(
      context,
      label: limitLabel(l10n, key),
      current: space.policy.limit(key),
      forMember: false,
    );
    if (choice == null || !mounted) return;
    if (choice.value == 0 &&
        !await confirmAdminAction(
          context,
          title: l10n.blockLimitTitle,
          body: l10n.blockLimitBody,
          confirmLabel: l10n.blockLimitAction,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = key);
    try {
      final updated = await runAdminFromWidget(
        ref,
        (api, id) =>
            api.updatePolicy(id, {key: choice.clear ? null : choice.value}),
      );
      if (mounted && updated != null) {
        showAdminMessage(context, l10n.adminSaved);
      }
    } catch (e) {
      if (mounted) showAdminMessage(context, describeAdminError(l10n, e));
    } finally {
      ref.invalidate(adminSpaceProvider);
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final space = ref.watch(adminSpaceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminLimitsTitle)),
      body: SafeArea(
        child: AdminAsyncBody<AdminSpace?>(
          value: space,
          onRefresh: () => ref.refresh(adminSpaceProvider.future),
          builder: (data) => [
            if (data != null)
              Section(
                title: l10n.spaceDefaultsTitle,
                subtitle: l10n.spaceDefaultsExplain,
                children: [
                  for (final key in limitKeys)
                    ListTile(
                      key: ValueKey('space-limit-$key'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(limitLabel(l10n, key)),
                      subtitle: Text(
                        describeLimit(context, value: data.policy.limit(key)),
                      ),
                      trailing: _busy == key
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_outlined),
                      onTap: _busy == null ? () => _edit(data, key) : null,
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.memberOverridesHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
