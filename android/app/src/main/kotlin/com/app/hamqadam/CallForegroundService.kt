package com.app.hamqadam

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps an in-progress call alive while the app is not on screen, and gives it
 * the notification-tray entry the member taps to come back to it.
 *
 * Both halves of that are the point, and the first one is not optional:
 *
 * * Since Android 9 a process with no foreground activity **and no foreground
 *   service** is denied the microphone — it keeps recording, but the buffers
 *   are silence. So the moment an audio call is minimised without a service
 *   like this one, the other side stops hearing anything while every indicator
 *   still says "connected". The `microphone` (and, for video, `camera`)
 *   foreground-service type is what keeps the capture real.
 * * A foreground service also stops the OEM cleaners from reaping the process
 *   mid-call, which is the same class of problem as the battery-optimisation
 *   note in the manifest.
 *
 * The notification is built with the framework builder rather than
 * `NotificationCompat`: androidx.core reaches this module only as a transitive
 * `implementation` dependency of the Flutter plugins, so it is not on our
 * compile classpath and adding it just for one builder is not worth a new
 * dependency.
 */
class CallForegroundService : Service() {

    companion object {
        /** Its own channel: silent and low, so an ongoing call never rings. */
        const val CHANNEL_ID = "ongoing_calls"
        const val NOTIFICATION_ID = 918_273

        const val ACTION_START = "com.app.hamqadam.CALL_ONGOING_START"
        const val ACTION_STOP = "com.app.hamqadam.CALL_ONGOING_STOP"
        const val ACTION_END_CALL = "com.app.hamqadam.CALL_ONGOING_END"

        const val EXTRA_NAME = "peer_name"
        const val EXTRA_VIDEO = "is_video"
        const val EXTRA_STATUS = "status"

        /**
         * Set by [MainActivity] while its Flutter engine is attached, so "End
         * call" on the notification reaches Dart instead of just killing the
         * service and leaving the server thinking the call is still up.
         */
        @Volatile
        var onEndCallRequested: (() -> Unit)? = null

        fun start(context: Context, name: String, isVideo: Boolean, status: String) {
            val intent = Intent(context, CallForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_NAME, name)
                putExtra(EXTRA_VIDEO, isVideo)
                putExtra(EXTRA_STATUS, status)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // ForegroundServiceStartNotAllowedException and friends. The
                // call still works while the app is on screen; it is only the
                // minimised case that degrades, and a crash here would be worse.
                android.util.Log.w("CallForegroundService", "could not start: $e")
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, CallForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {
                // Not running, or the app is backgrounded and the service is
                // already gone — either way there is nothing to stop.
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_END_CALL -> {
                val handler = onEndCallRequested
                if (handler != null) {
                    handler.invoke()
                } else {
                    // No engine to tell — the app is gone, so the only honest
                    // thing left is to take the notification down.
                    stopForegroundCompat()
                    stopSelf()
                }
                return START_NOT_STICKY
            }

            else -> {
                val name = intent?.getStringExtra(EXTRA_NAME) ?: "HamQadam call"
                val isVideo = intent?.getBooleanExtra(EXTRA_VIDEO, false) ?: false
                val status = intent?.getStringExtra(EXTRA_STATUS)
                    ?: if (isVideo) "Ongoing video call" else "Ongoing voice call"
                startAsForeground(name, status)
                return START_NOT_STICKY
            }
        }
    }

    override fun onDestroy() {
        stopForegroundCompat()
        super.onDestroy()
    }

    // ── Notification ────────────────────────────────────────────────────────

    private fun startAsForeground(name: String, status: String) {
        ensureChannel()
        val notification = buildNotification(name, status)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Microphone only, on a video call too. The camera is released
                // when the call leaves the foreground (VideoCallScreen does it
                // on the lifecycle change), so this service never needs the
                // camera type — and the app never needs the Play declaration
                // that comes with it.
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Android 14 refuses a microphone-typed service when RECORD_AUDIO
            // has not been granted, or when the start came from the background.
            // Try once more untyped, because the alternative is worse than a
            // degraded call: a service that was started with
            // `startForegroundService` and does not reach `startForeground`
            // inside five seconds is killed *with a crash*. If even that is
            // refused, fall back to a plain tray entry and stop the service
            // before that deadline can be missed.
            android.util.Log.w("CallForegroundService", "startForeground refused: $e")
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (e2: Exception) {
                // Nothing left to try. Stopping is not a nicety: a service
                // started with `startForegroundService` that never reaches
                // `startForeground` is killed with a crash five seconds later.
                // The call itself is unaffected while it is on screen; it is
                // only the minimised case that goes back to what it was.
                android.util.Log.w("CallForegroundService", "untyped start refused too: $e2")
                stopSelf()
            }
        }
    }

    private fun buildNotification(name: String, status: String): Notification {
        // Brings the *existing* task forward with the call screen still on top,
        // rather than launching a second copy of the activity.
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            launch ?: Intent(this, MainActivity::class.java),
            pendingIntentFlags(),
        )
        val endIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, CallForegroundService::class.java).setAction(ACTION_END_CALL),
            pendingIntentFlags(),
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setContentTitle(name)
            .setContentText(status)
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_CALL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)

        @Suppress("DEPRECATION")
        builder.addAction(
            android.R.drawable.ic_menu_close_clear_cancel,
            "End call",
            endIntent,
        )

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_LOW)
        }
        return builder.build()
    }

    private fun pendingIntentFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Ongoing Calls",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows the call you are on so you can return to it."
            setShowBadge(false)
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun stopForegroundCompat() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {
        }
    }
}
