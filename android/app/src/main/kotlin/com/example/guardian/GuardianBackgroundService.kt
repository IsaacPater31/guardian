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
    
    override fun onCreate() {
        super.onCreate()
        firestore = FirebaseFirestore.getInstance()
        createNotificationChannels()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_SERVICE" -> startForegroundService()
            "STOP_SERVICE" -> stopForegroundService()
        }
        return START_STICKY // El servicio se reiniciará si es eliminado por el sistema
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun startForegroundService() {
        if (isServiceRunning) return
        
        // Crear notificación persistente
        val notification = createPersistentNotification()
        
        // Iniciar servicio en primer plano
        startForeground(NOTIFICATION_ID, notification)
        
        // Iniciar escucha de alertas
        startAlertsListener()
        
        isServiceRunning = true
        println("✅ Guardian Background Service started successfully")
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
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = CHANNEL_DESCRIPTION
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
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
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Guardian Activo")
            .setContentText("Escuchando alertas en tu área")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setShowWhen(false)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
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
        
        // Crear notificación de alerta
        showAlertNotification(alertType, description, isAnonymous, shareLocation)
        
        // Vibración manual adicional
        triggerVibration()
        
        println("🚨 Alert received in background service: $alertType")
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
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            .setVibrate(longArrayOf(0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000))
            .setLights(0xFFD32F2F.toInt(), 1000, 1000)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
    }
    
    private fun getAlertTitle(alertType: String): String {
        return when (alertType) {
            "ROBBERY" -> "🚨 Robo Reportado"
            "FIRE" -> "🔥 Incendio Reportado"
            "ACCIDENT" -> "🚗 Accidente Reportado"
            "STREET ESCORT" -> "👥 Acompañamiento Solicitado"
            "UNSAFETY" -> "⚠️ Zona Insegura"
            "PHYSICAL RISK" -> "🚨 Riesgo Físico"
            "PUBLIC SERVICES EMERGENCY" -> "🏗️ Emergencia Servicios Públicos"
            "VIAL EMERGENCY" -> "🚦 Emergencia Vial"
            "ASSISTANCE" -> "🆘 Asistencia Necesaria"
            "EMERGENCY" -> "🚨 Emergencia General"
            else -> "🚨 Alerta de Emergencia"
        }
    }
    
    private fun buildAlertBody(
        alertType: String,
        description: String?,
        isAnonymous: Boolean,
        shareLocation: Boolean
    ): String {
        val body = StringBuilder(alertType)
        
        if (!description.isNullOrEmpty()) {
            body.append("\n").append(description)
        }
        
        if (shareLocation) {
            body.append("\n📍 Ubicación incluida")
        }
        
        if (isAnonymous) {
            body.append("\n👤 Reporte anónimo")
        }
        
        return body.toString()
    }
    
    private fun triggerVibration() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(VibratorManager::class.java)
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Vibrator::class.java)
            }
            
            if (vibrator.hasVibrator()) {
                val vibrationPattern = longArrayOf(0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000)
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val vibrationEffect = VibrationEffect.createWaveform(vibrationPattern, -1)
                    vibrator.vibrate(vibrationEffect)
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(vibrationPattern, -1)
                }
                
                println("📳 Vibración manual activada")
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
    }
}
