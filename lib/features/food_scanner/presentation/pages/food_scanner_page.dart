import 'dart:io';

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

final GetIt _sl = GetIt.instance;

class FoodScannerPage extends StatelessWidget {
  final VoidCallback? onBack;

  const FoodScannerPage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FoodScanBloc>(
      create: (_) => _sl<FoodScanBloc>(),
      child: FoodScannerView(onBack: onBack),
    );
  }
}

class FoodScannerView extends StatefulWidget {
  final VoidCallback? onBack;

  const FoodScannerView({super.key, this.onBack});

  @override
  State<FoodScannerView> createState() => _FoodScannerViewState();
}

class _FoodScannerViewState extends State<FoodScannerView> {
  final ImagePicker _imagePicker = ImagePicker();
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  XFile? _selectedImage;
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
      setState(() => _selectedImage = image);
      _analyzeImage(image.path);
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

    setState(() => _selectedImage = image);
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
    );
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
      listenWhen: (previous, current) =>
          current is RecognitionSucceeded ||
          current is RecognitionLowConfidence ||
          current is RecognitionFailed,
      listener: (context, state) {
        if (state is RecognitionSucceeded ||
            state is RecognitionLowConfidence) {
          _openDetail(context);
        } else if (state is RecognitionFailed) {
          setState(() => _selectedImage = null);
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
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _ScannerIconButton(
                            iconAsset: 'assets/icons/arrow.svg',
                            onTap:
                                widget.onBack ??
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
                      if (_selectedImage != null) ...[
                        _ScannedPreviewCard(
                          imagePath: _selectedImage!.path,
                          onEdit: _pickFromGallery,
                          onAdd: () => _analyzeImage(_selectedImage!.path),
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
                            isLoading: _isCapturing || isRecognizing,
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
              if (isRecognizing)
                const Positioned.fill(child: _RecognizingOverlay()),
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
  const _RecognizingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Analysing your meal...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
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
        child: CircularProgressIndicator(color: Colors.white),
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
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.7,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Image.file(
                File(imagePath),
                width: double.infinity,
                height: 180,
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
