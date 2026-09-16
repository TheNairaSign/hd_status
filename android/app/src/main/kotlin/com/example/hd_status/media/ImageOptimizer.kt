/*
 * Native image downscale/re-encode, replacing the earlier pure-Dart
 * pipeline (image_processor.dart used the `image` package). Two real wins
 * over that path:
 *  - BitmapFactory's inSampleSize decodes already-downsampled, instead of
 *    allocating a full-resolution bitmap (often 4000px+, tens of MB) just
 *    to immediately shrink it in memory.
 *  - Bitmap.compress(JPEG) goes through Android's native encoder
 *    (Skia/libjpeg-turbo), generally higher quality-per-byte than the pure
 *    Dart `image` package's encoder at the same quality setting — that gap
 *    was the ceiling on how far parameter tuning alone could close the
 *    margin over WhatsApp's own compression.
 *  - As a side effect, BitmapFactory can decode formats (HEIC/HEIF on
 *    API 28+) the old Dart pipeline likely couldn't.
 */
package com.example.hd_status.media

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.FileOutputStream

class ImageOptimizer {
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Runs on a background thread — decoding/resizing/encoding a real
     * photo is real CPU/memory work, and MethodChannel handlers otherwise
     * run on the platform (UI) thread. [onComplete]/[onError] are always
     * invoked on the main thread, since Flutter requires MethodChannel
     * results to be delivered there.
     */
    fun optimize(
        inputPath: String,
        outputPath: String,
        maxDimension: Int,
        quality: Int,
        onComplete: (String) -> Unit,
        onError: (String) -> Unit,
    ) {
        Thread {
            try {
                val result = process(inputPath, outputPath, maxDimension, quality)
                mainHandler.post { onComplete(result) }
            } catch (e: Exception) {
                mainHandler.post { onError(e.message ?: "Unable to prepare this photo") }
            }
        }.start()
    }

    private fun process(inputPath: String, outputPath: String, maxDimension: Int, quality: Int): String {
        val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(inputPath, boundsOptions)
        if (boundsOptions.outWidth <= 0 || boundsOptions.outHeight <= 0) {
            throw IllegalStateException("Unreadable or unsupported image")
        }

        val rotationDegrees = readExifRotationDegrees(inputPath)
        // A 90/270 rotation swaps which raw dimension becomes the "longest
        // edge" after baking orientation in — account for that up front so
        // the sample-size decode targets the right axis.
        val rotatedIsPortrait = rotationDegrees == 90 || rotationDegrees == 270
        val postRotationLongestEdge = if (rotatedIsPortrait) {
            maxOf(boundsOptions.outHeight, boundsOptions.outWidth)
        } else {
            maxOf(boundsOptions.outWidth, boundsOptions.outHeight)
        }

        val sampleSize = computeInSampleSize(postRotationLongestEdge, maxDimension)

        // Decode already-downsampled — avoids allocating a full-resolution
        // bitmap just to immediately shrink it. inSampleSize is chosen so
        // the sampled image's longest edge is always >= maxDimension, so
        // the precise resize below only ever scales down, never up.
        val decodeOptions = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        var bitmap = BitmapFactory.decodeFile(inputPath, decodeOptions)
            ?: throw IllegalStateException("Unreadable or unsupported image")

        if (rotationDegrees != 0) {
            val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated !== bitmap) bitmap.recycle()
            bitmap = rotated
        }

        val longestEdge = maxOf(bitmap.width, bitmap.height)
        if (longestEdge > maxDimension) {
            val scale = maxDimension.toFloat() / longestEdge
            val targetWidth = (bitmap.width * scale).toInt().coerceAtLeast(1)
            val targetHeight = (bitmap.height * scale).toInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true)
            if (scaled !== bitmap) bitmap.recycle()
            bitmap = scaled
        }

        val outFile = File(outputPath)
        outFile.parentFile?.mkdirs()
        // Writing straight to an OutputStream (not through a file API that
        // preserves metadata) means no EXIF block is written back — GPS
        // and every other EXIF field is dropped as a side effect, same
        // behavior as the pipeline this replaces.
        FileOutputStream(outFile).use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
        }
        bitmap.recycle()

        return outputPath
    }

    private fun readExifRotationDegrees(path: String): Int {
        return try {
            val exif = ExifInterface(path)
            when (exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }
        } catch (e: Exception) {
            0
        }
    }

    /** Largest power-of-2 sample size that still leaves the decoded
     * longest edge >= [targetLongestEdge] — never lets the sampled decode
     * undershoot the target, so the later precise resize only scales down. */
    private fun computeInSampleSize(longestEdge: Int, targetLongestEdge: Int): Int {
        var sampleSize = 1
        var current = longestEdge
        while (current / 2 >= targetLongestEdge) {
            current /= 2
            sampleSize *= 2
        }
        return sampleSize
    }
}
