import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class FoodScannerPage extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<String?> onNavigateToDetail;

  const FoodScannerPage({
    super.key,
    required this.onBack,
    required this.onNavigateToDetail,
  });

  @override
  State<FoodScannerPage> createState() => _FoodScannerPageState();
}

class _FoodScannerPageState extends State<FoodScannerPage> {
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
      widget.onNavigateToDetail(image.path);
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
    widget.onNavigateToDetail(image.path);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash is not available.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        onTap: widget.onBack,
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
                      onAdd: () => widget.onNavigateToDetail(_selectedImage!.path),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ScannerIconButton(
                        iconAsset: 'assets/icons/gallery_add.svg',
                        onTap: _pickFromGallery,
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
        ],
      ),
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
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onTap,
            child: Text(buttonLabel),
          ),
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

  const _CaptureButton({
    required this.isLoading,
    required this.onTap,
  });

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
                        colorFilter:
                            const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: onAdd,
                      icon: SvgPicture.asset(
                        'assets/icons/plus.svg',
                        width: 22,
                        height: 22,
                        colorFilter:
                            const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
