import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/vita/presentation/widgets/chat_bubble.dart';
import 'package:vital_up/features/vita/presentation/widgets/chat_composer.dart';
import '../../data/services/support_bot_service.dart';
import '../../domain/entities/support_ticket.dart';
import 'contact_support_page.dart';
import 'help_support_page.dart';

/// Support assistant chat — same bubbles, quick replies and composer as
/// Vita Chat so both conversations look alike.
class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final List<SupportBotMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.addAll(SupportBotService.getInitialMessages());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _sendMessage(String text) {
    final query = sanitizeText(
      text,
      maxLength: InputLimits.chatMessage,
      multiline: true,
    );
    if (query.isEmpty || _isTyping) return;

    setState(() {
      _messages.add(SupportBotMessage(text: query, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();
    HapticFeedback.lightImpact();

    // Simulate quick intelligent AI response
    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      final reply = SupportBotService.generateReply(query);
      setState(() {
        _isTyping = false;
        _messages.add(reply);
      });
      _scrollToBottom();
      HapticFeedback.mediumImpact();
    });
  }

  void _contactSupport({String subject = ''}) {
    openContactSupport(
      context,
      initialCategory: SupportCategory.general,
      initialSubject: subject,
    );
  }

  void _handleQuickAction(SupportBotMessage msg) {
    if (msg.actionRoute != null) {
      openSupportRoute(context, msg.actionRoute!);
    } else {
      _contactSupport(subject: 'Question from Support Chat');
    }
  }

  void _onQuickReply(String reply) {
    if (reply.toLowerCase().contains('email')) {
      _contactSupport();
    } else {
      _sendMessage(reply);
    }
  }

  /// Suggestions from the latest assistant reply, hidden while it's typing.
  List<String> get _quickReplies {
    if (_isTyping || _messages.isEmpty || _messages.last.isUser) {
      return const [];
    }
    return _messages.last.quickReplies;
  }

  @override
  Widget build(BuildContext context) {
    final quickReplies = _quickReplies;

    return AppScaffold(
      header: const AppPageHeader(
        title: 'Vital Assistant',
        subtitle: 'Instant automated support & diagnostics',
      ),
      padBody: false,
      scrollable: false,
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                AppDimens.sectionGap,
                context.gutter,
                AppDimens.space24,
              ),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppDimens.sectionGap),
              itemBuilder: (context, index) {
                if (index == _messages.length) return const TypingBubble();
                final msg = _messages[index];
                return _SupportBubble(
                  message: msg,
                  onAction: () => _handleQuickAction(msg),
                );
              },
            ),
          ),
          if (quickReplies.isNotEmpty) ...[
            QuickReplies(prompts: quickReplies, onSelected: _onQuickReply),
            const SizedBox(height: AppDimens.space16),
          ],
          ChatComposer(enabled: !_isTyping, onSend: _sendMessage),
        ],
      ),
    );
  }
}

const _botRadius = BorderRadius.only(
  topLeft: Radius.circular(VitaDimens.bubbleRadius),
  topRight: Radius.circular(VitaDimens.bubbleRadius),
  bottomRight: Radius.circular(VitaDimens.bubbleRadius),
);

const _bubblePadding = EdgeInsets.symmetric(
  horizontal: AppDimens.space16,
  vertical: AppDimens.space12,
);

/// One support message, styled like Vita Chat's [ChatBubble]: assistant
/// replies on the left with a bot badge + time, user messages on the right.
class _SupportBubble extends StatelessWidget {
  final SupportBotMessage message;
  final VoidCallback onAction;

  const _SupportBubble({required this.message, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final time = Text(
      DateFormat('h:mm a').format(message.timestamp).toLowerCase(),
      style: context.text.bodySmall?.copyWith(color: context.vColors.grayText),
    );
    TextStyle? textStyle(Color color) => context.text.bodyLarge
        ?.copyWith(color: color, height: VitaDimens.bubbleLineHeight);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (message.isUser) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * VitaDimens.userBubbleFraction,
                ),
                child: Container(
                  padding: _bubblePadding,
                  decoration: const BoxDecoration(
                    color: VitaColors.userBubble,
                    borderRadius: vitaUserBubbleRadius,
                  ),
                  child: Text(
                    message.text,
                    style: textStyle(VitaColors.userText),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.space10),
              time,
            ],
          );
        }

        final maxWidth = constraints.maxWidth * VitaDimens.botBubbleFraction;
        final hasAction = message.actionLabel != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                width: hasAction ? maxWidth : null,
                padding: _bubblePadding,
                decoration: BoxDecoration(
                  color: VitaColors.botBubble,
                  borderRadius: _botRadius,
                  border: Border.all(
                    color: VitaColors.botBubbleBorder,
                    width: AppDimens.borderThin,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message.text, style: textStyle(VitaColors.botText)),
                    if (hasAction) ...[
                      const SizedBox(height: AppDimens.space16),
                      AppPrimaryButton(
                        label: message.actionLabel!,
                        showRightArrow: true,
                        onTap: onAction,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.space12),
            Row(
              children: [
                const AppIconBadge(
                  icon: Icon(Icons.smart_toy_rounded),
                  size: VitaDimens.avatarSmall,
                ),
                const SizedBox(width: AppDimens.space12),
                time,
              ],
            ),
          ],
        );
      },
    );
  }
}
