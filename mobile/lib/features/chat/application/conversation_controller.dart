import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../spaces/application/space_controller.dart';
import '../data/chat_api.dart';
import '../data/chat_stream_event.dart';

final chatApiProvider = Provider<ChatApi>(
  (ref) => ChatApi(ref.watch(apiClientProvider)),
);

enum TurnPhase { sending, streaming, failed, interrupted, stopped }

enum TurnFailure {
  network,
  quota,
  rateLimited,
  policy,
  provider,
  sessionNotFound,
  documentAccess,
  forbidden,
  sessionExpired,
  protocol,
  other,
}

/// A prompt being answered, or one whose answer failed. Tokens update [text] only,
/// so the message list is not rebuilt for every delta.
class PendingTurn {
  PendingTurn._(
    this.prompt,
    this.text,
    this.phase,
    this.sources,
    this.userMessageId,
    this.failure,
    this.partial,
  );

  factory PendingTurn.start(String prompt) => PendingTurn._(
    prompt,
    ValueNotifier(''),
    TurnPhase.sending,
    const [],
    null,
    null,
    false,
  );

  final String prompt;
  final ValueNotifier<String> text;
  final TurnPhase phase;
  final List<Citation> sources;
  final String? userMessageId;
  final TurnFailure? failure;

  /// Text was shown before the turn failed or stopped; the server did not save it.
  final bool partial;

  bool get active => phase == TurnPhase.sending || phase == TurnPhase.streaming;

  PendingTurn copyWith({
    TurnPhase? phase,
    List<Citation>? sources,
    String? userMessageId,
    TurnFailure? failure,
    bool? partial,
  }) => PendingTurn._(
    prompt,
    text,
    phase ?? this.phase,
    sources ?? this.sources,
    userMessageId ?? this.userMessageId,
    failure ?? this.failure,
    partial ?? this.partial,
  );
}

class ConversationState {
  const ConversationState({
    this.sessionId,
    this.history = const [],
    this.loading = false,
    this.loadError,
    this.turn,
    this.sourcesByMessage = const {},
    this.reactions = const {},
  });

  final String? sessionId;
  final List<ChatMessage> history;
  final bool loading;
  final ApiException? loadError;
  final PendingTurn? turn;

  /// Citations from the stream, kept for this screen only (the backend does not persist them).
  final Map<String, List<Citation>> sourcesByMessage;

  /// Reactions sent from this screen; the backend has no read-back endpoint.
  final Map<String, Reaction> reactions;

  bool get busy => turn?.active ?? false;

  /// The pending prompt is drawn separately until the server confirms it is stored.
  bool get showPendingPrompt {
    final id = turn?.userMessageId;
    return turn != null && (id == null || history.every((m) => m.id != id));
  }

  ConversationState copyWith({
    String? sessionId,
    List<ChatMessage>? history,
    bool? loading,
    ApiException? loadError,
    bool clearLoadError = false,
    PendingTurn? turn,
    bool clearTurn = false,
    Map<String, List<Citation>>? sourcesByMessage,
    Map<String, Reaction>? reactions,
  }) => ConversationState(
    sessionId: sessionId ?? this.sessionId,
    history: history ?? this.history,
    loading: loading ?? this.loading,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
    turn: clearTurn ? null : (turn ?? this.turn),
    sourcesByMessage: sourcesByMessage ?? this.sourcesByMessage,
    reactions: reactions ?? this.reactions,
  );
}

/// Identifies one conversation view: a validated space scope plus an optional existing session.
typedef ConversationArgs = ({String scope, String? sessionId});

const _marker = '\n\n${ChatStreamDelta.providerErrorMarker}';

/// Text safe to show for a raw stream buffer: never the provider-error marker,
/// nor a trailing fragment that could be its beginning.
@visibleForTesting
({String text, bool providerError}) visibleStreamText(String buffer) {
  final full = buffer.indexOf(ChatStreamDelta.providerErrorMarker);
  if (full >= 0) {
    return (text: buffer.substring(0, full).trimRight(), providerError: true);
  }
  for (var k = _marker.length - 1; k > 0; k--) {
    if (buffer.endsWith(_marker.substring(0, k))) {
      return (
        text: buffer.substring(0, buffer.length - k),
        providerError: false,
      );
    }
  }
  return (text: buffer, providerError: false);
}

class ConversationController extends Notifier<ConversationState> {
  ConversationController(this.args);

  final ConversationArgs args;
  int _generation = 0;
  StreamSubscription<ChatStreamEvent>? _subscription;
  CancelToken? _cancelToken;
  final _buffer = StringBuffer();

  ChatApi get _api => ref.read(chatApiProvider);

  bool get _inScope => ref.read(spaceScopeProvider) == args.scope;

  @override
  ConversationState build() {
    ref.listen(spaceScopeProvider, (_, next) {
      if (next != args.scope) _abandon();
    });
    ref.onDispose(_abandon);
    if (args.sessionId == null) return const ConversationState();
    Future.microtask(reload);
    return ConversationState(sessionId: args.sessionId, loading: true);
  }

  Future<void> reload() async {
    final sessionId = state.sessionId;
    if (sessionId == null || !_inScope) return;
    final generation = _generation;
    state = state.copyWith(loading: true, clearLoadError: true);
    try {
      final detail = await _api.getSession(sessionId);
      if (generation != _generation || !ref.mounted) return;
      state = state.copyWith(history: detail.history, loading: false);
    } on ApiException catch (e) {
      if (generation != _generation ||
          !ref.mounted ||
          e is RequestCancelledException) {
        return;
      }
      state = state.copyWith(loading: false, loadError: e);
    }
  }

  /// Returns false when ignored (a reply is already in progress or the space changed).
  bool send(String prompt, {String? model, String? language}) {
    final text = prompt.trim();
    if (text.isEmpty || state.busy || !_inScope) return false;
    final generation = ++_generation;
    _buffer.clear();
    state.turn?.text.dispose();
    final turn = PendingTurn.start(text);
    state = state.copyWith(turn: turn);
    var finished = false;
    final cancelToken = _cancelToken = CancelToken();
    _subscription = _api
        .stream(
          message: text,
          sessionId: state.sessionId,
          model: model,
          language: language,
          cancelToken: cancelToken,
        )
        .listen(
          (event) {
            if (generation != _generation) return;
            // Listeners are notified asynchronously; check the scope synchronously too.
            if (!_inScope) {
              _abandon();
              return;
            }
            switch (event) {
              case ChatStreamMeta(
                :final sessionId,
                :final sources,
                :final userMessageId,
              ):
                state = state.copyWith(
                  sessionId: state.sessionId ?? sessionId,
                  turn: state.turn?.copyWith(
                    phase: TurnPhase.streaming,
                    sources: sources,
                    userMessageId: userMessageId,
                  ),
                );
              case ChatStreamDelta(:final text):
                _buffer.write(text);
                final visible = visibleStreamText(_buffer.toString());
                state.turn?.text.value = visible.text;
                if (visible.providerError) {
                  finished = true;
                  _subscription?.cancel();
                  _fail(generation, TurnFailure.provider);
                }
              case ChatStreamDone():
                finished = true;
                _complete(generation, event);
              case ChatStreamError():
                finished = true;
                _fail(generation, _failureFor(event));
            }
          },
          onError: (Object error) {
            if (generation != _generation || finished) return;
            finished = true;
            _fail(generation, _failureForError(error));
          },
          onDone: () {
            if (generation != _generation || finished) return;
            finished = true;
            _finish(generation, TurnPhase.interrupted, null);
          },
          cancelOnError: true,
        );
    return true;
  }

  /// Stops listening immediately. This does not cancel generation on the server.
  void stop() {
    final turn = state.turn;
    if (turn == null || !turn.active) return;
    final generation = ++_generation;
    _cancelRequest();
    state = state.copyWith(
      turn: turn.copyWith(
        phase: TurnPhase.stopped,
        partial: turn.text.value.isNotEmpty,
      ),
    );
    _reconcile(generation);
  }

  void dismissTurn() {
    if (state.busy) return;
    state.turn?.text.dispose();
    state = state.copyWith(clearTurn: true);
  }

  Future<void> react(String messageId, Reaction reaction) async {
    if (state.history.every((m) => m.id != messageId)) return;
    await _api.react(messageId, reaction);
    if (!ref.mounted) return;
    state = state.copyWith(
      reactions: {...state.reactions, messageId: reaction},
    );
  }

  /// Only for messages the server has confirmed.
  Future<String?> branch(String messageId) async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.history.every((m) => m.id != messageId)) {
      return null;
    }
    return _api.branch(sessionId, messageId);
  }

  void _complete(int generation, ChatStreamDone done) {
    final turn = state.turn;
    final messageId = done.messageId;
    final sources = {...state.sourcesByMessage};
    if (turn != null && messageId != null && turn.sources.isNotEmpty) {
      sources[messageId] = turn.sources;
    }
    final history = [
      ...state.history,
      if (turn != null && done.userMessageId != null)
        ChatMessage(
          id: done.userMessageId!,
          role: ChatRole.user,
          content: turn.prompt,
          createdAt: DateTime.now(),
        ),
      if (turn != null && messageId != null)
        ChatMessage(
          id: messageId,
          role: ChatRole.assistant,
          content: turn.text.value,
          createdAt: DateTime.now(),
        ),
    ];
    final known = done.userMessageId != null && messageId != null;
    state = state.copyWith(
      sessionId: state.sessionId ?? done.sessionId,
      history: history,
      sourcesByMessage: sources,
      clearTurn: known,
    );
    if (known) turn?.text.dispose();
    _reconcile(generation, clearTurnAfter: !known);
  }

  void _fail(int generation, TurnFailure failure) =>
      _finish(generation, TurnPhase.failed, failure);

  void _finish(int generation, TurnPhase phase, TurnFailure? failure) {
    final turn = state.turn;
    if (turn == null) return;
    state = state.copyWith(
      turn: turn.copyWith(
        phase: phase,
        failure: failure,
        partial: turn.text.value.isNotEmpty,
      ),
    );
    _reconcile(generation);
  }

  /// Replaces local guesses with the server's history. Never re-sends the prompt.
  Future<void> _reconcile(int generation, {bool clearTurnAfter = false}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || !_inScope) return;
    try {
      final detail = await _api.getSession(sessionId);
      if (generation != _generation || !ref.mounted) return;
      // A dropped connection or a late stop can still leave a reply the server
      // saved; the history is the truth, so the failure notice goes away.
      final clear = clearTurnAfter || _replySaved(state.turn, detail.history);
      if (clear) state.turn?.text.dispose();
      state = state.copyWith(history: detail.history, clearTurn: clear);
    } on ApiException {
      // Keep the local view; the user can pull to refresh.
    }
    if (ref.mounted) ref.invalidate(chatSessionsProvider);
  }

  static bool _replySaved(PendingTurn? turn, List<ChatMessage> history) {
    if (turn == null || turn.active || turn.userMessageId == null) return false;
    if (turn.phase != TurnPhase.interrupted &&
        turn.phase != TurnPhase.stopped) {
      return false;
    }
    final i = history.indexWhere((m) => m.id == turn.userMessageId);
    return i >= 0 &&
        i + 1 < history.length &&
        history[i + 1].role == ChatRole.assistant &&
        !history[i + 1].isStoredProviderError;
  }

  void _abandon() {
    _generation++;
    _cancelRequest();
  }

  /// Aborts the HTTP request directly instead of relying on stream cancellation.
  void _cancelRequest() {
    final token = _cancelToken;
    if (token != null && !token.isCancelled) {
      // Aborting ends the stream with a cancellation error that our onError
      // receives and ignores (the generation already changed). Cancelling the
      // subscription instead would leave Dio's error without a listener.
      token.cancel();
    } else {
      _subscription?.cancel();
    }
    _cancelToken = null;
    _subscription = null;
  }

  static TurnFailure _failureFor(ChatStreamError error) => switch (error.kind) {
    ChatErrorKind.quota => TurnFailure.quota,
    ChatErrorKind.policy => TurnFailure.policy,
    ChatErrorKind.provider => TurnFailure.provider,
    ChatErrorKind.sessionNotFound => TurnFailure.sessionNotFound,
    ChatErrorKind.documentAccess => TurnFailure.documentAccess,
    ChatErrorKind.forbidden => TurnFailure.forbidden,
    ChatErrorKind.other => TurnFailure.other,
  };

  static TurnFailure _failureForError(Object error) => switch (error) {
    NetworkUnavailableException() ||
    RequestTimeoutException() ||
    InsecureConnectionException() => TurnFailure.network,
    SessionExpiredException() => TurnFailure.sessionExpired,
    QuotaExceededException() => TurnFailure.quota,
    RateLimitedException() => TurnFailure.rateLimited,
    ForbiddenException() || NotFoundException() => TurnFailure.forbidden,
    ChatStreamProtocolException() || FormatException() => TurnFailure.protocol,
    _ => TurnFailure.other,
  };
}

final conversationProvider = NotifierProvider.autoDispose
    .family<ConversationController, ConversationState, ConversationArgs>(
      ConversationController.new,
    );

/// Conversations of the signed-in user in the selected space.
final chatSessionsProvider =
    FutureProvider.autoDispose<List<ChatSessionSummary>>((ref) async {
      if (ref.watch(spaceScopeProvider) == null) return const [];
      return ref.watch(chatApiProvider).listSessions();
    });

/// Models allowed for the user in the selected space (policy is applied server-side).
final chatModelsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  if (ref.watch(spaceScopeProvider) == null) return const [];
  return ref.watch(chatApiProvider).listModels();
});

/// Unsent text per conversation, in memory only, cleared on any account change.
class DraftsController extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    ref.watch(authScopeProvider);
    return const {};
  }

  String read(String key) => state[key] ?? '';

  void write(String key, String text) {
    final next = {...state};
    if (text.isEmpty) {
      next.remove(key);
    } else {
      next[key] = text;
    }
    state = next;
  }
}

final draftsProvider = NotifierProvider<DraftsController, Map<String, String>>(
  DraftsController.new,
);
