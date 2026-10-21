import 'package:flutter/material.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/activity_tracking/data/services/offline_map_service.dart';

/// Over the workout map with no connection and no saved map at this spot:
/// says the map may be blank but the workout still records (GPS needs no
/// network). Nothing otherwise. With [onTap] (before a workout) it opens
/// Offline maps, ending in a chevron.
class OfflineMapNote extends StatelessWidget {
  final VoidCallback? onTap;
  final double? latitude;
  final double? longitude;
  final OfflineMapService maps;
  final ConnectivityService connectivity;

  const OfflineMapNote({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.maps,
    required this.connectivity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: connectivity.onlineChanges,
      initialData: connectivity.isOnline,
      builder: (context, online) {
        if (online.data ?? true) return const SizedBox.shrink();
        return ValueListenableBuilder<OfflineMapsState>(
          valueListenable: maps.state,
          builder: (context, state, _) {
            // Unknown until read: say nothing rather than something wrong.
            if (!state.loaded || state.covers(lat, lng)) {
              return const SizedBox.shrink();
            }
            final grey = context.vColors.grayText;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                AppDimens.space8,
                context.gutter,
                0,
              ),
              child: AppCard(
                onTap: onTap,
                radius: AppDimens.radiusToast,
                blur: false,
                shadow: AppShadows.shadowY,
                tint: context.vColors.surfaceElevated,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space12,
                  vertical: AppDimens.space8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: AppDimens.iconSm,
                      color: grey,
                    ),
                    const SizedBox(width: AppDimens.space8),
                    Expanded(
                      child: Text(
                        'No offline map here. Your workout still records.',
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: AppDimens.space4),
                      const AppChevron(),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
