import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// NOTE: removed unused imports (TypedData / material) to fix analyzer warnings

// Compress image using FlutterImageCompress. Runs on main thread but uses native
// implementation. We still run a lightweight wrapper in compute for safety.
Future<File> compressImage(
  File inputFile, {
  int quality = 85,
  int width = 800,
  int height = 800,
}) async {
  final tempDir = await getTemporaryDirectory();
  final targetPath =
      '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

  // Call the compression directly (compute may cause issues on physical devices)
  final resultPath = await _compressWorker(
    _CompressParams(
      inputPath: inputFile.path,
      targetPath: targetPath,
      quality: quality,
      width: width,
      height: height,
    ),
  );

  if (resultPath == null) {
    // Fallback - return original file if we couldn't compress
    return inputFile;
  }

  return File(resultPath);
}

class _CompressParams {
  final String inputPath;
  final String targetPath;
  final int quality;
  final int width;
  final int height;

  _CompressParams({
    required this.inputPath,
    required this.targetPath,
    required this.quality,
    required this.width,
    required this.height,
  });
}

Future<String?> _compressWorker(_CompressParams params) async {
  try {
    final result = await FlutterImageCompress.compressAndGetFile(
      params.inputPath,
      params.targetPath,
      quality: params.quality,
      minWidth: params.width,
      minHeight: params.height,
      keepExif: true,
    );
    return result?.path;
  } catch (e) {
    debugPrint('Compression failed: $e');
    return null;
  }
}

/// Uploads a file to Supabase Storage `covers` bucket and returns a public URL if possible.
/// Uses basic retry/backoff.
Future<String?> uploadCoverFile(File file, {int maxRetries = 3}) async {
  final client = Supabase.instance.client;
  final fileName =
      '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';
  const bucket = 'covers';

  for (var attempt = 0; attempt < maxRetries; attempt++) {
    try {
      // Upload the file
      await client.storage.from(bucket).upload(fileName, file);

      // Try to get a public URL
      try {
        return client.storage.from(bucket).getPublicUrl(fileName);
      } catch (e) {
        debugPrint('getPublicUrl failed: $e');
      }

      // Fallback: create a signed URL (1 day)
      try {
        return await client.storage
            .from(bucket)
            .createSignedUrl(fileName, 86400);
      } catch (e) {
        debugPrint('createSignedUrl failed: $e');
      }

      // If we didn't return yet, return a best-effort path (non-public):
      return '/storage/v1/object/public/$bucket/$fileName';
    } catch (e) {
      debugPrint('upload attempt ${attempt + 1} failed: $e');
      await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
      continue;
    }
  }
  return null;
}
