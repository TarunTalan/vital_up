import 'package:flutter/material.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_state.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';

/// Horizontal row of filter chips (All, Outdoor, Workouts, then one per
/// recorded type) plus a search box for filtering by tag/note text.
class ActivityHistoryFilterBar extends StatelessWidget {
  final ActivityGroup? selectedGroup;
  final ActivityType? selectedType;

  /// Types the user has sessions of; only these get a chip.
  final List<ActivityType> types;
  final ValueChanged<ActivityGroup?> onGroupSelected;
  final ValueChanged<ActivityType?> onTypeSelected;
  final ValueChanged<String> onSearchChanged;

  const ActivityHistoryFilterBar({
    super.key,
    required this.selectedGroup,
    required this.selectedType,
    required this.types,
    required this.onGroupSelected,
    required this.onTypeSelected,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final chipHeight = context
        .textScaled(AppDimens.headerActionSize - AppDimens.space4)
        .clamp(AppDimens.headerActionSize - AppDimens.space4, double.infinity);

    return Column(
      children: [
        SizedBox(
          height: chipHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: context.pagePadding,
            children: [
              _FilterChip(
                label: 'All',
                selected: selectedType == null && selectedGroup == null,
                onTap: () => onGroupSelected(null),
              ),
              const SizedBox(width: AppDimens.space8),
              for (final group in ActivityGroup.values) ...[
                _FilterChip(
                  label: group.label,
                  selected: selectedGroup == group,
                  onTap: () => onGroupSelected(group),
                ),
                const SizedBox(width: AppDimens.space8),
              ],
              for (final type in types) ...[
                _FilterChip(
                  label: type.label,
                  icon: activityTypeIcon(type),
                  selected: selectedType == type,
                  onTap: () => onTypeSelected(type),
                ),
                const SizedBox(width: AppDimens.space8),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimens.space12),
        Padding(
          padding: context.pagePadding,
          child: TextField(
            onChanged: onSearchChanged,
            maxLength: InputLimits.search,
            inputFormatters: InputFormatters.text(InputLimits.search),
            textInputAction: TextInputAction.search,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurface,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Search by tag or note…',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: AppDimens.iconMd,
                color: v.grayText,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppDimens.space12,
                horizontal: AppDimens.space16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final fg = selected ? v.buttonText! : context.colors.onSurface;
    final radius = BorderRadius.circular(AppDimens.radiusPill);

    return Material(
      color: selected ? context.colors.primary : v.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? context.colors.primary : v.glassBorder!,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.space12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppDimens.iconXs, color: fg),
                const SizedBox(width: AppDimens.space6),
              ],
              Text(
                label,
                style: context.text.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
