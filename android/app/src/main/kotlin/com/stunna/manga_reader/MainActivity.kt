package com.stunna.manga_reader

import android.content.Intent
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }
}