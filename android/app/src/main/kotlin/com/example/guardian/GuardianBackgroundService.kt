package com.example.guardian

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import java.util.*
import com.google.firebase.auth.FirebaseAuth

class GuardianBackgroundService : Service() {
    
    companion object {
        private var isServiceRunning = false

        fun isRunning(): Boolean = isServiceRunning
    }
    
    private lateinit var firestore: FirebaseFirestore
    private var alertsListener: ListenerRegistration? = null
    private lateinit var auth: FirebaseAuth
    
    override fun onCreate() {
        super.onCreate()
        firestore = FirebaseFirestore.getInstance()
        auth = FirebaseAuth.getInstance()
        createNotificationChannels()
        
        // Inicializar EmergencyTypes con el contexto
        EmergencyTypes.initialize(this)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            GuardianNativeConfig.Service.ACTION_START -> startForegroundService()
            GuardianNativeConfig.Service.ACTION_STOP -> stopForegroundService()
        }
        // START_REDELIVER_INTENT: Reinicia el servicio con el último Intent si es eliminado
        return START_REDELIVER_INTENT
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun startForegroundService() {
        if (isServiceRunning) return
        
        println("🚀 Starting Guardian Background Service...")
        
        // Los permisos de notificación se verifican desde PermissionService.dart
        // No duplicar lógica aquí para mantener consistencia
        
        // Crear notificación persistente
        val notification = createPersistentNotification()
        
        // Iniciar servicio en primer plano
        startForeground(GuardianNativeConfig.Notifications.FOREGROUND_SERVICE_ID, notification)
        
        // Iniciar escucha de alertas
        startAlertsListener()
        
        isServiceRunning = true
        println("✅ Guardian Background Service started successfully")
        println("📱 Persistent notification should be visible in notification bar")
        
        // Verificar que la notificación se mostró
        val notificationManager = getSystemService(NotificationManager::class.java)
        val activeNotifications = notificationManager.activeNotifications
        println("📊 Active notifications count: ${activeNotifications.size}")
        for (notification in activeNotifications) {
            println("📱 Active notification ID: ${notification.id}, Channel: ${notification.notification.channelId}")
        }
    }
    
    private fun stopForegroundService() {
        if (!isServiceRunning) return
        
        // Detener escucha de alertas
        stopAlertsListener()
        
        // Detener servicio en primer plano
        stopForeground(true)
        stopSelf()
        
        isServiceRunning = false
        println("✅ Guardian Background Service stopped successfully")
    }
    
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)
            val language = getCurrentLanguage()

            val serviceChannelName =
                if (language == "es") "Protección activa de Guardian" else "Guardian Active Protection"
            val serviceChannelDescription =
                if (language == "es") {
                    "Mantiene Guardian monitoreando alertas en segundo plano"
                } else {
                    "Keeps Guardian monitoring alerts in the background"
                }

            val alertsChannelName =
                if (language == "es") "Alertas de emergencia" else "Emergency alerts"
            val alertsChannelDescription =
                if (language == "es") {
                    "Notificaciones de alertas enviadas por tu comunidad"
                } else {
                    "Notifications for alerts sent by your community"
                }
            
            // Canal para la notificación persistente del servicio
            val serviceChannel = NotificationChannel(
                GuardianNativeConfig.Notifications.CHANNEL_SERVICE,
                serviceChannelName,
                NotificationManager.IMPORTANCE_MIN // MIN para notificación persistente visible pero silenciosa
            ).apply {
                description = serviceChannelDescription
                setShowBadge(false) // No mostrar badge para servicio
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(false) // No omitir el modo No Molestar
            }
            
            // Canal para las alertas de emergencia
            val alertsChannel = NotificationChannel(
                GuardianNativeConfig.Notifications.CHANNEL_ALERTS,
                alertsChannelName,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = alertsChannelDescription
                setShowBadge(true)
                enableLights(true)
                enableVibration(true)
                setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, null)
                vibrationPattern = GuardianNativeConfig.Vibration.EMERGENCY_PATTERN_MS
                lightColor = GuardianNativeConfig.Notifications.ALERT_LIGHT_COLOR
            }
            
            notificationManager.createNotificationChannel(serviceChannel)
            notificationManager.createNotificationChannel(alertsChannel)
            
            println("✅ Notification channels created successfully")
            println("📱 Service channel: ${GuardianNativeConfig.Notifications.CHANNEL_SERVICE}")
            println("🚨 Alerts channel: ${GuardianNativeConfig.Notifications.CHANNEL_ALERTS}")
        } else {
            println("⚠️ Android version < 8.0, using legacy notifications")
        }
    }
    
    private fun createPersistentNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Action para detener el servicio desde la notificación
        val stopIntent = Intent(this, GuardianBackgroundService::class.java).apply {
            action = GuardianNativeConfig.Service.ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Obtener textos según el idioma actual
        val language = getCurrentLanguage()
        val title = if (language == "es") {
            "🛡️ Guardian Protección Activa"
        } else {
            "🛡️ Guardian Active Protection"
        }
        
        val content = if (language == "es") {
            "Monitoreando alertas de tu comunidad • Toca para abrir"
        } else {
            "Monitoring community alerts • Tap to open"
        }
        
        val subText = if (language == "es") {
            "Servicio de seguridad en segundo plano"
        } else {
            "Background security service"
        }
        
        val stopButtonText = if (language == "es") "Detener" else "Stop"
        
        val bigText = if (language == "es") {
            "Guardian está monitoreando alertas de tu comunidad. El servicio permanece activo para tu seguridad."
        } else {
            "Guardian is monitoring community alerts. The service remains active for your safety."
        }
        
        val summaryText = if (language == "es") {
            "Servicio de seguridad activo"
        } else {
            "Security service active"
        }
        
        return NotificationCompat.Builder(this, GuardianNativeConfig.Notifications.CHANNEL_SERVICE)
            .setContentTitle(title)
            .setContentText(content)
            .setSubText(subText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(android.graphics.BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher))
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setShowWhen(false) // No mostrar timestamp para notificación persistente
            .setWhen(System.currentTimeMillis())
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MIN) // MIN para notificación persistente visible
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(R.mipmap.ic_launcher, stopButtonText, stopPendingIntent)
            .setStyle(NotificationCompat.BigTextStyle()
                .setBigContentTitle(title)
                .bigText(bigText)
                .setSummaryText(summaryText))
            .build()
    }
    
    private fun getCurrentLanguage(): String {
        return try {
            val flutterPrefs = getSharedPreferences(
                GuardianNativeConfig.Locale.PREFS_FLUTTER,
                Context.MODE_PRIVATE,
            )
            var lang = flutterPrefs.getString(
                GuardianNativeConfig.Locale.KEY_FLUTTER_SELECTED_LANGUAGE,
                null,
            )
            if (lang == null) {
                for (key in flutterPrefs.all.keys) {
                    if (key.contains("selected_language")) {
                        lang = flutterPrefs.getString(key, null)
                        break
                    }
                }
            }
            if (lang != null) {
                getSharedPreferences(GuardianNativeConfig.Locale.PREFS_NATIVE, Context.MODE_PRIVATE)
                    .edit()
                    .putString(GuardianNativeConfig.Locale.KEY_LANGUAGE, lang)
                    .apply()
                return lang
            }
            val legacy = getSharedPreferences(
                GuardianNativeConfig.Locale.PREFS_NATIVE,
                Context.MODE_PRIVATE,
            )
            legacy.getString(
                GuardianNativeConfig.Locale.KEY_LANGUAGE,
                GuardianNativeConfig.Locale.DEFAULT_LANGUAGE,
            ) ?: GuardianNativeConfig.Locale.DEFAULT_LANGUAGE
        } catch (_: Exception) {
            GuardianNativeConfig.Locale.DEFAULT_LANGUAGE
        }
    }
    
    private fun startAlertsListener() {
        val windowStart = Date(
            System.currentTimeMillis() - GuardianNativeConfig.Durations.ALERTS_LISTENER_WINDOW_MS,
        )

        alertsListener = firestore.collection(GuardianNativeConfig.Firestore.COLLECTION_ALERTS)
            .whereGreaterThan(GuardianNativeConfig.Firestore.FIELD_TIMESTAMP, windowStart)
            .orderBy(GuardianNativeConfig.Firestore.FIELD_TIMESTAMP, Query.Direction.DESCENDING)
            .limit(GuardianNativeConfig.Firestore.RECENT_ALERTS_QUERY_LIMIT)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    println("❌ Error listening to alerts: $error")
                    return@addSnapshotListener
                }
                
                snapshot?.documentChanges?.forEach { change ->
                    if (change.type == com.google.firebase.firestore.DocumentChange.Type.ADDED) {
                        val alertData = change.document.data
                        if (alertData != null) {
                            handleNewAlert(alertData, change.document.id)
                        }
                    }
                }
            }
    }
    
    private fun stopAlertsListener() {
        alertsListener?.remove()
        alertsListener = null
    }
    
    private fun handleNewAlert(alertData: Map<String, Any>, documentId: String) {
        val fs = GuardianNativeConfig.Firestore
        val rawAlertType = alertData[fs.FIELD_ALERT_TYPE] as? String ?: return
        val flowType = alertData[fs.FIELD_TYPE] as? String ?: ""
        val alertType = EmergencyTypes.normalizeAlertTypeForNotification(rawAlertType, flowType)
        val description = alertData[fs.FIELD_DESCRIPTION] as? String
        val isAnonymous = alertData[fs.FIELD_IS_ANONYMOUS] as? Boolean ?: false
        val shareLocation = alertData[fs.FIELD_SHARE_LOCATION] as? Boolean ?: false
        val alertUserId = alertData[fs.FIELD_USER_ID] as? String
        val alertUserEmail = alertData[fs.FIELD_USER_EMAIL] as? String

        val currentUser = auth.currentUser
        if (currentUser == null) {
            println("⚠️ No user logged in, skipping notification")
            return
        }

        val isOwnAlert = (alertUserId != null && alertUserId == currentUser.uid) ||
                (alertUserEmail != null && alertUserEmail == currentUser.email)

        if (isOwnAlert) {
            println("🚫 Skipping notification for own alert: $alertType")
            return
        }

        val alertStatus = alertData[fs.FIELD_ALERT_STATUS] as? String ?: fs.STATUS_PENDING
        if (alertStatus == fs.STATUS_ATTENDED) {
            println("✅ Alert already attended, skipping notification: $alertType")
            return
        }

        val viewedBy = alertData[fs.FIELD_VIEWED_BY] as? List<String> ?: emptyList()
        if (viewedBy.contains(currentUser.uid)) {
            println("👁️ User already viewed this alert, skipping notification: $alertType")
            return
        }

        val timestamp = alertData[fs.FIELD_TIMESTAMP] as? com.google.firebase.Timestamp
        if (timestamp != null) {
            val alertTime = timestamp.toDate()
            val windowStart = Date(
                System.currentTimeMillis() - GuardianNativeConfig.Durations.ALERTS_LISTENER_WINDOW_MS,
            )
            if (alertTime.before(windowStart)) {
                println("⏰ Alert is too old (${alertTime}), skipping notification: $alertType")
                return
            }
        }

        val communityIds = linkedSetOf<String>()
        (alertData[fs.FIELD_COMMUNITY_IDS] as? List<*>)?.filterIsInstance<String>()?.let {
            communityIds.addAll(it)
        }
        (alertData[fs.FIELD_COMMUNITY_ID] as? String)?.let { communityIds.add(it) }

        if (communityIds.isNotEmpty()) {
            tryNotifyForCommunityTargets(
                currentUser.uid,
                communityIds.toList(),
                alertType,
                description,
                isAnonymous,
                shareLocation,
                0
            )
        } else {
            println("ℹ️ Alert $documentId without community scope (legacy), notifying user")
            showAlertNotification(alertType, description, isAnonymous, shareLocation)
            triggerVibration()
            println("🚨 New alert notification sent: $alertType")
        }
    }

    /**
     * Sends at most one notification: first [communityIds] entry where the user is a member.
     */
    private fun tryNotifyForCommunityTargets(
        userId: String,
        communityIds: List<String>,
        alertType: String,
        description: String?,
        isAnonymous: Boolean,
        shareLocation: Boolean,
        index: Int
    ) {
        if (index >= communityIds.size) {
            println("🚫 User not authorized for any community on this alert")
            return
        }
        val fs = GuardianNativeConfig.Firestore
        val communityId = communityIds[index]
        firestore.collection(fs.COLLECTION_COMMUNITIES)
            .document(communityId)
            .get()
            .addOnSuccessListener { communityDoc ->
                if (!communityDoc.exists()) {
                    tryNotifyForCommunityTargets(
                        userId, communityIds, alertType, description, isAnonymous, shareLocation, index + 1
                    )
                    return@addOnSuccessListener
                }
                firestore.collection(fs.COLLECTION_COMMUNITY_MEMBERS)
                    .whereEqualTo(fs.FIELD_USER_ID, userId)
                    .whereEqualTo(fs.FIELD_COMMUNITY_ID, communityId)
                    .limit(1)
                    .get()
                    .addOnSuccessListener { memberSnapshot ->
                        if (memberSnapshot.isEmpty) {
                            tryNotifyForCommunityTargets(
                                userId, communityIds, alertType, description, isAnonymous, shareLocation, index + 1
                            )
                            return@addOnSuccessListener
                        }
                        val memberData = memberSnapshot.documents[0].data
                        showAlertNotification(alertType, description, isAnonymous, shareLocation)
                        triggerVibration()
                        println("🚨 Alert notification sent for community $communityId: $alertType")
                    }
                    .addOnFailureListener { e ->
                        println("❌ Error checking user membership: $e")
                    }
            }
            .addOnFailureListener { e ->
                println("❌ Error getting community: $e")
            }
    }
    
    private fun showAlertNotification(
        alertType: String,
        description: String?,
        isAnonymous: Boolean,
        shareLocation: Boolean
    ) {
        val title = getAlertTitle(alertType)
        val body = buildAlertBody(alertType, description, isAnonymous, shareLocation)
        val summary = EmergencyTypes.buildNotificationSummary(description, isAnonymous, shareLocation)
        val expanded = if (body.isNotEmpty()) body else summary

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(
            this,
            GuardianNativeConfig.Notifications.CHANNEL_ALERTS,
        )
            .setContentTitle(title)
            .setContentText(summary)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            .setVibrate(GuardianNativeConfig.Vibration.EMERGENCY_PATTERN_MS)
            .setLights(
                GuardianNativeConfig.Notifications.ALERT_LIGHT_COLOR,
                GuardianNativeConfig.Durations.NOTIFICATION_LIGHT_FLASH_MS.toInt(),
                GuardianNativeConfig.Durations.NOTIFICATION_LIGHT_FLASH_MS.toInt(),
            )
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setFullScreenIntent(pendingIntent, true)
            .setTimeoutAfter(GuardianNativeConfig.Durations.EMERGENCY_NOTIFICATION_TIMEOUT_MS)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle(title)
                    .bigText(expanded)
                    .setSummaryText(summary)
            )
            .build()
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
    }
    
    private fun getAlertTitle(alertType: String): String {
        return EmergencyTypes.getNotificationTitle(alertType)
    }
    
    private fun buildAlertBody(
        alertType: String,
        description: String?,
        isAnonymous: Boolean,
        shareLocation: Boolean
    ): String {
        return EmergencyTypes.buildNotificationBody(alertType, description, isAnonymous, shareLocation)
    }
    
    private fun triggerVibration() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(VibratorManager::class.java)
                vibratorManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Vibrator::class.java)
            }

            if (vibrator != null && vibrator.hasVibrator()) {
                println("📳 Iniciando vibración de emergencia...")
                
                val emergencyPattern = GuardianNativeConfig.Vibration.EMERGENCY_PATTERN_MS
                val continuousDurationMs = GuardianNativeConfig.Durations.ACTIVE_ALERT_FEEDBACK_MS

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    try {
                        // Usar patrón de vibración más agresivo
                        val effect = VibrationEffect.createWaveform(emergencyPattern, 0) // repeat
                        vibrator.vibrate(effect)
                        
                        println("📳 Vibración con patrón agresivo activada")
                        
                        // Safety: cancel vibration after the duration
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            try { 
                                vibrator.cancel() 
                                println("📳 Vibración cancelada después de $continuousDurationMs ms")
                            } catch (ignored: Exception) {}
                        }, continuousDurationMs)
                    } catch (e: Exception) {
                        println("❌ Error con patrón de vibración, usando fallback: ${e.message}")
                        // Fallback más simple
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(continuousDurationMs)
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            try { vibrator.cancel() } catch (ignored: Exception) {}
                        }, continuousDurationMs)
                    }
                } else {
                    // Deprecated API fallback
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(emergencyPattern, 0) // repeat
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        try { vibrator.cancel() } catch (ignored: Exception) {}
                    }, continuousDurationMs)
                }

                println("📳 Vibración de emergencia activada por $continuousDurationMs ms")
            } else {
                println("❌ Vibrator no disponible o no soportado")
            }
        } catch (e: Exception) {
            println("❌ Error en vibración manual: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopAlertsListener()
        isServiceRunning = false
        println("🔄 Guardian Background Service destroyed")
        
        // Intentar reiniciar el servicio si fue eliminado inesperadamente
        try {
            val restartIntent = Intent(this, GuardianBackgroundService::class.java).apply {
                action = GuardianNativeConfig.Service.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(restartIntent)
            } else {
                startService(restartIntent)
            }
            println("🔄 Attempting to restart Guardian service...")
        } catch (e: Exception) {
            println("❌ Failed to restart service: ${e.message}")
        }
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        println("📱 App task removed - keeping service alive")
        
        // Reiniciar el servicio cuando la app es eliminada de recientes
        try {
            val restartIntent = Intent(this, GuardianBackgroundService::class.java).apply {
                action = GuardianNativeConfig.Service.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(restartIntent)
            } else {
                startService(restartIntent)
            }
            println("🔄 Service restarted after app task removal")
        } catch (e: Exception) {
            println("❌ Failed to restart service after task removal: ${e.message}")
        }
    }
}
