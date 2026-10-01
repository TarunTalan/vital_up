import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/utils/responsive.dart';

final GetIt _sl = GetIt.instance;

/// Scan-frame geometry, shared by the overlay painter, the captured preview
/// card and [cropCapturedImage] so the crop always matches what is drawn.
const double _scanFrameInset = AppDimens.gutter;
const double _scanFrameHeightFraction = 0.35;
const double _scanFrameLift = AppDimens.space40;

class FoodScannerPage extends StatelessWidget {
  final VoidCallback? onBack;
  final bool isEditingImage;

  const FoodScannerPage({super.key, this.onBack, this.isEditingImage = false});

  @override
  Widget build(BuildContext context) {
    if (isEditingImage) {
      return FoodScannerView(onBack: onBack, isEditingImage: isEditingImage);
    }
    return BlocProvider<FoodScanBloc>(
      create: (_) => _sl<FoodScanBloc>(),
      child: FoodScannerView(onBack: onBack, isEditingImage: isEditingImage),
    );
  }
}

class FoodScannerView extends StatefulWidget {
  final VoidCallback? onBack;
  final bool isEditingImage;

  const FoodScannerView({super.key, this.onBack, this.isEditingImage = false});

  @override
  State<FoodScannerView> createState() => _FoodScannerViewState();
}

class _FoodScannerViewState extends State<FoodScannerView> {
  final ImagePicker _imagePicker = ImagePicker();
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  XFile? _selectedImage;
  XFile? _croppedImage;
  bool _permissionDenied = false;
  bool _isCapturing = false;
  bool _torchEnabled = false;
  String? _errorMessage;

  CameraDescription? _cameraDescription;
  final BarcodeScanner _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  bool _isScanningBarcode = false;
  bool _isScanningNutritionLabel = false;
  String? _currentFailedBarcode;
  List<Offset> _detectedQrPoints = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopImageStream();
    _cameraController?.dispose();
    _barcodeScanner.close();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _permissionDenied = false;
      _errorMessage = null;
    });

    final permission = await Permission.camera.request();
    if (!mounted) return;

    if (!permission.isGranted) {
      setState(() => _permissionDenied = true);
      return;
    }

    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera found on this device.');
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      _cameraInitFuture = controller.initialize();
      await _cameraInitFuture;
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await _cameraController?.dispose();
      setState(() {
        _cameraController = controller;
        _cameraDescription = backCamera;
      });

      _startImageStream(controller);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to start camera.');
    }
  }

  void _startImageStream(CameraController controller) {
    if (_isStreaming) return;
    _isStreaming = true;
    _isProcessingFrame = false;
    _detectedQrPoints = [];

    controller.startImageStream((CameraImage image) {
      _processCameraImage(image);
    });
  }

  Future<void> _stopImageStream() async {
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
    if (_isProcessingFrame || _isScanningBarcode) return;
    _isProcessingFrame = true;

    try {
      final cameraDesc = _cameraDescription;
      if (cameraDesc == null) return;

      final inputImage = _convertCameraImage(image, cameraDesc);
      if (inputImage == null) return;

      final barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty && mounted) {
        final qr = barcodes.first;
        final corners = qr.cornerPoints;
        final barcodeVal = qr.rawValue ?? qr.displayValue;

        if (corners.length == 4) {
          final screenW = MediaQuery.sizeOf(context).width;
          final screenH = MediaQuery.sizeOf(context).height;

          final screenPoints = corners.map((p) {
            return _mapPoint(
              p,
              Size(image.width.toDouble(), image.height.toDouble()),
              cameraDesc.sensorOrientation,
              Size(screenW, screenH),
            );
          }).toList();

          if (mounted) {
            setState(() {
              _detectedQrPoints = screenPoints;
            });
          }

          if (barcodeVal != null && barcodeVal.isNotEmpty) {
            _onBarcodeDetected(barcodeVal);
          }
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

  InputImage? _convertCameraImage(CameraImage image, CameraDescription cameraDesc) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final rotation = InputImageRotationValue.fromRawValue(cameraDesc.sensorOrientation) ??
          InputImageRotation.rotation90deg;

      InputImageFormat format;
      if (Platform.isAndroid) {
        format = InputImageFormat.nv21;
      } else if (Platform.isIOS) {
        format = InputImageFormat.bgra8888;
      } else {
        format = InputImageFormatValue.fromRawValue(image.format.raw as int) ??
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

  Offset _mapPoint(math.Point<int> point, Size imageSize, int sensorOrientation, Size widgetSize) {
    final double imgW = imageSize.width;
    final double imgH = imageSize.height;
    final double widgetW = widgetSize.width;
    final double widgetH = widgetSize.height;

    final double previewW = imgH;
    final double previewH = imgW;

    final double scaleX = widgetW / previewW;
    final double scaleY = widgetH / previewH;
    final double scale = math.max(scaleX, scaleY);

    final double scaledW = previewW * scale;
    final double scaledH = previewH * scale;
    final double dx = (widgetW - scaledW) / 2;
    final double dy = (widgetH - scaledH) / 2;

    double x = point.x.toDouble();
    double y = point.y.toDouble();

    if (sensorOrientation == 90) {
      return Offset(
        (imgH - y) * scale + dx,
        x * scale + dy,
      );
    } else if (sensorOrientation == 270) {
      return Offset(
        y * scale + dx,
        (imgW - x) * scale + dy,
      );
    } else {
      return Offset(
        x * scale + dx,
        y * scale + dy,
      );
    }
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    await _stopImageStream();
    // Let the platform downscale large gallery photos natively; the upload
    // encoder shrinks further, but decoding a 12+ MP image in Dart is slow.
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 92,
    );
    if (image == null || !mounted) return;

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

  Future<void> _processNutritionLabelOcr(String path) async {
    // Show a loading indicator
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        );
      },
    );

    try {
      final inputImage = InputImage.fromFilePath(path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final parsed = NutritionOcrParser.parseNutritionText(recognizedText.text);

      // Close the loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Open the verify/edit nutrition dialog
      _openNutritionManualEntry(parsed);
    } catch (e) {
      debugPrint('OCR processing error: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loader
        // Fallback to manual entry with empty values
        _openNutritionManualEntry(null);
      }
    }
  }

  void _openNutritionManualEntry(Map<String, double>? parsed) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return NutritionManualEntryDialog(
          barcode: _currentFailedBarcode ?? '',
          initialName: '',
          parsedNutrition: parsed,
          onSave: ({
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
            final bloc = context.read<FoodScanBloc>();
            bloc.add(AddCustomNutritionItemRequested(
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
            ));

            // Clean up state
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
      if (_currentFailedBarcode != null) {
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
                'Product Not Found',
                style: context.text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.space12),
              Text(
                'We couldn\'t find details for barcode "$_currentFailedBarcode". How would you like to proceed?',
                style: context.text.bodyMedium?.copyWith(color: grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.space24),
              AppPrimaryButton(
                label: 'Scan Nutrition Label',
                leadingIcon: const Icon(Icons.document_scanner_outlined),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isScanningNutritionLabel = true;
                    _isScanningBarcode = false;
                    _detectedQrPoints = [];
                  });
                  // Restart stream to let them take photo of label
                  final controller = _cameraController;
                  if (controller != null && controller.value.isInitialized) {
                    _startImageStream(controller);
                  }
                },
              ),
              const SizedBox(height: AppDimens.space12),
              AppSecondaryButton(
                label: 'Enter Details Manually',
                leadingIcon: const Icon(Icons.edit_note_rounded),
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
    setState(() {
      _selectedImage = null;
      _croppedImage = null;
      _isScanningBarcode = false;
      _isScanningNutritionLabel = false;
      _currentFailedBarcode = null;
      _detectedQrPoints = [];
    });
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      _startImageStream(controller);
    }
  }

  void _analyzeImage(String path) {
    final bloc = context.read<FoodScanBloc>();
    bloc.add(ImageSelected(File(path)));
    bloc.add(RecognizeFoodRequested());
  }

  void _openDetail(BuildContext context) {
    final bloc = context.read<FoodScanBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<FoodScanBloc>.value(
          value: bloc,
          child: const FoodDetailPage(),
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedImage = null;
          _croppedImage = null;
          _isScanningBarcode = false;
          _detectedQrPoints = [];
        });
        final controller = _cameraController;
        if (controller != null && controller.value.isInitialized) {
          _startImageStream(controller);
        }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Flash is not available.')));
    }
  }

  void _handleBack() {
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
        final wasInDetail = previous is RecognitionSucceeded ||
            previous is RecognitionLowConfidence ||
            previous is NutritionLoaded ||
            previous is LoadingNutrition;

        return !wasInDetail &&
            (current is RecognitionSucceeded ||
             current is RecognitionLowConfidence ||
             current is NutritionLoaded ||
             current is RecognitionFailed);
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
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.failure.message)));
            _restartScanning();
          }
        }
      },
      builder: (context, state) {
        final isRecognizing = state is RecognizingFood;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
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
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(_scanFrameInset),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          BackIcon(
                            onClick: _handleBack,
                          ),
                          const Spacer(),
                          _ScannerIconButton(
                            iconAsset: 'assets/icons/info_icon.svg',
                            onTap: () {
                              showSmoothDialog(
                                context: context,
                                builder: (context) => const AccuracyInfoDialog(),
                              );
                            },
                          ),
                        ],
                      ),
                      if (_isScanningNutritionLabel) ...[
                        const SizedBox(height: AppDimens.space16),
                        const _NutritionLabelHint(),
                      ],
                      const Spacer(),
                      if (_croppedImage != null || _selectedImage != null) ...[
                        _ScannedPreviewCard(
                          imagePath: (_croppedImage ?? _selectedImage)!.path,
                          onEdit: _pickFromGallery,
                          onAdd: () => _analyzeImage((_croppedImage ?? _selectedImage)!.path),
                        ),
                        const SizedBox(height: AppDimens.space16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ScannerIconButton(
                            iconAsset: 'assets/icons/gallery_add.svg',
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
                            iconAsset: 'assets/icons/flash.svg',
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
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildCameraLayer() {
    if (_permissionDenied) {
      return _ScannerMessage(
        message: 'Camera permission is required to scan food.',
        buttonLabel: 'Grant Permission',
        onTap: _initializeCamera,
      );
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

  const _RecognizingOverlay({required this.image});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(
            image,
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppDimens.headerBlur / 2,
              sigmaY: AppDimens.headerBlur / 2,
            ),
            child: ColoredBox(
              color: AppColors.black.withValues(alpha: 0.35),
            ),
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
                  'Analysing your meal...',
                  textAlign: TextAlign.center,
                  style: context.text.titleSmall?.copyWith(
                    color: AppColors.white,
                  ),
                ),
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
class _NutritionLabelHint extends StatelessWidget {
  const _NutritionLabelHint();

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
            border: Border.all(color: primary, width: AppDimens.borderThick),
          ),
          child: Row(
            children: [
              Icon(
                Icons.document_scanner_outlined,
                color: primary,
                size: AppDimens.iconLg,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Text(
                  'Align the nutrition facts table inside the frame and tap Capture.',
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
                    'assets/icons/camera.svg',
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
    final cardHeight = context.screenHeight * _scanFrameHeightFraction;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Image.file(
            File(imagePath),
            width: double.infinity,
            height: cardHeight,
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
          action('assets/icons/edit.svg', onEdit),
          if (onAdd != null) action('assets/icons/plus.svg', onAdd!),
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
    final double boxWidth = width - 2 * _scanFrameInset;
    final double boxHeight = height * _scanFrameHeightFraction;
    final double left = (width - boxWidth) / 2;
    final double top = (height - boxHeight) / 2 - _scanFrameLift;
    final Rect rect = Rect.fromLTWH(left, top, boxWidth, boxHeight);
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

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

    final double lineLength = math.min(AppDimens.scanFrameBracket, math.min(boxWidth, boxHeight) / 3);

    // Top Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(left, top + lineLength)
        ..lineTo(left, top + borderRadius)
        ..arcToPoint(Offset(left + borderRadius, top), radius: Radius.circular(borderRadius))
        ..lineTo(left + lineLength, top),
      linePaint,
    );

    // Top Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(left + boxWidth - lineLength, top)
        ..lineTo(left + boxWidth - borderRadius, top)
        ..arcToPoint(Offset(left + boxWidth, top + borderRadius), radius: Radius.circular(borderRadius))
        ..lineTo(left + boxWidth, top + lineLength),
      linePaint,
    );

    // Bottom Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(left, top + boxHeight - lineLength)
        ..lineTo(left, top + boxHeight - borderRadius)
        ..arcToPoint(Offset(left + borderRadius, top + boxHeight), radius: Radius.circular(borderRadius), clockwise: false)
        ..lineTo(left + lineLength, top + boxHeight),
      linePaint,
    );

    // Bottom Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(left + boxWidth - lineLength, top + boxHeight)
        ..lineTo(left + boxWidth - borderRadius, top + boxHeight)
        ..arcToPoint(Offset(left + boxWidth, top + boxHeight - borderRadius), radius: Radius.circular(borderRadius), clockwise: false)
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
  final double boxWidth = sw - 2 * _scanFrameInset;
  final double boxHeight = sh * _scanFrameHeightFraction;
  final double boxLeft = (sw - boxWidth) / 2;
  final double boxTop = (sh - boxHeight) / 2 - _scanFrameLift;

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

  QrOutlinePainter({
    required this.points,
    required this.color,
  });

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

