import 'dart:io';
import 'package:image/image.dart';

void main() async {
  final file = File('assets/images/splash.png');
  if (!file.existsSync()) {
    print('Error: assets/images/splash.png not found');
    exit(1);
  }

  print('Reading splash image...');
  final bytes = await file.readAsBytes();
  final image = decodeImage(bytes);

  if (image == null) {
    print('Error: Could not decode image');
    exit(1);
  }

  print('Original size: ${image.width}x${image.height}');

  // Find bounding box of non-transparent pixels
  int minX = image.width;
  int minY = image.height;
  int maxX = 0;
  int maxY = 0;
  bool found = false;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.a > 0) {
        // Alpha > 0 means not fully transparent
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        found = true;
      }
    }
  }

  if (!found) {
    print('Warning: Image appears to be fully transparent');
    return;
  }

  // Add some padding (e.g., 20px)
  const padding = 20;
  minX = (minX - padding).clamp(0, image.width);
  minY = (minY - padding).clamp(0, image.height);
  maxX = (maxX + padding).clamp(0, image.width);
  maxY = (maxY + padding).clamp(0, image.height);

  final width = maxX - minX;
  final height = maxY - minY;

  print('Cropping to: $width x $height (from ($minX, $minY))');

  final cropped = copyCrop(
    image,
    x: minX,
    y: minY,
    width: width,
    height: height,
  );

  // Backup original
  await file.copy('assets/images/splash_backup.png');
  print('Original backed up to assets/images/splash_backup.png');

  // Save cropped
  // Encode as PNG
  final encoded = encodePng(cropped);
  await file.writeAsBytes(encoded);
  print('Saved cropped image to assets/images/splash.png');
}
