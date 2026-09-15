/*
 * Transparent proxy activity for the Android 14+ share path.
 * Mirrors Meta's reference sample almost verbatim:
 * https://github.com/fbsamples/whatsapp_status_api_android
 * (WhatsappStatusProxyActivity.kt, commit 9e4c853, fetched 2026-09-15).
 *
 * Why this exists (from the sample's own comment, still accurate here):
 * 1. WhatsApp's Status deep-link expects startActivityForResult; a
 *    PendingIntent-triggered chooser custom action can't do that directly.
 * 2. Android's Background Activity Launch restrictions require a foreground
 *    activity to reliably launch WhatsApp — this transparent activity
 *    provides that foreground context.
 * 3. URI permissions granted to this proxy carry through to WhatsApp within
 *    the same task stack.
 */
package com.example.hd_status.share

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity

class WhatsAppStatusProxyActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val targetIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_TARGET_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(EXTRA_TARGET_INTENT)
        }

        if (targetIntent != null) {
            try {
                @Suppress("DEPRECATION")
                startActivityForResult(targetIntent, 0)
            } catch (e: Exception) {
                finish()
            }
        } else {
            finish()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        finish()
    }

    companion object {
        const val EXTRA_TARGET_INTENT = "extra_target_intent"
    }
}
