import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const String _androidWidgetProvider = 'VitalUpWidgetProvider';
  static const String _iOSWidget = 'VitalUpWidget';

  static const String keySteps = 'widget_steps';
  static const String keyStepGoal = 'widget_step_goal';
  static const String keyWaterMl = 'widget_water_ml';
  static const String keyWaterGoalMl = 'widget_water_goal_ml';
  static const String keySleepScore = 'widget_sleep_score';
  static const String keyLastUpdated = 'widget_last_updated';

  /// Updates data displayed on the Android and iOS home screen widgets
  static Future<void> updateDashboardWidget({
    int steps = 0,
    int stepGoal = 10000,
    int waterMl = 0,
    int waterGoalMl = 2500,
    int sleepScore = 85,
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>(keySteps, steps);
      await HomeWidget.saveWidgetData<int>(keyStepGoal, stepGoal);
      await HomeWidget.saveWidgetData<int>(keyWaterMl, waterMl);
      await HomeWidget.saveWidgetData<int>(keyWaterGoalMl, waterGoalMl);
      await HomeWidget.saveWidgetData<int>(keySleepScore, sleepScore);
      await HomeWidget.saveWidgetData<String>(
        keyLastUpdated,
        DateTime.now().toIso8601String(),
      );

      await HomeWidget.updateWidget(
        name: _androidWidgetProvider,
        iOSName: _iOSWidget,
      );
    } catch (e) {
      debugPrint('Home widget update non-fatal error: $e');
    }
  }

  /// Register listener for widget deep clicks (e.g. quick 250ml water log)
  static void registerInteractivity(void Function(Uri?) onWidgetClick) {
    try {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(onWidgetClick);
      HomeWidget.widgetClicked.listen(onWidgetClick);
    } catch (e) {
      debugPrint('Home widget interactivity non-fatal error: $e');
    }
  }
}
