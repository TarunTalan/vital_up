import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.onSurface,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Center(
            child: BackIcon(
              onClick: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        title: Text(
          'ACTIVITY HISTORY',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: colors.onSurface,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SafeArea(
              child: BlocBuilder<ActivityHistoryBloc, ActivityHistoryState>(
                builder: (context, state) {
                  if (state is ActivityHistoryLoading) {
                    return Center(child: CircularProgressIndicator(color: colors.primary));
                  }

                  if (state is ActivityHistoryError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(state.message, textAlign: TextAlign.center, style: TextStyle(color: colors.onSurface)),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () =>
                                  context.read<ActivityHistoryBloc>().add(LoadActivityHistory()),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: colors.primary),
                                foregroundColor: colors.primary,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final loaded = state as ActivityHistoryLoaded;

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<ActivityHistoryBloc>().add(LoadActivityHistory());
                    },
                    color: colors.primary,
                    child: Column(
                      children: [
                        _HistorySummary(state: loaded),
                        const SizedBox(height: 12),
                        ActivityHistoryFilterBar(
                          selectedType: loaded.activityTypeFilter,
                          onTypeSelected: (type) =>
                              context.read<ActivityHistoryBloc>().add(FilterByActivityType(type)),
                          onSearchChanged: (query) =>
                              context.read<ActivityHistoryBloc>().add(SearchHistory(query)),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: loaded.visibleEntries.isEmpty
                              ? const _EmptyHistory()
                              : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
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
                                onDelete: () => context
                                    .read<ActivityHistoryBloc>()
                                    .add(DeleteSessionFromHistory(entry.session.id)),
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
        ],
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  final ActivityHistoryLoaded state;

  const _HistorySummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light 
            ? Colors.white.withValues(alpha: 0.72) 
            : colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: (theme.brightness == Brightness.light 
              ? const Color(0xFFD8D8D8) 
              : colors.outline).withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              value: '${state.totalSessions}',
              label: 'SESSIONS',
            ),
          ),
          Expanded(
            child: _SummaryStat(
              value: formatDistanceKm(state.totalDistanceMeters),
              label: 'KM',
            ),
          ),
          Expanded(
            child: _SummaryStat(
              value: formatDuration(Duration(seconds: state.totalDurationSeconds)),
              label: 'TIME',
            ),
          ),
          Expanded(
            child: _SummaryStat(
              value: '${state.totalCalories}',
              label: 'CALORIES',
            ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            color: customColors?.grayText ?? const Color(0xFF9A9A9A),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: colors.outline),
            const SizedBox(height: 12),
            Text(
              'No activities match',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: colors.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different filter or search term.',
              style: TextStyle(color: customColors?.grayText ?? const Color(0xFF9A9A9A)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}