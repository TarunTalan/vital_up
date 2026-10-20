import 'package:flutter/material.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/community/presentation/widgets/award_widgets.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/gamification/presentation/widgets/badge_widgets.dart';
import 'package:vital_up/core/utils/responsive.dart';

/// Community awards (trophies and medals, most important first), then every
/// badge: a summary, then earned and locked (closest to unlocking first)
/// grids. Tapping a badge opens its detail sheet.
class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  late Future<List<GameBadge>> _badges = _load();

  Future<List<GameBadge>> _load() =>
      sl<GamificationRepository>().getBadges().withLoadTimeout();

  void _reload() {
    setState(() {
      _badges = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      onRefresh: () async {
        _reload();
        await _badges.catchError((_) => const <GameBadge>[]);
      },
      header: const AppPageHeader(title: 'Badges'),
      body: FutureBuilder<List<GameBadge>>(
        future: _badges,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoadErrorView(onRetry: _reload);
          }
          final badges = snapshot.data;
          if (badges == null) {
            return const Center(child: VitalUpLoader());
          }
          if (badges.isEmpty) {
            return const AppInfoNote(
              message: 'No badges to show yet. Pull down to try again.',
            );
          }

          final earned = [
            for (final b in badges)
              if (b.earned) b,
          ]..sort((a, b) => b.earnedAt!.compareTo(a.earnedAt!));
          // Closest to unlocking first (a stable sort keeps the server's
          // order between equals).
          final order = {for (final (i, b) in badges.indexed) b.code: i};
          final locked =
              [
                for (final b in badges)
                  if (!b.earned) b,
              ]..sort((a, b) {
                final byProgress = (b.progressFraction ?? 0).compareTo(
                  a.progressFraction ?? 0,
                );
                return byProgress != 0
                    ? byProgress
                    : order[a.code]!.compareTo(order[b.code]!);
              });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MyCommunityAwards(),
              _SummaryCard(earned: earned.length, total: badges.length),
              const SizedBox(height: AppDimens.sectionGap),
              AppSectionHeader('Earned', count: earned.length),
              if (earned.isEmpty)
                const AppInfoNote(
                  icon: Icons.military_tech_outlined,
                  message:
                      'No badges yet. Keep logging your habits to earn '
                      'your first one.',
                )
              else
                _BadgeGrid(badges: earned),
              if (locked.isNotEmpty) ...[
                const SizedBox(height: AppDimens.sectionGap),
                AppSectionHeader('Locked', count: locked.length),
                _BadgeGrid(badges: locked),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int earned;
  final int total;

  const _SummaryCard({required this.earned, required this.total});

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final allDone = earned == total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                color: AppColors.rankGold,
                size: AppDimens.iconBadgeLarge,
                icon: Icon(Icons.military_tech_rounded),
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$earned of $total earned',
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      allDone
                          ? 'You have every badge. Nice work.'
                          : 'Each badge adds bonus points.',
                      style: context.text.bodySmall?.copyWith(color: grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space16),
          AppProgressBar(
            value: total == 0 ? 0 : earned / total,
            color: AppColors.rankGold,
          ),
        ],
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  final List<GameBadge> badges;

  const _BadgeGrid({required this.badges});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wider tiles with larger text, so names and dates stay whole.
        final columns =
            (constraints.maxWidth /
                    context.textScaled(AppDimens.badgeGridMinWidth))
                .floor()
                .clamp(2, 4);
        return Column(
          children: [
            for (var i = 0; i < badges.length; i += columns) ...[
              if (i > 0) const SizedBox(height: AppDimens.cardGap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < columns; j++) ...[
                      if (j > 0) const SizedBox(width: AppDimens.cardGap),
                      Expanded(
                        child: i + j < badges.length
                            ? BadgeTile(badge: badges[i + j])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
