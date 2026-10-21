import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/activity_tracking/data/services/offline_map_service.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/offline_map_area.dart';

/// Offline maps for outdoor workouts (route `offline-maps`, from Activity
/// settings): the area kept around the user, the areas the user saved,
/// and "Download a new area" (the picker). Downloads carry on with the
/// page closed.
class OfflineMapsPage extends StatefulWidget {
  /// Null: the app's service.
  final OfflineMapService? service;

  const OfflineMapsPage({super.key, this.service});

  @override
  State<OfflineMapsPage> createState() => _OfflineMapsPageState();
}

class _OfflineMapsPageState extends State<OfflineMapsPage> {
  late final OfflineMapService _maps =
      widget.service ?? sl<OfflineMapService>();

  @override
  void initState() {
    super.initState();
    _maps.refresh();
  }

  void _openPicker(OfflineMapsState state) {
    if (!_maps.canSaveMore) {
      showErrorSnackBar(
        context,
        'You can keep ${OfflineMapRules.maxSavedAreas} maps. '
        'Delete one first.',
      );
      return;
    }
    context.pushNamed('offline-map-picker');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineMapsState>(
      valueListenable: _maps.state,
      builder: (context, state, _) {
        if (!state.loaded) {
          return AppScaffold(
            header: const AppPageHeader(title: 'Offline maps'),
            body: const Center(child: VitalUpLoader()),
          );
        }
        final saved = state.saved;
        return AppScaffold(
          header: const AppPageHeader(title: 'Offline maps'),
          onRefresh: _maps.refresh,
          bottomBar: AppPrimaryButton(
            label: 'Download a new area',
            leadingIcon: const Icon(Icons.add_rounded),
            onTap: () => _openPicker(state),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppInfoNote(
                message:
                    'Workouts record without signal. Save the map of '
                    'places you go so it shows there too.',
              ),
              const SizedBox(height: AppDimens.sectionGap),
              const AppSectionHeader('Around you'),
              const SizedBox(height: AppDimens.space8),
              _AutoAreaCard(maps: _maps, state: state),
              const SizedBox(height: AppDimens.sectionGap),
              AppSectionHeader(
                'Saved areas',
                note: state.totalBytes > 0
                    ? 'All maps: ${OfflineMapRules.sizeLabel(state.totalBytes)}'
                    : null,
              ),
              const SizedBox(height: AppDimens.space8),
              if (saved.isEmpty)
                Text(
                  'Going somewhere new? Save its map before you go.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.vColors.grayText,
                  ),
                )
              else
                for (final (i, area) in saved.indexed) ...[
                  if (i > 0) const SizedBox(height: AppDimens.space12),
                  _AreaCard(
                    area: area,
                    state: state,
                    onResume: () => _maps.resume(area.id),
                    onDelete: () => _maps.delete(area.id),
                  ),
                ],
            ],
          ),
        );
      },
    );
  }
}

/// "20 × 20 km · 38 MB · Saved 22 Oct", or the download's progress.
String offlineAreaStatus(
  OfflineMapArea area,
  OfflineMapsState state, {
  DateTime? now,
}) {
  if (area.id == state.downloadingId) {
    return 'Downloading · ${(state.downloadProgress * 100).floor()}%';
  }
  if (state.queuedIds.contains(area.id)) return 'Waiting to download';
  if (!area.complete) {
    final percent = (area.progress * 100).floor();
    return percent > 0 ? 'Download stopped at $percent%' : 'Download stopped';
  }
  final parts = [
    OfflineMapRules.sideLabel(area.radiusKm),
    OfflineMapRules.sizeLabel(area.sizeBytes),
  ];
  if (area.savedAt case final savedAt?) {
    final clock = now ?? DateTime.now();
    final date = DateFormat(
      savedAt.year == clock.year ? 'd MMM' : 'd MMM y',
    ).format(savedAt);
    parts.add('${area.isAuto ? 'Updated' : 'Saved'} $date');
  }
  return parts.join(' · ');
}

class _AutoAreaCard extends StatelessWidget {
  final OfflineMapService maps;
  final OfflineMapsState state;

  const _AutoAreaCard({required this.maps, required this.state});

  @override
  Widget build(BuildContext context) {
    final auto = state.auto;
    final enabled = maps.autoEnabled;
    final grey = context.vColors.grayText;
    final String status;
    if (!enabled) {
      status = 'Off';
    } else if (auto == null) {
      status = 'Saved when you next open the workout map';
    } else {
      status = offlineAreaStatus(auto, state);
    }
    final downloading = auto != null && state.isBusy(auto.id);
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppIconBadge(icon: Icon(Icons.my_location_rounded)),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Map around you',
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      status,
                      style: context.text.bodySmall?.copyWith(color: grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Switch(
                value: enabled,
                onChanged: downloading && enabled
                    ? null
                    : (value) => maps.setAutoEnabled(value),
              ),
            ],
          ),
          if (downloading && auto.id == state.downloadingId) ...[
            const SizedBox(height: AppDimens.space12),
            AppProgressBar(value: state.downloadProgress),
          ],
          const SizedBox(height: AppDimens.space12),
          Text(
            'A 20 × 20 km map, kept up to date when you move. '
            'Uses mobile data when there is no Wi-Fi.',
            style: context.text.bodySmall?.copyWith(color: grey),
          ),
        ],
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final OfflineMapArea area;
  final OfflineMapsState state;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const _AreaCard({
    required this.area,
    required this.state,
    required this.onResume,
    required this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final delete = await showSmoothDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${area.name}?'),
        content: const Text(
          'Its map won\'t show without signal. You can download it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.colors.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete == true) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final downloading = area.id == state.downloadingId;
    final stopped = !area.complete && !state.isBusy(area.id);
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: Icon(
                  area.complete
                      ? Icons.map_rounded
                      : Icons.download_for_offline_rounded,
                ),
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.name,
                      style: context.text.titleSmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      offlineAreaStatus(area, state),
                      style: context.text.bodySmall?.copyWith(color: grey),
                    ),
                  ],
                ),
              ),
              // The map SDK can't stop a download under way.
              if (!downloading) ...[
                const SizedBox(width: AppDimens.space4),
                IconButton(
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(context),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: AppDimens.iconMd,
                    color: grey,
                  ),
                ),
              ],
            ],
          ),
          if (downloading) ...[
            const SizedBox(height: AppDimens.space12),
            AppProgressBar(value: state.downloadProgress),
          ],
          if (stopped) ...[
            const SizedBox(height: AppDimens.space8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Resume download'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
