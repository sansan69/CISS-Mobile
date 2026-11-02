package co.`in`.ciss.ciss_mobile

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
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
import java.security.MessageDigest

/**
 * Native method channel for in-app APK download and installation.
 *
 * Methods exposed:
 * - [canInstall] — returns true if the device can install APKs from unknown
 *   sources (Android 8+) or is running a pre-Oreo OS.
 * - [verifyApk] — inspects a downloaded APK archive with
 *   `PackageManager.getPackageArchiveInfo(path, GET_SIGNING_CERTIFICATES)` and
 *   reports whether its package name and signer certificate SHA-256 match the
 *   production values supplied by Dart. Install is refused unless this passes.
 * - [installApk] — copies the downloaded APK to a FileProvider-accessible
 *   location (only when it is outside the app cache) and fires the Package
 *   Installer intent.
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
            "verifyApk" -> {
                val path = call.argument<String>("path")
                val expectedPackageName = call.argument<String>("expectedPackageName")
                val expectedCertSha256 = call.argument<String>("expectedCertSha256")
                if (path == null || expectedPackageName == null || expectedCertSha256 == null) {
                    result.error(
                        "INVALID_ARGUMENT",
                        "path, expectedPackageName and expectedCertSha256 are required",
                        null
                    )
                    return
                }
                try {
                    result.success(verifyApk(path, expectedPackageName, expectedCertSha256))
                } catch (e: Exception) {
                    result.error("VERIFY_FAILED", e.message, null)
                }
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

    /**
     * Inspects the APK archive at [archivePath] without installing it.
     *
     * Returns a map with:
     * - `verified`: true only when the package name matches and every signer
     *   digest matches [expectedCertSha256]
     * - `packageName`: the archive's package id (nullable)
     * - `signerSha256`: the first signer digest in lower-case hex (nullable)
     * - `reason`: why verification failed (null when verified)
     */
    private fun verifyApk(
        archivePath: String,
        expectedPackageName: String,
        expectedCertSha256: String
    ): Map<String, Any?> {
        val file = File(archivePath)
        if (!file.isFile) {
            return failure("The downloaded update file is missing.")
        }

        val archive: PackageInfo = try {
            readArchiveInfo(archivePath)
        } catch (e: Exception) {
            null
        } ?: return failure("The downloaded file is not a readable APK archive.")

        val packageName = archive.packageName
        val signerDigests = try {
            signerSha256Digests(archive)
        } catch (e: Exception) {
            emptyList()
        }

        if (packageName != expectedPackageName) {
            return failure(
                "Package name mismatch: expected $expectedPackageName, " +
                    "found ${packageName ?: "unknown"}.",
                packageName
            )
        }
        if (signerDigests.isEmpty()) {
            return failure("The downloaded APK is not signed.", packageName)
        }

        val expectedDigest = normalizeDigest(expectedCertSha256)
        val verified = signerDigests.all { it == expectedDigest }
        return mapOf(
            "verified" to verified,
            "packageName" to packageName,
            "signerSha256" to signerDigests.first(),
            "reason" to if (verified) {
                null
            } else {
                "Signer certificate mismatch: expected $expectedDigest, " +
                    "found ${signerDigests.joinToString(", ")}."
            }
        )
    }

    /** Extracts the SHA-256 of every signer certificate in [archive]. */
    private fun signerSha256Digests(archive: PackageInfo): List<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = archive.signingInfo ?: return emptyList()
            // `apkContentsSigners` are the certificates that currently sign the
            // APK contents (v2/v3), for single and multiple signers alike.
            signingInfo.apkContentsSigners.ifEmpty { signingInfo.signingCertificateHistory }
        } else {
            legacySignatures(archive) ?: return emptyList()
        }

        return signatures.map { signature ->
            val digest = MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
            digest.joinToString("") { byte -> "%02x".format(byte.toInt() and 0xFF) }
        }
    }

    /** Reads an APK's manifest data without installing it. */
    private fun readArchiveInfo(archivePath: String): PackageInfo? {
        val packageManager = context.packageManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageArchiveInfo(
                archivePath,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
        } else {
            legacyArchiveInfo(archivePath)
        }
    }

    @Suppress("DEPRECATION")
    private fun legacyArchiveInfo(archivePath: String): PackageInfo? =
        context.packageManager.getPackageArchiveInfo(archivePath, PackageManager.GET_SIGNATURES)

    @Suppress("DEPRECATION")
    private fun legacySignatures(archive: PackageInfo) = archive.signatures

    private fun normalizeDigest(raw: String): String =
        raw.lowercase().replace(":", "").replace(" ", "")

    private fun failure(reason: String, packageName: String? = null): Map<String, Any?> =
        mapOf(
            "verified" to false,
            "packageName" to packageName,
            "signerSha256" to null,
            "reason" to reason
        )

    private fun installApk(sourcePath: String) {
        val file = File(sourcePath)
        if (!file.exists()) {
            throw IllegalStateException("APK file not found at: $sourcePath")
        }

        // A download written by ApkDownloader already lives in
        // cacheDir/android_updates, which `res/xml/file_paths.xml` exposes to
        // the FileProvider. Share it in place instead of copying ~86 MB again
        // (F-16) unless the source is somewhere the provider cannot read.
        val shareDir = File(context.cacheDir, UPDATE_DIR)
        val shareable = if (file.canonicalPath.startsWith(shareDir.canonicalPath + File.separator)) {
            file
        } else {
            shareDir.mkdirs()
            val dest = File(shareDir, "ciss-update-install.apk")
            file.copyTo(dest, overwrite = true)
            dest
        }

        val uri: Uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            shareable
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
        private const val UPDATE_DIR = "android_updates"
    }
}
