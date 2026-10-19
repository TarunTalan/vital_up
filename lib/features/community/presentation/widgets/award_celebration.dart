import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_award.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/widgets/award_widgets.dart';

/// Only trophies get the dialog (medals stay a notification), and only for
/// a month that ended in the last two weeks.
const _celebrateWithin = Duration(days: 14);

/// The trophy to celebrate: monthly, newer than [seenId], recent, and the
/// most important one when there are several.
CommunityAward? awardToCelebrate(
  List<CommunityAward> awards, {
  required int seenId,
  required DateTime now,
}) {
  final fresh = [
    for (final a in awards)
      if (a.isTrophy &&
          a.id > seenId &&
          now.difference(
                DateTime(a.periodStart.year, a.periodStart.month + 1),
              ) <=
              _celebrateWithin)
        a,
  ];
  return fresh.isEmpty ? null : sortByPrestige(fresh).first;
}

/// Wraps the Arena: once per new monthly trophy, shows a celebration.
/// Awards already seen (by id, per user) are remembered in prefs.
class AwardCelebrationHost extends StatefulWidget {
  final Widget child;

  const AwardCelebrationHost({super.key, required this.child});

  @override
  State<AwardCelebrationHost> createState() => _AwardCelebrationHostState();
}

class _AwardCelebrationHostState extends State<AwardCelebrationHost> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final userId = sl<SupabaseClient>().auth.currentUser?.id;
      if (userId == null) return;
      final awards = await sl<CommunityRepository>().getPlayerAwards();
      if (awards.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'community_award_seen_$userId';
      final award = awardToCelebrate(
        awards,
        seenId: prefs.getInt(key) ?? 0,
        now: DateTime.now(),
      );
      await prefs.setInt(
        key,
        awards.map((a) => a.id).reduce((a, b) => a > b ? a : b),
      );
      if (award == null || !mounted) return;
      await showSmoothDialog<void>(
        context: context,
        builder: (_) => CommunityAwardDialog(award: award),
      );
    } catch (e) {
      // Optional: the Arena works without it.
      debugPrint('Award celebration skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class CommunityAwardDialog extends StatelessWidget {
  final CommunityAward award;

  const CommunityAwardDialog({super.key, required this.award});

  @override
  Widget build(BuildContext context) {
    final where = award.communityType == CommunityType.global
        ? 'everyone on VitalUp'
        : award.communityName;
    final month = award.periodLabel;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusDialog),
      ),
      child: Padding(
        padding: AppDimens.cardPaddingLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppDimens.celebrationBadge,
              height: AppDimens.celebrationBadge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.rankGold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: AwardIcon(
                award.asset,
                size: AppDimens.celebrationBadge * 0.7,
              ),
            ),
            const SizedBox(height: AppDimens.space16),
            Text(
              award.place == 1
                  ? 'Champion of $month'
                  : '${awardPlaceLabel(award.place)} place for $month',
              style: context.text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.space8),
            Text(
              'You finished ${awardPlaceLabel(award.place)} among $where '
              'and earned a trophy.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppPrimaryButton(
              label: 'Nice',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
