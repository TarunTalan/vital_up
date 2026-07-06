import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Activity History',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
        ),
      ),
      body: BlocBuilder<ActivityHistoryBloc, ActivityHistoryState>(
        builder: (context, state) {
          if (state is ActivityHistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ActivityHistoryError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          context.read<ActivityHistoryBloc>().add(LoadActivityHistory()),
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
    );
  }
}

class _HistorySummary extends StatelessWidget {
  final ActivityHistoryLoaded state;

  const _HistorySummary({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
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
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFF9A9A9A),
            fontWeight: FontWeight.w700,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 48, color: Color(0xFFBDBDBD)),
            const SizedBox(height: 12),
            const Text(
              'No activities match',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try a different filter or search term.',
              style: TextStyle(color: Color(0xFF9A9A9A)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}