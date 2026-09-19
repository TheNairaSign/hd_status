/*
 * Hardware-accelerated encode via Media3 Transformer/MediaCodec — not
 * FFmpeg/x264. Rate control is therefore bitrate-based (VBR against the
 * Dart-computed target), not CRF; see the plan's "Video compression
 * algorithm" section for why that's the deliberate choice here.
 *
 * One job at a time (matches the app's single active Processing/Splitting
 * screen); starting a new encode implicitly cancels any in-flight one.
 *
 * KNOWN GAP: targetFps (OptimizationEngine's 30fps cap) is not enforced
 * here. Media3 Transformer 1.4.x has no straightforward "drop frames to a
 * target output rate" effect in the public API short of a custom
 * VideoFrameProcessor effect — not attempted here rather than guess at an
 * API that might silently no-op. A 60fps source is currently re-encoded at
 * its original frame rate, just at the target resolution/bitrate.
 *
 * (A prior attempt used EditedMediaItem.Builder.setFrameRate(), which does
 * compile against media3-transformer 1.4.1 — reverted because that method's
 * recalled documented use case is setting the frame rate when building a
 * video FROM a sequence of still images, not downsampling an existing
 * video's frame rate during transcode, and that distinction was never
 * confirmed on a real device before landing.)
 */
package com.example.hd_status.media

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.Effect
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Codec
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File

@UnstableApi
class VideoEncoder(private val context: Context) {
    private var transformer: Transformer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var progressRunnable: Runnable? = null

    interface Listener {
        fun onProgress(progress: Float)
        fun onCompleted(outputPath: String)
        fun onError(message: String)
    }

    /**
     * @param inputPath source file (already staged — any readable path).
     * @param outputPath destination; parent directory created if needed,
     *   any existing file at this path is overwritten.
     * @param targetWidth/targetHeight 0 means "no resize" (container/codec
     *   change only); non-zero must already be aspect-correct and even —
     *   see OptimizationEngine, which computes these preserving aspect
     *   ratio and never upscaling.
     * @param targetVideoKbps requested average video bitrate in kbps; <= 0
     *   means "let the platform encoder pick its own default for the
     *   resolution" instead of requesting one explicitly.
     * @param audioKbps requested AAC bitrate in kbps; <= 0 keeps Media3's
     *   hardcoded 128 kbps default (1.4.1 has no public audio-settings API,
     *   so this is applied via [AudioBitrateEncoderFactory]).
     * @param startMs/endMs clip trim in milliseconds; -1/-1 means the whole
     *   file (used by the segment splitter in Phase 6 to cut one segment
     *   per encode pass instead of a separate split-then-reencode step).
     */
    fun encode(
        inputPath: String,
        outputPath: String,
        targetWidth: Int,
        targetHeight: Int,
        targetVideoKbps: Int,
        audioKbps: Int,
        startMs: Long,
        endMs: Long,
        listener: Listener,
    ) {
        cancel()

        val outFile = File(outputPath)
        outFile.parentFile?.mkdirs()
        if (outFile.exists()) outFile.delete()

        var mediaItemBuilder = MediaItem.Builder().setUri(Uri.fromFile(File(inputPath)))
        if (startMs >= 0 && endMs > startMs) {
            mediaItemBuilder = mediaItemBuilder.setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(startMs)
                    .setEndPositionMs(endMs)
                    .build(),
            )
        }

        val editedItemBuilder = EditedMediaItem.Builder(mediaItemBuilder.build())
        if (targetWidth > 0 && targetHeight > 0) {
            val videoEffects: List<Effect> = listOf(
                Presentation.createForWidthAndHeight(targetWidth, targetHeight, Presentation.LAYOUT_SCALE_TO_FIT),
            )
            editedItemBuilder.setEffects(Effects(emptyList(), videoEffects))
        }

        val transformerBuilder = Transformer.Builder(context)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    stopProgressPolling()
                    listener.onCompleted(outputPath)
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    stopProgressPolling()
                    outFile.delete()
                    listener.onError(exportException.message ?: "Encode failed")
                }
            })

        if (targetVideoKbps > 0 || audioKbps > 0) {
            // Average-bitrate VBR against the Dart-computed budget — see the
            // plan's "Video compression algorithm" section for why this is
            // the bitrate-budget approach rather than CRF (MediaCodec's
            // hardware encoders don't expose CRF the way x264 does).
            val defaultFactoryBuilder = DefaultEncoderFactory.Builder(context)
            if (targetVideoKbps > 0) {
                defaultFactoryBuilder.setRequestedVideoEncoderSettings(
                    VideoEncoderSettings.Builder()
                        .setBitrate(targetVideoKbps * 1000)
                        .build(),
                )
            }
            val defaultFactory = defaultFactoryBuilder.build()
            transformerBuilder.setEncoderFactory(
                if (audioKbps > 0) AudioBitrateEncoderFactory(defaultFactory, audioKbps * 1000) else defaultFactory,
            )
        }

        val t = transformerBuilder.build()
        transformer = t
        t.start(editedItemBuilder.build(), outputPath)
        startProgressPolling(listener)
    }

    /** Cancels any in-flight job and deletes its partial output. */
    fun cancel() {
        stopProgressPolling()
        transformer?.cancel()
        transformer = null
    }

    private fun startProgressPolling(listener: Listener) {
        val holder = ProgressHolder()
        val runnable = object : Runnable {
            override fun run() {
                val t = transformer ?: return
                t.getProgress(holder)
                listener.onProgress((holder.progress.coerceIn(0, 100)) / 100f)
                handler.postDelayed(this, 200)
            }
        }
        progressRunnable = runnable
        handler.postDelayed(runnable, 200)
    }

    private fun stopProgressPolling() {
        progressRunnable?.let { handler.removeCallbacks(it) }
        progressRunnable = null
    }
}

/**
 * media3-transformer 1.4.1's DefaultEncoderFactory hardcodes audio at
 * 128 kbps whenever the requested Format has no bitrate; this wrapper
 * supplies one. Newer Media3 versions expose this via AudioEncoderSettings.
 */
@UnstableApi
private class AudioBitrateEncoderFactory(
    private val delegate: Codec.EncoderFactory,
    private val audioBitrate: Int,
) : Codec.EncoderFactory by delegate {
    override fun createForAudioEncoding(format: Format): Codec =
        delegate.createForAudioEncoding(format.buildUpon().setAverageBitrate(audioBitrate).build())
}
