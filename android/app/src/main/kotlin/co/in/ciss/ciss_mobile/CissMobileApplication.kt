package co.`in`.ciss.ciss_mobile

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class CissMobileApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Create the background tracking channel at process start — the very
        // first thing before any Activity or Service can try to use it.
        // This prevents CannotPostForegroundServiceNotificationException on
        // Android 14 (API 34) when a stale foreground service from a previous
        // hot-restart session survives and tries startForeground() before
        // MainActivity.onCreate() has a chance to run.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "ciss_tracking",
                "CISS Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Active duty location monitoring for field guards"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }
}
