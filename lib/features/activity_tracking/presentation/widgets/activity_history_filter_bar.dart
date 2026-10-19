import 'package:flutter/material.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_state.dart';

/// All / Outdoor / Workouts, and a search button that opens a field for
/// the activity name, tag or note. Closing the search clears it.
class ActivityHistoryFilterBar extends StatefulWidget {
  final ActivityGroup? selectedGroup;
  final ValueChanged<ActivityGroup?> onGroupSelected;
  final ValueChanged<String> onSearchChanged;

  const ActivityHistoryFilterBar({
    super.key,
    required this.selectedGroup,
    required this.onGroupSelected,
    required this.onSearchChanged,
  });

  @override
  State<ActivityHistoryFilterBar> createState() =>
      _ActivityHistoryFilterBarState();
}

class _ActivityHistoryFilterBarState extends State<ActivityHistoryFilterBar> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching && _search.text.isNotEmpty) {
      _search.clear();
      widget.onSearchChanged('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppSegmentedControl<ActivityGroup?>(
                values: const [null, ...ActivityGroup.values],
                selected: widget.selectedGroup,
                label: (group) => group?.label ?? 'All',
                onChanged: widget.onGroupSelected,
              ),
            ),
            const SizedBox(width: AppDimens.space8),
            AppHeaderAction(
              tooltip: _searching ? 'Close search' : 'Search',
              onTap: _toggleSearch,
              icon: Icon(
                _searching ? Icons.close_rounded : Icons.search_rounded,
                size: AppDimens.iconMd,
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
        if (_searching) ...[
          const SizedBox(height: AppDimens.space12),
          TextField(
            controller: _search,
            autofocus: true,
            onChanged: widget.onSearchChanged,
            maxLength: InputLimits.search,
            inputFormatters: InputFormatters.text(InputLimits.search),
            textInputAction: TextInputAction.search,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurface,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Activity, tag or note',
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
        ],
      ],
    );
  }
}
