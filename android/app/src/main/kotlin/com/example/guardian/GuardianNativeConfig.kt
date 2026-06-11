package com.example.guardian

/**
 * Configuración central del código nativo Android (como un ".env" de Kotlin).
 *
 * Cambia valores aquí para ajustar vibración, tiempos, límites de Firestore,
 * notificaciones y WorkManager sin buscar números repartidos en otros .kt.
 *
 * Paridad Flutter: [lib/core/app_constants.dart]
 * Paridad web: [webapp/src/config/alertTypes.js]
 */
object GuardianNativeConfig {

    // ─── Tiempos (ms) ───────────────────────────────────────────────────────

    object Durations {
        /**
         * Vibración + pulso UI al recibir alerta pendiente.
         * Flutter: [AppDurations.activeAlertFeedback]
         * Web: [ACTIVE_ALERT_FEEDBACK_MS]
         */
        const val ACTIVE_ALERT_FEEDBACK_MS = 10_000L

        /** Ventana del listener de alertas en segundo plano (solo alertas recientes). */
        const val ALERTS_LISTENER_WINDOW_MS = 60 * 60 * 1000L

        /** Auto-cierre de la notificación de emergencia en la barra del sistema. */
        const val EMERGENCY_NOTIFICATION_TIMEOUT_MS = 30_000L

        /** Parpadeo del LED en notificaciones de alerta. */
        const val NOTIFICATION_LIGHT_FLASH_MS = 1_000L
    }

    // ─── Vibración ──────────────────────────────────────────────────────────

    object Vibration {
        /**
         * Patrón on/off en ms (el primer valor es pausa inicial).
         * Usado en canal de notificaciones, notificación y vibrador directo.
         */
        val EMERGENCY_PATTERN_MS = longArrayOf(
            0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000,
        )
    }

    // ─── Firestore ──────────────────────────────────────────────────────────

    object Firestore {
        const val COLLECTION_ALERTS = "alerts"
        const val COLLECTION_COMMUNITIES = "communities"
        const val COLLECTION_COMMUNITY_MEMBERS = "community_members"

        /** Máx. documentos en el listener — Flutter: [AppFirestoreLimits.recentAlerts] */
        const val RECENT_ALERTS_QUERY_LIMIT = 100L

        const val FIELD_ALERT_TYPE = "alertType"
        const val FIELD_TYPE = "type"
        const val FIELD_DESCRIPTION = "description"
        const val FIELD_IS_ANONYMOUS = "isAnonymous"
        const val FIELD_SHARE_LOCATION = "shareLocation"
        const val FIELD_USER_ID = "userId"
        const val FIELD_USER_EMAIL = "userEmail"
        const val FIELD_ALERT_STATUS = "alert_status"
        const val FIELD_VIEWED_BY = "viewedBy"
        const val FIELD_TIMESTAMP = "timestamp"
        const val FIELD_COMMUNITY_IDS = "community_ids"
        const val FIELD_COMMUNITY_ID = "community_id"
        const val FIELD_IS_ENTITY = "is_entity"
        const val FIELD_ROLE = "role"

        const val STATUS_ATTENDED = "attended"
        const val STATUS_PENDING = "pending"
        const val ROLE_OFFICIAL = "official"
        const val ROLE_MEMBER = "member"
    }

    // ─── Notificaciones ─────────────────────────────────────────────────────

    object Notifications {
        const val FOREGROUND_SERVICE_ID = 1001
        const val CHANNEL_SERVICE = "guardian_background_service"
        const val CHANNEL_ALERTS = "emergency_alerts"
        const val ALERT_LIGHT_COLOR = 0xFFD32F2F.toInt()
    }

    // ─── Servicio en segundo plano ──────────────────────────────────────────

    object Service {
        const val ACTION_START = "START_SERVICE"
        const val ACTION_STOP = "STOP_SERVICE"
    }

    // ─── WorkManager (reinicio del servicio) ────────────────────────────────

    object WorkManager {
        const val STARTER_WORK_NAME = "guardian_starter_worker"
        const val PERIODIC_INTERVAL_MINUTES = 15L
        const val INITIAL_DELAY_MINUTES = 1L
    }

    // ─── Idioma / preferencias ──────────────────────────────────────────────

    object Locale {
        const val DEFAULT_LANGUAGE = "es"
        const val PREFS_FLUTTER = "FlutterSharedPreferences"
        const val PREFS_NATIVE = "flutter_localization"
        const val KEY_LANGUAGE = "language"
        const val KEY_FLUTTER_SELECTED_LANGUAGE = "flutter.selected_language"
    }

    // ─── Method channels (Flutter ↔ Android) ────────────────────────────────

    object MethodChannels {
        const val BACKGROUND_SERVICE = "guardian_background_service"
        const val AUDIO_PREVIEW = "guardian/audio_preview"
    }
}
