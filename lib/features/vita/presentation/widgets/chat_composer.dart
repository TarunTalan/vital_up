import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/features/vita/presentation/utils/vita_icons.dart';

/// Suggested questions, scrolling sideways: outlined chips, so they don't
/// read as messages already sent.
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
    final v = context.vColors;
    final style = context.text.bodyMedium?.copyWith(color: v.accentText);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: context.pagePadding,
      child: Row(
        children: [
          for (var i = 0; i < prompts.length; i++) ...[
            if (i > 0) const SizedBox(width: AppDimens.space8),
            Material(
              color: v.glassFill,
              shape: StadiumBorder(
                side: BorderSide(
                  color: v.primaryBorder!,
                  width: AppDimens.borderThin,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(prompts[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space16,
                    vertical: AppDimens.space8,
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

/// Message input: glass panel with top-rounded corners and a round send
/// button that lights up once there's something to send.
class ChatComposer extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool enabled;

  /// Off for the day (no messages left): typing is off too and the hint
  /// says why.
  final bool locked;
  final String hintText;

  const ChatComposer({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.locked = false,
    this.hintText = 'Ask Vita anything',
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();

  bool get _canSend =>
      widget.enabled &&
      !widget.locked &&
      sanitizeText(_controller.text, multiline: true).isNotEmpty;

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
            context.gutter,
            AppDimens.space16,
            context.gutter,
            AppDimens.space16 + context.safePadding.bottom,
          ),
          decoration: BoxDecoration(
            color: v.glassFill,
            gradient: AppColors.glassSheen,
            borderRadius: radius,
            border: Border.all(color: v.glassBorder!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space4,
                  ),
                  child: TextField(
                    controller: _controller,
                    enabled: !widget.locked,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: InputFormatters.text(
                      InputLimits.chatMessage,
                      multiline: true,
                    ),
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
                      hintText: widget.hintText,
                      hintStyle: context.text.bodyLarge?.copyWith(
                        color: v.grayText,
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
        color: enabled ? context.colors.primary : context.vColors.track,
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
              width: AppDimens.iconMd,
              height: AppDimens.iconMd,
              semanticsLabel: 'Send',
              colorFilter: ColorFilter.mode(
                enabled
                    ? context.vColors.buttonText!
                    : context.vColors.grayText!,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
