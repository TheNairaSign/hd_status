import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Run once on app launch. Deletes share-output files older than 24h —
/// mirrors the native FileProvider's share directory (`<cacheDir>/share/`),
/// the one place every pipeline writes its output.
class TempStorageService {
  Future<void> cleanupOldShareFiles({Duration maxAge = const Duration(hours: 24)}) async {
    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory(p.join(tempDir.path, 'share'));
    if (!shareDir.existsSync()) return;

    final cutoff = DateTime.now().subtract(maxAge);
    for (final entity in shareDir.listSync()) {
      if (entity is! File) continue;
      try {
        if (entity.statSync().modified.isBefore(cutoff)) {
          entity.deleteSync();
        }
      } catch (_) {
        // Best-effort cleanup — a locked/already-gone file isn't fatal.
      }
    }
  }
}
