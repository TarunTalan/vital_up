import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/features/vita/domain/entities/vita_message.dart';
import 'package:vital_up/features/vita/presentation/widgets/vita_avatar.dart';

/// Vita's bubble: rounded except the corner by its avatar (bottom left).
const _botRadius = BorderRadius.only(
  topLeft: Radius.circular(VitaDimens.bubbleRadius),
  topRight: Radius.circular(VitaDimens.bubbleRadius),
  bottomRight: Radius.circular(VitaDimens.bubbleRadius),
);

/// The user's bubble: rounded except bottom right.
const _userRadius = BorderRadius.only(
  topLeft: Radius.circular(VitaDimens.bubbleRadius),
  topRight: Radius.circular(VitaDimens.bubbleRadius),
  bottomLeft: Radius.circular(VitaDimens.bubbleRadius),
);

const _bubblePadding = EdgeInsets.symmetric(
  horizontal: AppDimens.space16,
  vertical: AppDimens.space12,
);

TextStyle? _bubbleText(BuildContext context, Color color) => context
    .text
    .bodyLarge
    ?.copyWith(color: color, height: VitaDimens.bubbleLineHeight);

/// Glass like every card, so Vita's replies follow the theme.
BoxDecoration _botDecoration(BuildContext context) => BoxDecoration(
  color: context.vColors.glassFill,
  borderRadius: _botRadius,
  border: Border.all(
    color: context.vColors.glassBorder!,
    width: AppDimens.borderThin,
  ),
);

/// One chat message. Vita's replies sit left in a glass bubble with its
/// avatar and the time underneath; the user's sit right in deep teal with
/// the time underneath.
class ChatBubble extends StatelessWidget {
  final VitaMessage message;
  final ValueChanged<VitaAction>? onAction;

  /// Tapped on a [VitaMessage.failed] user message.
  final VoidCallback? onRetry;

  /// Long press on the bubble (delete).
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.message,
    this.onAction,
    this.onRetry,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final timeLabel = DateFormat.jm().format(message.sentAt);
    final Widget time = message.failed
        ? InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(AppDimens.radiusXs),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: AppDimens.iconXs,
                    color: context.colors.error,
                  ),
                  const SizedBox(width: AppDimens.space4),
                  Flexible(
                    child: Text(
                      'Not sent',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.space12),
                  Icon(
                    Icons.refresh_rounded,
                    size: AppDimens.iconXs,
                    color: context.vColors.accentText,
                  ),
                  const SizedBox(width: AppDimens.space4),
                  Text(
                    'Retry',
                    style: context.text.bodySmall?.copyWith(
                      color: context.vColors.accentText,
                    ),
                  ),
                ],
              ),
            ),
          )
        : Text(timeLabel, style: context.text.bodySmall?.copyWith(color: grey));

    final bubble = LayoutBuilder(
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
                    borderRadius: _userRadius,
                  ),
                  child: Text(
                    message.text,
                    style: _bubbleText(context, VitaColors.userText),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.space8),
              time,
            ],
          );
        }

        final action = message.action;
        final maxWidth = constraints.maxWidth * VitaDimens.botBubbleFraction;
        final onSurface = context.colors.onSurface;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                width: action != null ? maxWidth : null,
                padding: _bubblePadding,
                decoration: _botDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message.text, style: _bubbleText(context, onSurface)),
                    if (message.bullets.isNotEmpty)
                      const SizedBox(height: AppDimens.space4),
                    for (final bullet in message.bullets) _Bullet(bullet),
                    if (action != null) ...[
                      const SizedBox(height: AppDimens.space12),
                      AppSecondaryButton(
                        label: action.label,
                        onTap: () => onAction?.call(action),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.space8),
            Row(
              children: [
                const VitaAvatar(),
                const SizedBox(width: AppDimens.space8),
                Flexible(child: time),
              ],
            ),
          ],
        );
      },
    );
    if (onLongPress == null) return bubble;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress!();
      },
      child: bubble,
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    final style = _bubbleText(context, context.colors.onSurface);
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppDimens.space16,
            child: Text('•', style: style),
          ),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// Vita's "typing" dots, in the same glass bubble as its replies.
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
    final dot = context.vColors.grayText;
    return Semantics(
      label: 'Vita is typing',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space16,
            vertical: AppDimens.space16,
          ),
          decoration: _botDecoration(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AppDimens.space6),
                FadeTransition(
                  opacity:
                      TweenSequence<double>([
                        TweenSequenceItem(
                          tween: Tween(begin: 0.3, end: 1),
                          weight: 1,
                        ),
                        TweenSequenceItem(
                          tween: Tween(begin: 1, end: 0.3),
                          weight: 1,
                        ),
                      ]).animate(
                        CurvedAnimation(
                          parent: _controller,
                          curve: Interval(i * 0.2, 0.6 + i * 0.2),
                        ),
                      ),
                  child: Container(
                    width: AppDimens.bulletDot,
                    height: AppDimens.bulletDot,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
