package com.example.hd_status

import androidx.media3.common.util.UnstableApi
import com.example.hd_status.media.MediaProbe
import com.example.hd_status.media.StorageInfo
import com.example.hd_status.media.VideoEncoder
import com.example.hd_status.share.ShareFileStaging
import com.example.hd_status.share.WhatsAppStatusSharer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

private const val WHATSAPP_CHANNEL = "com.example.hd_status/whatsapp_status"
private const val MEDIA_PROBE_CHANNEL = "com.example.hd_status/media_probe"
private const val VIDEO_ENCODER_CHANNEL = "com.example.hd_status/video_encoder"
private const val VIDEO_ENCODER_EVENTS = "com.example.hd_status/video_encoder_events"
private const val STORAGE_CHANNEL = "com.example.hd_status/storage"

//@OptIn(UnstableApi::class)
class MainActivity : FlutterActivity() {
    private var encoderEventSink: EventChannel.EventSink? = null

    @androidx.annotation.OptIn(UnstableApi::class)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Must be the Activity, not applicationContext: WhatsAppStatusSharer
        // calls startActivity() without FLAG_ACTIVITY_NEW_TASK (matching the
        // reference sample's behavior), which throws
        // "Calling startActivity() from outside of an Activity context
        // requires FLAG_ACTIVITY_NEW_TASK" when given a non-Activity Context.
        val sharer = WhatsAppStatusSharer(this)
        val mediaProbe = MediaProbe()
        val videoEncoder = VideoEncoder(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_PROBE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "probe" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("bad_args", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(mediaProbe.probe(filePath))
                    } catch (e: Exception) {
                        result.error("probe_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WHATSAPP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installedWhatsAppPackages" -> {
                    result.success(sharer.installedWhatsAppPackages())
                }

                "shareToStatus" -> {
                    val filePath = call.argument<String>("filePath")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType")
                    val targetPackage = call.argument<String>("targetPackage")
                    if (filePath == null || fileName == null || mimeType == null || targetPackage == null) {
                        result.error("bad_args", "filePath, fileName, mimeType and targetPackage are required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val staged = ShareFileStaging.stageForShare(applicationContext, filePath, fileName)
                        val attempted = sharer.shareToStatus(staged, mimeType, targetPackage)
                        result.success(attempted)
                    } catch (e: Exception) {
                        result.error("share_failed", e.message, null)
                    }
                }

                "shareGeneric" -> {
                    val filePath = call.argument<String>("filePath")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType")
                    if (filePath == null || fileName == null || mimeType == null) {
                        result.error("bad_args", "filePath, fileName and mimeType are required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val staged = ShareFileStaging.stageForShare(applicationContext, filePath, fileName)
                        sharer.shareGeneric(staged, mimeType)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("share_failed", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VIDEO_ENCODER_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    encoderEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    encoderEventSink = null
                }
            },
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIDEO_ENCODER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startEncode" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    val targetWidth = call.argument<Int>("targetWidth") ?: 0
                    val targetHeight = call.argument<Int>("targetHeight") ?: 0
                    val targetVideoKbps = call.argument<Int>("targetVideoKbps") ?: 0
                    val startMs = (call.argument<Number>("startMs") ?: -1).toLong()
                    val endMs = (call.argument<Number>("endMs") ?: -1).toLong()
                    if (inputPath == null || outputPath == null) {
                        result.error("bad_args", "inputPath and outputPath are required", null)
                        return@setMethodCallHandler
                    }
                    videoEncoder.encode(
                        inputPath,
                        outputPath,
                        targetWidth,
                        targetHeight,
                        targetVideoKbps,
                        startMs,
                        endMs,
                        object : VideoEncoder.Listener {
                            override fun onProgress(progress: Float) {
                                encoderEventSink?.success(mapOf("type" to "progress", "progress" to progress))
                            }

                            override fun onCompleted(outputPath: String) {
                                encoderEventSink?.success(mapOf("type" to "completed", "outputPath" to outputPath))
                            }

                            override fun onError(message: String) {
                                encoderEventSink?.success(mapOf("type" to "error", "message" to message))
                            }
                        },
                    )
                    result.success(null)
                }

                "cancelEncode" -> {
                    videoEncoder.cancel()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "freeBytes" -> {
                    result.success(StorageInfo.freeBytes(applicationContext.cacheDir.path))
                }
                else -> result.notImplemented()
            }
        }
    }
}
