package com.example.memora_application

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    // This channel name must match the one used in your Dart code.
    private val CHANNEL = "com.example.memora_application/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "sendToBackground") {
                moveTaskToBack(true) // This is the native Android code to send the app to the background.
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}