package com.example.guardian

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import androidx.core.app.NotificationCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import com.google.firebase.auth.FirebaseAuth
import java.lang.ref.WeakReference

class GuardianBackgroundService : Service() {
    
    companion object {
        private var isServiceRunning = false
        private const val PREFS_NOTIFIED_MESSAGES = "guardian_notified_messages"
        private val LISTENER_RETRY_DELAYS_MS = longArrayOf(1_000L, 2_000L, 5_000L, 10_000L)

        @Volatile
        private var appInForeground = false

        @Volatile
        private var instanceRef: WeakReference<GuardianBackgroundService>? = null

        fun isRunning(): Boolean = isServiceRunning

        fun setAppInForeground(foreground: Boolean) {
            appInForeground = foreground
            println("📱 App foreground: $foreground")
            // FlutterFire terminates default Firestore on engine teardown/reinit.
            // When UI is back, force-reattach so soft membership notifies work again.
            if (foreground) {
                instanceRef?.get()?.forceRefreshListeners("app foreground")
            }
        }

        /** Re-bind inbox listeners after Flutter has reinitialized Firestore. */
        fun requestListenerRefresh(reason: String) {
            instanceRef?.get()?.forceRefreshListeners(reason)
        }
    }
    
    private lateinit var firestore: FirebaseFirestore
    private var alertInboxListener: ListenerRegistration? = null
    private var alertInboxInitialSnapshot = true
    private var communityMessagesListener: ListenerRegistration? = null
    private var communityMessagesInitialSnapshot = true
    private var authStateListener: FirebaseAuth.AuthStateListener? = null
    /** Separate UIDs so alert vs message listeners cannot skip each other on auth switch. */
    private var lastAlertInboxUserId: String? = null
    private var lastCommunityMessagesUserId: String? = null
    private lateinit var auth: FirebaseAuth
    private val mainHandler = Handler(Looper.getMainLooper())
    private var listenerRetryAttempt = 0
    private val listenerRetryRunnable = Runnable {
        if (!isServiceRunning) return@Runnable
        println("🔁 Retrying Firestore inbox listeners (attempt ${listenerRetryAttempt + 1})")
        ensureAlertInboxListener()
        ensureCommunityMessagesListener()
        val alertsOk = alertInboxListener != null
        val messagesOk = communityMessagesListener != null
        if (alertsOk && messagesOk) {
            listenerRetryAttempt = 0
            return@Runnable
        }
        scheduleListenerRetry()
    }
    
    override fun onCreate() {
        super.onCreate()
        instanceRef = WeakReference(this)
        firestore = firestoreForBackgroundService()
        auth = FirebaseAuth.getInstance()
        createNotificationChannels()
        
        // Inicializar EmergencyTypes con el contexto
        EmergencyTypes.initialize(this)

        authStateListener = FirebaseAuth.AuthStateListener {
            if (!isServiceRunning) return@AuthStateListener
            val uid = auth.currentUser?.uid
            val sameUser = uid != null &&
                uid == lastAlertInboxUserId &&
                uid == lastCommunityMessagesUserId &&
                alertInboxListener != null &&
                communityMessagesListener != null
            if (sameUser) return@AuthStateListener
            println("🔐 Auth user changed — refreshing inbox listeners")
            if (uid == null) {
                stopAlertInboxListener()
                stopCommunityMessagesListener()
                lastAlertInboxUserId = null
                lastCommunityMessagesUserId = null
            } else {
                ensureAlertInboxListener()
                ensureCommunityMessagesListener()
            }
        }
        auth.addAuthStateListener(authStateListener!!)
    }

    /** Fresh Firestore for the service — never the Flutter-default instance. */
    private fun refreshFirestoreClient() {
        firestore = firestoreForBackgroundService()
    }

    /**
     * Dedicated FirebaseApp so FlutterFire's didReinitializeFirebaseCore()
     * (terminates default Firestore on engine restart) cannot kill our listeners.
     * Auth UID still comes from the default [auth] instance.
     */
    private fun firestoreForBackgroundService(): FirebaseFirestore {
        val appName = GuardianNativeConfig.Firebase.BACKGROUND_APP_NAME
        val app = try {
            FirebaseApp.getInstance(appName)
        } catch (_: IllegalStateException) {
            val options = FirebaseApp.getInstance().options
            FirebaseApp.initializeApp(applicationContext, options, appName)
                ?: FirebaseApp.getInstance(appName)
        }
        println("🔥 Service Firestore app=${app.name}")
        return FirebaseFirestore.getInstance(app)
    }

    private fun isTerminatedClientError(error: Any?): Boolean {
        val msg = when (error) {
            is Exception -> error.message
            else -> error?.toString()
        } ?: return false
        return msg.contains("terminated", ignoreCase = true)
    }

    private fun scheduleListenerRetry() {
        if (!isServiceRunning) return
        if (listenerRetryAttempt >= LISTENER_RETRY_DELAYS_MS.size) {
            println("⚠️ Exhausted Firestore listener retries — will retry on next foreground")
            listenerRetryAttempt = 0
            return
        }
        val delay = LISTENER_RETRY_DELAYS_MS[listenerRetryAttempt]
        listenerRetryAttempt += 1
        mainHandler.removeCallbacks(listenerRetryRunnable)
        mainHandler.postDelayed(listenerRetryRunnable, delay)
    }

    private fun forceRefreshListeners(reason: String) {
        if (!isServiceRunning) return
        println("🔄 Force refresh inbox listeners ($reason)")
        mainHandler.removeCallbacks(listenerRetryRunnable)
        listenerRetryAttempt = 0
        stopAlertInboxListener()
        stopCommunityMessagesListener()
        lastAlertInboxUserId = null
        lastCommunityMessagesUserId = null
        ensureAlertInboxListener()
        ensureCommunityMessagesListener()
        if (alertInboxListener == null || communityMessagesListener == null) {
            scheduleListenerRetry()
        }
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
        if (alertInboxListener == null || communityMessagesListener == null) {
            scheduleListenerRetry()
        }
    }

    private fun shouldDeliverNativeNotification(softChannel: Boolean = false): Boolean {
        // Soft channel (messages / membership): always notify — including foreground.
        if (softChannel) return true
        if (appInForeground) {
            println("📱 App en primer plano — alerta nativa omitida (Flutter maneja UI)")
            return false
        }
        return true
    }

    private fun ensureAlertInboxListener() {
        val uid = auth.currentUser?.uid ?: return
        if (alertInboxListener != null && lastAlertInboxUserId == uid) return
        stopAlertInboxListener()
        lastAlertInboxUserId = uid
        startAlertInboxListener()
    }

    private fun ensureCommunityMessagesListener() {
        val uid = auth.currentUser?.uid ?: return
        if (communityMessagesListener != null && lastCommunityMessagesUserId == uid) return
        stopCommunityMessagesListener()
        lastCommunityMessagesUserId = uid
        startCommunityMessagesListener()
    }
    
    private fun stopForegroundService() {
        if (!isServiceRunning) return
        
        // Detener escuchas
        stopAlertInboxListener()
        stopCommunityMessagesListener()
        lastAlertInboxUserId = null
        lastCommunityMessagesUserId = null
        
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
                NotificationManager.IMPORTANCE_DEFAULT,
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
        refreshFirestoreClient()
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
                        if (isTerminatedClientError(error)) {
                            alertInboxListener = null
                            lastAlertInboxUserId = null
                            scheduleListenerRetry()
                        }
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
                            if (change.type != com.google.firebase.firestore.DocumentChange.Type.ADDED &&
                                change.type != com.google.firebase.firestore.DocumentChange.Type.MODIFIED
                            ) {
                                return@forEach
                            }
                            val docId = change.document.id
                            if (isAlertAlreadyNotified(docId)) return@forEach
                            val data = change.document.data ?: return@forEach
                            if (shouldSkipInboxAlert(data)) {
                                markAlertNotified(docId)
                                return@forEach
                            }
                            val createdAt = data[fs.FIELD_CREATED_AT] as? com.google.firebase.Timestamp
                            if (createdAt == null) return@forEach
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
            lastAlertInboxUserId = null
            if (isTerminatedClientError(e)) {
                scheduleListenerRetry()
            }
        }
    }

    private fun stopAlertInboxListener() {
        try {
            alertInboxListener?.remove()
        } catch (e: Exception) {
            println("⚠️ stopAlertInboxListener: ${e.message}")
        }
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

    private fun messageNotifiedKey(docId: String): String {
        val uid = auth.currentUser?.uid ?: "anon"
        return "msg_${uid}_$docId"
    }

    private fun isMessageAlreadyNotified(docId: String): Boolean =
        messageNotifiedPrefs().getBoolean(messageNotifiedKey(docId), false)

    private fun markMessageNotified(docId: String) {
        messageNotifiedPrefs().edit().putBoolean(messageNotifiedKey(docId), true).apply()
    }

    private fun startCommunityMessagesListener() {
        val currentUser = auth.currentUser
        if (currentUser == null) {
            println("⚠️ No user logged in, skipping community messages listener")
            return
        }

        communityMessagesInitialSnapshot = true
        refreshFirestoreClient()

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
                        if (isTerminatedClientError(error)) {
                            communityMessagesListener = null
                            lastCommunityMessagesUserId = null
                            scheduleListenerRetry()
                        }
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
                                if (data == null || isMessageAlreadyNotified(doc.id)) {
                                    return@forEach
                                }
                                if (shouldSkipCommunityMessage(data, doc.id)) {
                                    markMessageNotified(doc.id)
                                    return@forEach
                                }
                                val createdAt = data[fs.FIELD_CREATED_AT] as? com.google.firebase.Timestamp
                                if (createdAt == null) {
                                    println("⏳ Skip mark (null created_at): ${doc.id}")
                                    return@forEach
                                }
                                val ageMs = now - createdAt.toDate().time
                                val kind = (data["kind"] as? String)?.trim().orEmpty()
                                val isMembership = kind == "member_added" ||
                                    kind == "member_removed" ||
                                    kind == "member_left" ||
                                    kind == "role_changed"
                                // Membership events: notify if unread within a wider window.
                                // Allow small negative age (web/device clock skew).
                                val window = if (isMembership) {
                                    startupWindow * 4
                                } else {
                                    startupWindow
                                }
                                if (ageMs in -60_000L..window) {
                                    if (deliverCommunityMessageNotification(data, doc.id)) {
                                        markMessageNotified(doc.id)
                                    }
                                } else {
                                    markMessageNotified(doc.id)
                                }
                            }
                            return@addSnapshotListener
                        }

                        snapshot.documentChanges.forEach { change ->
                            // ADDED = new doc; MODIFIED covers serverTimestamp resolve /
                            // docs that enter the orderBy query after created_at is set.
                            if (change.type != com.google.firebase.firestore.DocumentChange.Type.ADDED &&
                                change.type != com.google.firebase.firestore.DocumentChange.Type.MODIFIED
                            ) {
                                return@forEach
                            }
                            val docId = change.document.id
                            if (isMessageAlreadyNotified(docId)) return@forEach
                            val data = change.document.data ?: return@forEach
                            if (shouldSkipCommunityMessage(data, docId)) {
                                markMessageNotified(docId)
                                return@forEach
                            }
                            // Wait until created_at exists (orderBy-ready).
                            val createdAt = data[fs.FIELD_CREATED_AT] as? com.google.firebase.Timestamp
                            if (createdAt == null) return@forEach
                            if (deliverCommunityMessageNotification(data, docId)) {
                                markMessageNotified(docId)
                            }
                        }
                    } catch (e: Exception) {
                        println("❌ Community message handler error (non-fatal): ${e.message}")
                    }
                }
            println("💬 Community messages listener attached for user ${currentUser.uid}")
        } catch (e: Exception) {
            println("❌ Failed to start community messages listener (non-fatal): ${e.message}")
            communityMessagesListener = null
            lastCommunityMessagesUserId = null
            if (isTerminatedClientError(e)) {
                scheduleListenerRetry()
            }
        }
    }

    private fun stopCommunityMessagesListener() {
        try {
            communityMessagesListener?.remove()
        } catch (e: Exception) {
            println("⚠️ stopCommunityMessagesListener: ${e.message}")
        }
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

        val kind = (data["kind"] as? String)?.trim().orEmpty()
        val isMembershipEvent = kind == "member_added" ||
            kind == "member_removed" ||
            kind == "member_left" ||
            kind == "role_changed"

        // Own broadcasts: skip native notify (still in Flutter feed).
        // Membership events must always reach the affected user.
        val senderId = data[fs.FIELD_SENDER_ID] as? String
        if (!isMembershipEvent && senderId != null && senderId == currentUser.uid) {
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

    /** @return true if a system notification was posted */
    private fun deliverCommunityMessageNotification(data: Map<String, Any>, documentId: String): Boolean {
        if (!shouldDeliverNativeNotification(softChannel = true)) return false

        val fs = GuardianNativeConfig.Firestore
        val title = (data[fs.FIELD_MESSAGE_TITLE] as? String)?.trim().orEmpty()
        val body = (data[fs.FIELD_MESSAGE_BODY] as? String)?.trim().orEmpty()
        val senderName = (data[fs.FIELD_SENDER_NAME] as? String)?.trim()
        val communityName = (data["community_name"] as? String)?.trim()
        val isEntity = data["is_entity"] == true
        return try {
            showCommunityMessageNotification(
                title,
                body,
                senderName,
                communityName,
                documentId,
                isEntity = isEntity,
            )
            println("💬 Community message notification sent: $documentId")
            true
        } catch (e: Exception) {
            println("❌ Failed to show community message notification: ${e.message}")
            false
        }
    }

    private fun showCommunityMessageNotification(
        title: String,
        body: String,
        senderName: String?,
        communityName: String?,
        documentId: String,
        isEntity: Boolean = false,
    ) {
        val language = LocaleHelper.getCurrentLanguage(this)
        val defaultTitle = when {
            isEntity && language == "es" -> "Mensaje de tu reporte"
            isEntity -> "Message from your report"
            language == "es" -> "Mensaje de tu comunidad"
            else -> "Message from your community"
        }
        val contentTitle = if (title.isNotEmpty()) title else defaultTitle
        val communityLine = if (!communityName.isNullOrEmpty()) {
            when {
                isEntity && language == "es" -> "Reporte: $communityName"
                isEntity -> "Report: $communityName"
                language == "es" -> "Comunidad: $communityName"
                else -> "Community: $communityName"
            }
        } else {
            null
        }
        val summary = when {
            body.isNotEmpty() && communityLine != null -> "$communityLine\n$body"
            body.isNotEmpty() -> body
            communityLine != null -> communityLine
            !senderName.isNullOrEmpty() -> {
                if (language == "es") "De $senderName" else "From $senderName"
            }
            else -> {
                if (language == "es") "Tienes una nueva notificación" else "You have a new notification"
            }
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
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
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
                    .bigText(summary),
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
        mainHandler.removeCallbacks(listenerRetryRunnable)
        if (instanceRef?.get() === this) {
            instanceRef = null
        }
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
