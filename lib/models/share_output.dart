/// A single ready-to-share result — one item from the normal Processing
/// path, or one clip from a split. Shared by Result and Clips-ready.
class ShareOutput {
  const ShareOutput({
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.isVideo,
    this.unchanged = false,
  });

  final String filePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final bool isVideo;

  /// True when this was a passthrough — no processing changed the file.
  final bool unchanged;

  String get sizeLabel {
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)}MB';
    return '${(sizeBytes / 1024).toStringAsFixed(0)}KB';
  }
}
