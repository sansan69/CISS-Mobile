package co.`in`.ciss.ciss_mobile

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Device compatibility bridge for background location tracking.
 *
 * Chinese OEMs (Xiaomi, Oppo, Vivo, Realme, OnePlus, Huawei) aggressively
 * kill background services unless the user exempts the app from battery
 * optimization AND enables auto-start. This plugin exposes the OS knobs
 * plus the brand-specific auto-start settings deep links so the app can
 * guide the user through the two taps that keep tracking alive.
 *
 * Methods exposed:
 * - [isIgnoringBatteryOptimizations] — PowerManager exemption state.
 * - [requestIgnoreBatteryOptimizations] — fires the system "allow" dialog
 *   (ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS; requires the
 *   REQUEST_IGNORE_BATTERY_OPTIMIZATIONS manifest permission).
 * - [openBatteryOptimizationSettings] — the full battery-optimization list.
 * - [openBrandAutostartSettings] — OEM-specific auto-start settings page,
 *   falling back to the app detail settings when the OEM intent is absent.
 * - [getManufacturer] — Build.MANUFACTURER (e.g. "Xiaomi", "vivo").
 */
class DeviceCompatPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isIgnoringBatteryOptimizations" -> {
                result.success(isIgnoringBatteryOptimizations())
            }
            "openBatteryOptimizationSettings" -> {
                result.success(openBatteryOptimizationSettings())
            }
            "openBrandAutostartSettings" -> {
                result.success(openBrandAutostartSettings())
            }
            "openFingerprintEnrollSettings" -> {
                result.success(openFingerprintEnrollSettings())
            }
            "getManufacturer" -> {
                result.success(manufacturer())
            }
            else -> result.notImplemented()
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager =
            context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    /**
     * Opens the battery-optimization list. Deliberately uses the generic
     * settings screen instead of ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS:
     * that action requires the REQUEST_IGNORE_BATTERY_OPTIMIZATIONS manifest
     * permission, which is Play-restricted and banned by the app's Android
     * tracking contract. One extra tap, no policy risk.
     */
    private fun openBatteryOptimizationSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openBrandAutostartSettings(): Boolean {
        val manufacturer = manufacturer().lowercase()
        val candidates = when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") ||
                manufacturer.contains("poco") -> listOf(
                "com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity",
                "com.miui.securitycenter/com.miui.securitycenter.autoStart.AutoStartManagementActivity",
                "com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity",
            )
            manufacturer.contains("oppo") || manufacturer.contains("realme") -> listOf(
                "com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity",
                "com.coloros.safecenter/com.coloros.safecenter.startupapp.StartupAppListActivity",
                "com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity",
            )
            manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> listOf(
                "com.vivo.permissionmanager/com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                "com.iqoo.secure/com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            )
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> listOf(
                "com.huawei.systemmanager/com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                "com.huawei.systemmanager/com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
            )
            manufacturer.contains("oneplus") -> listOf(
                "com.oneplus.security/com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            )
            else -> emptyList()
        }

        for (component in candidates) {
            try {
                val intent = Intent().apply {
                    setClassName(
                        component.substringBefore('/'),
                        component.substringAfter('/'),
                    )
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // Try the next known component for this brand.
            } catch (_: Exception) {
                return false
            }
        }

        // Fallback: open this app's detail settings where the user can at
        // least disable battery restrictions.
        return openAppDetails()
    }

    private fun openAppDetails(): Boolean {
        return try {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${context.packageName}"),
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Opens the OS fingerprint enrollment screen (Android 6.0+). Falls back to
     * the biometric enrollment screen (Android 9+) and then the security
     * settings page when the OEM blocks the direct activity.
     */
    private fun openFingerprintEnrollSettings(): Boolean {
        val candidates = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            candidates.add(
                Intent(Settings.ACTION_FINGERPRINT_ENROLL).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            candidates.add(
                Intent(Settings.ACTION_BIOMETRIC_ENROLL).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        }
        candidates.add(
            Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
        for (intent in candidates) {
            try {
                context.startActivity(intent)
                return true
            } catch (_: Exception) {
                // Try the next fallback.
            }
        }
        return false
    }

    private fun manufacturer(): String = Build.MANUFACTURER ?: "unknown"

    companion object {
        private const val CHANNEL_NAME = "co.in.ciss.ciss_mobile/device_compat"
    }
}
