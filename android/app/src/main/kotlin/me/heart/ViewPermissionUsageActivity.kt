package me.heart

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log

/**
 * Answers "why does this app have my health data?" with the privacy policy.
 *
 * Android 14 and up put that question on the system privacy screens and on
 * Health Connect's own consent sheet, where it reads *"You can learn how Heart
 * handles your data in the developer's privacy policy"*. Tapping it fires
 * [Intent.ACTION_VIEW_PERMISSION_USAGE] at whichever component declares the
 * filter, and only a caller holding `START_VIEW_PERMISSION_USAGE` may send it —
 * which is the system, and is why the path cannot be exercised with `adb`.
 *
 * It used to be an `<activity-alias>` onto `MainActivity`, which satisfied the
 * manifest requirement and defeated the intent's purpose: the whole app booted
 * and landed the user on Profile, with no policy in sight. That is precisely
 * what the Play health-data declaration is reviewed against.
 *
 * So: no UI, no Flutter engine, no web view. Hand the URL to the browser and
 * get out of the way — the user sees the policy, Heart never appears, and back
 * returns them to where they were. A web view would mean shipping a browser to
 * display one static page the site already serves.
 */
class ViewPermissionUsageActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val policy = getString(R.string.privacy_policy_url)
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(policy)))
        } catch (error: ActivityNotFoundException) {
            // A device with no browser at all. Nothing useful is left to do —
            // opening the app would reproduce exactly the confusion this class
            // exists to remove — so leave rather than mislead.
            Log.w(TAG, "No activity can show $policy", error)
        }

        finish()
    }

    private companion object {
        const val TAG = "HeartPrivacy"
    }
}
