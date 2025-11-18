package com.example.memora_application

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    // Channel name must match the one used in Dart.
    private val CHANNEL = "com.example.memora_application/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendToBackground" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                "getDeviceState" -> {
                    val state = getDeviceState()
                    result.success(state)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getDeviceState(): Map<String, Any> {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

        val isLocked = keyguardManager.isKeyguardLocked
        @Suppress("DEPRECATION")
        val isInteractive = powerManager.isInteractive

        @Suppress("DEPRECATION")
        val runningTasks = activityManager.getRunningTasks(1)
        val topPackage = if (runningTasks.isNotEmpty()) {
            runningTasks[0].topActivity?.packageName
        } else {
            null
        }
        val isAppOnTop = topPackage == packageName

        return mapOf(
            "isLocked" to isLocked,
            "isInteractive" to isInteractive,
            "isAppOnTop" to isAppOnTop
        )
    }
}
