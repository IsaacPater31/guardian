package com.example.guardian

import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = GuardianNativeConfig.MethodChannels.BACKGROUND_SERVICE
    private val audioPreviewChannelName = GuardianNativeConfig.MethodChannels.AUDIO_PREVIEW
    private lateinit var audioPreviewChannel: MethodChannel
    private var audioPreviewPlayer: MediaPlayer? = null

    companion object {
        private const val PREFS_NAV = "guardian_navigation"
        private const val KEY_OPEN_COMMUNITY_MESSAGES = "open_community_messages"
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        storeNotificationNavigationIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        GuardianBackgroundService.setAppInForeground(true)
    }

    override fun onPause() {
        GuardianBackgroundService.setAppInForeground(false)
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        storeNotificationNavigationIntent(intent)
    }

    private fun storeNotificationNavigationIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(
                GuardianNativeConfig.Notifications.EXTRA_OPEN_COMMUNITY_MESSAGES,
                false,
            ) == true
        ) {
            getSharedPreferences(PREFS_NAV, MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_OPEN_COMMUNITY_MESSAGES, true)
                .apply()
            intent.removeExtra(GuardianNativeConfig.Notifications.EXTRA_OPEN_COMMUNITY_MESSAGES)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioPreviewChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            audioPreviewChannelName,
        )
        audioPreviewChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val path = (call.arguments as? Map<*, *>)?.get("path") as? String
                    if (path.isNullOrEmpty()) {
                        result.error("BAD_ARGS", "path required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        audioPreviewPlayer?.release()
                        audioPreviewPlayer = MediaPlayer().apply {
                            setDataSource(path)
                            setOnCompletionListener {
                                Handler(Looper.getMainLooper()).post {
                                    try {
                                        audioPreviewChannel.invokeMethod("completed", null)
                                    } catch (_: Exception) { }
                                }
                                try {
                                    release()
                                } catch (_: Exception) { }
                                audioPreviewPlayer = null
                            }
                            prepare()
                            start()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PLAY_FAILED", e.message, null)
                    }
                }
                "stop" -> {
                    try {
                        audioPreviewPlayer?.stop()
                    } catch (_: Exception) { }
                    try {
                        audioPreviewPlayer?.release()
                    } catch (_: Exception) { }
                    audioPreviewPlayer = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        syncFlutterLocaleToNative()
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val intent = Intent(this, GuardianBackgroundService::class.java).apply {
                        action = GuardianNativeConfig.Service.ACTION_START
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopService" -> {
                    val intent = Intent(this, GuardianBackgroundService::class.java).apply {
                        action = GuardianNativeConfig.Service.ACTION_STOP
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
                "checkNotificationPermissions" -> {
                    result.success(checkNotificationPermissions())
                }
                "requestNotificationPermissions" -> {
                    requestNotificationPermissions()
                    result.success(true)
                }
                "setLanguage" -> {
                    val language = call.argument<String>("language")
                    setLanguage(language)
                    result.success(true)
                }
                "setAppForeground" -> {
                    val foreground = call.argument<Boolean>("foreground") ?: false
                    GuardianBackgroundService.setAppInForeground(foreground)
                    result.success(true)
                }
                "consumeOpenCommunityMessages" -> {
                    val prefs = getSharedPreferences(PREFS_NAV, MODE_PRIVATE)
                    val open = prefs.getBoolean(KEY_OPEN_COMMUNITY_MESSAGES, false)
                    if (open) {
                        prefs.edit().remove(KEY_OPEN_COMMUNITY_MESSAGES).apply()
                    }
                    result.success(open)
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

    /**
     * Establece el idioma actual para las notificaciones nativas
     */
    private fun setLanguage(language: String?) {
        if (language != null) {
            val prefs = getSharedPreferences(GuardianNativeConfig.Locale.PREFS_NATIVE, MODE_PRIVATE)
            prefs.edit()
                .putString(GuardianNativeConfig.Locale.KEY_LANGUAGE, language)
                .apply()
            println("✅ Language set to: $language")
        }
    }

    /**
     * Copia el idioma guardado por Flutter (`shared_preferences`) al almacén
     * que lee el servicio en segundo plano, para que arranque con el locale correcto.
     */
    private fun syncFlutterLocaleToNative() {
        try {
            val lang = LocaleHelper.getCurrentLanguage(this)
            println("✅ Synced Flutter locale to native: $lang")
        } catch (e: Exception) {
            println("⚠️ syncFlutterLocaleToNative: ${e.message}")
        }
    }
}
