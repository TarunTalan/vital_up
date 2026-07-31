import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'dart:ui';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';

/// Horizontal row of activity-type filter chips plus a search box for
/// filtering by tag/note text.
class ActivityHistoryFilterBar extends StatelessWidget {
  final ActivityType? selectedType;
  final ValueChanged<ActivityType?> onTypeSelected;
  final ValueChanged<String> onSearchChanged;

  const ActivityHistoryFilterBar({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: 'All',
                selected: selectedType == null,
                onTap: () => onTypeSelected(null),
              ),
              const SizedBox(width: 8),
              for (final type in ActivityType.values) ...[
                _FilterChip(
                  label: type.label,
                  icon: activityTypeIcon(type),
                  selected: selectedType == type,
                  onTap: () => onTypeSelected(type),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.hPadding),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.light
                      ? Colors.white.withValues(alpha: 0.80)
                      : colors.surface.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (theme.brightness == Brightness.light
                            ? const Color(0xFFD8D8D8)
                            : colors.outline)
                        .withValues(alpha: 0.72),
                  ),
                ),
                child: TextField(
                  onChanged: onSearchChanged,
                  style: TextStyle(color: colors.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by tag or note…',
                    hintStyle: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.4),
                        fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 20,
                        color: colors.onSurface.withValues(alpha: 0.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          border: Border.all(
            color: selected ? colors.primary : colors.outline.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? (customColors?.buttonText ?? Colors.black) : colors.onSurface),
              const SizedBox(width: 6),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: selected ? (customColors?.buttonText ?? Colors.black) : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}