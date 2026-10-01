import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';

class AppBottomNavItem {
  final String label;
  final String iconAsset;

  const AppBottomNavItem(this.label, this.iconAsset);
}

/// Floating pill bottom bar — Figma `bars & panels/tab`: lighter fill,
/// radius 58, "elevated" shadow, 32 icons + small 12 labels; the selected
/// item gets a darker label and a soft cyan glow behind its icon.
class AppBottomNav extends StatelessWidget {
  final List<AppBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final horizontalPadding = context.isSmallPhone
        ? AppDimens.space8
        : AppDimens.navBarPadding.horizontal / 2;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.gutter,
              0,
              context.gutter,
              AppDimens.navBarBottomOffset,
            ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AppDimens.navBarPadding.vertical / 2,
            ),
            decoration: BoxDecoration(
              color: v.navBg,
              borderRadius: BorderRadius.circular(AppDimens.radiusNavBar),
              boxShadow: AppShadows.elevated,
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavItem(
                      item: items[i],
                      selected: selectedIndex == i,
                      onTap: () => onItemSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final primary = context.colors.primary;
    final iconColor = selected ? primary : v.navSelected!;
    final labelColor = selected ? v.navSelected : v.navUnselected;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppDimens.navBarItemHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: AppDurations.medium,
                curve: Curves.easeOut,
                width: AppDimens.iconLg,
                height: AppDimens.iconLg,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: selected ? 0.35 : 0),
                      primary.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: SvgPicture.asset(
                  item.iconAsset,
                  width: AppDimens.iconLg,
                  height: AppDimens.iconLg,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
              const SizedBox(height: AppDimens.space4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: AppDurations.medium,
                  curve: Curves.easeOut,
                  style: context.text.labelSmall!.copyWith(color: labelColor),
                  child: Text(item.label, maxLines: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
