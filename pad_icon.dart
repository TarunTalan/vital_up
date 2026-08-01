import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icons/app_icon.png');
  if (!file.existsSync()) {
    print('Error: assets/icons/app_icon.png not found.');
    return;
  }

  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Error: Failed to decode PNG.');
    return;
  }

  // Backup original icon
  final backupFile = File('assets/icons/app_icon_original.png');
  if (!backupFile.existsSync()) {
    backupFile.writeAsBytesSync(bytes);
    print('Backup created at assets/icons/app_icon_original.png');
  }

  final int width = image.width;
  final int height = image.height;

  // Scale down the icon design to 85% of the canvas size
  // This will leave 7.5% padding on all sides.
  final double scaleFactor = 0.85;
  final int newWidth = (width * scaleFactor).round();
  final int newHeight = (height * scaleFactor).round();

  print('Resizing icon from ${width}x${height} to ${newWidth}x${newHeight}...');
  final resizedImage = img.copyResize(
    image,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.average,
  );

  // 1. Create a transparent canvas for Android Adaptive foreground
  final canvasTransparent = img.Image(width: width, height: height, numChannels: 4);
  img.fill(canvasTransparent, color: img.ColorRgba8(0, 0, 0, 0));

  // 2. Create a solid white canvas for iOS and Android legacy icons
  final canvasWhite = img.Image(width: width, height: height, numChannels: 4);
  img.fill(canvasWhite, color: img.ColorRgba8(255, 255, 255, 255));

  // Center the resized icon on both canvases
  final int dstX = (width - newWidth) ~/ 2;
  final int dstY = (height - newHeight) ~/ 2;

  print('Compositing centered icons...');
  img.compositeImage(
    canvasTransparent,
    resizedImage,
    dstX: dstX,
    dstY: dstY,
  );

  img.compositeImage(
    canvasWhite,
    resizedImage,
    dstX: dstX,
    dstY: dstY,
  );

  // Save the result files
  File('assets/icons/app_icon_transparent.png').writeAsBytesSync(img.encodePng(canvasTransparent));
  File('assets/icons/app_icon_white.png').writeAsBytesSync(img.encodePng(canvasWhite));

  print('Success!');
  print('- Transparent padded icon saved to assets/icons/app_icon_transparent.png');
  print('- White padded icon saved to assets/icons/app_icon_white.png');
}
