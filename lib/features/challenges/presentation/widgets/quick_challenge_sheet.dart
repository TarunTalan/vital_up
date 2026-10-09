import 'package:flutter/material.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/widgets/challenge_tile.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';

/// Ready-made challenges. The server accepts 3, 7 or 14 days on active
/// minutes, distance or workouts, so every option here is one it takes.
const _options = [
  (metric: ChallengeMetric.activeMinutes, days: 3),
  (metric: ChallengeMetric.activeMinutes, days: 7),
  (metric: ChallengeMetric.distanceKm, days: 7),
  (metric: ChallengeMetric.workouts, days: 7),
  (metric: ChallengeMetric.distanceKm, days: 14),
];

/// Sends one friend a ready-made challenge. Returns true once sent.
class QuickChallengeSheet extends StatefulWidget {
  final Friend friend;

  const QuickChallengeSheet({super.key, required this.friend});

  static Future<bool?> show(BuildContext context, {required Friend friend}) {
    return showAppBottomSheet<bool>(
      context: context,
      builder: (_) => QuickChallengeSheet(friend: friend),
    );
  }

  @override
  State<QuickChallengeSheet> createState() => _QuickChallengeSheetState();
}

class _QuickChallengeSheetState extends State<QuickChallengeSheet> {
  var _selected = _options.first;
  bool _submitting = false;

  Future<void> _send() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    try {
      await sl<ChallengesRepository>().create(
        metric: _selected.metric,
        days: _selected.days,
        friendIds: [widget.friend.userId],
      );
      if (mounted) navigator.pop(true);
      if (rootContext.mounted) {
        showSuccessSnackBar(
          rootContext,
          'Challenge sent to @${widget.friend.username}',
        );
      }
    } catch (e) {
      debugPrint('Sending a challenge failed: $e');
      if (mounted) {
        showErrorSnackBar(
          context,
          e is ChallengeException
              ? e.message
              : userMessage(
                  e,
                  fallback: "Couldn't send the challenge. Try again.",
                ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          AppDimens.space12,
          context.gutter,
          AppDimens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Challenge @${widget.friend.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.headlineSmall,
            ),
            const SizedBox(height: AppDimens.space4),
            Text(
              'Pick what to compete on. Scores come from synced workouts.',
              style: context.text.bodySmall?.copyWith(color: grey),
            ),
            const SizedBox(height: AppDimens.space16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final o in _options) ...[
                      ChallengeOptionTile(
                        icon: challengeMetricIcon(o.metric),
                        title:
                            'Most ${o.metric.label.toLowerCase()} in '
                            '${o.days} days',
                        selected: o == _selected,
                        onTap: () => setState(() => _selected = o),
                      ),
                      const SizedBox(height: AppDimens.space8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.space16),
            AppPrimaryButton(
              label: 'Send challenge',
              leadingIcon: const Icon(
                Icons.send_rounded,
                size: AppDimens.iconSm,
              ),
              isLoading: _submitting,
              onTap: _send,
            ),
          ],
        ),
      ),
    );
  }
}
