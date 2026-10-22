import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vital_up/core/permissions/permission_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vital_up/features/subscription/domain/pro_limits.dart';
import 'package:vital_up/features/subscription/presentation/utils/pro_gate.dart';
import 'package:vital_up/features/food_scanner/domain/nutrition_sanity.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_state.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/food_detail_page.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/nutrition_ocr_parser.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/nutrition_manual_entry_dialog.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/accuracy_info_dialog.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/scans_left_hint.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/features/food_scanner/domain/ml_kit_errors.dart';
import 'package:vital_up/features/food_scanner/presentation/utils/scan_frame.dart';

final GetIt _sl = GetIt.instance;

/// Asks before leaving while a photo is being analysed: the scan already
/// counts toward today's limit, and leaving throws its result away.
Future<bool> confirmLeaveFoodScan(BuildContext context) async {
  final leave = await showSmoothDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Leave now?'),
      content: const Text(
        'Your meal is still being analysed. Leaving discards this scan, '
        'and it still counts toward today.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Stay'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  return leave ?? false;
}

class FoodScannerPage extends StatelessWidget {
  final VoidCallback? onBack;
  final bool isEditingImage;

  /// Set while a photo is being analysed, for a host (the dashboard) that
  /// handles back itself and must ask before leaving.
  final ValueNotifier<bool>? busy;

  const FoodScannerPage({
    super.key,
    this.onBack,
    this.isEditingImage = false,
    this.busy,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditingImage) {
      return FoodScannerView(
        onBack: onBack,
        isEditingImage: isEditingImage,
        busy: busy,
      );
    }
    return BlocProvider<FoodScanBloc>(
      create: (_) => _sl<FoodScanBloc>(),
      child: FoodScannerView(
        onBack: onBack,
        isEditingImage: isEditingImage,
        busy: busy,
      ),
    );
  }
}

class FoodScannerView extends StatefulWidget {
  final VoidCallback? onBack;
  final bool isEditingImage;
  final ValueNotifier<bool>? busy;

  const FoodScannerView({
    super.key,
    this.onBack,
    this.isEditingImage = false,
    this.busy,
  });

  @override
  State<FoodScannerView> createState() => _FoodScannerViewState();
}

class _FoodScannerViewState extends State<FoodScannerView>
    with WidgetsBindingObserver {
  final ImagePicker _imagePicker = ImagePicker();
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  XFile? _selectedImage;
  XFile? _croppedImage;
  bool _permissionDenied = false;

  /// Denied with "don't ask again": only the system settings can grant it.
  bool _permissionPermanentlyDenied = false;

  /// Last scanned code that is not a product barcode (e.g. a website QR),
  /// so the hint shows once rather than on every frame.
  String? _ignoredCode;
  bool _isCapturing = false;
  bool _torchEnabled = false;
  String? _errorMessage;

  CameraDescription? _cameraDescription;

  /// Retail barcodes, plus QR for GS1 Digital Link codes on newer packs
  /// (`normalizeProductBarcode` ignores other QR codes).
  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upca,
      BarcodeFormat.upce,
      BarcodeFormat.qrCode,
    ],
  );
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  DateTime? _lastFrameProcessedAt;
  static const _frameInterval = Duration(milliseconds: 250);
  bool _isScanningBarcode = false;
  bool _isScanningNutritionLabel = false;
  String? _currentFailedBarcode;
  List<Offset> _detectedQrPoints = [];

  /// Whether barcode reading should run once the camera is ready; kept while
  /// the camera is let go in the background.
  bool _wantsBarcodeReading = true;

  /// The camera was let go when the app left the screen; start it on resume.
  bool _cameraReleased = false;

  /// Bumped when the camera is let go, so a start still in progress stops.
  int _cameraGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // Not on inactive: the notification shade and permission dialogs
      // only make the app inactive, and restarting the camera there flickers.
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _releaseCamera();
      case AppLifecycleState.resumed:
        _restoreCamera();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Lets the camera go in the background (other apps can use it, and no
  /// frames are read while nobody sees the screen).
  Future<void> _releaseCamera() async {
    if (_permissionDenied || _cameraReleased) return;
    _cameraGeneration++;
    _cameraReleased = true;
    final controller = _cameraController;
    await _stopImageStream(keepWanted: true);
    _cameraController = null;
    _cameraInitFuture = null;
    _torchEnabled = false;
    if (mounted) setState(() {});
    await controller?.dispose();
  }

  /// Starts the camera again after [_releaseCamera], or after the user
  /// granted the permission in system settings. Never asks for it here:
  /// closing a permission screen resumes the app and would loop.
  Future<void> _restoreCamera() async {
    if (!_cameraReleased && !_permissionDenied) return;
    final status = await Permission.camera.status;
    if (!mounted || _cameraController != null || !status.isGranted) return;
    if (!_cameraReleased && !_permissionDenied) return;
    _cameraReleased = false;
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopImageStream();
    _cameraController?.dispose();
    _barcodeScanner.close();
    _textRecognizer.close();
    widget.busy?.value = false;
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final generation = _cameraGeneration;
    setState(() {
      _permissionDenied = false;
      _errorMessage = null;
    });

    // Never the system dialog on opening the tab: the camera card asks
    // first ([_allowCamera]).
    final granted = await AppPermission.camera.isGranted();
    if (!mounted || generation != _cameraGeneration) return;

    if (!granted) {
      final blocked = await AppPermission.camera.isBlocked();
      if (!mounted) return;
      setState(() {
        _permissionDenied = true;
        _permissionPermanentlyDenied = blocked;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (!mounted || generation != _cameraGeneration) return;

      if (cameras.isEmpty) {
        setState(
          () => _errorMessage =
              'No camera found. Pick a photo from your gallery.',
        );
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // High stays: the same controller takes the meal photo.
      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        // NV21 arrives as one plane ML Kit reads directly, no copy.
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      final initFuture = controller.initialize();
      _cameraInitFuture = initFuture;
      await initFuture;
      if (!mounted || generation != _cameraGeneration) {
        await controller.dispose();
        return;
      }

      await _cameraController?.dispose();
      setState(() {
        _cameraController = controller;
        _cameraDescription = backCamera;
      });

      if (_wantsBarcodeReading) _startImageStream(controller);
    } catch (error) {
      debugPrint('Camera start failed: $error');
      if (!mounted || generation != _cameraGeneration) return;
      setState(() => _errorMessage = "Couldn't start the camera. Try again.");
    }
  }

  /// Reads barcodes again (now, or once the camera is back from the background).
  void _resumeBarcodeReading() {
    _wantsBarcodeReading = true;
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized)
      _startImageStream(controller);
  }

  void _startImageStream(CameraController controller) {
    _wantsBarcodeReading = true;
    if (_isStreaming) return;
    _isStreaming = true;
    _isProcessingFrame = false;
    _detectedQrPoints = [];

    controller.startImageStream((CameraImage image) {
      _processCameraImage(image);
    });
  }

  Future<void> _stopImageStream({bool keepWanted = false}) async {
    if (!keepWanted) _wantsBarcodeReading = false;
    if (!_isStreaming) return;
    _isStreaming = false;
    _isProcessingFrame = false;
    _detectedQrPoints = [];

    final controller = _cameraController;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (e) {
        debugPrint('Error stopping image stream: $e');
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _processCameraImage(CameraImage image) async {
    // While framing a nutrition label the package barcode is usually in
    // view too; don't start another lookup for it.
    if (_isProcessingFrame || _isScanningBarcode || _isScanningNutritionLabel)
      return;
    // A few looks a second find a barcode just as fast as every frame,
    // without the CPU and battery cost.
    final now = DateTime.now();
    final last = _lastFrameProcessedAt;
    if (last != null &&
        now.difference(last) < _frameInterval &&
        !now.isBefore(last)) {
      return;
    }
    _lastFrameProcessedAt = now;
    _isProcessingFrame = true;

    try {
      final cameraDesc = _cameraDescription;
      if (cameraDesc == null) return;

      final inputImage = _convertCameraImage(image, cameraDesc);
      if (inputImage == null) return;

      final barcodes = await _barcodeScanner.processImage(inputImage);

      if (!mounted) return;
      final screen = MediaQuery.sizeOf(context);
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final placed = <PlacedCode>[
        for (final code in barcodes)
          if ((code.rawValue ?? code.displayValue)?.isNotEmpty ?? false)
            (
              value: (code.rawValue ?? code.displayValue)!,
              points: [
                for (final p in _codeCorners(code))
                  mapCameraPoint(
                    p,
                    imageSize,
                    cameraDesc.sensorOrientation,
                    screen,
                  ),
              ],
            ),
      ];
      // Only codes inside the scan frame count, and a pack's website QR
      // there loses to its EAN.
      final picked = pickCodeInFrame(placed, scanFrameRect(screen));

      if (picked != null) {
        setState(() {
          _detectedQrPoints = picked.code.points;
        });

        final productCode = picked.product;
        final barcodeVal = picked.code.value;
        if (productCode != null) {
          _onBarcodeDetected(productCode);
        } else if (_ignoredCode != barcodeVal) {
          _ignoredCode = barcodeVal;
          showErrorSnackBar(context, "That isn't a food barcode. Try another.");
        }
      } else {
        if (_detectedQrPoints.isNotEmpty && mounted) {
          setState(() {
            _detectedQrPoints = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error processing camera image: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _convertCameraImage(
    CameraImage image,
    CameraDescription cameraDesc,
  ) {
    try {
      // NV21 (Android) and BGRA (iOS) both come as a single plane.
      if (image.planes.length != 1) return null;
      final bytes = image.planes.first.bytes;

      final rotation =
          InputImageRotationValue.fromRawValue(cameraDesc.sensorOrientation) ??
          InputImageRotation.rotation90deg;

      InputImageFormat format;
      if (Platform.isAndroid) {
        format = InputImageFormat.nv21;
      } else if (Platform.isIOS) {
        format = InputImageFormat.bgra8888;
      } else {
        format =
            InputImageFormatValue.fromRawValue(image.format.raw as int) ??
            InputImageFormat.nv21;
      }

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  /// A code's corners in the camera frame (its box when ML Kit gives none).
  List<Offset> _codeCorners(Barcode code) {
    final corners = code.cornerPoints;
    if (corners.length == 4) {
      return [for (final p in corners) Offset(p.x.toDouble(), p.y.toDouble())];
    }
    final box = code.boundingBox;
    return [box.topLeft, box.topRight, box.bottomRight, box.bottomLeft];
  }

  void _onBarcodeDetected(String barcode) async {
    if (_isScanningBarcode) return;
    _isScanningBarcode = true;
    _currentFailedBarcode = barcode;

    HapticFeedback.lightImpact();
    await _stopImageStream();

    if (mounted) {
      context.read<FoodScanBloc>().add(ScanBarcodeRequested(barcode));
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    // One scan at a time: a second capture would spend another scan.
    if (context.read<FoodScanBloc>().state is RecognizingFood) return;

    setState(() => _isCapturing = true);
    try {
      await _stopImageStream();
      final image = await controller.takePicture();
      if (!mounted) return;

      // Crop the captured photo to match the viewport outline
      final screenWidth = MediaQuery.sizeOf(context).width;
      final screenHeight = MediaQuery.sizeOf(context).height;
      final croppedFile = await cropCapturedImage(
        imagePath: image.path,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

      setState(() {
        _selectedImage = image;
        _croppedImage = XFile(croppedFile.path);
      });

      if (_isScanningNutritionLabel) {
        _processNutritionLabelOcr(croppedFile.path);
      } else {
        _analyzeImage(croppedFile.path);
      }
    } catch (e) {
      debugPrint('Photo capture failed: $e');
      if (!mounted) return;
      showErrorSnackBar(context, "Couldn't take the photo. Try again.");
      _resumeBarcodeReading();
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (context.read<FoodScanBloc>().state is RecognizingFood) return;
    await _stopImageStream();
    // Let the platform downscale large gallery photos natively; the upload
    // encoder shrinks further, but decoding a 12+ MP image in Dart is slow.
    XFile? image;
    try {
      image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
    } catch (e) {
      // Photo access denied or the picker failed to open.
      debugPrint('Gallery pick failed: $e');
      if (mounted)
        showErrorSnackBar(
          context,
          "Couldn't open your photos. Check app permissions.",
        );
    }
    if (!mounted) return;
    if (image == null) {
      // Cancelled: keep scanning barcodes.
      _resumeBarcodeReading();
      return;
    }
    if (!_isScanningNutritionLabel && await _lookUpBarcodeInPhoto(image.path))
      return;
    if (!mounted) return;

    setState(() {
      _selectedImage = image;
      _croppedImage = null;
    });

    if (_isScanningNutritionLabel) {
      _processNutritionLabelOcr(image.path);
    } else {
      _analyzeImage(image.path);
    }
  }

  /// Looks up a product barcode found in a picked photo instead of sending
  /// the photo to the AI: exact, and it keeps one of the day's photo scans.
  /// True when a lookup started.
  Future<bool> _lookUpBarcodeInPhoto(String path) async {
    try {
      final codes = await _barcodeScanner.processImage(
        InputImage.fromFilePath(path),
      );
      for (final code in codes) {
        final value = code.rawValue ?? code.displayValue;
        final product = value == null ? null : normalizeProductBarcode(value);
        if (product == null) continue;
        if (!mounted) return false;
        _onBarcodeDetected(product);
        return true;
      }
    } catch (e) {
      debugPrint('Barcode check on photo failed: $e');
    }
    return false;
  }

  /// The photo whose nutrition label is being read; null otherwise. Shown
  /// as an overlay on this page: a loader dialog had to be closed with a
  /// pop that could take the wrong screen with it after a back press.
  String? _readingLabelPath;

  Future<void> _processNutritionLabelOcr(String path) async {
    if (_readingLabelPath != null) return;
    setState(() => _readingLabelPath = path);

    try {
      final inputImage = InputImage.fromFilePath(path);
      final RecognizedText recognizedText = await _textRecognizer
          .processImage(inputImage)
          .timeout(const Duration(seconds: 30));
      final parsed = NutritionOcrParser.parseNutritionText(recognizedText.text);

      if (!mounted) return;
      setState(() => _readingLabelPath = null);

      // Open the verify/edit nutrition dialog
      _openNutritionManualEntry(parsed);
    } catch (e) {
      debugPrint('OCR processing error: $e');
      if (mounted) {
        setState(() => _readingLabelPath = null);
        showErrorSnackBar(
          context,
          mlKitErrorMessage(
            e,
            fallback: "Couldn't read the label. Enter the details.",
          ),
        );
        // Fallback to manual entry with empty values
        _openNutritionManualEntry(null);
      }
    }
  }

  void _openNutritionManualEntry(Map<String, double>? parsed) {
    // The dialog lives on the root navigator, above the BlocProvider, so
    // read the bloc here rather than from the dialog context.
    final bloc = context.read<FoodScanBloc>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return NutritionManualEntryDialog(
          barcode: _currentFailedBarcode ?? '',
          initialName: '',
          parsedNutrition: parsed,
          onSave:
              ({
                required String name,
                required double quantity,
                required String unit,
                required double calories,
                required double proteinG,
                required double carbsG,
                required double fatG,
                required double fiberG,
                required double sugarG,
                required double sodiumMg,
              }) {
                bloc.add(
                  AddCustomNutritionItemRequested(
                    // A new product: don't add to items left from an earlier scan.
                    replaceCurrent: true,
                    barcode: _currentFailedBarcode ?? '',
                    name: name,
                    quantity: quantity,
                    unit: unit,
                    calories: calories,
                    proteinG: proteinG,
                    carbsG: carbsG,
                    fatG: fatG,
                    fiberG: fiberG,
                    sugarG: sugarG,
                    sodiumMg: sodiumMg,
                    source: parsed != null ? 'ocr' : 'manual',
                  ),
                );

                // Clean up state
                if (!mounted) return;
                setState(() {
                  _isScanningNutritionLabel = false;
                  _currentFailedBarcode = null;
                  _selectedImage = null;
                  _croppedImage = null;
                });
              },
        );
      },
    ).then((_) {
      // If dialog was dismissed without saving, reset scanner
      if (mounted && _currentFailedBarcode != null) {
        _restartScanning();
      }
    });
  }

  void _showLookupFailureOptions() {
    showAppBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      builder: (BuildContext context) {
        final grey = context.vColors.grayText;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            AppDimens.space24,
            context.gutter,
            AppDimens.space16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Product not found',
                style: context.text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.space12),
              Text(
                "We don't know this product yet. Scan its label or add it yourself.",
                style: context.text.bodyMedium?.copyWith(color: grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.space24),
              AppPrimaryButton(
                label: 'Scan Nutrition Label',
                leadingIcon: const Icon(Icons.document_scanner_rounded),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isScanningNutritionLabel = true;
                    _isScanningBarcode = false;
                    _detectedQrPoints = [];
                  });
                  // Restart stream to let them take photo of label
                  _resumeBarcodeReading();
                },
              ),
              const SizedBox(height: AppDimens.space12),
              AppSecondaryButton(
                label: 'Enter Details Manually',
                leadingIcon: SvgPicture.asset(
                  'assets/icons/ui/edit.svg',
                  width: AppDimens.iconMd,
                  height: AppDimens.iconMd,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _openNutritionManualEntry(null);
                },
              ),
              const SizedBox(height: AppDimens.space8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _restartScanning();
                },
                style: TextButton.styleFrom(foregroundColor: grey),
                child: Text(
                  'Cancel & Scan Another',
                  style: context.text.labelLarge?.copyWith(color: grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _restartScanning() {
    if (!mounted) return;
    setState(() {
      _selectedImage = null;
      _croppedImage = null;
      _isScanningBarcode = false;
      _isScanningNutritionLabel = false;
      _currentFailedBarcode = null;
      _detectedQrPoints = [];
    });
    _resumeBarcodeReading();
  }

  void _analyzeImage(String path) {
    final bloc = context.read<FoodScanBloc>();
    if (bloc.state is RecognizingFood) return;
    bloc.add(ImageSelected(File(path)));
    bloc.add(RecognizeFoodRequested());
  }

  void _openDetail(BuildContext context) {
    final bloc = context.read<FoodScanBloc>();
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider<FoodScanBloc>.value(
              value: bloc,
              child: const FoodDetailPage(),
            ),
          ),
        )
        .then((_) {
          if (mounted) {
            setState(() {
              _selectedImage = null;
              _croppedImage = null;
              _isScanningBarcode = false;
              _detectedQrPoints = [];
            });
            _resumeBarcodeReading();
          }
        });
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    final enabled = !_torchEnabled;
    try {
      await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => _torchEnabled = enabled);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Flash is not available on this phone.');
    }
  }

  Future<void> _handleBack() async {
    if (context.read<FoodScanBloc>().state is RecognizingFood &&
        widget.onBack == null) {
      // A dashboard host asks in its own back handler.
      if (!await confirmLeaveFoodScan(context) || !mounted) return;
    }
    if (!mounted) return;
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.goNamed('dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FoodScanBloc, FoodScanState>(
      listenWhen: (previous, current) {
        // States the detail page owns; returning from them is not a new
        // result for this page (or it would push a second detail page).
        final wasInDetail =
            previous is RecognitionSucceeded ||
            previous is RecognitionLowConfidence ||
            previous is NutritionLoaded ||
            previous is LoadingNutrition ||
            previous is SavingMealLog ||
            previous is ScanActionFailed;

        return !wasInDetail &&
            (current is RecognitionSucceeded ||
                current is RecognitionLowConfidence ||
                current is NutritionLoaded ||
                current is RecognitionFailed ||
                current is ScanActionFailed);
      },
      listener: (context, state) {
        if (state is RecognitionSucceeded ||
            state is RecognitionLowConfidence ||
            state is NutritionLoaded) {
          _stopImageStream();
          if (widget.isEditingImage) {
            final bloc = context.read<FoodScanBloc>();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider<FoodScanBloc>.value(
                  value: bloc,
                  child: const FoodDetailPage(),
                ),
              ),
              (route) => route.isFirst,
            );
          } else {
            _openDetail(context);
          }
        } else if (state is RecognitionFailed) {
          if (state.failure is BarcodeNotFoundFailure) {
            _showLookupFailureOptions();
          } else if (state.failure is ScanQuotaExceededFailure) {
            _restartScanning();
            offerProForLimit(
              context,
              reason: ProReason.photoScans,
              message: state.failure.message,
            );
          } else {
            showErrorSnackBar(context, state.failure.message);
            _restartScanning();
          }
        } else if (state is ScanActionFailed) {
          showErrorSnackBar(context, state.failure.message);
          _restartScanning();
        }
      },
      builder: (context, state) {
        final isRecognizing = state is RecognizingFood;
        // Only read by the host's back handler, never listened to, so
        // setting it during build triggers nothing.
        widget.busy?.value = isRecognizing;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            // As a dashboard tab, the dashboard's own PopScope handles back;
            // every PopScope on a route is told, so handling it here too
            // would step back through two tabs at once.
            if (didPop || widget.onBack != null) return;
            _handleBack();
          },
          child: Scaffold(
            backgroundColor: AppColors.black,
            body: Stack(
              children: [
                Positioned.fill(child: _buildCameraLayer()),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.black.withValues(alpha: 0.48),
                          Colors.transparent,
                          AppColors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_permissionDenied)
                  Positioned.fill(
                    child: CameraPermissionSheet(
                      blocked: _permissionPermanentlyDenied,
                      onAllow: _allowCamera,
                      onGallery: _pickFromGallery,
                    ),
                  ),
                // Scanner focused viewport overlay
                if (_cameraController != null &&
                    _cameraController!.value.isInitialized &&
                    _cameraInitFuture != null &&
                    state is! RecognizingFood)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: ScannerOverlayPainter()),
                    ),
                  ),
                // Dynamic QR outline overlay when detected
                if (_cameraController != null &&
                    _cameraController!.value.isInitialized &&
                    state is! RecognizingFood &&
                    _detectedQrPoints.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: QrOutlinePainter(
                          points: _detectedQrPoints,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                  ),
                // Tells first-time users the camera reads barcodes by itself.
                if (_cameraController != null &&
                    _cameraController!.value.isInitialized &&
                    !isRecognizing &&
                    !_isScanningNutritionLabel &&
                    !_isScanningBarcode &&
                    _selectedImage == null &&
                    _croppedImage == null &&
                    _detectedQrPoints.isEmpty)
                  Positioned(
                    top:
                        scanFrameRect(MediaQuery.sizeOf(context)).bottom +
                        AppDimens.space16,
                    left: kScanFrameInset,
                    right: kScanFrameInset,
                    child: const IgnorePointer(
                      child: _ScannerHint(
                        icon: Icons.qr_code_scanner_rounded,
                        text: 'Point at a barcode, or tap Capture for a meal',
                      ),
                    ),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(kScanFrameInset),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            BackIcon(onClick: _handleBack, elevated: true),
                            const Spacer(),
                            _ScannerIconButton(
                              iconAsset: 'assets/icons/ui/info_icon.svg',
                              onTap: () {
                                showSmoothDialog(
                                  context: context,
                                  builder: (context) =>
                                      const AccuracyInfoDialog(),
                                );
                              },
                            ),
                          ],
                        ),
                        if (_isScanningNutritionLabel) ...[
                          const SizedBox(height: AppDimens.space16),
                          const _ScannerHint(
                            icon: Icons.document_scanner_rounded,
                            text:
                                'Align the nutrition facts table inside the frame and tap Capture.',
                            highlighted: true,
                          ),
                        ],
                        const Spacer(),
                        if (_croppedImage != null ||
                            _selectedImage != null) ...[
                          _ScannedPreviewCard(
                            imagePath: (_croppedImage ?? _selectedImage)!.path,
                            onEdit: _pickFromGallery,
                            onAdd: () => _analyzeImage(
                              (_croppedImage ?? _selectedImage)!.path,
                            ),
                          ),
                          const SizedBox(height: AppDimens.space16),
                        ],
                        // Barcodes and labels don't use a photo scan; with
                        // no camera the permission card has the gallery.
                        if (!isRecognizing &&
                            !_isScanningNutritionLabel &&
                            !_permissionDenied) ...[
                          const ScansLeftHint(),
                          const SizedBox(height: AppDimens.space12),
                        ],
                        if (!_permissionDenied)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ScannerIconButton(
                                iconAsset: 'assets/icons/ui/gallery_add.svg',
                                onTap: isRecognizing ? () {} : _pickFromGallery,
                              ),
                              const Flexible(
                                child: SizedBox(width: AppDimens.scanBarGap),
                              ),
                              _CaptureButton(
                                isLoading: _isCapturing,
                                onTap: _capturePhoto,
                              ),
                              const Flexible(
                                child: SizedBox(width: AppDimens.scanBarGap),
                              ),
                              _ScannerIconButton(
                                iconAsset: 'assets/icons/ui/flash.svg',
                                active: _torchEnabled,
                                onTap: _toggleFlash,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                if (state is RecognizingFood)
                  Positioned.fill(
                    child: _RecognizingOverlay(
                      image: File(_selectedImage?.path ?? state.image.path),
                      hint: 'This can take up to a minute.',
                    ),
                  ),
                if (_readingLabelPath case final labelPath?)
                  Positioned.fill(
                    child: _RecognizingOverlay(
                      image: File(labelPath),
                      title: 'Reading the label...',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Allow on the camera card: the system dialog, or Settings when it
  /// won't ask again (the camera starts on return, see [_restoreCamera]).
  Future<void> _allowCamera() async {
    if (_permissionPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    if (await AppPermission.camera.request()) {
      if (mounted) _initializeCamera();
      return;
    }
    final blocked = await AppPermission.camera.isBlocked();
    if (mounted) setState(() => _permissionPermanentlyDenied = blocked);
  }

  Widget _buildCameraLayer() {
    // The camera card is drawn above the shading (see build).
    if (_permissionDenied) {
      return const ColoredBox(color: AppColors.cameraBackdrop);
    }

    if (_errorMessage != null) {
      return _ScannerMessage(
        message: _errorMessage!,
        buttonLabel: 'Try Again',
        onTap: _initializeCamera,
      );
    }

    final controller = _cameraController;
    final initFuture = _cameraInitFuture;
    if (controller == null || initFuture == null) {
      return const _ScannerLoading();
    }

    return FutureBuilder<void>(
      future: initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ScannerLoading();
        }

        if (!controller.value.isInitialized) {
          return const _ScannerLoading();
        }

        return _FullScreenCameraPreview(controller: controller);
      },
    );
  }
}

class _RecognizingOverlay extends StatelessWidget {
  final File image;

  /// Second line under the title (how long it may take).
  final String? hint;

  final String title;

  const _RecognizingOverlay({
    required this.image,
    this.title = 'Analysing your meal...',
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(
            image,
            // Gallery picks can be 2048 px or more; decode at screen size.
            cacheWidth:
                (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppDimens.headerBlur / 2,
              sigmaY: AppDimens.headerBlur / 2,
            ),
            child: ColoredBox(color: AppColors.black.withValues(alpha: 0.35)),
          ),
        ),
        Center(
          child: Container(
            padding: AppDimens.cardPaddingLarge,
            margin: const EdgeInsets.symmetric(horizontal: AppDimens.space40),
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(AppDimens.radiusDialog),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VitalUpLoader(),
                const SizedBox(height: AppDimens.space20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.text.titleSmall?.copyWith(
                    color: AppColors.white,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: AppDimens.space8),
                  Text(
                    hint!,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FullScreenCameraPreview extends StatelessWidget {
  final CameraController controller;

  const _FullScreenCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _ScannerLoading extends StatelessWidget {
  const _ScannerLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.cameraBackdrop,
      child: Center(child: VitalUpLoader()),
    );
  }
}

/// The camera card in place of the viewfinder: what the camera is for,
/// then the system dialog on Allow (or Settings once it won't ask).
/// Drawn like the other permission cards: a sheet along the bottom edge
/// (same colour, corners and handle), scrolling when it can't fit.
class CameraPermissionSheet extends StatelessWidget {
  final bool blocked;
  final VoidCallback onAllow;
  final VoidCallback onGallery;

  const CameraPermissionSheet({
    required this.blocked,
    required this.onAllow,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    final sheet = Theme.of(context).bottomSheetTheme;
    final padding = context.safePadding;
    final handle = sheet.dragHandleSize;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppDimens.maxContentWidth,
          // Clear of the back button at the top.
          maxHeight:
              MediaQuery.sizeOf(context).height -
              padding.top -
              AppDimens.sectionGap * 2,
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: sheet.backgroundColor ?? context.colors.surface,
            shape:
                sheet.shape ??
                const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppDimens.radiusSheet),
                  ),
                ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              context.gutter,
              0,
              context.gutter,
              AppDimens.space16 + padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (handle != null)
                  SizedBox(
                    height: kMinInteractiveDimension,
                    child: Center(
                      child: Container(
                        width: handle.width,
                        height: handle.height,
                        decoration: BoxDecoration(
                          color: sheet.dragHandleColor,
                          borderRadius: BorderRadius.circular(handle.height),
                        ),
                      ),
                    ),
                  ),
                PermissionPrompt(
                  ask: const PermissionAsk(
                    main: AppPermission.camera,
                    title: 'Scan your food',
                    message:
                        'Point your camera at a meal, a barcode or a '
                        'nutrition label and VitalUp fills in the details.',
                  ),
                  missing: const [AppPermission.camera],
                  blocked: blocked,
                  onAllow: onAllow,
                  // Photos from the gallery work without the camera.
                  onNotNow: onGallery,
                  notNowLabel: 'Pick from gallery',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerMessage extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final VoidCallback onTap;

  const _ScannerMessage({
    required this.message,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cameraBackdrop,
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        AppDimens.space24,
        context.gutter,
        AppDimens.space24 +
            AppDimens.captureButtonSize +
            context.safePadding.bottom,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppDimens.space12),
          AppPrimaryButton(label: buttonLabel, onTap: onTap),
        ],
      ),
    );
  }
}

/// Hint banner shown while the user frames a nutrition-facts label.
/// A short instruction over the camera. [highlighted] (a primary border)
/// marks a mode the user picked, such as label scanning.
class _ScannerHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlighted;

  const _ScannerHint({
    required this.icon,
    required this.text,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusToast),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDimens.glassBlur / 2,
          sigmaY: AppDimens.glassBlur / 2,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space16,
            vertical: AppDimens.space12,
          ),
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppDimens.radiusToast),
            border: Border.all(
              color: highlighted
                  ? primary
                  : AppColors.white.withValues(alpha: 0.12),
              width: highlighted ? AppDimens.borderThick : AppDimens.borderThin,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: primary, size: AppDimens.iconLg),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Text(
                  text,
                  style: context.text.bodyMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma `bars & panels/ scan` side button: 48dp translucent-white circle,
/// "elevated" shadow, 24dp dark icon.
class _ScannerIconButton extends StatelessWidget {
  final String iconAsset;
  final VoidCallback onTap;
  final bool active;

  const _ScannerIconButton({
    required this.iconAsset,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final fill = active ? context.colors.primary : AppColors.cameraControlFill;
    return Container(
      width: AppDimens.backButtonSize,
      height: AppDimens.backButtonSize,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        boxShadow: AppShadows.elevated,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: SvgPicture.asset(
              iconAsset,
              width: AppDimens.iconLg,
              height: AppDimens.iconLg,
              colorFilter: const ColorFilter.mode(
                AppColors.darker,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma scan-bar shutter: 72dp translucent ring around a 54dp white disc
/// with the camera glyph.
class _CaptureButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _CaptureButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Capture',
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: AppDimens.captureButtonSize,
          height: AppDimens.captureButtonSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cameraCaptureRing,
          ),
          padding: const EdgeInsets.all(10.0),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cameraControlFill,
            ),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox.square(
                    dimension: AppDimens.iconLg,
                    child: CircularProgressIndicator(
                      color: AppColors.darker,
                      strokeWidth: AppDimens.borderThick,
                    ),
                  )
                : SvgPicture.asset(
                    'assets/icons/ui/camera.svg',
                    width: AppDimens.iconLg,
                    height: AppDimens.iconLg,
                    colorFilter: const ColorFilter.mode(
                      AppColors.darker,
                      BlendMode.srcIn,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ScannedPreviewCard extends StatelessWidget {
  final String imagePath;
  final VoidCallback onEdit;
  final VoidCallback onAdd;

  const _ScannedPreviewCard({
    required this.imagePath,
    required this.onEdit,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cardHeight = context.screenHeight * kScanFrameHeightFraction;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Image.file(
            File(imagePath),
            width: double.infinity,
            height: cardHeight,
            cacheWidth:
                (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.space8),
            child: FoodImageActionPill(onEdit: onEdit, onAdd: onAdd),
          ),
        ],
      ),
    );
  }
}

/// Small translucent pill with edit / add actions overlaid on a food photo
/// (Figma food scanner/info image chips).
class FoodImageActionPill extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback? onAdd;

  const FoodImageActionPill({super.key, required this.onEdit, this.onAdd});

  @override
  Widget build(BuildContext context) {
    Widget action(String asset, VoidCallback onTap) => InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space8),
        child: SvgPicture.asset(
          asset,
          width: AppDimens.iconMd,
          height: AppDimens.iconMd,
          colorFilter: const ColorFilter.mode(
            AppColors.darker,
            BlendMode.srcIn,
          ),
        ),
      ),
    );

    return Material(
      color: AppColors.cameraControlFill,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          action('assets/icons/ui/edit.svg', onEdit),
          if (onAdd != null) action('assets/icons/ui/plus.svg', onAdd!),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Color barrierColor;
  final double borderRadius;
  final double strokeWidth;
  final Color strokeColor;

  ScannerOverlayPainter({
    this.barrierColor = AppColors.cameraScrim,
    this.borderRadius = 72.0,
    this.strokeWidth = AppDimens.borderThick,
    this.strokeColor = AppColors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Viewport has the exact same dimensions as the captured preview card
    final Rect rect = scanFrameRect(size);
    final double left = rect.left;
    final double top = rect.top;
    final double boxWidth = rect.width;
    final double boxHeight = rect.height;
    final RRect rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    // 1. Draw the darkened background mask with cutout for viewport
    final Paint maskPaint = Paint()..color = barrierColor;
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, width, height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, maskPaint);

    // 2. Draw the corner brackets
    final Paint linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double lineLength = math.min(
      AppDimens.scanFrameBracket,
      math.min(boxWidth, boxHeight) / 3,
    );

    // Top Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(left, top + lineLength)
        ..lineTo(left, top + borderRadius)
        ..arcToPoint(
          Offset(left + borderRadius, top),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(left + lineLength, top),
      linePaint,
    );

    // Top Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(left + boxWidth - lineLength, top)
        ..lineTo(left + boxWidth - borderRadius, top)
        ..arcToPoint(
          Offset(left + boxWidth, top + borderRadius),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(left + boxWidth, top + lineLength),
      linePaint,
    );

    // Bottom Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(left, top + boxHeight - lineLength)
        ..lineTo(left, top + boxHeight - borderRadius)
        ..arcToPoint(
          Offset(left + borderRadius, top + boxHeight),
          radius: Radius.circular(borderRadius),
          clockwise: false,
        )
        ..lineTo(left + lineLength, top + boxHeight),
      linePaint,
    );

    // Bottom Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(left + boxWidth - lineLength, top + boxHeight)
        ..lineTo(left + boxWidth - borderRadius, top + boxHeight)
        ..arcToPoint(
          Offset(left + boxWidth, top + boxHeight - borderRadius),
          radius: Radius.circular(borderRadius),
          clockwise: false,
        )
        ..lineTo(left + boxWidth, top + boxHeight - lineLength),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<File> cropCapturedImage({
  required String imagePath,
  required double screenWidth,
  required double screenHeight,
}) async {
  try {
    final bytes = await File(imagePath).readAsBytes();
    // Decoding a full-resolution JPEG takes hundreds of ms; keep it off the
    // UI isolate so the capture animation doesn't freeze.
    final croppedBytes = await Isolate.run(
      () => _cropToScanFrame(bytes, screenWidth, screenHeight),
    );
    if (croppedBytes == null) return File(imagePath);
    return File(imagePath)..writeAsBytesSync(croppedBytes);
  } catch (_) {
    return File(imagePath);
  }
}

Uint8List? _cropToScanFrame(Uint8List bytes, double sw, double sh) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  // Camera JPEGs are often stored sensor-rotated with an EXIF orientation
  // tag. The crop math below is in upright screen space, so apply the
  // rotation first or the crop lands on the wrong part of the frame.
  final originalImage = img.bakeOrientation(decoded);

  final double imgW = originalImage.width.toDouble();
  final double imgH = originalImage.height.toDouble();

  // Viewport coordinates matching the custom painter overlay
  final frame = scanFrameRect(Size(sw, sh));
  final double boxWidth = frame.width;
  final double boxHeight = frame.height;
  final double boxLeft = frame.left;
  final double boxTop = frame.top;

  // Camera preview uses BoxFit.cover, so we calculate the scale and offsets
  final double scale = math.max(sw / imgW, sh / imgH);
  final double previewScaledW = imgW * scale;
  final double previewScaledH = imgH * scale;
  final double dx = (sw - previewScaledW) / 2;
  final double dy = (sh - previewScaledH) / 2;

  // Map screen coordinates of the viewport to original image pixels
  final double cropLeft = (boxLeft - dx) / scale;
  final double cropTop = (boxTop - dy) / scale;
  final double cropWidth = boxWidth / scale;
  final double cropHeight = boxHeight / scale;

  final croppedImage = img.copyCrop(
    originalImage,
    x: cropLeft.round().clamp(0, originalImage.width - 1),
    y: cropTop.round().clamp(0, originalImage.height - 1),
    width: cropWidth.round().clamp(1, originalImage.width),
    height: cropHeight.round().clamp(1, originalImage.height),
  );

  return img.encodeJpg(croppedImage, quality: 90);
}

class QrOutlinePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  QrOutlinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 4) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppDimens.borderThick * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();

    // Draw the outline path
    canvas.drawPath(path, paint);

    // Draw a translucent fill overlay inside the QR code region
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant QrOutlinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
