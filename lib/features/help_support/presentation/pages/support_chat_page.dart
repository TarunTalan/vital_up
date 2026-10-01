import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import '../../data/services/support_bot_service.dart';
import '../../domain/entities/support_ticket.dart';
import '../widgets/contact_support_sheet.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final List<SupportBotMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.addAll(SupportBotService.getInitialMessages());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    final query = text.trim();
    if (query.isEmpty) return;

    _textController.clear();
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

  void _handleQuickAction(SupportBotMessage msg) {
    if (msg.actionRoute != null) {
      context.pushNamed(msg.actionRoute!);
    } else {
      showContactSupportSheet(
        context,
        initialCategory: SupportCategory.general,
        initialSubject: 'Question from Support Chat',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return AppScaffold(
      header: AppPageHeader(
        title: 'Vital Assistant',
        action: IconButton(
          tooltip: 'Email Support',
          icon: const Icon(Icons.mail_outline_rounded),
          onPressed: () {
            showContactSupportSheet(
              context,
              initialCategory: SupportCategory.general,
            );
          },
        ),
      ),
      padBody: false,
      scrollable: false,
      body: Column(
        children: [
          // Sub-header status bar
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.gutter,
              vertical: AppDimens.space8,
            ),
            decoration: BoxDecoration(
              color: v.primaryFill,
              border: Border(
                bottom: BorderSide(color: v.primaryBorder ?? Colors.transparent),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                Expanded(
                  child: Text(
                    'Instant Automated Support & Diagnostics',
                    style: context.text.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    showContactSupportSheet(
                      context,
                      initialCategory: SupportCategory.general,
                    );
                  },
                  child: Text(
                    'Email Team ✉️',
                    style: context.text.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                AppDimens.space12,
                context.gutter,
                AppDimens.space16,
              ),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Input Bar with Quick Replies
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(SupportBotMessage msg) {
    final v = context.vColors;
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space16),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(50),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('⚡', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(AppDimens.space12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary
                        : (v.glassFill ?? AppColors.glassFill),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppDimens.radiusCard),
                      topRight: const Radius.circular(AppDimens.radiusCard),
                      bottomLeft: isUser
                          ? const Radius.circular(AppDimens.radiusCard)
                          : const Radius.circular(AppDimens.space4),
                      bottomRight: isUser
                          ? const Radius.circular(AppDimens.space4)
                          : const Radius.circular(AppDimens.radiusCard),
                    ),
                    border: Border.all(
                      color: isUser
                          ? AppColors.primary
                          : (v.glassBorder ?? AppColors.glassBorder),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text,
                        style: context.text.bodyMedium?.copyWith(
                          color: isUser
                              ? AppColors.buttonText
                              : context.colors.onSurface,
                          height: 1.4,
                        ),
                      ),
                      if (msg.actionLabel != null) ...[
                        const SizedBox(height: AppDimens.space8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isUser
                                ? AppColors.white
                                : AppColors.primary,
                            foregroundColor: isUser
                                ? AppColors.primary
                                : AppColors.buttonText,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.space12,
                              vertical: AppDimens.space6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusSm),
                            ),
                          ),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: AppDimens.iconSm,
                          ),
                          label: Text(
                            msg.actionLabel!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _handleQuickAction(msg),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!isUser && msg.quickReplies.isNotEmpty) ...[
            const SizedBox(height: AppDimens.space8),
            Padding(
              padding: const EdgeInsets.only(left: 40.0),
              child: Wrap(
                spacing: AppDimens.space6,
                runSpacing: AppDimens.space6,
                children: msg.quickReplies.map((reply) {
                  return ActionChip(
                    label: Text(reply),
                    labelStyle: context.text.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: v.primaryFill,
                    side: BorderSide(
                      color: v.primaryBorder ?? AppColors.primaryBorder,
                    ),
                    onPressed: () {
                      if (reply.toLowerCase().contains('email')) {
                        showContactSupportSheet(
                          context,
                          initialCategory: SupportCategory.general,
                        );
                      } else {
                        _sendMessage(reply);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final v = context.vColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space16, left: 40.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.space12,
              vertical: AppDimens.space8,
            ),
            decoration: BoxDecoration(
              color: v.glassFill,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: v.glassBorder ?? AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(width: AppDimens.space8),
                Text(
                  'Assistant is typing...',
                  style: context.text.bodySmall?.copyWith(color: v.grayText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final v = context.vColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        AppDimens.space8,
        context.gutter,
        AppDimens.space8 + bottomInset + context.safePadding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          top: BorderSide(color: v.glassBorder ?? AppColors.glassBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: v.glassFill,
                  borderRadius: BorderRadius.circular(AppDimens.radiusToast),
                  border: Border.all(
                    color: v.glassBorder ?? AppColors.glassBorder,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space12,
                ),
                child: TextField(
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask a question or describe an issue...',
                    hintStyle: context.text.bodyMedium?.copyWith(
                      color: v.grayText,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppDimens.space10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.space8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: AppColors.buttonText,
                  size: AppDimens.iconSm,
                ),
                onPressed: () => _sendMessage(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
