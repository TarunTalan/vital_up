import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_card.dart';

/// UUID for the standard Bluetooth Heart Rate Service.
const _kHeartRateServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';

/// UUID for the Heart Rate Measurement characteristic.
const _kHrmCharacteristicUuid = '00002a37-0000-1000-8000-00805f9b34fb';

/// Lowest and highest heart rate accepted from a monitor. Readings outside
/// this band are contact or sensor glitches (0 when the strap is loose).
const int kMinValidBpm = 25;
const int kMaxValidBpm = 250;

/// Parses a Heart Rate Measurement characteristic value (Bluetooth spec:
/// first byte flags, bit 0 picks an 8 or 16 bit value). Returns null for
/// short packets or readings outside [kMinValidBpm]..[kMaxValidBpm].
int? parseHeartRateMeasurement(List<int> data) {
  if (data.length < 2) return null;
  final int bpm;
  if ((data[0] & 0x01) == 0) {
    bpm = data[1];
  } else {
    if (data.length < 3) return null;
    bpm = data[1] | (data[2] << 8);
  }
  if (bpm < kMinValidBpm || bpm > kMaxValidBpm) return null;
  return bpm;
}

/// Thrown when a device connects but does not expose heart rate.
class NoHeartRateServiceException implements Exception {
  const NoHeartRateServiceException();
}

/// Manages a BLE connection to a heart rate monitor and exposes a live BPM stream.
class HeartRateManager {
  BluetoothDevice? _device;
  bool _connected = false;
  StreamSubscription<List<int>>? _valueSubscription;
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;

  final StreamController<int?> _bpmController =
      StreamController<int?>.broadcast();

  Stream<int?> get bpmStream => _bpmController.stream;
  BluetoothDevice? get connectedDevice => _device;

  /// False once the monitor drops the link (out of range, battery).
  bool get isConnected => _connected;

  void _emit(int? bpm) {
    if (!_bpmController.isClosed) _bpmController.add(bpm);
  }

  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    _device = device;
    try {
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
      _connected = true;

      _stateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connected = false;
          _emit(null);
        } else if (state == BluetoothConnectionState.connected) {
          _connected = true;
        }
      });

      final services = await device
          .discoverServices()
          .timeout(const Duration(seconds: 15));
      BluetoothCharacteristic? hrm;
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() != _kHeartRateServiceUuid) {
          continue;
        }
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == _kHrmCharacteristicUuid) {
            hrm = char;
          }
        }
      }
      if (hrm == null) throw const NoHeartRateServiceException();

      await hrm.setNotifyValue(true);
      _valueSubscription = hrm.lastValueStream.listen(
        (data) {
          final bpm = parseHeartRateMeasurement(data);
          if (bpm != null) _emit(bpm);
        },
        onError: (Object e) => debugPrint('Heart rate stream error: $e'),
      );
    } catch (_) {
      // Leave nothing half-connected behind a failed attempt.
      await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _valueSubscription?.cancel();
    await _stateSubscription?.cancel();
    _valueSubscription = null;
    _stateSubscription = null;
    _connected = false;
    final device = _device;
    _device = null;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (e) {
        debugPrint('Heart rate monitor disconnect failed: $e');
      }
    }
    _emit(null);
  }

  void dispose() {
    disconnect().whenComplete(_bpmController.close);
  }
}

/// Bottom sheet that scans for BLE Heart Rate Service devices and lets
/// the user connect to one.
class HrDeviceSheet extends StatefulWidget {
  final HeartRateManager manager;

  const HrDeviceSheet({super.key, required this.manager});

  static Future<void> show(
    BuildContext context,
    HeartRateManager manager,
  ) async {
    await showAppBottomSheet(
      context: context,
      builder: (_) => HrDeviceSheet(manager: manager),
    );
  }

  @override
  State<HrDeviceSheet> createState() => _HrDeviceSheetState();
}

class _HrDeviceSheetState extends State<HrDeviceSheet> {
  final List<ScanResult> _results = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isScanning = false;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  /// Shown in place of the device list when scanning can't run.
  String? _scanError;

  Future<void> _startScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    if (!mounted) return;
    setState(() {
      _results.clear();
      _scanError = null;
      _isScanning = true;
    });

    try {
      if (!await FlutterBluePlus.isSupported) {
        _stopWithError("This phone doesn't support Bluetooth monitors.");
        return;
      }
      final adapter = await FlutterBluePlus.adapterState
          .where((s) => s != BluetoothAdapterState.unknown)
          .first
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => BluetoothAdapterState.unknown,
          );
      if (adapter == BluetoothAdapterState.unauthorized) {
        _stopWithError('Allow Bluetooth access in Settings to pair.');
        return;
      }
      if (adapter != BluetoothAdapterState.on &&
          adapter != BluetoothAdapterState.unknown) {
        _stopWithError('Turn on Bluetooth to find heart rate monitors.');
        return;
      }

      _scanSub = FlutterBluePlus.scanResults.listen(
        (results) {
          if (!mounted) return;
          setState(() {
            for (final r in results) {
              if (!_results.any((e) => e.device.remoteId == r.device.remoteId)) {
                _results.add(r);
              }
            }
          });
        },
        onError: (Object e) => debugPrint('Heart rate scan error: $e'),
      );

      // Filter to devices advertising the Heart Rate Service
      await FlutterBluePlus.startScan(
        withServices: [Guid(_kHeartRateServiceUuid)],
        timeout: const Duration(seconds: 10),
      );
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      if (mounted) setState(() => _isScanning = false);
    } catch (e) {
      debugPrint('Heart rate scan failed: $e');
      _stopWithError("Couldn't search for devices. Check Bluetooth access.");
    }
  }

  void _stopWithError(String message) {
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _scanError = message;
    });
  }

  Future<void> _connect(ScanResult result) async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Stopping heart rate scan failed: $e');
    }
    if (!mounted) return;
    setState(() => _connectingId = result.device.remoteId.str);
    try {
      await widget.manager.connect(result.device);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Heart rate monitor connection failed: $e');
      if (mounted) {
        setState(() => _connectingId = null);
        showErrorSnackBar(
          context,
          e is NoHeartRateServiceException
              ? "This device doesn't share heart rate."
              : "Couldn't connect. Keep the monitor close and try again.",
        );
      }
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan().catchError(
      (Object e) => debugPrint('Stopping heart rate scan failed: $e'),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;
    final titleStyle = context.text.titleSmall?.copyWith(
      color: colors.onSurface,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (_, scrollCtrl) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            0,
            context.gutter,
            AppDimens.space16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Heart Rate Monitor',
                          style: context.text.headlineSmall,
                        ),
                        const SizedBox(height: AppDimens.space4),
                        Text(
                          'Pair a BLE heart rate device',
                          style: context.text.bodyMedium?.copyWith(
                            color: v.grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.manager.connectedDevice != null)
                    TextButton.icon(
                      onPressed: () async {
                        await widget.manager.disconnect();
                        if (mounted) setState(() {});
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                        textStyle: context.text.bodySmall,
                      ),
                      icon: const Icon(
                        Icons.link_off_rounded,
                        size: AppDimens.iconXs,
                      ),
                      label: const Text('Disconnect'),
                    ),
                  if (_isScanning)
                    const SizedBox.square(
                      dimension: AppDimens.iconSm,
                      child: CircularProgressIndicator(
                        strokeWidth: AppDimens.borderThick,
                      ),
                    )
                  else
                    IconButton(
                      onPressed: _startScan,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Rescan',
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.space12),
              const Divider(),

              // Connected device
              if (widget.manager.connectedDevice != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AppIconBadge(
                    icon: const Icon(Icons.favorite_rounded),
                    color: colors.error,
                  ),
                  title: Text(
                    widget.manager.connectedDevice!.platformName.isEmpty
                        ? 'HR Monitor'
                        : widget.manager.connectedDevice!.platformName,
                    style: titleStyle,
                  ),
                  subtitle: Text(
                    widget.manager.isConnected ? 'Connected' : 'Disconnected',
                    style: context.text.bodyMedium?.copyWith(
                      color: widget.manager.isConnected
                          ? v.success
                          : v.grayText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: StreamBuilder<int?>(
                    stream: widget.manager.bpmStream,
                    builder: (_, snap) {
                      final bpm = snap.data;
                      return Text(
                        bpm != null ? '$bpm BPM' : '--',
                        style: context.text.titleSmall?.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
              ],

              // Scanned devices list
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _scanError ??
                              (_isScanning
                                  ? 'Scanning for heart rate monitors…'
                                  : 'No devices found.\nPut your monitor in pairing mode.'),
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium?.copyWith(
                            color: v.grayText,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final r = _results[i];
                          final id = r.device.remoteId.str;
                          final name = r.device.platformName.isEmpty
                              ? 'HR Device'
                              : r.device.platformName;
                          final isConnecting = _connectingId == id;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: AppIconBadge(
                              icon: const Icon(Icons.favorite_border_rounded),
                              color: colors.error,
                            ),
                            title: Text(name, style: titleStyle),
                            subtitle: Text(
                              'RSSI: ${r.rssi} dBm',
                              style: context.text.bodySmall?.copyWith(
                                color: v.grayText,
                              ),
                            ),
                            trailing: isConnecting
                                ? const SizedBox.square(
                                    dimension: AppDimens.iconMd,
                                    child: CircularProgressIndicator(
                                      strokeWidth: AppDimens.borderThick,
                                    ),
                                  )
                                : Icon(
                                    Icons.chevron_right_rounded,
                                    color: v.grayText,
                                  ),
                            onTap: _connectingId != null
                                ? null
                                : () => _connect(r),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
