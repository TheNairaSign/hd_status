package com.example.hd_status.media

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import java.io.File
import java.io.FileOutputStream

/** Pulls evenly-spaced real frames from a video for ManualSplitScreen's
 * timeline strip — not a single thumbnail (that's MediaProbe's job) but a
 * row of them across the whole duration, so the trim UI shows what's
 * actually in the video instead of a plain bar. */
object FilmstripExtractor {
    fun extractFrames(sourcePath: String, cacheDir: File, frameCount: Int): List<String> {
        if (frameCount <= 0) return emptyList()
        val retriever = MediaMetadataRetriever()
        val outputDir = File(cacheDir, "filmstrip").apply { mkdirs() }
        val paths = mutableListOf<String>()
        val callId = System.currentTimeMillis()
        try {
            retriever.setDataSource(sourcePath)
            val durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            if (durationMs <= 0) return emptyList()

            // Sample from the center of each slice, not its start edge, so the
            // strip represents the whole duration rather than being biased
            // toward what the first frame of each slice looks like.
            val sliceUs = (durationMs * 1000L) / frameCount
            for (i in 0 until frameCount) {
                val timeUs = sliceUs * i + sliceUs / 2
                val bitmap: Bitmap? = try {
                    retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                } catch (_: Exception) {
                    null
                }
                if (bitmap != null) {
                    val file = File(outputDir, "frame_${callId}_$i.jpg")
                    FileOutputStream(file).use { out -> bitmap.compress(Bitmap.CompressFormat.JPEG, 70, out) }
                    bitmap.recycle()
                    paths.add(file.absolutePath)
                }
            }
        } finally {
            retriever.release()
        }
        return paths
    }
}
