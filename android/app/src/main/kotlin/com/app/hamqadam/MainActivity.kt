package com.app.hamqadam

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Hosts the Flutter UI, and owns the three things Flutter cannot do for an
 * incoming call: come up over the lock screen, hold the screen on while the
 * call lasts, and report the Android grants that decide whether a sleeping
 * phone rings at all.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "com.app.hamqadam/call_reliability"

        /**
         * Where `NotificationService._rememberPendingCall` leaves a ringing
         * call. `shared_preferences` namespaces every key with `flutter.`, so
         * the Dart key `pending_incoming_call_v1` is stored under this name.
         */
        const val PREFS = "FlutterSharedPreferences"
        const val PENDING_CALL_KEY = "flutter.pending_incoming_call_v1"

        /** Matches `NotificationService._pendingCallTtl`. */
        const val PENDING_CALL_TTL_MS = 90_000L
    }

    /** True while a call is ringing or connected on this activity. */
    private var callMode = false

    /**
     * Turn the lock-screen behaviour **off** unless a call is ringing.
     *
     * The manifest declares `showWhenLocked` / `turnScreenOn` because Android
     * decides whether an activity may appear over the keyguard at launch time,
     * before any of our code runs — without the attribute a full-screen intent
     * on a locked phone is refused outright and the member gets a silent
     * "New notification" line instead of a ringing screen.
     *
     * The cost of leaving them on is that the launcher activity is a
     * lock-screen surface on every ordinary launch, and a window shown over the
     * keyguard gets the short keyguard display timeout instead of the member's
     * own sleep setting — the reported "screen goes off in about five seconds
     * whenever the app is open". So the capability is granted in the manifest
     * and withdrawn here the moment we know this is not a call.
     *
     * Reading the pending-call record natively rather than waiting for Dart is
     * deliberate: this has to be settled before the window is added, and the
     * Flutter engine has not run a line of Dart yet.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        callMode = hasPendingCall()
        applyCallScreenFlags(callMode)
    }

    /**
     * The warm full-screen-intent path: the process is already alive, so the
     * intent brings this singleTop activity forward without a fresh `onCreate`.
     */
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        if (hasPendingCall()) {
            callMode = true
            applyCallScreenFlags(true)
        }
    }

    /**
     * Belt and braces: a resume that is not a call must not inherit lock-screen
     * behaviour from a call that has since ended.
     */
    /**
     * Belt and braces: a resume that is not a call must not inherit lock-screen
     * behaviour from a call that has since ended.
     */
    override fun onResume() {
        super.onResume()
        if (!callMode) {
            setLockScreenCapable(false)
            setKeepScreenOn(false)
        }
    }

    /**
     * Hand the lock-screen capability *back* while the app is not visible.
     *
     * Android reads `canShowWhenLocked` off the existing activity record when a
     * full-screen intent tries to bring it forward — and if the last resume
     * revoked it, the intent is refused and a locked phone shows a silent "New
     * notification" line instead of ringing. Measured exactly that.
     *
     * Restoring it here is free: the activity is not on screen, so it cannot
     * inherit the keyguard's short display timeout. `onResume` takes it away
     * again the moment the app is actually being used for something other than
     * a call.
     */
    override fun onStop() {
        super.onStop()
        setLockScreenCapable(true)
    }

    private fun hasPendingCall(): Boolean {
        return try {
            val raw = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(PENDING_CALL_KEY, null) ?: return false
            val at = JSONObject(raw).optLong("at", 0L)
            at > 0L && System.currentTimeMillis() - at <= PENDING_CALL_TTL_MS
        } catch (_: Exception) {
            false
        }
    }

    /**
     * [on] = behave as a call surface: draw over the keyguard, light the screen
     * up, and hold it on. [on] = false hands all three back to the system so
     * the phone sleeps on the member's own timeout.
     */
    /** Whether this activity may be drawn over the keyguard and wake the screen. */
    private fun setLockScreenCapable(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            @Suppress("DEPRECATION")
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    /** Holds the display on — only for the duration of a call. */
    private fun setKeepScreenOn(on: Boolean) {
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    private fun applyCallScreenFlags(on: Boolean) {
        setLockScreenCapable(on)
        setKeepScreenOn(on)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Android 14+ gates the full-screen intent behind its own
                    // grant, and denies it by default to anything it does not
                    // already class as a calling app. Without it a call push
                    // becomes a heads-up banner behind the lock screen.
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())

                    // A battery-optimised app is the one the OEM cleaner
                    // force-stops, and a force-stopped app is delivered no FCM
                    // at all until it is opened by hand.
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())

                    // A call started while the activity already existed: the
                    // manifest no longer carries these flags, and onCreate did
                    // not run, so the ringing screen asks for them here.
                    "beginCallScreen" -> {
                        callMode = true
                        runOnUiThread { applyCallScreenFlags(true) }
                        result.success(true)
                    }

                    // The call is over — stop holding the screen on and stop
                    // being a lock-screen surface.
                    "endCallScreen" -> {
                        callMode = false
                        runOnUiThread { applyCallScreenFlags(false) }
                        result.success(true)
                    }

                    // Called after Accept. An audio call runs happily over the
                    // keyguard, but anything that needs the real UI behind it
                    // does not, so ask the system to take the lock screen away
                    // — on a device with no secure lock this dismisses it
                    // outright; with a PIN it prompts, which is the most any
                    // app is allowed to do.
                    "dismissKeyguard" -> {
                        dismissKeyguard()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun canUseFullScreenIntent(): Boolean {
        // The grant only exists on 14+; below that the intent is always honoured.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return false
        return manager.canUseFullScreenIntent()
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val manager = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return manager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun dismissKeyguard() {
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager ?: return
        if (!keyguard.isKeyguardLocked) return
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                keyguard.requestDismissKeyguard(this, null)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
            }
        }
    }
}
