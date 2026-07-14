import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_state.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/food_detail_page.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';

final GetIt _sl = GetIt.instance;

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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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
        imageFormatGroup: ImageFormatGroup.jpeg,
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to start camera.');
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
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
      _analyzeImage(croppedFile.path);
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
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() {
      _selectedImage = image;
      _croppedImage = null;
    });
    _analyzeImage(image.path);
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
        });
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FoodScanBloc, FoodScanState>(
      listenWhen: (previous, current) {
        // Prevent duplicate navigation / page pushes:
        // If the previous state was already a detail-view state, we are already
        // showing the detail page. In that case, do not push another screen.
        final wasInDetail = previous is RecognitionSucceeded ||
            previous is RecognitionLowConfidence ||
            previous is NutritionLoaded ||
            previous is LoadingNutrition;

        return !wasInDetail &&
            (current is RecognitionSucceeded ||
             current is RecognitionLowConfidence ||
             current is RecognitionFailed);
      },
      listener: (context, state) {
        if (state is RecognitionSucceeded ||
            state is RecognitionLowConfidence) {
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
          setState(() {
            _selectedImage = null;
            _croppedImage = null;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.failure.message)));
        }
      },
      builder: (context, state) {
        final isRecognizing = state is RecognizingFood;
        return Scaffold(
          backgroundColor: Colors.black,
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
                        Colors.black.withValues(alpha: 0.48),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
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
                    child: CustomPaint(
                      painter: ScannerOverlayPainter(
                        strokeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          BackIcon(
                            onClick: widget.onBack ??
                                () => Navigator.of(context).maybePop(),
                          ),
                          const Spacer(),
                          _ScannerIconButton(
                            iconAsset: 'assets/icons/info_icon.svg',
                            onTap: () {},
                            size: 26,
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (_croppedImage != null || _selectedImage != null) ...[
                        _ScannedPreviewCard(
                          imagePath: (_croppedImage ?? _selectedImage)!.path,
                          onEdit: _pickFromGallery,
                          onAdd: () => _analyzeImage((_croppedImage ?? _selectedImage)!.path),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ScannerIconButton(
                            iconAsset: 'assets/icons/gallery_add.svg',
                            onTap: isRecognizing ? () {} : _pickFromGallery,
                          ),
                          _CaptureButton(
                            isLoading: _isCapturing,
                            onTap: _capturePhoto,
                          ),
                          _ScannerIconButton(
                            iconAsset: 'assets/icons/flash.svg',
                            color: _torchEnabled ? Colors.yellow : Colors.white,
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
        // 1. Display the captured image in the background (full size to avoid zoom jumps)
        Positioned.fill(
          child: Image.file(
            image,
            fit: BoxFit.cover,
          ),
        ),
        // 2. Apply glassmorphic blur filter on top of the image
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),
        // 3. Center loading card
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VitalUpLoader(
                  size: 80,
                  iconSize: 26,
                ),
                SizedBox(height: 20),
                Text(
                  'Analysing your meal...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
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
    return Container(
      color: const Color(0xFF101316),
      child: const Center(
        child: VitalUpLoader(
          size: 80,
          iconSize: 26,
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
      color: const Color(0xFF101316),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onTap, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class _ScannerIconButton extends StatelessWidget {
  final String iconAsset;
  final VoidCallback onTap;
  final Color color;
  final double size;

  const _ScannerIconButton({
    required this.iconAsset,
    required this.onTap,
    this.color = Colors.white,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 50,
        height: 50,
        child: Center(
          child: SvgPicture.asset(
            iconAsset,
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _CaptureButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
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
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double cardHeight = screenHeight * 0.35;

    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width - 40.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      icon: SvgPicture.asset(
                        'assets/icons/edit.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: onAdd,
                      icon: SvgPicture.asset(
                        'assets/icons/plus.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    this.barrierColor = const Color(0x66000000),
    this.borderRadius = 24.0,
    this.strokeWidth = 3.0,
    this.strokeColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Viewport has the exact same dimensions as the captured preview card
    final double boxWidth = width - 40.0;
    final double boxHeight = height * 0.35;
    final double left = (width - boxWidth) / 2;
    final double top = (height - boxHeight) / 2 - 40; // offset upwards slightly for aesthetic balance
    final Rect rect = Rect.fromLTWH(left, top, boxWidth, boxHeight);
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Draw the darkened background mask with cutout for viewport
    final Paint maskPaint = Paint()..color = barrierColor;
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, width, height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, maskPaint);

    // 2. Draw the viewport outline with low opacity
    final Paint outlinePaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.18)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, outlinePaint);

    // 3. Draw the corner brackets
    final Paint linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double lineLength = 20.0; // bracket arm length

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
    final originalImage = img.decodeImage(bytes);
    if (originalImage == null) return File(imagePath);

    final double imgW = originalImage.width.toDouble();
    final double imgH = originalImage.height.toDouble();

    final double sw = screenWidth;
    final double sh = screenHeight;

    // Viewport coordinates matching the custom painter overlay
    final double boxWidth = sw - 40.0;
    final double boxHeight = sh * 0.35;
    final double boxLeft = (sw - boxWidth) / 2;
    final double boxTop = (sh - boxHeight) / 2 - 40;

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

    final croppedBytes = img.encodeJpg(croppedImage);
    final croppedFile = File(imagePath)..writeAsBytesSync(croppedBytes);
    return croppedFile;
  } catch (_) {
    return File(imagePath);
  }
}

