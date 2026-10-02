import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/features/notifications/domain/entities/app_notification.dart';
import 'package:vital_up/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:vital_up/features/notifications/presentation/widgets/notification_widgets.dart';

/// Every notification: friend requests (answerable in place), badges,
/// level-ups, streaks and app announcements. Expects a
/// [NotificationsCubit] above it (the dashboard's, passed via the route).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  NotificationFilter _filter = NotificationFilter.all;

  void _open(AppNotification n) {
    context.read<NotificationsCubit>().markRead(n);
    final route = notificationRoute(n.type, n.route);
    if (route != null) context.pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationsCubit, NotificationsState>(
      listenWhen: (prev, next) => next.messageId != prev.messageId,
      listener: (context, s) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.message!))),
      builder: (context, state) {
        final cubit = context.read<NotificationsCubit>();
        final items = state.items;
        final visible = [
          for (final n in items ?? const <AppNotification>[])
            if (_filter.matches(n)) n,
        ];

        return AppScaffold(
          scrollable: false,
          padBody: false,
          header: AppPageHeader(
            title: 'Notifications',
            subtitle: state.unreadCount == 0
                ? null
                : '${state.unreadCount} unread',
            action: state.unreadCount == 0
                ? null
                : AppHeaderAction(
                    tooltip: 'Mark all as read',
                    onTap: cubit.markAllRead,
                    icon: const Icon(Icons.done_all_rounded),
                  ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDimens.space16),
              SizedBox(
                height: MediaQuery.textScalerOf(
                  context,
                ).scale(AppDimens.headerActionSize - AppDimens.space4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: context.pagePadding,
                  itemCount: NotificationFilter.values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppDimens.space8),
                  itemBuilder: (context, i) {
                    final f = NotificationFilter.values[i];
                    return NotificationFilterChip(
                      label: f.label,
                      selected: f == _filter,
                      onTap: () => setState(() => _filter = f),
                    );
                  },
                ),
              ),
              Expanded(
                child: items == null
                    ? state.failed
                          ? LoadErrorView(onRetry: cubit.load)
                          : const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: cubit.refresh,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: context.pagePadding.add(
                            EdgeInsets.only(
                              top: AppDimens.sectionGap,
                              bottom:
                                  context.safePadding.bottom +
                                  AppDimens.sectionGap,
                            ),
                          ),
                          itemCount: visible.isEmpty ? 1 : visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppDimens.cardGap),
                          itemBuilder: (context, i) {
                            if (visible.isEmpty) {
                              return AppInfoNote(
                                icon: Icons.notifications_none_rounded,
                                message: _filter == NotificationFilter.all
                                    ? "You're all caught up. Friend requests, "
                                          'badges and updates will show up '
                                          'here.'
                                    : 'No ${_filter.label.toLowerCase()} '
                                          'notifications yet.',
                              );
                            }
                            final n = visible[i];
                            return Dismissible(
                              key: ValueKey(n.id),
                              direction: n.isPendingRequest
                                  ? DismissDirection.none
                                  : DismissDirection.endToStart,
                              onDismissed: (_) => cubit.remove(n),
                              background: _DismissBackground(),
                              child: NotificationTile(
                                notification: n,
                                busy: state.busy.contains(n.id),
                                onTap: () => _open(n),
                                onAccept: () => cubit.respond(n, accept: true),
                                onDecline: () =>
                                    cubit.respond(n, accept: false),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.symmetric(horizontal: AppDimens.space20),
    decoration: BoxDecoration(
      color: context.vColors.errorFill,
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
    ),
    child: Icon(Icons.delete_outline_rounded, color: context.colors.error),
  );
}
