import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// `<cacheDir>/share/` — the one directory exposed through the Android
/// FileProvider (file_provider_paths.xml). Every pipeline that produces a
/// share-ready file (Dart image processor, native video encoder) writes here.
class SharePaths {
  static Future<String> newOutputPath(String extension, {String prefix = 'hd_status'}) async {
    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory(p.join(tempDir.path, 'share'));
    if (!shareDir.existsSync()) shareDir.createSync(recursive: true);
    return p.join(shareDir.path, '${prefix}_${DateTime.now().microsecondsSinceEpoch}.$extension');
  }
}
