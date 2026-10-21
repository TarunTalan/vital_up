import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_colors.dart';

/// A notification's large icon drawn from one of the app's SVG icons: the
/// glyph in white on a filled circle (a tracker accent or the brand
/// colour), like the icon badges in the app. Kept in memory per icon and
/// colour; null when the SVG can't be drawn (the notification then shows
/// without one). Android only (iOS ignores large icons).
abstract final class NotificationIcons {
  static const _sizePx = 192;
  static final Map<String, Future<Uint8List?>> _cache = {};

  static Future<AndroidBitmap<Object>?> largeIcon(
    String asset, {
    ui.Color background = AppColors.primary,
  }) async {
    final key = '$asset#${background.toARGB32()}';
    final future = _cache[key] ??= _draw(asset, background);
    // A failure is kept too: an engine that can't draw shouldn't wait
    // again for every reminder.
    final bytes = await future;
    return bytes == null ? null : ByteArrayAndroidBitmap(bytes);
  }

  static Future<Uint8List?> _draw(String asset, ui.Color background) async {
    try {
      final info = await vg.loadPicture(SvgAssetLoader(asset), null);
      const size = _sizePx * 1.0;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawCircle(
        const ui.Offset(size / 2, size / 2),
        size / 2,
        ui.Paint()..color = background,
      );
      const glyph = size * 0.5;
      final scale = glyph / info.size.longestSide;
      canvas.save();
      canvas.translate(
        (size - info.size.width * scale) / 2,
        (size - info.size.height * scale) / 2,
      );
      canvas.scale(scale);
      canvas.saveLayer(
        ui.Offset.zero & info.size,
        ui.Paint()
          ..colorFilter = const ui.ColorFilter.mode(
            AppColors.white,
            BlendMode.srcIn,
          ),
      );
      canvas.drawPicture(info.picture);
      canvas.restore();
      canvas.restore();
      info.picture.dispose();
      // Background engines (widgets, notification actions) may not draw:
      // never hold a reminder up waiting for its icon.
      final image = await recorder
          .endRecording()
          .toImage(_sizePx, _sizePx)
          .timeout(const Duration(seconds: 3));
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return png?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Notification icon $asset failed: $e');
      return null;
    }
  }
}
