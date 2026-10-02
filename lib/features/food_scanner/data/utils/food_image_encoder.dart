import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Longest edge sent to the vision model. Vision models downsample
/// internally (Gemini tiles at 768 px, Groq bills a flat token cost per
/// image), so anything larger only adds upload time: a 12 MP gallery photo
/// is ~4 MB, this is typically 100-200 KB.
const int kFoodImageMaxEdge = 1024;
const int kFoodImageJpegQuality = 85;

/// Downscales, applies EXIF orientation and re-encodes [path] as JPEG in a
/// background isolate. Falls back to the original bytes if decoding fails
/// (e.g. HEIC on older devices) so a scan is never blocked by this step.
Future<Uint8List> encodeFoodImageForUpload(String path) async =>
    encodeFoodImageBytesForUpload(await File(path).readAsBytes());

/// [encodeFoodImageForUpload] for bytes already read from disk.
Future<Uint8List> encodeFoodImageBytesForUpload(Uint8List original) async {
  try {
    return await Isolate.run(() => _encode(original));
  } catch (_) {
    return original;
  }
}

Uint8List _encode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  var image = img.bakeOrientation(decoded);
  final longEdge = image.width > image.height ? image.width : image.height;
  if (longEdge > kFoodImageMaxEdge) {
    image = image.width >= image.height
        ? img.copyResize(image, width: kFoodImageMaxEdge, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: kFoodImageMaxEdge, interpolation: img.Interpolation.average);
  }
  return img.encodeJpg(image, quality: kFoodImageJpegQuality);
}
