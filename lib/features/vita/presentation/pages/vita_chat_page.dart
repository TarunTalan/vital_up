import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/tracker/log_history_card.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/subscription/data/services/ai_quota_service.dart';
import 'package:vital_up/features/subscription/domain/pro_limits.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:vital_up/features/subscription/presentation/widgets/ai_quota_line.dart';
import 'package:vital_up/features/subscription/presentation/utils/pro_gate.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';
import 'package:vital_up/features/vita/presentation/cubit/vita_chat_cubit.dart';
import 'package:vital_up/features/vita/presentation/widgets/chat_bubble.dart';
import 'package:vital_up/features/vita/presentation/widgets/chat_composer.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_ai_consent_sheet.dart';

/// `vita-chat` route extra when opened to tweak an unsaved [draftPlan]:
/// "Update my plan" then pops back with the change instructions
/// (a `String`) instead of opening the plan screen.
class VitaChatArgs {
  final String? initialPrompt;
  final MealPlan? draftPlan;

  const VitaChatArgs({this.initialPrompt, this.draftPlan});
}

/// Chat with Vita: replies grouped by day, suggested questions until the
/// first one is asked, composer pinned at the bottom.
class VitaChatPage extends StatelessWidget {
  /// Sent on open, e.g. "Ask Vita to tweak this plan" from the diet plan.
  final String? initialPrompt;
  final MealPlan? draftPlan;

  const VitaChatPage({super.key, this.initialPrompt, this.draftPlan});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<VitaChatCubit>(),
      child: _VitaChatView(initialPrompt: initialPrompt, draftPlan: draftPlan),
    );
  }
}

class _VitaChatView extends StatefulWidget {
  final String? initialPrompt;
  final MealPlan? draftPlan;

  const _VitaChatView({this.initialPrompt, this.draftPlan});

  bool get returnsTweak => draftPlan != null;

  @override
  State<_VitaChatView> createState() => _VitaChatViewState();
}

class _VitaChatViewState extends State<_VitaChatView> {
  /// Offered until the user has asked something.
  static const _suggestions = [
    'How am I doing this week?',
    'A lighter dinner idea',
    'Help me sleep better',
    'How do I log water?',
  ];

  /// The list is reversed: offset 0 is the latest message, so the chat
  /// opens there, or where it was left, on its first frame (no visible
  /// scroll), and a new message only has to scroll to 0.
  late final ScrollController _scroll;
  late final VitaChatCubit _cubit;

  /// Closer than this to the latest message counts as being at the end.
  static const _endSlack = 48.0;

  /// Free messages left today (null: unknown or Pro), from [AiQuotaLine].
  int? _chatsLeft;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<VitaChatCubit>();
    _scroll = ScrollController(initialScrollOffset: _cubit.savedScroll ?? 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  /// Nothing is sent before the user has accepted the AI data notice.
  Future<void> _start() async {
    if (!mounted) return;
    final allowed = await ensureVitaAiConsent(context);
    if (!mounted) return;
    if (!allowed) {
      Navigator.of(context).maybePop();
      return;
    }
    await context.read<VitaChatCubit>().load(
      initialPrompt: widget.initialPrompt,
      draftPlan: widget.draftPlan,
    );
  }

  @override
  void dispose() {
    _rememberScroll();
    _scroll.dispose();
    super.dispose();
  }

  /// Saved per user, so the chat reopens here (also after a restart).
  void _rememberScroll() {
    if (!_scroll.hasClients || _cubit.state.isLoading) return;
    final pixels = _scroll.position.pixels;
    _cubit.saveScroll(pixels < _endSlack ? null : pixels);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || _scroll.position.pixels == 0) return;
      _scroll.animateTo(
        0,
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Today's chat limit: free users can start Pro, then the unanswered
  /// message is sent again.
  Future<void> _offerPro(String message) async {
    final started = await offerProForLimit(
      context,
      reason: ProReason.vitaChats,
      message: message,
    );
    if (!started || !mounted) return;
    final cubit = context.read<VitaChatCubit>();
    final failed = cubit.state.messages.where((m) => m.failed).lastOrNull;
    if (failed != null) await cubit.retry(failed);
  }

  Future<void> _confirmClear() async {
    final clear = await showSmoothDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear this chat?'),
        content: const Text(
          'Your messages with Vita will be removed from this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.colors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (clear == true && mounted) {
      await context.read<VitaChatCubit>().clear();
    }
  }

  Future<void> _confirmDelete(VitaMessage message) async {
    final cubit = context.read<VitaChatCubit>();
    if (cubit.state.isTyping) {
      showErrorSnackBar(context, 'Wait for Vita to reply, then try again.');
      return;
    }
    final delete = await showSmoothDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this message?'),
        content: const Text('It will be removed from this chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.colors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete == true && mounted) await cubit.delete(message);
  }

  void _onAction(VitaMessage message, VitaAction action) {
    switch (action) {
      case VitaAction.viewDietPlan:
        context.pushNamed('vita-diet-plan', extra: true);
      case VitaAction.updateDietPlan:
        final instructions = message.planInstructions;
        if (instructions == null || instructions.isEmpty) {
          context.pushNamed('vita-diet-plan', extra: true);
        } else if (widget.returnsTweak) {
          context.pop(instructions);
        } else {
          context.pushNamed(
            'diet-plan-result',
            extra: {'mode': 'tweak', 'instructions': instructions},
          );
        }
      case VitaAction.viewAnalysis:
        context.pushNamed('vita-analysis');
      case VitaAction.viewStressGuide:
        context.pushNamed('vita-stress');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VitaChatCubit>();

    return AppScaffold(
      header: AppPageHeader(
        title: 'Ask Vita',
        action: BlocSelector<VitaChatCubit, VitaChatState, bool>(
          selector: (state) =>
              !state.isLoading &&
              !state.isTyping &&
              state.messages.any((m) => !m.isFromVita),
          builder: (context, canClear) => AppHeaderAction(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_outline_rounded),
            onTap: canClear ? _confirmClear : null,
          ),
        ),
      ),
      scrollable: false,
      padBody: false,
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<VitaChatCubit, VitaChatState>(
              listener: (context, state) {
                _scrollToEnd();
                final error = state.error;
                if (error == null) return;
                if (state.limitReached) {
                  _offerPro(error);
                } else {
                  showErrorSnackBar(context, error);
                }
              },
              // Not on the load itself: the controller's initial offset
              // already opened the chat where it was left.
              listenWhen: (prev, next) =>
                  !prev.isLoading &&
                  (next.messages.length > prev.messages.length ||
                      prev.isTyping != next.isTyping ||
                      (next.error != null && prev.error != next.error)),
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: VitalUpLoader());
                }
                final items = _chatItems(state.messages);
                final typing = state.isTyping ? 1 : 0;
                // Newest first from the bottom; a short chat still starts
                // at the top.
                final list = ListView.separated(
                  controller: _scroll,
                  reverse: true,
                  shrinkWrap: true,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    context.gutter,
                    AppDimens.space8,
                    context.gutter,
                    AppDimens.space16,
                  ),
                  itemCount: items.length + typing,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: VitaDimens.messageGap),
                  itemBuilder: (context, index) {
                    if (index < typing) return const TypingBubble();
                    final item = items[items.length - 1 - (index - typing)];
                    if (item is DateTime) return _DayLabel(formatLogDay(item));
                    final message = item as VitaMessage;
                    return ChatBubble(
                      message: message,
                      onAction: (action) => _onAction(message, action),
                      onRetry: () => cubit.retry(message),
                      onLongPress: () => _confirmDelete(message),
                    );
                  },
                );
                return NotificationListener<ScrollEndNotification>(
                  onNotification: (_) {
                    _rememberScroll();
                    return false;
                  },
                  child: Align(alignment: Alignment.topCenter, child: list),
                );
              },
            ),
          ),
          BlocSelector<VitaChatCubit, VitaChatState, bool>(
            selector: (state) =>
                !state.isLoading && !state.messages.any((m) => !m.isFromVita),
            builder: (context, fresh) => fresh
                ? Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.space12),
                    child: QuickReplies(
                      prompts: _suggestions,
                      onSelected: cubit.send,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.gutter,
              0,
              context.gutter,
              AppDimens.space8,
            ),
            child: AiQuotaLine(
              quota: AiQuota.vitaChat,
              onChanged: (left) {
                if (left != _chatsLeft) setState(() => _chatsLeft = left);
              },
            ),
          ),
          BlocSelector<VitaChatCubit, VitaChatState, bool>(
            selector: (state) => !state.isTyping && !state.isLoading,
            builder: (context, canSend) {
              // Free messages only: buying Pro unlocks it at once.
              final pro =
                  context.watch<SubscriptionCubit?>()?.state.isPro ?? false;
              final out = _chatsLeft == 0 && !pro;
              return ChatComposer(
                enabled: canSend,
                locked: out,
                hintText: out ? 'No messages left today' : 'Ask Vita anything',
                onSend: cubit.send,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// [messages] with the day before each new day's first message.
List<Object> _chatItems(List<VitaMessage> messages) {
  final items = <Object>[];
  DateTime? day;
  for (final m in messages) {
    final d = DateTime(m.sentAt.year, m.sentAt.month, m.sentAt.day);
    if (day == null || d != day) {
      items.add(d);
      day = d;
    }
    items.add(m);
  }
  return items;
}

class _DayLabel extends StatelessWidget {
  final String text;

  const _DayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: context.text.bodySmall?.copyWith(color: context.vColors.grayText),
    );
  }
}
