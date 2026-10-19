import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// A person's name in a list row. Long names wrap to a second line, and the
/// user's own row gets a separate "(you)" tag that is never cut off.
class NameWithYouTag extends StatelessWidget {
  final String name;
  final bool isMe;
  final TextStyle? style;

  const NameWithYouTag({
    super.key,
    required this.name,
    required this.isMe,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (!isMe) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: text),
        const SizedBox(width: AppDimens.space4),
        Text(
          '(you)',
          style: style?.copyWith(
            color: context.vColors.grayText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
