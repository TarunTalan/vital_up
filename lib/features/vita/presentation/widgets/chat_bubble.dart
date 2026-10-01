import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_avatar.dart';

const _botRadius = BorderRadius.only(
  topLeft: Radius.circular(VitaDimens.bubbleRadius),
  topRight: Radius.circular(VitaDimens.bubbleRadius),
  bottomRight: Radius.circular(VitaDimens.bubbleRadius),
);

/// User bubble / quick-reply shape: rounded except bottom-right.
const vitaUserBubbleRadius = BorderRadius.only(
  topLeft: Radius.circular(VitaDimens.bubbleRadius),
  topRight: Radius.circular(VitaDimens.bubbleRadius),
  bottomLeft: Radius.circular(VitaDimens.bubbleRadius),
);

const _bubblePadding = EdgeInsets.symmetric(
  horizontal: AppDimens.space16,
  vertical: AppDimens.space12,
);

TextStyle? _bubbleText(BuildContext context, Color color) => context
    .text.bodyLarge
    ?.copyWith(color: color, height: VitaDimens.bubbleLineHeight);

/// One chat message — Figma `health coach/chat` bubbles. Vita's replies sit
/// left in a light-cyan bubble with avatar + time underneath; the user's sit
/// right in teal with the time underneath.
class ChatBubble extends StatelessWidget {
  final VitaMessage message;
  final ValueChanged<VitaAction>? onAction;

  /// Tapped on a [VitaMessage.failed] user message.
  final VoidCallback? onRetry;

  const ChatBubble({
    super.key,
    required this.message,
    this.onAction,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel = DateFormat('h:mm a').format(message.sentAt).toLowerCase();
    final Widget time = message.failed
        ? InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(AppDimens.radiusXs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: AppDimens.iconXs,
                  color: context.colors.error,
                ),
                const SizedBox(width: AppDimens.space4),
                Text(
                  'Not sent · Tap to retry',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ],
            ),
          )
        : Text(
            timeLabel,
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!message.isFromVita) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      constraints.maxWidth * VitaDimens.userBubbleFraction,
                ),
                child: Container(
                  padding: _bubblePadding,
                  decoration: const BoxDecoration(
                    color: VitaColors.userBubble,
                    borderRadius: vitaUserBubbleRadius,
                  ),
                  child: Text(
                    message.text,
                    textAlign: TextAlign.right,
                    style: _bubbleText(context, VitaColors.userText),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.space10),
              time,
            ],
          );
        }

        final action = message.action;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BotBubble(
              maxWidth: constraints.maxWidth * VitaDimens.botBubbleFraction,
              expand: action != null,
              children: [
                Text(message.text,
                    style: _bubbleText(context, VitaColors.botText)),
                for (final bullet in message.bullets) _Bullet(bullet),
                if (action != null) ...[
                  const SizedBox(height: AppDimens.space24),
                  AppPrimaryButton(
                    label: action.label,
                    showRightArrow: true,
                    onTap: () => onAction?.call(action),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppDimens.space12),
            Row(
              children: [
                const VitaAvatar(),
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

class _BotBubble extends StatelessWidget {
  final double maxWidth;
  final bool expand;
  final List<Widget> children;

  const _BotBubble({
    required this.maxWidth,
    required this.expand,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        width: expand ? maxWidth : null,
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
          children: children,
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    final style = _bubbleText(context, VitaColors.botText);
    return Padding(
      padding: const EdgeInsets.only(left: AppDimens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: AppDimens.space16, child: Text('•', style: style)),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// Vita "typing…" bubble shown while a reply is on its way.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space20,
          vertical: AppDimens.space16,
        ),
        decoration: BoxDecoration(
          color: VitaColors.botBubble,
          borderRadius: _botRadius,
          border: Border.all(color: VitaColors.botBubbleBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: AppDimens.space6),
              FadeTransition(
                opacity: TweenSequence<double>([
                  TweenSequenceItem(tween: Tween(begin: 0.3, end: 1), weight: 1),
                  TweenSequenceItem(tween: Tween(begin: 1, end: 0.3), weight: 1),
                ]).animate(CurvedAnimation(
                  parent: _controller,
                  curve: Interval(i * 0.2, 0.6 + i * 0.2),
                )),
                child: Container(
                  width: AppDimens.bulletDot,
                  height: AppDimens.bulletDot,
                  decoration: const BoxDecoration(
                    color: VitaColors.botText,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
