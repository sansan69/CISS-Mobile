package co.`in`.ciss.ciss_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
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

        // Recents/screenshot protection for sensitive surfaces (armed app lock,
        // payslips, identity documents, guard profile). Driven by the Dart
        // ScreenSecurity service, which reference-counts its holders and only
        // clears the flag when the last sensitive surface goes away.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURE_WINDOW_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val secure = call.argument<Boolean>("secure") ?: true
                    // Window flag changes must run on the UI thread.
                    runOnUiThread {
                        if (secure) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val SECURE_WINDOW_CHANNEL = "co.in.ciss.ciss_mobile/secure_window"
    }
}
