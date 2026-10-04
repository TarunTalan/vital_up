import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';

final _count = NumberFormat.compact();

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

/// Round avatar from a URL, falling back to the username's initial.
class UserAvatar extends StatelessWidget {
  final String username;
  final String? url;
  final double size;
  final Color? ringColor;

  const UserAvatar({
    super.key,
    required this.username,
    this.url,
    this.size = AppDimens.avatarSmall,
    this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final initial = username.isEmpty
        ? '?'
        : username.characters.first.toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: context.text.titleSmall?.copyWith(color: context.colors.primary),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.primary.withValues(alpha: 0.15),
        border: ringColor == null
            ? null
            : Border.all(color: ringColor!, width: AppDimens.borderThick),
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipOval(
        child: url == null || url!.isEmpty
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// A community row: icon, name, what it ranks on and member count, with an
/// optional trailing action.
class CommunityTile extends StatelessWidget {
  final Community community;
  final VoidCallback onTap;
  final Widget? trailing;

  const CommunityTile({
    super.key,
    required this.community,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final members = community.memberCount;
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      onTap: onTap,
      child: Row(
        children: [
          AppIconBadge(
            color: context.colors.primary,
            icon: GameIcon(
              GamificationIcons.communityIcon(community.iconKey),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimens.space2),
                Text(
                  '${_count.format(members)} ${members == 1 ? 'member' : 'members'}'
                  ' · ${community.rankedOn}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          trailing ??
              Icon(
                Icons.arrow_forward_ios,
                color: context.colors.onSurface,
                size: AppDimens.iconXs,
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
  String? _error;

  @override
  void dispose() {
    _city.dispose();
    _country.dispose();
    super.dispose();
  }

  void _save() {
    final city = _city.text.trim();
    final country = _country.text.trim().toUpperCase();
    if (city.isNotEmpty && country.length != 2) {
      setState(() => _error = 'Use a 2-letter country code, like IN');
      return;
    }
    Navigator.of(context).pop((city, country));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.space16 + MediaQuery.viewInsetsOf(context).bottom,
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
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
            ),
            const SizedBox(height: AppDimens.space12),
            AppTextField(
              controller: _country,
              label: 'Country code',
              hint: 'IN',
              error: _error,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              inputFormatters: [LengthLimitingTextInputFormatter(2)],
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
