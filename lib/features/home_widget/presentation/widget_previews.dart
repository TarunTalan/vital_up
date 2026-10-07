import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/home_widget/data/widget_data.dart';

/// Flutter copies of the Android widget layouts (res/layout/wg_*.xml),
/// drawn at the same dp sizes with the same text, colours and size rules
/// as the Kotlin providers, so a preview matches the home screen.
///
/// Keep the size thresholds here in step with MetricsWidget.kt,
/// HydrationWidgetProvider.kt, MoodWidgetProvider.kt and
/// QuickShortcutsWidgetProvider.kt.

/// A widget size as the launcher reports it, in dp.
class WidgetSize {
  final String label;
  final double width;
  final double height;
  const WidgetSize(this.label, this.width, this.height);

  static const small = WidgetSize('2 × 2', 160, 160);
  static const wide = WidgetSize('4 × 2', 330, 150);
  static const large = WidgetSize('4 × 3', 330, 260);
  static const xLarge = WidgetSize('4 × 4', 330, 340);
  static const bar = WidgetSize('4 × 1', 330, 70);
  static const barSmall = WidgetSize('2 × 1', 160, 70);
}

/// The sizes each widget offers and the provider that pins it at that size
/// (Android places a pinned widget at its provider's default size).
abstract final class WidgetSizeProviders {
  static const today = {
    WidgetSize.small: WidgetProviders.todaySmall,
    WidgetSize.wide: WidgetProviders.today,
    WidgetSize.large: WidgetProviders.todayLarge,
    WidgetSize.xLarge: WidgetProviders.todayXLarge,
  };
  static const custom = {
    WidgetSize.small: WidgetProviders.customSmall,
    WidgetSize.wide: WidgetProviders.custom,
    WidgetSize.large: WidgetProviders.customLarge,
    WidgetSize.xLarge: WidgetProviders.customXLarge,
  };
  static const water = {
    WidgetSize.small: WidgetProviders.water,
    WidgetSize.wide: WidgetProviders.waterWide,
  };
  static const mood = {
    WidgetSize.bar: WidgetProviders.moodBar,
    WidgetSize.wide: WidgetProviders.mood,
  };
  static const shortcuts = {
    WidgetSize.barSmall: WidgetProviders.shortcutsSmall,
    WidgetSize.bar: WidgetProviders.shortcuts,
  };
}

/// "Updated 9:41 AM" (just "9:41 AM" when [short], for narrow widgets),
/// or the prompt shown when data is from an earlier day.
String widgetUpdatedLabel(
  WidgetInputs inputs,
  DateTime? updatedAt, {
  bool short = false,
}) {
  if (inputs.day != WidgetInputs.dayOf(DateTime.now())) {
    return short ? 'Tap ↻' : 'Tap ↻ to update';
  }
  if (updatedAt == null) return '';
  final time = DateFormat.jm().format(updatedAt);
  return short ? time : 'Updated $time';
}

/// The widget surface: wg_bg.xml (24 radius, surface fill, hairline border).
class _Frame extends StatelessWidget {
  final WidgetSize size;
  final double padding;
  final Widget child;

  const _Frame({required this.size, required this.child, this.padding = 12});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    // Scale down to fit narrow screens; the layout itself stays at dp size.
    // Widget text is sized in dp (not scaled by the font setting), as on
    // the home screen, so it fits the fixed widget size.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: MediaQuery.withNoTextScaling(
        child: Container(
          width: size.width,
          height: size.height,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: v.glassBorder!),
            boxShadow: AppShadows.soft,
          ),
          child: child,
        ),
      ),
    );
  }
}

TextStyle _t(
  BuildContext context,
  double size, {
  bool secondary = false,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => TextStyle(
  fontFamily: context.text.bodyMedium?.fontFamily,
  fontSize: size,
  height: 1.1,
  fontWeight: weight,
  color:
      color ??
      (secondary ? context.vColors.grayText : context.colors.onSurface),
);

class _Text extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _Text(this.text, this.style);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
}

/// wg_header.xml: title, updated time, refresh.
/// Marks previews as refreshing: headers show the spinner and "Updating…",
/// as the home screen widgets do (wg_refresh_progress).
class WidgetRefreshing extends InheritedWidget {
  final bool refreshing;

  const WidgetRefreshing({
    super.key,
    required this.refreshing,
    required super.child,
  });

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WidgetRefreshing>()
          ?.refreshing ??
      false;

  @override
  bool updateShouldNotify(WidgetRefreshing old) => old.refreshing != refreshing;
}

/// wg_header.xml: title, updated time, and refresh (a spinner while
/// refreshing).
class _Header extends StatelessWidget {
  final String title;
  final String updated;
  const _Header(this.title, this.updated);

  @override
  Widget build(BuildContext context) {
    final refreshing = WidgetRefreshing.of(context);
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Expanded(
            child: _Text(title, _t(context, 13, weight: FontWeight.w600)),
          ),
          _Text(
            refreshing ? 'Updating…' : updated,
            _t(context, 11, secondary: true),
          ),
          const SizedBox(width: 2),
          SizedBox.square(
            dimension: 24,
            child: refreshing
                ? Padding(
                    padding: const EdgeInsets.all(5),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.primary,
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: context.vColors.grayText,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Tinted circle with an icon, as in the native badges.
class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  const _Badge(this.icon, this.color, this.size, {this.iconSize});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: iconSize ?? size / 2 + 2, color: color),
  );
}

/// wg_bar_track + wg_bar_fill: 6dp bar, hidden (but spaced) without a goal.
class _Bar extends StatelessWidget {
  final int? progress;
  final Color color;
  const _Bar(this.progress, this.color);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 6,
    child: progress == null
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(color: context.vColors.track),
                FractionallySizedBox(
                  widthFactor: progress! / 100,
                  child: Container(color: color),
                ),
              ],
            ),
          ),
  );
}

class _Tile extends StatelessWidget {
  final Widget child;
  final double padding;
  const _Tile({required this.child, this.padding = 8});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: context.vColors.glassFill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.vColors.glassBorder!),
    ),
    child: child,
  );
}

IconData _metricIcon(MetricTile t, WidgetInputs inputs) =>
    t.metric == WidgetMetric.mood && inputs.moodLevel != null
    ? moodIcon(inputs.moodLevel!)
    : t.metric.icon;

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final double height;
  const _Action(
    this.icon,
    this.label, {
    this.primary = false,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final fg = primary ? v.buttonText! : context.colors.primary;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: primary ? context.colors.primary : v.primaryFill,
        borderRadius: BorderRadius.circular(14),
        border: primary ? null : Border.all(color: v.primaryBorder!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: _Text(
              label,
              _t(context, 12, weight: FontWeight.w500, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _gap(double w) => SizedBox(width: w, height: w);

/// A metric value that shrinks to fit, like the native auto-size text
/// (max [size], min 11).
class _Value extends StatelessWidget {
  final String text;
  final double size;
  const _Value(this.text, this.size);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size + 6,
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        style: _t(context, size, weight: FontWeight.w600),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Today / My metrics (MetricsWidget.kt)
// ---------------------------------------------------------------------------

class MetricsWidgetPreview extends StatelessWidget {
  final String title;
  final List<WidgetMetric> metrics;
  final WidgetInputs inputs;
  final DateTime? updatedAt;
  final WidgetSize size;

  const MetricsWidgetPreview({
    super.key,
    required this.title,
    required this.metrics,
    required this.inputs,
    required this.updatedAt,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (!inputs.signedIn) return SignedOutPreview(size: size);
    final tiles = buildTiles(inputs);
    final shown = [for (final m in metrics) tiles[m]!];
    final header = _Header(
      title,
      widgetUpdatedLabel(inputs, updatedAt, short: size.width < 220),
    );
    final w = size.width;
    final h = size.height;

    final Widget body;
    if (w < 220) {
      final count = ((h - 48) ~/ 44).clamp(1, 4);
      body = Column(
        children: [
          header,
          for (final t in shown.take(count))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        _Badge(_metricIcon(t, inputs), t.color, 24),
                        _gap(8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Text(t.label, _t(context, 11, secondary: true)),
                              const SizedBox(height: 1),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _Text(
                                    t.value,
                                    _t(context, 15, weight: FontWeight.w600),
                                  ),
                                  _gap(4),
                                  Expanded(
                                    child: _Text(
                                      t.detail,
                                      _t(context, 10, secondary: true),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _Bar(t.progress, t.color),
                  ],
                ),
              ),
            ),
        ],
      );
    } else if (h < 170) {
      final count = w < 290 ? 3 : 4;
      final cols = shown.take(count).toList();
      body = Column(
        children: [
          header,
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cols.length; i++) ...[
                  if (i > 0) _gap(6),
                  Expanded(
                    child: _Tile(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Too narrow for an icon and a full label.
                          _Text(
                            cols[i].label,
                            _t(context, 11, secondary: true),
                          ),
                          const SizedBox(height: 2),
                          _Value(cols[i].value, 16),
                          const SizedBox(height: 1),
                          Text(
                            cols[i].detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _t(context, 10, secondary: true),
                          ),
                          const Spacer(),
                          _Bar(cols[i].progress, cols[i].color),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    } else {
      Widget tile(MetricTile t) => _Tile(
        padding: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Badge(_metricIcon(t, inputs), t.color, 24),
                _gap(8),
                Expanded(
                  child: _Text(t.label, _t(context, 12, secondary: true)),
                ),
              ],
            ),
            const Spacer(),
            _Value(t.value, 18),
            _Text(t.detail, _t(context, 11, secondary: true)),
            const SizedBox(height: 6),
            _Bar(t.progress, t.color),
          ],
        ),
      );
      Widget row(List<MetricTile> items) => Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) _gap(8),
              Expanded(child: tile(items[i])),
            ],
          ],
        ),
      );
      body = Column(
        children: [
          header,
          const SizedBox(height: 8),
          row(shown.take(2).toList()),
          if (shown.length > 2) ...[
            const SizedBox(height: 8),
            row(shown.skip(2).take(2).toList()),
          ],
          if (h >= 320) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(
                  child: _Action(Icons.photo_camera_rounded, 'Scan meal'),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: _Action(Icons.add_rounded, '250 ml', primary: true),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: _Action(Icons.auto_awesome_rounded, 'Ask Vita'),
                ),
              ],
            ),
          ],
        ],
      );
    }
    return _Frame(size: size, child: body);
  }
}

// ---------------------------------------------------------------------------
// Water (HydrationWidgetProvider.kt)
// ---------------------------------------------------------------------------

class WaterWidgetPreview extends StatelessWidget {
  final WidgetInputs inputs;
  final DateTime? updatedAt;
  final WidgetSize size;

  const WaterWidgetPreview({
    super.key,
    required this.inputs,
    required this.updatedAt,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (!inputs.signedIn) return SignedOutPreview(size: size);
    final t = buildTiles(inputs)[WidgetMetric.water]!;
    final wide = size.width >= 220;
    return _Frame(
      size: size,
      child: Column(
        children: [
          if (size.height >= 150)
            _Header(
              'Water',
              widgetUpdatedLabel(inputs, updatedAt, short: size.width < 220),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Badge(Icons.water_drop_rounded, t.color, 32),
              _gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Text(t.value, _t(context, 20, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    _Text(t.detail, _t(context, 11, secondary: true)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Bar(t.progress, t.color),
          const Spacer(),
          // Fixed gap so the bar never touches the buttons.
          const SizedBox(height: 12),
          Row(
            children: wide
                ? const [
                    Expanded(
                      child: _Action(Icons.add_rounded, '150 ml', height: 32),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: _Action(
                        Icons.add_rounded,
                        '250 ml',
                        primary: true,
                        height: 32,
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: _Action(Icons.add_rounded, '500 ml', height: 32),
                    ),
                  ]
                : const [
                    Expanded(
                      child: _Action(
                        Icons.add_rounded,
                        '250 ml',
                        primary: true,
                        height: 32,
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mood check-in (MoodWidgetProvider.kt)
// ---------------------------------------------------------------------------

class MoodWidgetPreview extends StatelessWidget {
  final WidgetInputs inputs;
  final DateTime? updatedAt;
  final WidgetSize size;

  const MoodWidgetPreview({
    super.key,
    required this.inputs,
    required this.updatedAt,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (!inputs.signedIn) return SignedOutPreview(size: size);
    final compact = size.height < 100;
    final level = inputs.moodLevel;
    final logged = level != null && level >= 1 && level <= 5;
    final faceSize = compact ? 34.0 : 40.0;

    Widget faces() => Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Expanded(
            child: Center(
              child: _Badge(
                moodIcon(i),
                moodColor(i),
                faceSize,
                iconSize: faceSize - 12,
              ),
            ),
          ),
      ],
    );

    Widget done() {
      final t = buildTiles(inputs)[WidgetMetric.mood]!;
      final s = compact ? 34.0 : 48.0;
      return Row(
        children: [
          _Badge(moodIcon(level!), t.color, s, iconSize: s - 12),
          _gap(10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Text(
                  t.value,
                  _t(context, compact ? 15 : 20, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                _Text(t.detail, _t(context, 12, secondary: true)),
              ],
            ),
          ),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.vColors.primaryFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.vColors.primaryBorder!),
            ),
            child: _Text(
              'Change',
              _t(
                context,
                12,
                weight: FontWeight.w500,
                color: context.colors.primary,
              ),
            ),
          ),
        ],
      );
    }

    return _Frame(
      size: size,
      padding: compact ? 8 : 12,
      child: compact
          ? Center(child: logged ? done() : faces())
          : Column(
              children: [
                _Header(
                  logged ? "Today's mood" : 'How are you feeling?',
                  widgetUpdatedLabel(
                    inputs,
                    updatedAt,
                    short: size.width < 220,
                  ),
                ),
                Expanded(
                  child: logged
                      ? done()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            faces(),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _Text(
                                    'Very calm',
                                    _t(context, 11, secondary: true),
                                  ),
                                ),
                                _Text(
                                  'Very stressed',
                                  _t(context, 11, secondary: true),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shortcuts (QuickShortcutsWidgetProvider.kt)
// ---------------------------------------------------------------------------

class ShortcutsWidgetPreview extends StatelessWidget {
  final WidgetSize size;
  const ShortcutsWidgetPreview({super.key, required this.size});

  static const _items = [
    (Icons.photo_camera_rounded, 'Scan', AppColors.primary),
    (Icons.water_drop_rounded, 'Water', AppColors.trackWater),
    (Icons.directions_run_rounded, 'Workout', AppColors.trackActivity),
    (Icons.auto_awesome_rounded, 'Vita', AppColors.trackMood),
  ];

  @override
  Widget build(BuildContext context) {
    final count = size.width < 180
        ? 2
        : size.width < 250
        ? 3
        : 4;
    return _Frame(
      size: size,
      padding: 8,
      child: Row(
        children: [
          for (final (icon, label, color) in _items.take(count))
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Badge(icon, color, 36, iconSize: 20),
                  const SizedBox(height: 4),
                  _Text(label, _t(context, 11, weight: FontWeight.w500)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// wg_signed_out.xml, shown by every widget while signed out.
class SignedOutPreview extends StatelessWidget {
  final WidgetSize size;
  const SignedOutPreview({super.key, required this.size});

  @override
  Widget build(BuildContext context) => _Frame(
    size: size,
    child: Row(
      children: [
        Image.asset('assets/icons/app_icon.png', width: 32, height: 32),
        _gap(10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Text('VitalUp', _t(context, 14, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              _Text(
                'Sign in to see your day',
                _t(context, 12, secondary: true),
              ),
            ],
          ),
        ),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: _Text(
            'Sign in',
            _t(
              context,
              12,
              weight: FontWeight.w500,
              color: context.vColors.buttonText,
            ),
          ),
        ),
      ],
    ),
  );
}
