import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/activity_tracking/data/services/offline_map_service.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/offline_map_area.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';

/// Picks an area to save offline (route `offline-map-picker`): the square
/// in the frame is what downloads, so the user pans to the place and
/// zooms to the size (like Google Maps' offline areas). Shows the size and
/// the download estimate as the map settles; Download goes back to the
/// list, where progress shows.
class OfflineMapPickerPage extends StatefulWidget {
  const OfflineMapPickerPage({super.key});

  @override
  State<OfflineMapPickerPage> createState() => _OfflineMapPickerPageState();
}

class _OfflineMapPickerPageState extends State<OfflineMapPickerPage> {
  final OfflineMapService _maps = sl<OfflineMapService>();
  final MapTileRepository _tiles = sl<MapTileRepository>();
  final ConnectivityService _connectivity = sl<ConnectivityService>();
  late final TextEditingController _name = TextEditingController(
    text: _maps.suggestedName(),
  );

  /// Street level: about 3 km across on a phone. Zooming out picks more.
  static const double _closeZoom = 13;

  /// Where the map opens; null while it's being found.
  mbx.CameraOptions? _start;
  mbx.MapboxMap? _map;

  /// Location is on and allowed: the map shows the user's dot.
  bool _canLocate = false;

  /// A fresh fix that came before the map was ready.
  ({double latitude, double longitude})? _pendingFix;

  /// The user has panned or zoomed: a late fix doesn't move the map.
  bool _userMoved = false;

  /// The frame's side in logical px (from the layout).
  double _framePx = 0;
  double _latitude = 0;
  double _longitude = 0;
  double _zoom = 0;

  int? _estimateBytes;
  bool _estimating = false;
  int _estimateRun = 0;
  Timer? _estimateDelay;

  late bool _online = _connectivity.isOnline;
  StreamSubscription<bool>? _onlineSub;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _onlineSub = _connectivity.onlineChanges.listen((online) {
      if (!mounted) return;
      setState(() => _online = online);
      if (online) _scheduleEstimate();
    });
    _findStart();
  }

  @override
  void dispose() {
    _estimateDelay?.cancel();
    _onlineSub?.cancel();
    _name.dispose();
    super.dispose();
  }

  /// Opens zoomed in on the user at once (last known fix), then moves to
  /// a fresh fix when it comes, unless the user has moved the map. Never
  /// asks for location: without it the map opens on the area around the
  /// user, else the world.
  Future<void> _findStart() async {
    final auto = _maps.state.value.auto;
    _canLocate = await OfflineMapService.canLocate();
    final known = _canLocate ? await OfflineMapService.lastKnownFix() : null;
    if (!mounted) return;
    final lat = known?.latitude ?? auto?.latitude;
    final lng = known?.longitude ?? auto?.longitude;
    final zoom = lat == null ? 1.0 : _closeZoom;
    setState(() {
      _start = mbx.CameraOptions(
        center: mbx.Point(coordinates: mbx.Position(lng ?? 0, lat ?? 20)),
        zoom: zoom,
      );
      _latitude = lat ?? 20;
      _longitude = lng ?? 0;
      _zoom = zoom;
    });
    _scheduleEstimate();
    if (!_canLocate) return;
    final fresh = await OfflineMapService.currentFix();
    if (fresh == null || !mounted) return;
    _moveTo(fresh);
  }

  void _onMapCreated(mbx.MapboxMap map) {
    _map = map;
    final start = _start;
    if (start != null) map.setCamera(start);
    if (_canLocate) {
      map.location.updateSettings(
        mbx.LocationComponentSettings(enabled: true, pulsingEnabled: true),
      );
    }
    final pending = _pendingFix;
    if (pending != null) {
      _pendingFix = null;
      _moveTo(pending);
    }
  }

  void _moveTo(({double latitude, double longitude}) fix) {
    if (_userMoved) return;
    final map = _map;
    if (map == null) {
      _pendingFix = fix;
      return;
    }
    map.easeTo(
      mbx.CameraOptions(
        center: mbx.Point(
          coordinates: mbx.Position(fix.longitude, fix.latitude),
        ),
        zoom: _closeZoom,
      ),
      mbx.MapAnimationOptions(duration: 600),
    );
  }

  double get _radiusKm => OfflineMapRules.radiusForFrame(
    framePx: _framePx,
    latitude: _latitude,
    zoom: _zoom,
  );

  bool get _tooLarge => _radiusKm > OfflineMapRules.maxRadiusKm;

  OfflineMapArea _draft() => _maps.draft(
    latitude: _latitude,
    longitude: _longitude,
    radiusKm: _radiusKm,
    name: _name.text,
  );

  void _onCamera(mbx.CameraState camera) {
    final center = camera.center.coordinates;
    setState(() {
      _latitude = center.lat.toDouble();
      _longitude = center.lng.toDouble();
      _zoom = camera.zoom;
      _estimateBytes = null;
    });
    _scheduleEstimate();
  }

  /// Once the map has settled: the estimate asks Mapbox's servers.
  void _scheduleEstimate() {
    _estimateDelay?.cancel();
    _estimateRun++;
    if (!_online || _tooLarge || _framePx == 0) {
      if (_estimating) setState(() => _estimating = false);
      return;
    }
    _estimateDelay = Timer(const Duration(milliseconds: 600), _estimate);
  }

  Future<void> _estimate() async {
    final run = _estimateRun;
    setState(() => _estimating = true);
    final bytes = await _tiles.estimateBytes(_draft());
    if (!mounted || run != _estimateRun) return;
    setState(() {
      _estimating = false;
      _estimateBytes = bytes;
    });
  }

  void _download() {
    if (_saving || !_online || _tooLarge) return;
    _saving = true;
    final message = _maps.download(_draft());
    if (message != null) {
      _saving = false;
      showErrorSnackBar(context, message);
      return;
    }
    Navigator.of(context).pop();
  }

  String get _sizeLine {
    if (!_online) return 'Connect to the internet to download a map.';
    if (_tooLarge) return 'Zoom in to pick a smaller area.';
    final side = OfflineMapRules.sideLabel(
      max(_radiusKm, OfflineMapRules.minRadiusKm),
    );
    final bytes = _estimateBytes;
    if (bytes != null) {
      return '$side · about ${OfflineMapRules.sizeLabel(bytes)}';
    }
    return _estimating ? '$side · working out the size' : side;
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    final grey = context.vColors.grayText;
    return AppScaffold(
      header: const AppPageHeader(title: 'Choose an area'),
      scrollable: false,
      padBody: false,
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _name,
            label: 'Name',
            maxLength: InputLimits.shortText,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            _sizeLine,
            style: context.text.bodyMedium?.copyWith(color: grey),
          ),
          const SizedBox(height: AppDimens.space12),
          AppPrimaryButton(
            label: 'Download',
            leadingIcon: const Icon(Icons.download_rounded),
            enabled: start != null && _online && !_tooLarge,
            onTap: _download,
          ),
        ],
      ),
      body: start == null
          ? const Center(child: VitalUpLoader())
          : LayoutBuilder(
              builder: (context, constraints) {
                final side =
                    min(constraints.maxWidth, constraints.maxHeight) -
                    AppDimens.space32 * 2;
                final framePx = max(0.0, side);
                if (framePx != _framePx) {
                  // First layout or rotation: the size follows the frame.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || framePx == _framePx) return;
                    setState(() => _framePx = framePx);
                    _scheduleEstimate();
                  });
                }
                return Stack(
                  children: [
                    Positioned.fill(
                      child: mbx.MapWidget(
                        key: const ValueKey('offlineMapPicker'),
                        styleUri: mbx.MapboxStyles.MAPBOX_STREETS,
                        onMapCreated: _onMapCreated,
                        onScrollListener: (_) => _userMoved = true,
                        onZoomListener: (_) => _userMoved = true,
                        onCameraChangeListener: (event) =>
                            _onCamera(event.cameraState),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _FramePainter(
                            side: framePx,
                            scrim: context.colors.scrim.withValues(alpha: 0.35),
                            border: _tooLarge
                                ? context.colors.error
                                : context.colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

/// Dims the map outside the square that will be saved.
class _FramePainter extends CustomPainter {
  final double side;
  final Color scrim;
  final Color border;

  const _FramePainter({
    required this.side,
    required this.scrim,
    required this.border,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (side <= 0) return;
    final frame = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(outside, Paint()..color = scrim);
    canvas.drawRect(
      frame,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.side != side || old.scrim != scrim || old.border != border;
}
