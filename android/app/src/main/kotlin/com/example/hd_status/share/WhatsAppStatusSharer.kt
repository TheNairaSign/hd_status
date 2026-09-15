/*
 * Share-to-WhatsApp-Status implementation, adapted from Meta's reference sample:
 * https://github.com/fbsamples/whatsapp_status_api_android
 * (app/src/main/java/com/example/sharetowhatsappstatus/MainActivity.kt,
 *  commit 9e4c853, fetched 2026-09-15 — verified against the live repo, not
 *  reconstructed from the Product Brief's paraphrase).
 *
 * Deliberate differences from the sample:
 *  - The sample exposes its entire filesDir via FileProvider; we expose only
 *    the scoped "share" cache subdirectory (see file_provider_paths.xml),
 *    per the Product Brief's "expose only the share-output directory"
 *    privacy rule.
 *  - The sample only ever targets "com.whatsapp". We support WhatsApp
 *    Business too (Product Brief R2 / UX Guide S07), leaving package choice
 *    to the caller.
 *  - The sample's pre-Android-14 path does not catch
 *    ActivityNotFoundException at all (it would crash if WhatsApp isn't
 *    installed). We catch it here so the Dart side can fall back to the
 *    generic Android share sheet, per the Product Brief's explicit
 *    "catch launch errors even if detection succeeds" instruction.
 */
package com.example.hd_status.share

import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.service.chooser.ChooserAction
import androidx.annotation.RequiresApi
import androidx.core.content.FileProvider
import androidx.core.net.toUri
import java.io.File

object WhatsAppPackages {
    const val CONSUMER = "com.whatsapp"
    const val BUSINESS = "com.whatsapp.w4b"
    val ALL = listOf(CONSUMER, BUSINESS)
}

class WhatsAppStatusSharer(private val context: Context) {

    /** Which of [WhatsAppPackages.ALL] are actually installed on this device.
     * Requires the <queries> package visibility declarations in the manifest
     * (Product Brief R2) or this always returns an empty list on API 30+. */
    fun installedWhatsAppPackages(): List<String> =
        WhatsAppPackages.ALL.filter(::isInstalled)

    private fun isInstalled(packageName: String): Boolean = try {
        context.packageManager.getPackageInfo(packageName, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    /**
     * @param filePath a file already inside this app's FileProvider-covered
     *   "share" cache directory (see [Context.getCacheDir]`/share/` and
     *   file_provider_paths.xml). A raw picker content:// URI from a
     *   different provider cannot be granted to WhatsApp from here — the
     *   caller must copy it in first.
     * @param mimeType e.g. "image/jpeg" or "video/mp4".
     * @param targetPackage [WhatsAppPackages.CONSUMER] or [WhatsAppPackages.BUSINESS].
     * @return true if a launch was attempted without an immediate
     *   [ActivityNotFoundException]; false means the caller should fall
     *   back to [shareGeneric].
     */
    fun shareToStatus(filePath: String, mimeType: String, targetPackage: String): Boolean {
        val mediaUri = uriFor(filePath)
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                launchChooserWithStatusAction(mediaUri, mimeType, targetPackage)
            } else {
                context.startActivity(buildStatusIntent(mediaUri, mimeType, targetPackage))
            }
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    /** Generic Android share sheet fallback — always available, used when the
     * dedicated Status path fails or no WhatsApp package is installed. */
    fun shareGeneric(filePath: String, mimeType: String) {
        val mediaUri = uriFor(filePath)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, mediaUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, null))
    }

    private fun uriFor(filePath: String): Uri {
        val authority = "${context.packageName}.fileprovider"
        return FileProvider.getUriForFile(context, authority, File(filePath))
    }

    private fun buildStatusIntent(mediaUri: Uri, mimeType: String, targetPackage: String): Intent {
        return Intent(Intent.ACTION_VIEW).apply {
            data = WHATSAPP_STATUS_DEEPLINK.toUri()
            setPackage(targetPackage)
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, mediaUri)
            putExtra(SHARE_TYPE_EXTRA_KEY, "SHARE_TO_STATUS")
            putExtra(SOURCE_APP_PACKAGE_EXTRA_KEY, context.packageName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
            context.grantUriPermission(targetPackage, mediaUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    /**
     * Android 14+ (UPSIDE_DOWN_CAKE) path. Background Activity Launch
     * restrictions mean a PendingIntent-triggered custom chooser action
     * can't jump straight to WhatsApp — instead we show the OS share sheet
     * with a "Share to Status" custom action that, when tapped, opens
     * [WhatsAppStatusProxyActivity] (foreground, so BAL allows it) which
     * then fires the real Status deep-link intent.
     */
    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun launchChooserWithStatusAction(mediaUri: Uri, mimeType: String, targetPackage: String) {
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, mediaUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val proxyIntent = Intent(context, WhatsAppStatusProxyActivity::class.java).apply {
            putExtra(WhatsAppStatusProxyActivity.EXTRA_TARGET_INTENT, buildStatusIntent(mediaUri, mimeType, targetPackage))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }

        val options = ActivityOptions.makeBasic()
        options.pendingIntentCreatorBackgroundActivityStartMode =
            ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED

        val customActionIntent = PendingIntent.getActivity(
            context,
            0,
            proxyIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            options.toBundle(),
        )

        val customAction = ChooserAction.Builder(
            Icon.createWithResource(context, context.applicationInfo.icon),
            "Share to Status",
            customActionIntent,
        ).build()

        val chooserIntent = Intent.createChooser(shareIntent, null).apply {
            putExtra(Intent.EXTRA_CHOOSER_CUSTOM_ACTIONS, arrayOf(customAction))
        }
        context.startActivity(chooserIntent)
    }

    companion object {
        private const val WHATSAPP_STATUS_DEEPLINK = "https://wa.me/status"
        private const val SHARE_TYPE_EXTRA_KEY = "share_type"
        private const val SOURCE_APP_PACKAGE_EXTRA_KEY = "source_app_package_name"
    }
}
