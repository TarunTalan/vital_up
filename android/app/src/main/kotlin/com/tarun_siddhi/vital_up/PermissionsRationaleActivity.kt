package com.tarun_siddhi.vital_up

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * Health Connect's "why does this app need access" link (and the Android 14+
 * permission-usage entry): opens the privacy policy in the browser, then
 * closes without showing anything itself.
 */
class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val url = Uri.parse(getString(R.string.privacy_policy_url))
        try {
            startActivity(
                Intent(Intent.ACTION_VIEW, url).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (e: ActivityNotFoundException) {
            // No browser: nothing to show.
        }
        finish()
    }
}
