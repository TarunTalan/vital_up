import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/features/vita/presentation/utils/vita_icons.dart';
import 'package:vital_up/features/vita/presentation/widgets/chat_bubble.dart';

/// Horizontally scrolling suggested prompts — Figma Frame 412 (teal chips
/// shaped like user bubbles).
class QuickReplies extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onSelected;

  const QuickReplies({
    super.key,
    required this.prompts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyLarge?.copyWith(color: VitaColors.userText);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: context.pagePadding,
      child: Row(
        children: [
          for (var i = 0; i < prompts.length; i++) ...[
            if (i > 0) const SizedBox(width: AppDimens.space10),
            Material(
              color: VitaColors.userBubble,
              shape: const RoundedRectangleBorder(
                borderRadius: vitaUserBubbleRadius,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(prompts[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space16,
                    vertical: AppDimens.space12,
                  ),
                  child: Text(prompts[i], style: style),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Message input — Figma Frame 415: glass panel with top-rounded corners,
/// placeholder text and a 52dp round send button.
class ChatComposer extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool enabled;

  const ChatComposer({super.key, required this.onSend, this.enabled = true});

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();

  bool get _canSend => widget.enabled && _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (!_canSend) return;
    widget.onSend(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    const radius = BorderRadius.vertical(
      top: Radius.circular(AppDimens.radiusCard),
    );

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDimens.glassBlur / 2,
          sigmaY: AppDimens.glassBlur / 2,
        ),
        child: Container(
          constraints: BoxConstraints(
            minHeight: VitaDimens.composerHeight + context.safePadding.bottom,
          ),
          padding: EdgeInsets.fromLTRB(
            AppDimens.space24,
            AppDimens.space16,
            AppDimens.space24,
            AppDimens.space16 + context.safePadding.bottom,
          ),
          decoration: BoxDecoration(
            color: v.glassFill,
            gradient: AppColors.glassSheen,
            borderRadius: radius,
            border: Border.all(color: v.glassBorder!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppDimens.space4),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: context.text.bodyLarge?.copyWith(
                      color: context.colors.onSurface,
                    ),
                    // The composer panel is the field's frame, so drop every
                    // border/fill the app input theme would otherwise add
                    // (collapsed only clears `border`, not focus states).
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText: 'Type your message...',
                      hintStyle: context.text.bodyLarge?.copyWith(
                        color: VitaColors.composerMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.space12),
              _SendButton(enabled: _canSend, onTap: _send),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: VitaDimens.sendButton,
      height: VitaDimens.sendButton,
      decoration: BoxDecoration(
        color: enabled ? context.colors.primary : VitaColors.composerMuted,
        shape: BoxShape.circle,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Center(
            child: SvgPicture.asset(
              VitaIcons.send,
              width: AppDimens.iconLg,
              height: AppDimens.iconLg,
              semanticsLabel: 'Send',
            ),
          ),
        ),
      ),
    );
  }
}
