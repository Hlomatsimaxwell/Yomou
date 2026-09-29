package com.stunna.manga_reader

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val dirPickerRequestCode = 0xDA1
    private var dirPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/battery"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openBatterySettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("battery", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/secure"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setScreenshotBlocked" -> {
                    val block = call.arguments as? Boolean ?: false
                    runOnUiThread {
                        if (block) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/saf"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDirectoryPicker" -> {
                    dirPickerResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    intent.addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                    )
                    startActivityForResult(intent, dirPickerRequestCode)
                }
                "resolveTreeUri" -> {
                    val uriString = call.arguments as? String
                    if (uriString.isNullOrEmpty()) {
                        result.error("uri", "no uri given", null)
                        return@setMethodCallHandler
                    }
                    result.success(treeUriToPath(Uri.parse(uriString)))
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/storage"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStats" -> {
                    val path = call.arguments as? String
                    if (path.isNullOrEmpty()) {
                        result.error("path", "no path given", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val stat = StatFs(path)
                        result.success(
                            mapOf(
                                "total" to stat.totalBytes,
                                "free" to stat.availableBytes
                            )
                        )
                    } catch (e: Exception) {
                        result.error("statfs", e.message, null)
                    }
                }
                // The real shared Downloads folder. `path_provider`'s
                // getDownloadsDirectory() falls back to the app-scoped external
                // dir on API 29+, which is neither shared nor visible to the
                // user, so settings would label a private folder "Public
                // downloads". Resolving it natively keeps the label honest.
                "getPublicDownloadsPath" -> {
                    result.success(
                        Environment.getExternalStoragePublicDirectory(
                            Environment.DIRECTORY_DOWNLOADS
                        )?.absolutePath
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != dirPickerRequestCode) return
        val pending = dirPickerResult ?: return
        dirPickerResult = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri != null) {
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            } catch (_: Exception) {
                // Grant may only cover this session; the picked URI is still useful.
            }
            pending.success(uri.toString())
        } else {
            pending.success(null)
        }
    }

    /**
     * Turns a `content://…/tree/<docId>` URI picked through
     * ACTION_OPEN_DOCUMENT_TREE into a real file-system path (for example
     * `/storage/emulated/0/Download`) so settings can show a readable location
     * instead of the raw URI. Returns null when the volume can't be matched,
     * e.g. an unmounted SD card.
     */
    private fun treeUriToPath(uri: Uri): String? {
        val docId = try {
            DocumentsContract.getTreeDocumentId(uri)
        } catch (_: Exception) {
            return null
        }
        // Some providers (Downloads, MediaStore) encode an absolute path in
        // the document id itself, e.g. "raw:/storage/emulated/0/Download/saves".
        if (docId.startsWith("/")) return docId
        if (docId.startsWith("raw:/", ignoreCase = true)) return docId.substring(4)
        val volumeId = docId.substringBefore(":").removePrefix("uuid:")
        val relative = docId.substringAfter(":", "")
        val base = if (volumeId.equals("primary", ignoreCase = true)) {
            Environment.getExternalStorageDirectory()?.absolutePath
        } else {
            volumeRoots().firstOrNull {
                it.substringAfterLast("/").equals(volumeId, ignoreCase = true)
            }
        } ?: return null
        return if (relative.isEmpty()) base else "$base/$relative"
    }

    /** Mount points of every mounted external volume (e.g. `/storage/1AEF-2A03`). */
    private fun volumeRoots(): List<String> {
        val roots = ArrayList<String>()
        for (dir in getExternalFilesDirs(null)) {
            if (dir == null) continue
            try {
                // .../Android/data/<pkg>/files -> up to the volume root.
                val root = File(dir, "../../..").canonicalFile.absolutePath
                roots.add(root)
            } catch (_: Exception) {
                // Ignore volumes we can't resolve.
            }
        }
        return roots.distinct()
    }
}