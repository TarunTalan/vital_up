package com.tarun_siddhi.vital_up

/*
 * Size variants. Android has no way to pin a widget at a chosen size: the
 * launcher always uses the provider's default (targetCell / minWidth in
 * res/xml/<name>_info.xml). So each size the app offers is its own provider
 * with its own default; the layout code is shared and every variant can
 * still be resized freely after it's placed.
 *
 * The originals keep their class names (widgets already on home screens keep
 * working) and their sizes: Today 4x2, My metrics 4x2, Water 2x2,
 * Mood 4x2, Shortcuts 4x1.
 */

class TodaySmallWidgetProvider : VitalUpWidgetProvider()
class TodayLargeWidgetProvider : VitalUpWidgetProvider()
class TodayXLargeWidgetProvider : VitalUpWidgetProvider()

class CustomSmallWidgetProvider : CustomWidgetProvider()
class CustomLargeWidgetProvider : CustomWidgetProvider()
class CustomXLargeWidgetProvider : CustomWidgetProvider()

class WaterWideWidgetProvider : HydrationWidgetProvider()

class MoodBarWidgetProvider : MoodWidgetProvider()

class ShortcutsSmallWidgetProvider : QuickShortcutsWidgetProvider()
