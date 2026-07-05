package co.`in`.ciss.ciss_mobile

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

/**
 * Native method channel for in-app APK download and installation.
 *
 * Methods exposed:
 * - [canInstall] — returns true if the device can install APKs from unknown
 *   sources (Android 8+) or is running a pre-Oreo OS.
 * - [installApk] — copies the downloaded APK to a FileProvider-accessible
 *   location and fires the Package Installer intent.
 * - [openInstallSettings] — opens the "Install unknown apps" system settings
 *   page for this app.
 */
class ApkInstallerPlugin : FlutterPlugin, MethodCallHandler {

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
            "canInstall" -> {
                result.success(canInstall())
            }
            "installApk" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGUMENT", "Path argument is required", null)
                    return
                }
                try {
                    installApk(path)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INSTALL_FAILED", e.message, null)
                }
            }
            "openInstallSettings" -> {
                openInstallSettings()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun canInstall(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true // Pre-Oreo doesn't have this restriction
        }
    }

    private fun installApk(sourcePath: String) {
        val file = File(sourcePath)
        if (!file.exists()) {
            throw IllegalStateException("APK file not found at: $sourcePath")
        }

        // Copy to a FileProvider-accessible location so the Package Installer
        // can read it (direct access to getTemporaryDirectory() may not be
        // shareable across processes on all API levels).
        val cacheDir = File(context.cacheDir, "android_updates")
        cacheDir.mkdirs()
        val destFile = File(cacheDir, "ciss-update-install.apk")
        file.copyTo(destFile, overwrite = true)

        val uri: Uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            destFile
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            // On Android 14+ (API 34), grantUriPermission is required for
            // cross-app URI sharing. FLAG_GRANT_READ_URI_PERMISSION handles this.
        }

        context.startActivity(intent)
    }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${context.packageName}")
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }
    }

    companion object {
        private const val CHANNEL_NAME = "co.in.ciss.ciss_mobile/apk_installer"
    }
}
