import 'package:intl/intl.dart';

/// Whole number with grouping, e.g. "9,850". Use where there is room.
String formatCount(num value) =>
    NumberFormat.decimalPattern().format(value.round());

/// Whole number for tight spots (tiles, chips, podiums): exact below
/// 10,000 ("9,850"), short above it ("12.5K", "1.2M"), so a figure
/// stays readable instead of ending in an ellipsis.
String formatCompactCount(num value) {
  final rounded = value.round();
  if (rounded.abs() < 10000) return formatCount(rounded);
  return NumberFormat.compact().format(rounded);
}
