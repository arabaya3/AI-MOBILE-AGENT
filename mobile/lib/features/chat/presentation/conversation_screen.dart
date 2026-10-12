import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/text_direction.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../spaces/application/space_controller.dart';
import '../application/conversation_controller.dart';
import '../data/chat_api.dart';
import 'conversation_sheets.dart';
import 'message_widgets.dart';

/// Picks the model to send: the saved choice for this account if still allowed, else the first allowed.
String? effectiveModel(List<String> allowed, String? saved) =>
    allowed.contains(saved) ? saved : (allowed.isEmpty ? null : allowed.first);

class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(spaceScopeProvider);
    if (scope == null) return const Scaffold(body: LoadingView());
    return _ConversationView(
      key: ValueKey('$scope|$sessionId'),
      args: (scope: scope, sessionId: sessionId),
    );
  }
}

class _ConversationView extends ConsumerStatefulWidget {
  const _ConversationView({super.key, required this.args});

  final ConversationArgs args;

  @override
  ConsumerState<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends ConsumerState<_ConversationView> {
  final _scroll = ScrollController();
  late final TextEditingController _input;
  bool _atBottom = true;

  String get _draftKey =>
      '${widget.args.scope}|${widget.args.sessionId ?? 'new'}';
  String get _modelKey =>
      'chat_model.${ref.read(currentUserProvider)?.id ?? ''}';

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(
      text: ref.read(draftsProvider.notifier).read(_draftKey),
    );
    _scroll.addListener(() {
      final atBottom = !_scroll.hasClients || _scroll.position.extentAfter < 96;
      if (atBottom != _atBottom) setState(() => _atBottom = atBottom);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  /// Follows new content only when the user is already at the bottom.
  void _follow() {
    if (!_atBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _send(String? model) {
    final text = _input.text;
    final language = ref.read(currentUserProvider)?.preferredLanguage;
    final accepted = ref
        .read(conversationProvider(widget.args).notifier)
        .send(text, model: model, language: language);
    if (!accepted) return;
    _input.clear();
    ref.read(draftsProvider.notifier).write(_draftKey, '');
    setState(() => _atBottom = true);
    _follow();
  }

  Future<void> _branch(String messageId) async {
    final l10n = AppLocalizations.of(context);
    try {
      final newId = await ref
          .read(conversationProvider(widget.args).notifier)
          .branch(messageId);
      if (newId != null && mounted) context.pushReplacement('/chat/c/$newId');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeApiException(l10n, e))));
      }
    }
  }

  Future<void> _react(String messageId, Reaction reaction) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(conversationProvider(widget.args).notifier)
          .react(messageId, reaction);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeApiException(l10n, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(conversationProvider(widget.args));
    final controller = ref.read(conversationProvider(widget.args).notifier);
    final models = ref.watch(chatModelsProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final allowed = models.value ?? const <String>[];
    final model = effectiveModel(allowed, prefs.getString(_modelKey));
    ref.listen(
      conversationProvider(
        widget.args,
      ).select((s) => (s.history.length, s.turn?.phase)),
      (_, _) => _follow(),
    );

    final title = state.sessionId == null
        ? l10n.newConversation
        : (ref
                  .watch(chatSessionsProvider)
                  .value
                  ?.where((s) => s.id == state.sessionId)
                  .firstOrNull
                  ?.title ??
              l10n.untitledConversation);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (state.sessionId != null)
            ConversationMenu(sessionId: state.sessionId!, busy: state.busy),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (allowed.length > 1)
              _ModelPicker(
                models: allowed,
                selected: model,
                enabled: !state.busy,
                onChanged: (value) =>
                    setState(() => prefs.setString(_modelKey, value)),
              ),
            Expanded(
              child: Stack(
                children: [
                  _MessageList(
                    state: state,
                    controller: _scroll,
                    onGrow: _follow,
                    onReact: _react,
                    onBranch: _branch,
                    onRetry: () {
                      final prompt = state.turn?.prompt ?? '';
                      controller.dismissTurn();
                      controller.send(
                        prompt,
                        model: model,
                        language: ref
                            .read(currentUserProvider)
                            ?.preferredLanguage,
                      );
                    },
                    onDismiss: controller.dismissTurn,
                    onReload: controller.reload,
                  ),
                  if (!_atBottom)
                    PositionedDirectional(
                      end: AppSpacing.md,
                      bottom: AppSpacing.md,
                      child: FloatingActionButton.small(
                        heroTag: null,
                        tooltip: l10n.jumpToLatest,
                        onPressed: _jumpToLatest,
                        child: const Icon(Icons.arrow_downward),
                      ),
                    ),
                ],
              ),
            ),
            if (models.hasValue && allowed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: NoticeBanner(
                  tone: StatusTone.warning,
                  text: l10n.noModels,
                ),
              ),
            _Composer(
              controller: _input,
              busy: state.busy,
              canSend: model != null,
              onChanged: (text) =>
                  ref.read(draftsProvider.notifier).write(_draftKey, text),
              onSend: () => _send(model),
              onStop: controller.stop,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelPicker extends StatelessWidget {
  const _ModelPicker({
    required this.models,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<String> models;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Text(l10n.modelLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: DropdownButton<String>(
              value: selected,
              isExpanded: true,
              onChanged: enabled
                  ? (v) => v == null ? null : onChanged(v)
                  : null,
              items: [
                for (final m in models)
                  DropdownMenuItem(
                    value: m,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(m),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.controller,
    required this.onGrow,
    required this.onReact,
    required this.onBranch,
    required this.onRetry,
    required this.onDismiss,
    required this.onReload,
  });

  final ConversationState state;
  final ScrollController controller;
  final VoidCallback onGrow;
  final void Function(String, Reaction) onReact;
  final ValueChanged<String> onBranch;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.loading && state.history.isEmpty) return const LoadingView();
    if (state.loadError != null && state.history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ErrorView(
          message: describeApiException(l10n, state.loadError!),
          onRetry: onReload,
        ),
      );
    }
    final turn = state.turn;
    final items = <Widget>[
      for (final m in state.history)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: m.role == ChatRole.user
              ? UserBubble(m.content)
              : AssistantBubble(
                  message: m,
                  sources: state.sourcesByMessage[m.id] ?? const [],
                  reaction: state.reactions[m.id],
                  onReact: (r) => onReact(m.id, r),
                  onBranch: () => onBranch(m.id),
                ),
        ),
      if (turn != null && state.showPendingPrompt)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: UserBubble(turn.prompt),
        ),
      if (turn != null)
        _PendingReply(
          turn: turn,
          onGrow: onGrow,
          onRetry: onRetry,
          onDismiss: onDismiss,
        ),
    ];
    if (items.isEmpty) {
      return Center(
        child: EmptyView(
          title: l10n.chatEmptyTitle,
          message: l10n.chatEmptyBody,
          icon: Icons.chat_bubble_outline,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onReload,
      child: ListView(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: items,
      ),
    );
  }
}

/// Rebuilds only itself as tokens arrive.
class _PendingReply extends StatelessWidget {
  const _PendingReply({
    required this.turn,
    required this.onGrow,
    required this.onRetry,
    required this.onDismiss,
  });

  final PendingTurn turn;
  final VoidCallback onGrow;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: turn.text,
          builder: (context, text, _) {
            onGrow();
            if (text.isEmpty && turn.active) {
              return Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.assistantTyping),
                  ],
                ),
              );
            }
            if (text.isEmpty) return const SizedBox.shrink();
            return Opacity(
              opacity: turn.active ? 1 : 0.7,
              child: MarkdownMessage(text),
            );
          },
        ),
        if (turn.sources.isNotEmpty) SourcesRow(sources: turn.sources),
        if (!turn.active) ...[
          const SizedBox(height: AppSpacing.sm),
          NoticeBanner(
            tone: turn.phase == TurnPhase.stopped
                ? StatusTone.info
                : StatusTone.error,
            text: _turnMessage(l10n, turn),
            action: Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton(onPressed: onRetry, child: Text(l10n.sendAgain)),
                TextButton(
                  onPressed: onDismiss,
                  child: Text(l10n.dismissAction),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _turnMessage(AppLocalizations l10n, PendingTurn turn) =>
      switch (turn.phase) {
        TurnPhase.stopped => l10n.turnStopped,
        TurnPhase.interrupted => l10n.turnInterrupted,
        _ => switch (turn.failure) {
          TurnFailure.quota => l10n.turnQuota,
          TurnFailure.rateLimited => l10n.turnRateLimited,
          TurnFailure.policy => l10n.turnPolicy,
          TurnFailure.provider => l10n.turnProvider,
          TurnFailure.sessionNotFound => l10n.turnSessionNotFound,
          TurnFailure.documentAccess => l10n.turnDocumentAccess,
          TurnFailure.protocol => l10n.turnProtocol,
          TurnFailure.network => '${l10n.errorNetwork} ${l10n.turnUncertain}',
          TurnFailure.sessionExpired => l10n.errorSessionExpired,
          _ => l10n.turnGeneric,
        },
      };
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.canSend,
    required this.onChanged,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool busy;
  final bool canSend;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: l10n.attachmentsUnavailable,
              icon: Icon(
                Icons.attach_file,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              onPressed: () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(l10n.attachmentsUnavailable)),
                ),
            ),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 6,
                  maxLength: 8000,
                  textInputAction: TextInputAction.newline,
                  textDirection: value.text.isEmpty
                      ? null
                      : detectTextDirection(
                          value.text,
                          fallback: Directionality.of(context),
                        ),
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: l10n.composerHint,
                    counterText: '',
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => busy
                  ? IconButton.filledTonal(
                      tooltip: l10n.stopAction,
                      icon: const Icon(Icons.stop),
                      onPressed: onStop,
                    )
                  : IconButton.filled(
                      tooltip: l10n.sendAction,
                      icon: const Icon(Icons.send),
                      onPressed: canSend && value.text.trim().isNotEmpty
                          ? onSend
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
