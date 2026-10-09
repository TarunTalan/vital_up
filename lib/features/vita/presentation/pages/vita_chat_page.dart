import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/diet_plan/domain/entities/meal_plan.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';
import 'package:vital_up/features/vita/presentation/cubit/vita_chat_cubit.dart';
import 'package:vital_up/features/vita/presentation/widgets/chat_bubble.dart';
import 'package:vital_up/features/vita/presentation/widgets/chat_composer.dart';

/// `vita-chat` route extra when opened to tweak an unsaved [draftPlan]:
/// "Update My Plan" then pops back with the change instructions
/// (a `String`) instead of opening the plan screen.
class VitaChatArgs {
  final String? initialPrompt;
  final MealPlan? draftPlan;

  const VitaChatArgs({this.initialPrompt, this.draftPlan});
}

/// Figma `health coach/chat` (1904:13319).
class VitaChatPage extends StatelessWidget {
  /// Sent on open, e.g. "Ask Vita to tweak this plan" from the diet plan.
  final String? initialPrompt;
  final MealPlan? draftPlan;

  const VitaChatPage({super.key, this.initialPrompt, this.draftPlan});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<VitaChatCubit>()
        ..load(initialPrompt: initialPrompt, draftPlan: draftPlan),
      child: _VitaChatView(returnsTweak: draftPlan != null),
    );
  }
}

class _VitaChatView extends StatefulWidget {
  final bool returnsTweak;

  const _VitaChatView({required this.returnsTweak});

  @override
  State<_VitaChatView> createState() => _VitaChatViewState();
}

class _VitaChatViewState extends State<_VitaChatView> {
  static const _quickReplies = [
    'My health report',
    'Diet suggestions',
    'Sleep tips',
  ];

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
      );
    });
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
      header: const AppTitleBar(title: 'Vita Chat'),
      scrollable: false,
      padBody: false,
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<VitaChatCubit, VitaChatState>(
              listener: (context, state) {
                _scrollToEnd();
                final error = state.error;
                if (error != null) showErrorSnackBar(context, error);
              },
              listenWhen: (prev, next) =>
                  prev.messages.length != next.messages.length ||
                  prev.isTyping != next.isTyping ||
                  (next.error != null && prev.error != next.error),
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = state.messages;
                final typing = state.isTyping ? 1 : 0;
                return ListView.separated(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    context.gutter,
                    0,
                    context.gutter,
                    AppDimens.space24,
                  ),
                  itemCount: 1 + messages.length + typing,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: VitaDimens.messageGap),
                  itemBuilder: (context, index) {
                    if (index == 0) return const _DayLabel('Today');
                    final i = index - 1;
                    if (i == messages.length) return const TypingBubble();
                    final message = messages[i];
                    return ChatBubble(
                      message: message,
                      onAction: (action) => _onAction(message, action),
                      onRetry: () => cubit.retry(message),
                    );
                  },
                );
              },
            ),
          ),
          QuickReplies(prompts: _quickReplies, onSelected: cubit.send),
          const SizedBox(height: AppDimens.space16),
          BlocSelector<VitaChatCubit, VitaChatState, bool>(
            selector: (state) => !state.isTyping && !state.isLoading,
            builder: (context, canSend) =>
                ChatComposer(enabled: canSend, onSend: cubit.send),
          ),
        ],
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  final String text;

  const _DayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: context.text.bodyLarge?.copyWith(color: context.vColors.grayText),
    );
  }
}
