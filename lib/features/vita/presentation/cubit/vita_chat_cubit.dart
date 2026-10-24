import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';

class VitaChatState extends Equatable {
  final List<VitaMessage> messages;
  final bool isLoading;
  final bool isTyping;

  /// Last error to surface (offline, daily limit…); cleared on next send.
  final String? error;

  /// [error] is today's chat limit (free users can get more with Pro).
  final bool limitReached;

  const VitaChatState({
    this.messages = const [],
    this.isLoading = true,
    this.isTyping = false,
    this.error,
    this.limitReached = false,
  });

  VitaChatState copyWith({
    List<VitaMessage>? messages,
    bool? isLoading,
    bool? isTyping,
    String? Function()? error,
    bool? limitReached,
  }) => VitaChatState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    isTyping: isTyping ?? this.isTyping,
    error: error == null ? this.error : error(),
    limitReached: limitReached ?? this.limitReached,
  );

  @override
  List<Object?> get props => [
    messages,
    isLoading,
    isTyping,
    error,
    limitReached,
  ];
}

/// How a reply ended: the chat to show, and the error when it failed.
class _ReplyOutcome {
  final List<VitaMessage> messages;
  final String? error;
  final bool limitReached;

  const _ReplyOutcome(this.messages, {this.error, this.limitReached = false});
}

/// A reply being fetched for [owner]'s chat.
class _PendingReply {
  final String owner;
  final Future<_ReplyOutcome> outcome;

  const _PendingReply(this.owner, this.outcome);
}

/// Vita conversation; history is stored on device so it's readable offline.
///
/// A reply outlives the page that asked for it: leaving the chat neither
/// cancels nor loses it (it's saved when it lands), and a chat opened in
/// the meantime shows the typing dots until it does.
class VitaChatCubit extends Cubit<VitaChatState> {
  final VitaRepository _repository;

  /// Unsaved plan being tweaked; Vita sees it instead of the active plan.
  MealPlan? _draftPlan;

  /// Shared by every chat page (they're created per visit).
  static _PendingReply? _pending;

  VitaChatCubit(this._repository) : super(const VitaChatState());

  /// The reply still coming for the signed-in user's chat, if any.
  _PendingReply? get _pendingForOwner {
    final pending = _pending;
    return pending != null && pending.owner == _repository.chatOwnerId
        ? pending
        : null;
  }

  /// Loads saved history, waits for a reply asked from an earlier visit,
  /// then optionally sends [initialPrompt].
  Future<void> load({String? initialPrompt, MealPlan? draftPlan}) async {
    _draftPlan = draftPlan;
    final history = await _loadHistory();
    if (isClosed) return;
    final pending = _pendingForOwner;
    emit(
      state.copyWith(
        messages: history,
        isLoading: false,
        isTyping: pending != null,
      ),
    );
    if (pending != null) {
      final outcome = await pending.outcome;
      if (isClosed) return;
      // Its error was for the visit that asked; the bubble offers a retry.
      emit(state.copyWith(messages: outcome.messages, isTyping: false));
    }
    if (initialPrompt != null) await send(initialPrompt);
  }

  Future<List<VitaMessage>> _loadHistory() async {
    try {
      return await _repository.loadHistory();
    } catch (e) {
      debugPrint('Vita chat history unreadable: $e');
      return const [];
    }
  }

  /// Where the chat was left: pixels up from the latest message, or null.
  double? get savedScroll {
    try {
      return _repository.readChatScroll();
    } catch (e) {
      debugPrint('Vita chat scroll unreadable: $e');
      return null;
    }
  }

  /// Kept even after this cubit is closed (the page saves it on leaving).
  void saveScroll(double? offsetFromEnd) {
    _repository.saveChatScroll(offsetFromEnd).catchError((Object e) {
      debugPrint('Vita chat scroll not saved: $e');
    });
  }

  /// Cleans a typed message: no invisible characters, at most
  /// [InputLimits.chatMessage] characters. Empty when nothing is left.
  static String cleanMessage(String text) =>
      sanitizeText(text, maxLength: InputLimits.chatMessage, multiline: true);

  Future<void> send(String text) async {
    final trimmed = cleanMessage(text);
    if (trimmed.isEmpty || state.isTyping || state.isLoading) return;
    await _ask([
      ...state.messages,
      VitaMessage(
        sender: VitaSender.user,
        text: trimmed,
        sentAt: DateTime.now(),
      ),
    ]);
  }

  /// Starts over: the saved chat is removed and Vita greets again.
  Future<void> clear() async {
    if (state.isTyping || state.isLoading) return;
    await _save(const []);
    saveScroll(null);
    final history = await _loadHistory();
    if (isClosed) return;
    emit(state.copyWith(messages: history, error: () => null));
  }

  /// Removes one message from the chat (long press). Not while a reply is
  /// coming: it's saved with the messages it was asked with.
  Future<void> delete(VitaMessage message) async {
    if (state.isTyping || state.isLoading) return;
    final rest = state.messages.where((m) => m != message).toList();
    if (rest.length == state.messages.length) return;
    await _save(rest);
    // An empty chat starts over with Vita's greeting.
    final shown = rest.isEmpty ? await _loadHistory() : rest;
    if (isClosed) return;
    emit(state.copyWith(messages: shown, error: () => null));
  }

  /// Re-sends a user message Vita couldn't answer.
  Future<void> retry(VitaMessage message) async {
    if (state.isTyping || state.isLoading || !message.failed) return;
    final rest = state.messages.where((m) => m != message).toList();
    await _ask([...rest, message.copyWith(failed: false)]);
  }

  /// Longest a reply may take before the message is marked failed.
  static const replyTimeout = Duration(seconds: 75);

  Future<void> _ask(List<VitaMessage> history) async {
    emit(
      state.copyWith(
        messages: history,
        isTyping: true,
        error: () => null,
        limitReached: false,
      ),
    );
    await _save(history);

    final owner = _repository.chatOwnerId;
    final outcome = _fetchReply(history, owner);
    final pending = _PendingReply(owner, outcome);
    _pending = pending;
    final result = await outcome;
    if (identical(_pending, pending)) _pending = null;
    if (isClosed) return;
    emit(
      state.copyWith(
        messages: result.messages,
        isTyping: false,
        error: () => result.error,
        limitReached: result.limitReached,
      ),
    );
  }

  /// Fetches and saves the reply whether or not this cubit is still open.
  /// Never throws.
  Future<_ReplyOutcome> _fetchReply(
    List<VitaMessage> history,
    String owner,
  ) async {
    _ReplyOutcome outcome;
    try {
      // Whole answer, health snapshot and a retried request included: the
      // typing dots must always end.
      final reply = await _repository
          .reply(history, draftPlan: _draftPlan)
          .withLoadTimeout(replyTimeout);
      outcome = _ReplyOutcome([...history, reply]);
    } catch (e) {
      debugPrint('Vita reply failed: $e');
      outcome = _ReplyOutcome(
        [
          ...history.sublist(0, history.length - 1),
          history.last.copyWith(failed: true),
        ],
        error: e is VitaException
            ? e.message
            : userMessage(e, fallback: VitaException.couldNotReply),
        limitReached: e is VitaException && e.dailyLimit,
      );
    }
    // Signed out (or into another account) meanwhile: not their chat.
    if (_repository.chatOwnerId == owner) await _save(outcome.messages);
    return outcome;
  }

  /// Storage failures must not leave the chat stuck on "typing".
  Future<void> _save(List<VitaMessage> messages) async {
    try {
      await _repository.saveHistory(messages);
    } catch (e) {
      debugPrint('Vita chat history not saved: $e');
    }
  }
}
