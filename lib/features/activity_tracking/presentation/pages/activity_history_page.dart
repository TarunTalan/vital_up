import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_bloc.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_event.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_state.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_history_card.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_history_filter_bar.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/session_detail_sheet.dart';

/// Shows every saved activity session with date/time, key stats, and any
/// tag/note the user added, with filtering by activity type and search.
class ActivityHistoryPage extends StatelessWidget {
  const ActivityHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ActivityHistoryBloc>()..add(LoadActivityHistory()),
      child: const _ActivityHistoryView(),
    );
  }
}

class _ActivityHistoryView extends StatelessWidget {
  const _ActivityHistoryView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppScaffold(
      header: const AppPageHeader(title: 'Activity History'),
      scrollable: false,
      padBody: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          top: false,
          child: BlocBuilder<ActivityHistoryBloc, ActivityHistoryState>(
            builder: (context, state) {
              if (state is ActivityHistoryLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is ActivityHistoryError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.space24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: context.text.bodyLarge?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppDimens.space16),
                        AppSecondaryButton(
                          label: 'Retry',
                          expand: false,
                          onTap: () => context.read<ActivityHistoryBloc>().add(
                            LoadActivityHistory(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final loaded = state as ActivityHistoryLoaded;

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<ActivityHistoryBloc>().add(
                    LoadActivityHistory(),
                  );
                },
                child: Column(
                  children: [
                    const SizedBox(height: AppDimens.space16),
                    _HistorySummary(state: loaded),
                    const SizedBox(height: AppDimens.space12),
                    ActivityHistoryFilterBar(
                      selectedType: loaded.activityTypeFilter,
                      onTypeSelected: (type) => context
                          .read<ActivityHistoryBloc>()
                          .add(FilterByActivityType(type)),
                      onSearchChanged: (query) => context
                          .read<ActivityHistoryBloc>()
                          .add(SearchHistory(query)),
                    ),
                    const SizedBox(height: AppDimens.space8),
                    Expanded(
                      child: loaded.visibleEntries.isEmpty
                          ? const _EmptyHistory()
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                bottom: AppDimens.sectionGap,
                              ),
                              itemCount: loaded.visibleEntries.length,
                              itemBuilder: (context, index) {
                                final entry = loaded.visibleEntries[index];
                                return ActivityHistoryCard(
                                  entry: entry,
                                  onTap: () async {
                                    final result = await showSessionDetailSheet(
                                      context,
                                      entry: entry,
                                    );
                                    if (result != null && context.mounted) {
                                      final (tag, note) = result;
                                      context.read<ActivityHistoryBloc>().add(
                                        UpdateSessionAnnotation(
                                          sessionId: entry.session.id,
                                          tag: tag,
                                          note: note,
                                        ),
                                      );
                                    }
                                  },
                                  onDelete: () =>
                                      context.read<ActivityHistoryBloc>().add(
                                        DeleteSessionFromHistory(
                                          entry.session.id,
                                        ),
                                      ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  final ActivityHistoryLoaded state;

  const _HistorySummary({required this.state});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: context.pagePadding,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppCaption('All time'),
          const SizedBox(height: AppDimens.space12),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  value: '${state.totalSessions}',
                  label: 'Sessions',
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  value: formatDistanceKm(state.totalDistanceMeters),
                  label: 'km',
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  value: formatDuration(
                    Duration(seconds: state.totalDurationSeconds),
                  ),
                  label: 'Time',
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  value: '${state.totalCalories}',
                  label: 'Calories',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: context.text.headlineSmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.space2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconBadge(
              icon: const Icon(Icons.history_rounded),
              size: AppDimens.iconBadgeLarge,
            ),
            const SizedBox(height: AppDimens.space12),
            Text(
              'No activities match',
              style: context.text.titleSmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.space4),
            Text(
              'Try a different filter or search term.',
              style: context.text.bodyMedium?.copyWith(color: v.grayText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
