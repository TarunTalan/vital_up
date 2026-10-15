import 'package:flutter/material.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/gamification/presentation/widgets/flip_badge_card.dart';

/// Every badge, earned ones first in full colour, locked ones dimmed.
class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  late Future<List<GameBadge>> _badges = _load();

  Future<List<GameBadge>> _load() =>
      sl<GamificationRepository>().getBadges().withLoadTimeout();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      onRefresh: () async => setState(() {
        _badges = _load();
      }),
      header: const AppPageHeader(title: 'Badges'),
      body: FutureBuilder<List<GameBadge>>(
        future: _badges,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoadErrorView(
              onRetry: () => setState(() {
                _badges = _load();
              }),
            );
          }
          final badges = snapshot.data;
          if (badges == null) {
            return const Center(child: VitalUpLoader());
          }
          final earned = badges.where((b) => b.earned).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$earned of ${badges.length} earned',
                    style: context.text.titleSmall?.copyWith(
                      color: context.vColors.grayText,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 13,
                        color: context.vColors.grayText,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Tap to view goal',
                        style: context.text.labelSmall?.copyWith(
                          fontSize: 10,
                          color: context.vColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      (constraints.maxWidth / AppDimens.badgeGridMinWidth)
                          .floor()
                          .clamp(2, 6);
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppDimens.cardGap,
                    crossAxisSpacing: AppDimens.cardGap,
                    childAspectRatio: AppDimens.badgeTileAspect,
                    children: [
                      for (final b in [
                        ...badges.where((b) => b.earned),
                        ...badges.where((b) => !b.earned),
                      ])
                        BadgeTile(badge: b),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// An achievement badge card that flips 180° around with a 3D perspective
/// animation on click, revealing the goal and requirements to earn it.
class BadgeTile extends StatelessWidget {
  final GameBadge badge;

  const BadgeTile({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    return FlipBadgeCard(badge: badge);
  }
}
