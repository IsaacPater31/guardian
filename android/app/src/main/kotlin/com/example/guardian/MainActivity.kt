package com.example.guardian

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "guardian_background_service"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val intent = Intent(this, GuardianBackgroundService::class.java).apply {
                        action = "START_SERVICE"
                    }
                    startService(intent)
                    result.success(true)
                }
                "stopService" -> {
                    val intent = Intent(this, GuardianBackgroundService::class.java).apply {
                        action = "STOP_SERVICE"
                    }
                    startService(intent)
                    result.success(true)
                }
                "isServiceRunning" -> {
                    result.success(GuardianBackgroundService.isRunning())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
