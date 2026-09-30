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

/// Manages a BLE connection to a heart rate monitor and exposes a live BPM stream.
class HeartRateManager {
  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _valueSubscription;
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;

  final StreamController<int?> _bpmController =
      StreamController<int?>.broadcast();

  Stream<int?> get bpmStream => _bpmController.stream;
  BluetoothDevice? get connectedDevice => _device;

  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    _device = device;
    await device.connect(
      autoConnect: false,
      timeout: const Duration(seconds: 10),
    );

    _stateSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _bpmController.add(null);
      }
    });

    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == _kHeartRateServiceUuid) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == _kHrmCharacteristicUuid) {
            await char.setNotifyValue(true);
            _valueSubscription = char.lastValueStream.listen((data) {
              if (data.isNotEmpty) {
                // Parse HRM per Bluetooth spec — first byte flags, BPM follows.
                final bpm = (data[0] & 0x01) == 0
                    ? data[1]
                    : data[1] | (data[2] << 8);
                _bpmController.add(bpm);
              }
            });
          }
        }
      }
    }
  }

  Future<void> disconnect() async {
    await _valueSubscription?.cancel();
    await _stateSubscription?.cancel();
    _valueSubscription = null;
    _stateSubscription = null;
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
      _device = null;
    }
    _bpmController.add(null);
  }

  void dispose() {
    disconnect();
    _bpmController.close();
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

  void _startScan() {
    setState(() {
      _results.clear();
      _isScanning = true;
    });

    // Filter to devices advertising the Heart Rate Service
    FlutterBluePlus.startScan(
      withServices: [Guid(_kHeartRateServiceUuid)],
      timeout: const Duration(seconds: 10),
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          for (final r in results) {
            if (!_results.any((e) => e.device.remoteId == r.device.remoteId)) {
              _results.add(r);
            }
          }
        });
      }
    });

    FlutterBluePlus.isScanning.where((s) => !s).first.then((_) {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  Future<void> _connect(ScanResult result) async {
    await FlutterBluePlus.stopScan();
    setState(() => _connectingId = result.device.remoteId.str);
    try {
      await widget.manager.connect(result.device);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _connectingId = null);
        showErrorSnackBar(context, 'Connection failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
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
                    'Connected',
                    style: context.text.bodyMedium?.copyWith(
                      color: v.success,
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
                          _isScanning
                              ? 'Scanning for heart rate monitors…'
                              : 'No devices found.\nMake sure your device is in pairing mode.',
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
