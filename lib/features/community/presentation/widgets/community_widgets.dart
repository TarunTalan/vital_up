import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/domain/entities/community_standing.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

export 'package:vital_up/core/widgets/user_avatar.dart';

final _count = NumberFormat.compact();
final _rankFormat = NumberFormat.decimalPattern();

IconData communityFallbackIcon(Community c) => switch (c.type) {
  CommunityType.global => Icons.public_rounded,
  CommunityType.local => Icons.location_city_rounded,
  CommunityType.friends => Icons.people_alt_rounded,
  CommunityType.interest => switch (c.slug) {
    'runners' || 'joggers' => Icons.directions_run_rounded,
    'strength' => Icons.fitness_center_rounded,
    'dieting' => Icons.restaurant_rounded,
    'mindful' => Icons.self_improvement_rounded,
    'weight-loss' => Icons.monitor_weight_rounded,
    _ => Icons.groups_rounded,
  },
};

String communityIconAsset(Community c) {
  if (c.slug.toLowerCase().contains('weight') ||
      c.iconKey.toLowerCase().contains('weight') ||
      c.name.toLowerCase().contains('weight')) {
    return 'assets/icons/trackers/weight_icon.svg';
  }
  if (c.slug.toLowerCase().contains('step') ||
      c.iconKey.toLowerCase().contains('step') ||
      c.name.toLowerCase().contains('step') ||
      c.slug.toLowerCase().contains('walk') ||
      c.iconKey.toLowerCase().contains('walk') ||
      c.name.toLowerCase().contains('walk')) {
    return 'assets/icons/trackers/step.svg';
  }
  if (c.slug.toLowerCase().contains('activity') ||
      c.iconKey.toLowerCase().contains('activity') ||
      c.name.toLowerCase().contains('activity') ||
      c.slug.toLowerCase().contains('workout') ||
      c.iconKey.toLowerCase().contains('workout') ||
      c.name.toLowerCase().contains('workout') ||
      c.slug.toLowerCase().contains('runner') ||
      c.slug.toLowerCase().contains('jogger')) {
    return 'assets/icons/trackers/activity.svg';
  }
  return GamificationIcons.communityIcon(c.iconKey);
}

/// A community row for an [AppListGroup]: icon, name, member count and
/// what it ranks on (or how many friends are ranked there), with an
/// optional trailing action. With a [standing], the caller's rank this week
/// replaces the chevron. Text wraps rather than being cut off.
class CommunityTile extends StatelessWidget {
  final Community community;
  final VoidCallback onTap;
  final Widget? trailing;
  final CommunityStanding? standing;

  const CommunityTile({
    super.key,
    required this.community,
    required this.onTap,
    this.trailing,
    this.standing,
  });

  @override
  Widget build(BuildContext context) {
    final members = community.memberCount;
    final friends = standing?.friendCount ?? 0;
    final rank = standing?.rank;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space16,
          vertical: AppDimens.space10,
        ),
        child: Row(
          children: [
            AppIconBadge(
              color: context.colors.primary,
              icon: GameIcon(
                communityIconAsset(community),
                fallback: communityFallbackIcon(community),
                size: AppDimens.iconMd,
              ),
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.name,
                    style: context.text.titleSmall?.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimens.space2),
                  Text(
                    '${_count.format(members)} ${members == 1 ? 'member' : 'members'}'
                    ' · ${friends > 0 ? '$friends ${friends == 1 ? 'friend' : 'friends'} ranked' : community.rankedOn}',
                    style: context.text.bodySmall?.copyWith(
                      color: context.vColors.grayText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.space8),
            // A Join button replaces the chevron (the sheet); otherwise the
            // row opens the leaderboard, with your rank before the chevron.
            if (trailing case final trailing?)
              trailing
            else ...[
              if (rank != null) ...[
                _RankBadge(rank: rank),
                const SizedBox(width: AppDimens.space4),
              ],
              const AppChevron(),
            ],
          ],
        ),
      ),
    );
  }
}

/// "#12 / this week" on a community tile.
class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'You are ranked $rank this week',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#${_rankFormat.format(rank)}',
            style: context.text.titleSmall?.copyWith(
              color: context.vColors.accentText,
            ),
          ),
          Text(
            'this week',
            style: context.text.labelSmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ],
      ),
    );
  }
}

/// A grid-style card for a community.
class CommunityGridCard extends StatelessWidget {
  final Community community;
  final VoidCallback onTap;
  final Widget? action;

  const CommunityGridCard({
    super.key,
    required this.community,
    required this.onTap,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final members = community.memberCount;
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.space12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                color: context.colors.primary,
                icon: GameIcon(
                  communityIconAsset(community),
                  fallback: communityFallbackIcon(community),
                  size: AppDimens.iconSm,
                ),
              ),
              const Spacer(),
              ?action,
            ],
          ),
          const SizedBox(height: AppDimens.space12),
          Text(
            community.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(
              color: context.colors.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppDimens.space4),
          Text(
            '${_count.format(members)} members',
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            community.rankedOn,
            style: context.text.labelSmall?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet asking for the user's city; pops with `(city, country)`.
class CitySheet extends StatefulWidget {
  final String? city;
  final String? countryCode;

  const CitySheet({super.key, this.city, this.countryCode});

  static const defaultCountry = 'IN';

  @override
  State<CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<CitySheet> {
  late final _city = TextEditingController(text: widget.city ?? '');
  late final _country = TextEditingController(
    text: widget.countryCode ?? CitySheet.defaultCountry,
  );
  String? _cityError;
  String? _countryError;

  @override
  void dispose() {
    _city.dispose();
    _country.dispose();
    super.dispose();
  }

  void _save() {
    final city = sanitizeText(_city.text, maxLength: InputLimits.city);
    final country = sanitizeText(_country.text).toUpperCase();
    final cityError = cityInputError(city);
    final countryError = countryCodeInputError(city, country);
    if (cityError != null || countryError != null) {
      setState(() {
        _cityError = cityError;
        _countryError = countryError;
      });
      return;
    }
    Navigator.of(context).pop((city, city.isEmpty ? '' : country));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your city', style: context.text.headlineSmall),
            const SizedBox(height: AppDimens.space8),
            Text(
              'Join the leaderboard for people near you. Only your city is '
              'shared, never your location.',
              style: context.text.bodyMedium?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppTextField(
              controller: _city,
              label: 'City',
              hint: 'e.g. Bengaluru',
              autofocus: true,
              error: _cityError,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              inputFormatters: InputFormatters.text(InputLimits.city),
              onChanged: (_) {
                if (_cityError != null) setState(() => _cityError = null);
              },
            ),
            const SizedBox(height: AppDimens.space12),
            AppTextField(
              controller: _country,
              label: 'Country code',
              hint: 'IN',
              error: _countryError,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                LengthLimitingTextInputFormatter(2),
              ],
              onChanged: (_) {
                if (_countryError != null) {
                  setState(() => _countryError = null);
                }
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppPrimaryButton(label: 'Save', onTap: _save),
            if ((widget.city ?? '').isNotEmpty) ...[
              const SizedBox(height: AppDimens.buttonGap),
              AppSecondaryButton(
                label: 'Leave local community',
                onTap: () => Navigator.of(context).pop(('', '')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
