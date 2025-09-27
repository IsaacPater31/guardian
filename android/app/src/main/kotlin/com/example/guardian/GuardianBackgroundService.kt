package com.example.guardian

import android.app.*
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
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "guardian_background_service"
        private const val CHANNEL_NAME = "Guardian Background Service"
        private const val CHANNEL_DESCRIPTION = "Mantiene Guardian escuchando alertas en segundo plano"
        
        private const val ALERTS_CHANNEL_ID = "emergency_alerts"
        private const val ALERTS_CHANNEL_NAME = "Emergency Alerts"
        private const val ALERTS_CHANNEL_DESCRIPTION = "Notificaciones de alertas de emergencia"
        
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
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_SERVICE" -> startForegroundService()
            "STOP_SERVICE" -> stopForegroundService()
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
        startForeground(NOTIFICATION_ID, notification)
        
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
            
            // Canal para la notificación persistente del servicio
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_MIN // MIN para notificación persistente visible pero silenciosa
            ).apply {
                description = CHANNEL_DESCRIPTION
                setShowBadge(false) // No mostrar badge para servicio
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(false) // No omitir el modo No Molestar
            }
            
            // Canal para las alertas de emergencia
            val alertsChannel = NotificationChannel(
                ALERTS_CHANNEL_ID,
                ALERTS_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = ALERTS_CHANNEL_DESCRIPTION
                setShowBadge(true)
                enableLights(true)
                enableVibration(true)
                setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, null)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000)
                lightColor = 0xFFD32F2F.toInt()
            }
            
            notificationManager.createNotificationChannel(serviceChannel)
            notificationManager.createNotificationChannel(alertsChannel)
            
            println("✅ Notification channels created successfully")
            println("📱 Service channel: $CHANNEL_ID")
            println("🚨 Alerts channel: $ALERTS_CHANNEL_ID")
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
            action = "STOP_SERVICE"
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🛡️ Guardian Protección Activa")
            .setContentText("Monitoreando alertas de emergencia • Toca para abrir")
            .setSubText("Servicio de seguridad en segundo plano")
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
            .addAction(R.mipmap.ic_launcher, "Detener", stopPendingIntent)
            .setStyle(NotificationCompat.BigTextStyle()
                .setBigContentTitle("🛡️ Guardian Protección Activa")
                .bigText("Guardian está monitoreando alertas de emergencia en tu área. El servicio permanece activo para tu seguridad.")
                .setSummaryText("Servicio de seguridad activo"))
            .build()
    }
    
    private fun startAlertsListener() {
        // Escuchar alertas de la última hora
        val oneHourAgo = Date(System.currentTimeMillis() - 60 * 60 * 1000)
        
        alertsListener = firestore.collection("alerts")
            .whereGreaterThan("timestamp", oneHourAgo)
            .orderBy("timestamp", com.google.firebase.firestore.Query.Direction.DESCENDING)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    println("❌ Error listening to alerts: $error")
                    return@addSnapshotListener
                }
                
                snapshot?.documentChanges?.forEach { change ->
                    if (change.type == com.google.firebase.firestore.DocumentChange.Type.ADDED) {
                        val alertData = change.document.data
                        if (alertData != null) {
                            handleNewAlert(alertData)
                        }
                    }
                }
            }
    }
    
    private fun stopAlertsListener() {
        alertsListener?.remove()
        alertsListener = null
    }
    
    private fun handleNewAlert(alertData: Map<String, Any>) {
        val alertType = alertData["alertType"] as? String ?: return
        val description = alertData["description"] as? String
        val isAnonymous = alertData["isAnonymous"] as? Boolean ?: false
        val shareLocation = alertData["shareLocation"] as? Boolean ?: false
        val alertUserId = alertData["userId"] as? String
        val alertUserEmail = alertData["userEmail"] as? String
        val alertId = alertData["id"] as? String
        
        // Obtener usuario actual
        val currentUser = auth.currentUser
        if (currentUser == null) {
            println("⚠️ No user logged in, skipping notification")
            return
        }
        
        // Verificar si la alerta es del mismo usuario
        val isOwnAlert = (alertUserId != null && alertUserId == currentUser.uid) ||
                        (alertUserEmail != null && alertUserEmail == currentUser.email)
        
        if (isOwnAlert) {
            println("🚫 Skipping notification for own alert: $alertType")
            return
        }
        
        // Verificar si el usuario ya vio esta alerta
        val viewedBy = alertData["viewedBy"] as? List<String> ?: emptyList()
        if (viewedBy.contains(currentUser.uid)) {
            println("👁️ User already viewed this alert, skipping notification: $alertType")
            return
        }
        
        // Verificar si la alerta es muy antigua (más de 1 hora)
        val timestamp = alertData["timestamp"] as? com.google.firebase.Timestamp
        if (timestamp != null) {
            val alertTime = timestamp.toDate()
            val oneHourAgo = Date(System.currentTimeMillis() - 60 * 60 * 1000)
            if (alertTime.before(oneHourAgo)) {
                println("⏰ Alert is too old (${alertTime}), skipping notification: $alertType")
                return
            }
        }
        
        // Crear notificación de alerta
        showAlertNotification(alertType, description, isAnonymous, shareLocation)
        
        // Vibración manual adicional
        triggerVibration()
        
        println("🚨 New alert notification sent: $alertType")
    }
    
    private fun showAlertNotification(
        alertType: String,
        description: String?,
        isAnonymous: Boolean,
        shareLocation: Boolean
    ) {
        val title = getAlertTitle(alertType)
        val body = buildAlertBody(alertType, description, isAnonymous, shareLocation)
        
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(this, ALERTS_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_MAX) // MAX para alertas críticas
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            .setVibrate(longArrayOf(0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000))
            .setLights(0xFFD32F2F.toInt(), 1000, 1000)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setFullScreenIntent(pendingIntent, true) // Mostrar en pantalla completa
            .setTimeoutAfter(30000) // Timeout después de 30 segundos
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
                
                // Patrón de vibración más agresivo para alertas de emergencia
                val emergencyPattern = longArrayOf(0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000)
                val continuousDurationMs = 10000L // 10 segundos

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
                action = "START_SERVICE"
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
                action = "START_SERVICE"
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
