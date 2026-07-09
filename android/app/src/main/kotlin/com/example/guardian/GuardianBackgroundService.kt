package com.example.guardian

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import com.google.firebase.auth.FirebaseAuth

class GuardianBackgroundService : Service() {
    
    companion object {
        private var isServiceRunning = false
        private const val PREFS_NOTIFIED_MESSAGES = "guardian_notified_messages"

        @Volatile
        private var appInForeground = false

        fun isRunning(): Boolean = isServiceRunning

        fun setAppInForeground(foreground: Boolean) {
            appInForeground = foreground
            println("📱 App foreground: $foreground")
        }
    }
    
    private lateinit var firestore: FirebaseFirestore
    private var alertInboxListener: ListenerRegistration? = null
    private var alertInboxInitialSnapshot = true
    private var communityMessagesListener: ListenerRegistration? = null
    private var communityMessagesInitialSnapshot = true
    private var authStateListener: FirebaseAuth.AuthStateListener? = null
    private var lastInboxListenerUserId: String? = null
    private lateinit var auth: FirebaseAuth
    
    override fun onCreate() {
        super.onCreate()
        firestore = FirebaseFirestore.getInstance()
        auth = FirebaseAuth.getInstance()
        createNotificationChannels()
        
        // Inicializar EmergencyTypes con el contexto
        EmergencyTypes.initialize(this)

        authStateListener = FirebaseAuth.AuthStateListener {
            if (!isServiceRunning) return@AuthStateListener
            val uid = auth.currentUser?.uid
            if (uid == lastInboxListenerUserId) return@AuthStateListener
            println("🔐 Auth user changed — refreshing inbox listeners")
            if (uid == null) {
                stopAlertInboxListener()
                stopCommunityMessagesListener()
                lastInboxListenerUserId = null
            } else {
                ensureAlertInboxListener()
                ensureCommunityMessagesListener()
            }
        }
        auth.addAuthStateListener(authStateListener!!)
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
        if (!isServiceRunning) {
            println("🚀 Starting Guardian Background Service...")

            // Los permisos de notificación se verifican desde PermissionService.dart
            // No duplicar lógica aquí para mantener consistencia

            val notification = createPersistentNotification()
            startForeground(GuardianNativeConfig.Notifications.FOREGROUND_SERVICE_ID, notification)
            isServiceRunning = true

            println("✅ Guardian Background Service started successfully")
            println("📱 Persistent notification should be visible in notification bar")

            val notificationManager = getSystemService(NotificationManager::class.java)
            val activeNotifications = notificationManager.activeNotifications
            println("📊 Active notifications count: ${activeNotifications.size}")
            for (active in activeNotifications) {
                println("📱 Active notification ID: ${active.id}, Channel: ${active.notification.channelId}")
            }
        } else {
            println("♻️ Guardian Background Service already running — ensuring listeners")
        }

        // Siempre asegurar listeners (p. ej. login posterior al arranque del servicio).
        ensureAlertInboxListener()
        ensureCommunityMessagesListener()
    }

    private fun shouldDeliverNativeNotification(): Boolean {
        if (appInForeground) {
            println("📱 App en primer plano — notificación nativa omitida (Flutter maneja UI)")
            return false
        }
        return true
    }

    private fun ensureAlertInboxListener() {
        val uid = auth.currentUser?.uid ?: return
        if (alertInboxListener != null && lastInboxListenerUserId == uid) return
        lastInboxListenerUserId = uid
        stopAlertInboxListener()
        startAlertInboxListener()
    }

    private fun ensureCommunityMessagesListener() {
        val uid = auth.currentUser?.uid ?: return
        if (communityMessagesListener != null && lastInboxListenerUserId == uid) return
        stopCommunityMessagesListener()
        startCommunityMessagesListener()
    }
    
    private fun stopForegroundService() {
        if (!isServiceRunning) return
        
        // Detener escuchas
        stopAlertInboxListener()
        stopCommunityMessagesListener()
        lastInboxListenerUserId = null
        
        // Detener servicio en primer plano
        stopForeground(true)
        stopSelf()
        
        isServiceRunning = false
        println("✅ Guardian Background Service stopped successfully")
    }
    
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)
            val language = LocaleHelper.getCurrentLanguage(this)

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

            val messagesChannelName =
                if (language == "es") "Mensajes de comunidad" else "Community messages"
            val messagesChannelDescription =
                if (language == "es") {
                    "Comunicados enviados por administradores de tu comunidad"
                } else {
                    "Announcements sent by your community administrators"
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
            
            // Canal para las alertas de emergencia (sonido alarma + vibración fuerte)
            val emergencySoundUri = resolveEmergencySoundUri()
            val alarmAudio = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val alertsChannel = NotificationChannel(
                GuardianNativeConfig.Notifications.CHANNEL_ALERTS,
                alertsChannelName,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = alertsChannelDescription
                setShowBadge(true)
                enableLights(true)
                enableVibration(true)
                setSound(emergencySoundUri, alarmAudio)
                vibrationPattern = GuardianNativeConfig.Vibration.EMERGENCY_PATTERN_MS
                lightColor = GuardianNativeConfig.Notifications.ALERT_LIGHT_COLOR
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            notificationManager.createNotificationChannel(serviceChannel)
            notificationManager.createNotificationChannel(alertsChannel)

            val messagesChannel = NotificationChannel(
                GuardianNativeConfig.Notifications.CHANNEL_COMMUNITY_MESSAGES,
                messagesChannelName,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = messagesChannelDescription
                setShowBadge(true)
                enableLights(true)
                enableVibration(true)
                setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, null)
                vibrationPattern = longArrayOf(
                    0,
                    GuardianNativeConfig.Durations.COMMUNITY_MESSAGE_VIBRATE_MS,
                )
                lightColor = GuardianNativeConfig.Notifications.MESSAGE_LIGHT_COLOR
            }
            notificationManager.createNotificationChannel(messagesChannel)

            println("✅ Notification channels created successfully")
            println("📱 Service channel: ${GuardianNativeConfig.Notifications.CHANNEL_SERVICE}")
            println("🚨 Alerts channel: ${GuardianNativeConfig.Notifications.CHANNEL_ALERTS}")
            println("💬 Messages channel: ${GuardianNativeConfig.Notifications.CHANNEL_COMMUNITY_MESSAGES}")
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
        val language = LocaleHelper.getCurrentLanguage(this)
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
    
    private fun alertNotifiedPrefs() =
        getSharedPreferences(GuardianNativeConfig.Firestore.PREFS_NOTIFIED_ALERTS, Context.MODE_PRIVATE)

    private fun isAlertAlreadyNotified(docId: String): Boolean =
        alertNotifiedPrefs().getBoolean("alert_$docId", false)

    private fun markAlertNotified(docId: String) {
        alertNotifiedPrefs().edit().putBoolean("alert_$docId", true).apply()
    }

    private fun startAlertInboxListener() {
        val currentUser = auth.currentUser
        if (currentUser == null) {
            println("⚠️ No user logged in, skipping alert inbox listener")
            return
        }

        alertInboxInitialSnapshot = true
        val fs = GuardianNativeConfig.Firestore

        try {
            alertInboxListener = firestore
                .collection(fs.COLLECTION_USERS)
                .document(currentUser.uid)
                .collection(fs.SUBCOLLECTION_ALERT_INBOX)
                .orderBy(fs.FIELD_CREATED_AT, Query.Direction.DESCENDING)
                .limit(fs.ALERT_INBOX_QUERY_LIMIT)
                .addSnapshotListener { snapshot, error ->
                    if (error != null) {
                        println("❌ Error listening to alert inbox (non-fatal): $error")
                        return@addSnapshotListener
                    }
                    if (snapshot == null) return@addSnapshotListener

                    try {
                        if (alertInboxInitialSnapshot) {
                            alertInboxInitialSnapshot = false
                            val now = System.currentTimeMillis()
                            val startupWindow = fs.ALERT_INBOX_STARTUP_NOTIFY_WINDOW_MS
                            snapshot.documents.forEach { doc ->
                                val data = doc.data
                                if (data != null && !isAlertAlreadyNotified(doc.id)) {
                                    if (!shouldSkipInboxAlert(data)) {
                                        val createdAt = data[fs.FIELD_CREATED_AT] as? com.google.firebase.Timestamp
                                        if (createdAt != null) {
                                            val ageMs = now - createdAt.toDate().time
                                            if (ageMs in 0..startupWindow) {
                                                deliverInboxAlertNotification(data, doc.id)
                                            }
                                        }
                                    }
                                }
                                markAlertNotified(doc.id)
                            }
                            return@addSnapshotListener
                        }

                        snapshot.documentChanges.forEach { change ->
                            if (change.type != com.google.firebase.firestore.DocumentChange.Type.ADDED) {
                                return@forEach
                            }
                            val docId = change.document.id
                            if (isAlertAlreadyNotified(docId)) return@forEach
                            val data = change.document.data ?: return@forEach
                            if (shouldSkipInboxAlert(data)) {
                                markAlertNotified(docId)
                                return@forEach
                            }
                            deliverInboxAlertNotification(data, docId)
                            markAlertNotified(docId)
                        }
                    } catch (e: Exception) {
                        println("❌ Alert inbox handler error (non-fatal): ${e.message}")
                    }
                }
            println("🚨 Alert inbox listener attached for user ${currentUser.uid}")
        } catch (e: Exception) {
            println("❌ Failed to start alert inbox listener (non-fatal): ${e.message}")
            alertInboxListener = null
        }
    }

    private fun stopAlertInboxListener() {
        alertInboxListener?.remove()
        alertInboxListener = null
        alertInboxInitialSnapshot = true
    }

    private fun shouldSkipInboxAlert(data: Map<String, Any>): Boolean {
        val fs = GuardianNativeConfig.Firestore
        val read = data[fs.FIELD_READ] as? Boolean ?: false
        if (read) return true

        val status = data[fs.FIELD_ALERT_STATUS] as? String ?: fs.STATUS_PENDING
        if (status == fs.STATUS_ATTENDED) return true

        val alertType = data[fs.FIELD_INBOX_ALERT_TYPE] as? String
        return alertType.isNullOrBlank()
    }

    private fun deliverInboxAlertNotification(data: Map<String, Any>, inboxDocId: String) {
        if (!shouldDeliverNativeNotification()) return

        val fs = GuardianNativeConfig.Firestore
        val rawAlertType = data[fs.FIELD_INBOX_ALERT_TYPE] as? String ?: return
        val flowType = data[fs.FIELD_INBOX_FLOW_TYPE] as? String ?: ""
        val alertType = EmergencyTypes.normalizeAlertTypeForNotification(rawAlertType, flowType)
        val description = data[fs.FIELD_INBOX_DESCRIPTION] as? String
        val isAnonymous = data[fs.FIELD_INBOX_IS_ANONYMOUS] as? Boolean ?: false
        val shareLocation = data[fs.FIELD_INBOX_SHARE_LOCATION] as? Boolean ?: false

        showAlertNotification(alertType, description, isAnonymous, shareLocation)
        triggerEmergencyVibration()
        println("🚨 Inbox alert notification sent: $inboxDocId ($alertType)")
    }

    private fun resolveEmergencySoundUri(): Uri {
        val rawName = GuardianNativeConfig.Notifications.RAW_EMERGENCY_SIREN
        val resId = resources.getIdentifier(rawName, "raw", packageName)
        if (resId != 0) {
            return Uri.parse("android.resource://$packageName/$resId")
        }
        return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI
    }

    private fun triggerEmergencyVibration() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(VibratorManager::class.java)?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Vibrator::class.java)
            } ?: return

            if (!vibrator.hasVibrator()) return

            val pattern = GuardianNativeConfig.Vibration.EMERGENCY_PATTERN_MS
            val durationMs = GuardianNativeConfig.Durations.ACTIVE_ALERT_FEEDBACK_MS

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, 0)
            }

            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try { vibrator.cancel() } catch (_: Exception) {}
            }, durationMs)
            println("📳 Vibración de emergencia activa ${durationMs}ms")
        } catch (e: Exception) {
            println("❌ Emergency vibration error: ${e.message}")
        }
    }

    private fun messageNotifiedPrefs() =
        getSharedPreferences(PREFS_NOTIFIED_MESSAGES, Context.MODE_PRIVATE)

    private fun isMessageAlreadyNotified(docId: String): Boolean =
        messageNotifiedPrefs().getBoolean("msg_$docId", false)

    private fun markMessageNotified(docId: String) {
        messageNotifiedPrefs().edit().putBoolean("msg_$docId", true).apply()
    }

    private fun startCommunityMessagesListener() {
        val currentUser = auth.currentUser
        if (currentUser == null) {
            println("⚠️ No user logged in, skipping community messages listener")
            return
        }

        communityMessagesInitialSnapshot = true

        val fs = GuardianNativeConfig.Firestore
        try {
            communityMessagesListener = firestore
                .collection(fs.COLLECTION_USERS)
                .document(currentUser.uid)
                .collection(fs.SUBCOLLECTION_COMMUNITY_MESSAGES)
                .orderBy(fs.FIELD_CREATED_AT, Query.Direction.DESCENDING)
                .limit(fs.COMMUNITY_MESSAGES_QUERY_LIMIT)
                .addSnapshotListener { snapshot, error ->
                    if (error != null) {
                        println("❌ Error listening to community messages (non-fatal): $error")
                        return@addSnapshotListener
                    }
                    if (snapshot == null) return@addSnapshotListener

                    try {
                        if (communityMessagesInitialSnapshot) {
                            communityMessagesInitialSnapshot = false
                            val now = System.currentTimeMillis()
                            val startupWindow = fs.MESSAGES_STARTUP_NOTIFY_WINDOW_MS
                            snapshot.documents.forEach { doc ->
                                val data = doc.data
                                if (data != null && !isMessageAlreadyNotified(doc.id)) {
                                    if (!shouldSkipCommunityMessage(data, doc.id)) {
                                        val createdAt = data[fs.FIELD_CREATED_AT] as? com.google.firebase.Timestamp
                                        if (createdAt != null) {
                                            val ageMs = now - createdAt.toDate().time
                                            if (ageMs in 0..startupWindow) {
                                                deliverCommunityMessageNotification(data, doc.id)
                                            }
                                        }
                                    }
                                }
                                markMessageNotified(doc.id)
                            }
                            return@addSnapshotListener
                        }

                        snapshot.documentChanges.forEach { change ->
                            if (change.type != com.google.firebase.firestore.DocumentChange.Type.ADDED) {
                                return@forEach
                            }
                            val docId = change.document.id
                            if (isMessageAlreadyNotified(docId)) return@forEach
                            val data = change.document.data ?: return@forEach
                            if (shouldSkipCommunityMessage(data, docId)) {
                                markMessageNotified(docId)
                                return@forEach
                            }
                            deliverCommunityMessageNotification(data, docId)
                            markMessageNotified(docId)
                        }
                    } catch (e: Exception) {
                        println("❌ Community message handler error (non-fatal): ${e.message}")
                    }
                }
            println("💬 Community messages listener attached for user ${currentUser.uid}")
        } catch (e: Exception) {
            println("❌ Failed to start community messages listener (non-fatal): ${e.message}")
            communityMessagesListener = null
        }
    }

    private fun stopCommunityMessagesListener() {
        communityMessagesListener?.remove()
        communityMessagesListener = null
        communityMessagesInitialSnapshot = true
    }

    private fun shouldSkipCommunityMessage(data: Map<String, Any>, documentId: String): Boolean {
        val fs = GuardianNativeConfig.Firestore
        val currentUser = auth.currentUser ?: return true

        val read = data[fs.FIELD_READ] as? Boolean ?: false
        if (read) {
            println("📭 Community message already read, skip: $documentId")
            return true
        }

        val senderId = data[fs.FIELD_SENDER_ID] as? String
        if (senderId != null && senderId == currentUser.uid) {
            println("🚫 Skipping own community message: $documentId")
            return true
        }

        val title = (data[fs.FIELD_MESSAGE_TITLE] as? String)?.trim().orEmpty()
        val body = (data[fs.FIELD_MESSAGE_BODY] as? String)?.trim().orEmpty()
        if (title.isEmpty() && body.isEmpty()) {
            println("⚠️ Empty community message, skip: $documentId")
            return true
        }

        return false
    }

    private fun deliverCommunityMessageNotification(data: Map<String, Any>, documentId: String) {
        if (!shouldDeliverNativeNotification()) return

        val fs = GuardianNativeConfig.Firestore
        val title = (data[fs.FIELD_MESSAGE_TITLE] as? String)?.trim().orEmpty()
        val body = (data[fs.FIELD_MESSAGE_BODY] as? String)?.trim().orEmpty()
        val senderName = (data[fs.FIELD_SENDER_NAME] as? String)?.trim()
        showCommunityMessageNotification(title, body, senderName, documentId)
        println("💬 Community message notification sent: $documentId")
    }

    private fun showCommunityMessageNotification(
        title: String,
        body: String,
        senderName: String?,
        documentId: String,
    ) {
        val language = LocaleHelper.getCurrentLanguage(this)
        val defaultTitle = if (language == "es") "Mensaje de tu comunidad" else "Message from your community"
        val contentTitle = if (title.isNotEmpty()) title else defaultTitle
        val summary = if (body.isNotEmpty()) {
            body
        } else if (!senderName.isNullOrEmpty()) {
            if (language == "es") "De $senderName" else "From $senderName"
        } else {
            if (language == "es") "Tienes un nuevo mensaje" else "You have a new message"
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(GuardianNativeConfig.Notifications.EXTRA_OPEN_COMMUNITY_MESSAGES, true)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            documentId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(
            this,
            GuardianNativeConfig.Notifications.CHANNEL_COMMUNITY_MESSAGES,
        )
            .setContentTitle(contentTitle)
            .setContentText(summary)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            .setVibrate(
                longArrayOf(
                    0,
                    GuardianNativeConfig.Durations.COMMUNITY_MESSAGE_VIBRATE_MS,
                ),
            )
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle(contentTitle)
                    .bigText(if (body.isNotEmpty()) body else summary),
            )
            .build()

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(documentId.hashCode(), notification)
    }
    
    private fun showAlertNotification(
        alertType: String,
        description: String?,
        isAnonymous: Boolean,
        shareLocation: Boolean
    ) {
        val title = EmergencyTypes.getNotificationTitle(alertType)
        val body = EmergencyTypes.buildNotificationBody(alertType, description, isAnonymous, shareLocation)
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
            .setSound(resolveEmergencySoundUri())
            .setVibrate(GuardianNativeConfig.Vibration.EMERGENCY_PATTERN_MS)
            .setLights(
                GuardianNativeConfig.Notifications.ALERT_LIGHT_COLOR,
                GuardianNativeConfig.Durations.NOTIFICATION_LIGHT_FLASH_MS.toInt(),
                GuardianNativeConfig.Durations.NOTIFICATION_LIGHT_FLASH_MS.toInt(),
            )
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
    
    override fun onDestroy() {
        authStateListener?.let { auth.removeAuthStateListener(it) }
        stopAlertInboxListener()
        stopCommunityMessagesListener()
        isServiceRunning = false
        super.onDestroy()
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
