import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';

class VitaChatState extends Equatable {
  final List<VitaMessage> messages;
  final bool isLoading;
  final bool isTyping;

  /// Last error to surface (offline, daily limit…); cleared on next send.
  final String? error;

  const VitaChatState({
    this.messages = const [],
    this.isLoading = true,
    this.isTyping = false,
    this.error,
  });

  VitaChatState copyWith({
    List<VitaMessage>? messages,
    bool? isLoading,
    bool? isTyping,
    String? Function()? error,
  }) =>
      VitaChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        isTyping: isTyping ?? this.isTyping,
        error: error == null ? this.error : error(),
      );

  @override
  List<Object?> get props => [messages, isLoading, isTyping, error];
}

/// Vita conversation; history is stored on device so it's readable offline.
class VitaChatCubit extends Cubit<VitaChatState> {
  final VitaRepository _repository;

  /// Unsaved plan being tweaked; Vita sees it instead of the active plan.
  MealPlan? _draftPlan;

  VitaChatCubit(this._repository) : super(const VitaChatState());

  /// Loads saved history, then optionally sends [initialPrompt].
  Future<void> load({String? initialPrompt, MealPlan? draftPlan}) async {
    _draftPlan = draftPlan;
    var history = const <VitaMessage>[];
    try {
      history = await _repository.loadHistory();
    } catch (e) {
      debugPrint('Vita chat history unreadable: $e');
    }
    if (isClosed) return;
    emit(state.copyWith(messages: history, isLoading: false));
    if (initialPrompt != null) await send(initialPrompt);
  }

  /// Cleans a typed message: no invisible characters, at most
  /// [InputLimits.chatMessage] characters. Empty when nothing is left.
  static String cleanMessage(String text) => sanitizeText(
        text,
        maxLength: InputLimits.chatMessage,
        multiline: true,
      );

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

  /// Re-sends a user message Vita couldn't answer.
  Future<void> retry(VitaMessage message) async {
    if (state.isTyping || state.isLoading || !message.failed) return;
    final rest = state.messages.where((m) => m != message).toList();
    await _ask([...rest, message.copyWith(failed: false)]);
  }

  Future<void> _ask(List<VitaMessage> history) async {
    emit(state.copyWith(messages: history, isTyping: true, error: () => null));
    await _save(history);

    try {
      final reply = await _repository.reply(history, draftPlan: _draftPlan);
      if (isClosed) return;
      final updated = [...history, reply];
      emit(state.copyWith(messages: updated, isTyping: false));
      await _save(updated);
    } catch (e) {
      debugPrint('Vita reply failed: $e');
      if (isClosed) return;
      final message = e is VitaException
          ? e.message
          : userMessage(e, fallback: VitaException.couldNotReply);
      final updated = [
        ...history.sublist(0, history.length - 1),
        history.last.copyWith(failed: true),
      ];
      emit(state.copyWith(
        messages: updated,
        isTyping: false,
        error: () => message,
      ));
      await _save(updated);
    }
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
