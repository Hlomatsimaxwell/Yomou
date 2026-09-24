package com.stunna.manga_reader

import android.app.Activity
import android.content.Intent
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
}