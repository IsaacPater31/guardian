package com.example.guardian

import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
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
                "requestBatteryOptimizationExemption" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }
                "isBatteryOptimizationIgnored" -> {
                    result.success(isBatteryOptimizationIgnored())
                }
                "requestWhitelistPermission" -> {
                    requestWhitelistPermission()
                    result.success(true)
                }
                "scheduleWorker" -> {
                    // Schedule WorkManager periodic work from native side
                    try {
                        GuardianStarterWorker.schedulePeriodicWork(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WORKER_ERROR", e.message, null)
                    }
                }
                "checkNotificationPermissions" -> {
                    result.success(checkNotificationPermissions())
                }
                "requestNotificationPermissions" -> {
                    requestNotificationPermissions()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Solicita exención de optimización de batería para la app
     */
    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent().apply {
                action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                data = Uri.parse("package:$packageName")
            }
            try {
                startActivity(intent)
                println("✅ Battery optimization exemption requested")
            } catch (e: Exception) {
                println("❌ Error requesting battery optimization exemption: ${e.message}")
                // Fallback: abrir configuración general de optimización de batería
                try {
                    val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    startActivity(fallbackIntent)
                } catch (e2: Exception) {
                    println("❌ Error opening battery optimization settings: ${e2.message}")
                }
            }
        }
    }

    /**
     * Verifica si la app está exenta de optimización de batería
     */
    private fun isBatteryOptimizationIgnored(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(PowerManager::class.java)
            powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
        } else {
            true // En versiones anteriores no hay optimización de batería
        }
    }

    /**
     * Solicita agregar la app a la lista blanca del sistema
     */
    private fun requestWhitelistPermission() {
        try {
            // Abrir configuración de aplicaciones para que el usuario pueda configurar manualmente
            val intent = Intent().apply {
                action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                data = Uri.fromParts("package", packageName, null)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            println("✅ App settings opened for manual configuration")
        } catch (e: Exception) {
            println("❌ Error opening app settings: ${e.message}")
            try {
                // Fallback: abrir configuración general de aplicaciones
                val fallbackIntent = Intent(Settings.ACTION_APPLICATION_SETTINGS)
                startActivity(fallbackIntent)
            } catch (e2: Exception) {
                println("❌ Error opening application settings: ${e2.message}")
            }
        }
    }

    /**
     * Verifica si las notificaciones están habilitadas para la app
     * MÉTODO NATIVO - Solo para uso desde PermissionService.dart
     */
    private fun checkNotificationPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.areNotificationsEnabled()
        } else {
            true // En versiones anteriores, las notificaciones están habilitadas por defecto
        }
    }

    /**
     * Solicita permisos de notificación (Android 13+)
     * MÉTODO NATIVO - Solo para uso desde PermissionService.dart
     */
    private fun requestNotificationPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                val intent = Intent().apply {
                    action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                println("✅ Notification settings opened")
            } catch (e: Exception) {
                println("❌ Error opening notification settings: ${e.message}")
                // Fallback: abrir configuración general de la app
                requestWhitelistPermission()
            }
        } else {
            println("ℹ️ Notification permissions not required for Android < 13")
        }
    }
}
