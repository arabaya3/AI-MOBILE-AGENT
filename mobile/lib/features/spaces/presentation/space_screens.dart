import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/forms.dart';
import '../../../core/widgets/section.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../links/pending_link.dart';
import '../application/space_controller.dart';
import '../data/spaces_api.dart';

class SpacePickerScreen extends ConsumerWidget {
  const SpacePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(spaceControllerProvider);
    final controller = ref.read(spaceControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.spacesTitle),
        actions: [
          IconButton(
            tooltip: l10n.accountTitle,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/account'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(availableSpacesProvider);
            await controller.refresh();
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                l10n.spacesSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              ...switch (state) {
                SpaceIdle() || SpaceLoading() => [const LoadingView()],
                SpaceLoadFailed(:final error) => [
                  ErrorView(
                    message: describeApiException(l10n, error),
                    onRetry: controller.refresh,
                  ),
                ],
                SpaceChoosing(:final spaces, :final notice) => [
                  if (notice == SpaceNotice.accessLost)
                    NoticeBanner(
                      tone: StatusTone.warning,
                      text: l10n.spaceAccessLost,
                    ),
                  _YourSpaces(spaces: spaces, selectedId: null),
                ],
                SpaceSelected(:final spaces, :final space) => [
                  _YourSpaces(spaces: spaces, selectedId: space.id),
                ],
              },
              const SizedBox(height: AppSpacing.md),
              const _AvailableSpaces(),
              const SizedBox(height: AppSpacing.md),
              const _InvitationEntry(),
            ],
          ),
        ),
      ),
    );
  }
}

class _YourSpaces extends ConsumerWidget {
  const _YourSpaces({required this.spaces, required this.selectedId});

  final List<Space> spaces;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (spaces.isEmpty) {
      return Section(
        title: l10n.spacesYours,
        children: [
          EmptyView(
            title: l10n.spacesNoneTitle,
            message: l10n.spacesNoneBody,
            icon: Icons.workspaces_outline,
          ),
        ],
      );
    }
    return Section(
      title: l10n.spacesYours,
      children: [
        for (final space in spaces)
          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: BidiText(space.name),
            selected: space.id == selectedId,
            trailing: space.id == selectedId
                ? const Icon(Icons.check)
                : const Icon(Icons.chevron_right),
            onTap: () async {
              await ref.read(spaceControllerProvider.notifier).select(space.id);
              if (context.mounted &&
                  ref.read(spaceControllerProvider) is SpaceSelected) {
                context.go('/home');
              }
            },
          ),
      ],
    );
  }
}

class _AvailableSpaces extends ConsumerStatefulWidget {
  const _AvailableSpaces();

  @override
  ConsumerState<_AvailableSpaces> createState() => _AvailableSpacesState();
}

class _AvailableSpacesState extends ConsumerState<_AvailableSpaces> {
  String? _requesting;
  ApiException? _error;

  Future<void> _request(String spaceId) async {
    if (_requesting != null) return;
    setState(() {
      _requesting = spaceId;
      _error = null;
    });
    try {
      await ref.read(spacesApiProvider).requestToJoin(spaceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).accessRequested)),
      );
      ref.invalidate(availableSpacesProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _requesting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = ref.watch(availableSpacesProvider);
    return Section(
      title: l10n.spacesAvailable,
      children: [
        if (_error != null)
          NoticeBanner(
            tone: StatusTone.error,
            text: describeApiException(l10n, _error!),
          ),
        ...available.when(
          loading: () => [const LoadingView()],
          error: (e, _) => [
            ErrorView(
              message: e is ApiException
                  ? describeApiException(l10n, e)
                  : l10n.errorUnexpected,
              onRetry: () => ref.invalidate(availableSpacesProvider),
            ),
          ],
          data: (items) => items.isEmpty
              ? [
                  Text(
                    l10n.spacesAvailableEmpty,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ]
              : [
                  for (final item in items)
                    ListTile(
                      title: BidiText(item.space.name),
                      subtitle: item.requestPending
                          ? Text(l10n.accessPending)
                          : null,
                      trailing: item.requestPending
                          ? const Icon(Icons.hourglass_top)
                          : TextButton(
                              onPressed: _requesting == null
                                  ? () => _request(item.space.id)
                                  : null,
                              child: Text(l10n.requestAccess),
                            ),
                    ),
                ],
        ),
      ],
    );
  }
}

class _InvitationEntry extends ConsumerStatefulWidget {
  const _InvitationEntry();

  @override
  ConsumerState<_InvitationEntry> createState() => _InvitationEntryState();
}

class _InvitationEntryState extends ConsumerState<_InvitationEntry> {
  final _pasted = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pasted.dispose();
    super.dispose();
  }

  void _use() {
    final token = tokenFromPastedText(_pasted.text, LinkKind.invite);
    _pasted.clear();
    if (token == null) {
      setState(() => _error = AppLocalizations.of(context).inviteCodeInvalid);
      return;
    }
    setState(() => _error = null);
    ref
        .read(pendingLinkProvider.notifier)
        .hold(PendingLink(LinkKind.invite, token));
    context.go('/invite');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Section(
      title: l10n.haveInvitation,
      children: [
        TextField(
          controller: _pasted,
          autocorrect: false,
          enableSuggestions: false,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l10n.inviteCodeLabel,
            errorText: _error,
          ),
          onSubmitted: (_) => _use(),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: _use, child: Text(l10n.continueAction)),
      ],
    );
  }
}

class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({super.key});

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  String? _token;
  bool _busy = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(
        () => _token = ref
            .read(pendingLinkProvider.notifier)
            .take(LinkKind.invite),
      );
    });
  }

  Future<void> _accept() async {
    final token = _token;
    if (_busy || token == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final spaceId = await ref.read(spacesApiProvider).acceptInvite(token);
      _token = null;
      await ref.read(spaceControllerProvider.notifier).refresh(prefer: spaceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).inviteAccepted)),
      );
      context.go('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      final rejected =
          e is NotFoundException ||
          e is BadRequestException ||
          e is ForbiddenException;
      setState(() {
        _busy = false;
        _error = e;
        if (rejected) _token = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = _error;
    final rejected =
        error is NotFoundException ||
        error is BadRequestException ||
        error is ForbiddenException;
    return FormPage(
      title: l10n.inviteTitle,
      subtitle: l10n.inviteBody,
      children: [
        if (error != null)
          NoticeBanner(
            tone: StatusTone.error,
            text: rejected
                ? l10n.inviteInvalid
                : describeApiException(l10n, error),
          ),
        if (_token != null)
          SubmitButton(
            label: l10n.inviteAction,
            busy: _busy,
            onPressed: _accept,
          ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _busy ? null : () => context.go('/spaces'),
          child: Text(l10n.notNow),
        ),
      ],
    );
  }
}
