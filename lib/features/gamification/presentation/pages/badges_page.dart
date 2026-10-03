import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/features/gamification/domain/entities/game_badge.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

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
      onRefresh: () async => setState(() => _badges = _load()),
      header: const AppPageHeader(title: 'Badges'),
      body: FutureBuilder<List<GameBadge>>(
        future: _badges,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoadErrorView(
              onRetry: () => setState(() => _badges = _load()),
            );
          }
          final badges = snapshot.data;
          if (badges == null) {
            return const Padding(
              padding: EdgeInsets.only(top: AppDimens.space48),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final earned = badges.where((b) => b.earned).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$earned of ${badges.length} earned',
                style: context.text.titleSmall?.copyWith(
                  color: context.vColors.grayText,
                ),
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

class BadgeTile extends StatelessWidget {
  final GameBadge badge;

  const BadgeTile({super.key, required this.badge});

  void _showDetails(BuildContext context) {
    final earnedAt = badge.earnedAt;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            earnedAt != null
                ? '${badge.name}: earned ${DateFormat.yMMMd().format(earnedAt.toLocal())}'
                : '${badge.name}: ${badge.description}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final color = badge.earned ? AppColors.rankGold : context.vColors.grayText!;
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.space8),
      onTap: () => _showDetails(context),
      child: Opacity(
        opacity: badge.earned ? 1 : AppDimens.badgeLockedOpacity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconBadge(
              size: AppDimens.badgeTile,
              color: color,
              icon: GameIcon(
                GamificationIcons.badge(badge.iconKey),
                fallback: badge.earned
                    ? Icons.military_tech_rounded
                    : Icons.lock_outline_rounded,
                size: AppDimens.iconXl,
                color: color,
              ),
            ),
            const SizedBox(height: AppDimens.space8),
            Text(
              badge.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
