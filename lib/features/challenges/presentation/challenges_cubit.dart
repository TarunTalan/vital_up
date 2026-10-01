import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';

class ChallengesState extends Equatable {
  final List<Challenge>? challenges;
  final bool failed;

  /// Challenge ids with a join / decline in flight.
  final Set<String> busy;

  /// One-off snackbar text; [messageId] changes each time.
  final String? message;
  final int messageId;

  const ChallengesState({
    this.challenges,
    this.failed = false,
    this.busy = const {},
    this.message,
    this.messageId = 0,
  });

  ChallengesState copyWith({
    List<Challenge>? challenges,
    bool? failed,
    Set<String>? busy,
    String? message,
  }) => ChallengesState(
    challenges: challenges ?? this.challenges,
    failed: failed ?? this.failed,
    busy: busy ?? this.busy,
    message: message,
    messageId: message != null ? messageId + 1 : messageId,
  );

  @override
  List<Object?> get props => [challenges, failed, busy, message, messageId];
}

class ChallengesCubit extends Cubit<ChallengesState> {
  final ChallengesRepository _repository;

  ChallengesCubit(this._repository) : super(const ChallengesState());

  Future<void> load() async {
    emit(state.copyWith(failed: false));
    try {
      final challenges = await _repository.getChallenges();
      if (!isClosed) emit(state.copyWith(challenges: challenges));
    } on ChallengeException {
      if (!isClosed) emit(state.copyWith(failed: true));
    }
  }

  /// Null on success, otherwise a message for the create sheet.
  Future<String?> create({
    required ChallengeMetric metric,
    required int days,
    required List<String> friendIds,
  }) async {
    try {
      await _repository.create(
        metric: metric,
        days: days,
        friendIds: friendIds,
      );
    } on ChallengeException catch (e) {
      return e.message;
    }
    await load();
    if (!isClosed) emit(state.copyWith(message: 'Challenge sent!'));
    return null;
  }

  Future<void> respond(Challenge challenge, {required bool accept}) async {
    emit(state.copyWith(busy: {...state.busy, challenge.id}));
    try {
      await _repository.respond(challenge, accept: accept);
      await load();
    } on ChallengeException catch (e) {
      if (!isClosed) emit(state.copyWith(message: e.message));
    } finally {
      if (!isClosed) {
        emit(state.copyWith(busy: {...state.busy}..remove(challenge.id)));
      }
    }
  }
}
