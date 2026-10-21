import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/feature_tips/data/feature_tips_service.dart';

/// In-app tips, each answered once (`FeatureTipsService.dismiss`).
abstract final class FeatureTipKeys {
  /// Workout screen: save maps before going somewhere without signal.
  static const offlineMaps = 'offline_maps';

  /// Sleep sheet: the arc moves the whole night.
  static const sleepDial = 'sleep_dial';

  /// Scan tab: barcodes are exact and free, how to frame a meal.
  static const scanTab = 'scan_tab';
}

/// The app's tips, or null where they aren't set up (widget tests that
/// build one page without the app's services): no tip shows then.
FeatureTipsService? featureTipsOrNull() =>
    sl.isRegistered<FeatureTipsService>() ? sl<FeatureTipsService>() : null;
