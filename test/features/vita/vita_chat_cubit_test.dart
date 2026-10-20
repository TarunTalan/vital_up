import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';
import 'package:vital_up/features/vita/presentation/cubit/vita_chat_cubit.dart';

/// Chat storage per owner; replies wait for [answer] to complete.
class _FakeChat implements VitaRepository {
  final saved = <String, List<VitaMessage>>{};
  String owner = 'a';
  Completer<VitaMessage> answer = Completer();

  @override
  String get chatOwnerId => owner;

  @override
  Future<List<VitaMessage>> loadHistory() async {
    final chat = saved[owner] ?? const [];
    return chat.isEmpty ? [_vita('Hi')] : chat;
  }

  @override
  Future<void> saveHistory(List<VitaMessage> messages) async {
    saved[owner] = messages;
  }

  @override
  Future<VitaMessage> reply(
    List<VitaMessage> history, {
    MealPlan? draftPlan,
  }) => answer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

VitaMessage _vita(String text) =>
    VitaMessage(sender: VitaSender.vita, text: text, sentAt: DateTime(2026));

void main() {
  test('a reply asked before leaving is saved and shown on return', () async {
    final repo = _FakeChat();
    final first = VitaChatCubit(repo);
    await first.load();
    unawaited(first.send('How did I sleep?'));
    await Future<void>.delayed(Duration.zero);
    await first.close();

    final second = VitaChatCubit(repo);
    final loading = second.load();
    await Future<void>.delayed(Duration.zero);
    expect(second.state.isTyping, isTrue);

    repo.answer.complete(_vita('7h 10m, close to your goal.'));
    await loading;
    expect(second.state.isTyping, isFalse);
    expect(second.state.messages.last.text, '7h 10m, close to your goal.');
    expect(repo.saved['a']!.last.text, '7h 10m, close to your goal.');
    await second.close();
  });

  test('a failed reply marks the message for retry', () async {
    final repo = _FakeChat();
    final cubit = VitaChatCubit(repo);
    await cubit.load();
    final sending = cubit.send('Hello');
    repo.answer.completeError(const VitaException(VitaException.tooSlow));
    await sending;
    expect(cubit.state.messages.last.failed, isTrue);
    expect(cubit.state.error, VitaException.tooSlow);

    repo.answer = Completer()..complete(_vita('Hi there'));
    await cubit.retry(cubit.state.messages.last);
    expect(cubit.state.messages.map((m) => m.failed), everyElement(isFalse));
    expect(cubit.state.messages.last.text, 'Hi there');
    await cubit.close();
  });

  test('a reply that lands after sign-out is not saved', () async {
    final repo = _FakeChat();
    final cubit = VitaChatCubit(repo);
    await cubit.load();
    final sending = cubit.send('Hello');
    await Future<void>.delayed(Duration.zero);
    repo.owner = 'b';
    repo.answer.complete(_vita('Hi'));
    await sending;
    expect(repo.saved['b'], isNull);
    expect(repo.saved['a']!.last.text, 'Hello');
    await cubit.close();

    final other = VitaChatCubit(repo);
    await other.load();
    expect(other.state.isTyping, isFalse);
    await other.close();
  });

  test('long press delete removes one message and keeps the rest', () async {
    final repo = _FakeChat();
    final cubit = VitaChatCubit(repo);
    await cubit.load();
    repo.answer.complete(_vita('Drink a glass now.'));
    await cubit.send('Water?');
    expect(cubit.state.messages, hasLength(3));

    final question = cubit.state.messages[1];
    await cubit.delete(question);
    expect(cubit.state.messages.map((m) => m.text), [
      'Hi',
      'Drink a glass now.',
    ]);
    expect(repo.saved['a'], cubit.state.messages);

    // Deleting everything starts over with the greeting.
    for (final m in [...cubit.state.messages]) {
      await cubit.delete(m);
    }
    expect(cubit.state.messages.single.text, 'Hi');
    await cubit.close();
  });
}
