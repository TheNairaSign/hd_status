package com.example.hd_status.media

import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import androidx.exifinterface.media.ExifInterface
import java.io.File

/** Read-only metadata probe — no transformation, no I/O beyond reading the
 * one file. Wraps MediaMetadataRetriever for video and BitmapFactory/Exif
 * for images, per the plan's Phase 3. */
class MediaProbe {
    fun probe(filePath: String): Map<String, Any?> {
        val file = File(filePath)
        if (!file.exists()) throw IllegalArgumentException("File not found: $filePath")
        val sizeBytes = file.length()
        val mime = guessMimeType(filePath)

        return if (mime?.startsWith("video/") == true) {
            probeVideo(filePath, mime, sizeBytes)
        } else {
            probeImage(filePath, mime, sizeBytes)
        }
    }

    private fun probeVideo(filePath: String, mime: String, sizeBytes: Long): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(filePath)
            val durationMs = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
                ?: throw IllegalStateException("Unreadable/unsupported video")
            val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            return mapOf(
                "type" to "video",
                "mimeType" to mime,
                "width" to width,
                "height" to height,
                "durationMs" to durationMs,
                "rotationDegrees" to rotation,
                "sizeBytes" to sizeBytes,
            )
        } finally {
            retriever.release()
        }
    }

    private fun probeImage(filePath: String, mime: String?, sizeBytes: Long): Map<String, Any?> {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(filePath, options)
        if (options.outWidth <= 0 || options.outHeight <= 0) {
            throw IllegalStateException("Unreadable/unsupported image")
        }

        var rotation = 0
        try {
            val exif = ExifInterface(filePath)
            rotation = when (exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }
        } catch (e: Exception) {
            // No EXIF block, or unreadable — orientation stays 0, not fatal.
        }

        return mapOf(
            "type" to "image",
            "mimeType" to (mime ?: options.outMimeType),
            "width" to options.outWidth,
            "height" to options.outHeight,
            "durationMs" to null,
            "rotationDegrees" to rotation,
            "sizeBytes" to sizeBytes,
        )
    }

    private fun guessMimeType(filePath: String): String? {
        return when (filePath.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            "heic", "heif" -> "image/heic"
            "mp4" -> "video/mp4"
            "mov" -> "video/quicktime"
            "webm" -> "video/webm"
            "3gp" -> "video/3gpp"
            "mkv" -> "video/x-matroska"
            else -> null
        }
    }
}
