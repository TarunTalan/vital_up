import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_bloc.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_event.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_state.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_history_card.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_history_filter_bar.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/log_workout_sheet.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/session_detail_sheet.dart';

/// Every saved activity, newest first, laid out like the other log
/// histories (meals): one card per entry with its kind, when, a delete
/// button and its figures. An All / Outdoor / Workouts filter and search
/// sit above the list.
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

  void _reload(BuildContext context) =>
      context.read<ActivityHistoryBloc>().add(LoadActivityHistory());

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: AppPageHeader(
        title: 'Activity history',
        action: AppHeaderAction(
          icon: const Icon(Icons.add_rounded),
          tooltip: 'Log a workout',
          onTap: () async {
            final saved = await showLogWorkoutSheet(context);
            if (!saved || !context.mounted) return;
            showSuccessSnackBar(context, 'Workout saved');
            _reload(context);
          },
        ),
      ),
      scrollable: false,
      padBody: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () async {
              final done = Completer<void>();
              context.read<ActivityHistoryBloc>().add(
                LoadActivityHistory(done: done),
              );
              // The spinner stays until the list has reloaded.
              await done.future.timeout(kLoadTimeout, onTimeout: () {});
            },
            child: BlocConsumer<ActivityHistoryBloc, ActivityHistoryState>(
              listenWhen: (previous, current) =>
                  current is ActivityHistoryLoaded &&
                  current.actionError != null &&
                  (previous is! ActivityHistoryLoaded ||
                      previous.actionErrorId != current.actionErrorId),
              listener: (context, state) {
                final message = (state as ActivityHistoryLoaded).actionError;
                if (message != null) showErrorSnackBar(context, message);
              },
              builder: (context, state) {
                if (state is ActivityHistoryLoading) {
                  return const Center(child: VitalUpLoader());
                }
                if (state is ActivityHistoryError) {
                  return _FullHeight(
                    child: LoadErrorView(
                      message: state.message,
                      onRetry: () => _reload(context),
                    ),
                  );
                }
                final loaded = state as ActivityHistoryLoaded;
                if (loaded.allEntries.isEmpty) {
                  return const _FullHeight(
                    child: TrackerEmptyState(
                      metric: TrackerMetric.activity,
                      title: 'No activities yet',
                      message: 'Your finished workouts will show up here.',
                    ),
                  );
                }
                return _HistoryList(state: loaded);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Centres [child] in a scrollable, so pull-to-refresh still works.
class _FullHeight extends StatelessWidget {
  final Widget child;

  const _FullHeight({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        padding: context.pagePadding,
        child: child,
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final ActivityHistoryLoaded state;

  const _HistoryList({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ActivityHistoryBloc>();
    final entries = state.visibleEntries;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
        horizontal: context.gutter,
        vertical: AppDimens.sectionGap,
      ),
      // The filter first, then the entries (or why there are none).
      itemCount: 1 + (entries.isEmpty ? 1 : entries.length),
      separatorBuilder: (_, _) => const SizedBox(height: AppDimens.cardGap),
      itemBuilder: (context, index) {
        if (index == 0) {
          return ActivityHistoryFilterBar(
            selectedGroup: state.groupFilter,
            onGroupSelected: (group) => bloc.add(FilterByActivityGroup(group)),
            onSearchChanged: (query) => bloc.add(SearchHistory(query)),
          );
        }
        if (entries.isEmpty) {
          return const TrackerEmptyState(
            metric: TrackerMetric.activity,
            title: 'No activities match',
            message: 'Try a different filter or search term.',
          );
        }
        final entry = entries[index - 1];
        return ActivityHistoryCard(
          entry: entry,
          onTap: () async {
            final result = await showSessionDetailSheet(context, entry: entry);
            if (result == null || !context.mounted) return;
            final (tag, note) = result;
            bloc.add(
              UpdateSessionAnnotation(
                sessionId: entry.session.id,
                tag: tag,
                note: note,
              ),
            );
          },
          onDelete: () => bloc.add(DeleteSessionFromHistory(entry.session.id)),
        );
      },
    );
  }
}
