package co.`in`.ciss.ciss_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Create the background tracking notification channel before Flutter boots.
        // On Android 14+ (API 34), startForeground() with a missing channel is a hard crash.
        // Creating it here ensures it always exists — even when the service survives hot restarts.
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(ApkInstallerPlugin())
        flutterEngine.plugins.add(DeviceCompatPlugin())
    }
}
