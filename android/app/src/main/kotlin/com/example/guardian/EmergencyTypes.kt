package com.example.guardian

import android.content.Context

/**
 * Tipos de emergencia alineados con [lib/core/alert_detail_catalog.dart] y
 * [lib/models/emergency_types.dart] (Firestore `alertType`).
 * Las notificaciones en segundo plano usan las mismas claves y títulos que la app.
 */
object EmergencyTypes {

    private var context: Context? = null

    fun initialize(context: Context) {
        this.context = context
    }

    private fun getCurrentLanguage(): String {
        val ctx = context ?: return GuardianNativeConfig.Locale.DEFAULT_LANGUAGE
        return LocaleHelper.getCurrentLanguage(ctx)
    }

    /**
     * Misma lógica que [AlertModel.fromFirestore]: quick + HEALTH antiguo → URGENCY.
     * Unifica alias viejos con claves cortas actuales.
     */
    fun normalizeAlertTypeForNotification(alertType: String, flowType: String): String {
        var t = alertType.trim()
        if (flowType == "quick" && t == "HEALTH") return "URGENCY"
        return normalizeAliasToCanonicalKey(t)
    }

    private fun normalizeAliasToCanonicalKey(typeName: String): String {
        val t = typeName.trim()
        return when (t) {
            "HOME_HELP" -> "casa"
            "SECURITY_BREACH" -> "seguridad"
            "ROAD_EMERGENCY" -> "vial"
            "HARASSMENT" -> "acoso"
            "ENVIRONMENTAL" -> "ambiental"
            "POLICE" -> "policial"
            "VIAL EMERGENCY" -> "vial"
            else -> t
        }
    }

    private val spanishTitles = mapOf(
        "HEALTH" to "🏥 Sanitaria",
        "casa" to "🏠 Casa",
        "policial" to "🚔 Policial",
        "FIRE" to "🔥 Bomberos",
        "seguridad" to "🛡️ Seguridad",
        "vial" to "🚗 Vial",
        "ambiental" to "🌿 Ambiental",
        "ACCOMPANIMENT" to "👥 Acompañamiento",
        "acoso" to "✋ Acoso",
        "URGENCY" to "🚨 Urgencia",
        // Legacy / datos antiguos en Firestore
        "HOME_HELP" to "🏠 Casa",
        "POLICE" to "🚔 Policial",
        "SECURITY_BREACH" to "🛡️ Seguridad",
        "ROAD_EMERGENCY" to "🚗 Vial",
        "ENVIRONMENTAL" to "🌿 Ambiental",
        "HARASSMENT" to "✋ Acoso",
        "ROBBERY" to "🚨 Robo reportado",
        "ACCIDENT" to "🚗 Accidente reportado",
        "UNSAFETY" to "⚠️ Zona insegura",
        "PHYSICAL RISK" to "🚨 Riesgo físico",
        "PUBLIC SERVICES EMERGENCY" to "🏗️ Emergencia servicios públicos",
        "STREET ESCORT" to "👥 Acompañamiento solicitado",
        "ASSISTANCE" to "🆘 Asistencia necesaria",
        "EMERGENCY" to "🚨 Emergencia general",
        "VIAL EMERGENCY" to "🚗 Vial",
    )

    private val englishTitles = mapOf(
        "HEALTH" to "🏥 Health",
        "casa" to "🏠 Home",
        "policial" to "🚔 Police",
        "FIRE" to "🔥 Firefighters",
        "seguridad" to "🛡️ Security",
        "vial" to "🚗 Road",
        "ambiental" to "🌿 Environmental",
        "ACCOMPANIMENT" to "👥 Accompaniment",
        "acoso" to "✋ Harassment",
        "URGENCY" to "🚨 Urgency",
        "HOME_HELP" to "🏠 Home",
        "POLICE" to "🚔 Police",
        "SECURITY_BREACH" to "🛡️ Security breach",
        "ROAD_EMERGENCY" to "🚗 Road emergency",
        "ENVIRONMENTAL" to "🌿 Environmental",
        "HARASSMENT" to "✋ Harassment",
        "ROBBERY" to "🚨 Robbery reported",
        "ACCIDENT" to "🚗 Accident reported",
        "UNSAFETY" to "⚠️ Unsafe area",
        "PHYSICAL RISK" to "🚨 Physical risk",
        "PUBLIC SERVICES EMERGENCY" to "🏗️ Public services emergency",
        "STREET ESCORT" to "👥 Street escort requested",
        "ASSISTANCE" to "🆘 Assistance needed",
        "EMERGENCY" to "🚨 General emergency",
        "VIAL EMERGENCY" to "🚗 Traffic emergency",
    )

    fun getNotificationTitle(alertType: String): String {
        val language = getCurrentLanguage()
        val titles = if (language == "es") spanishTitles else englishTitles
        val key = normalizeAliasToCanonicalKey(alertType)
        return titles[key]
            ?: titles[alertType.trim()]
            ?: if (language == "es") "🚨 Alerta de emergencia" else "🚨 Emergency alert"
    }

    fun buildNotificationBody(
        alertType: String,
        description: String?,
        isAnonymous: Boolean,
        shareLocation: Boolean,
    ): String {
        val language = getCurrentLanguage()
        val body = StringBuilder()

        if (!description.isNullOrEmpty()) {
            body.append(description.trim())
        }

        if (shareLocation) {
            val locationText = if (language == "es") "📍 Ubicación compartida" else "📍 Location shared"
            if (body.isNotEmpty()) body.append("\n")
            body.append(locationText)
        }

        if (isAnonymous) {
            val anonymousText = if (language == "es") "👤 Reporte anónimo" else "👤 Anonymous report"
            if (body.isNotEmpty()) body.append("\n")
            body.append(anonymousText)
        }

        return body.toString().trim()
    }

    fun buildNotificationSummary(
        description: String?,
        isAnonymous: Boolean,
        shareLocation: Boolean,
    ): String {
        val language = getCurrentLanguage()
        val parts = mutableListOf<String>()
        if (!description.isNullOrBlank()) {
            val oneLine = description.trim().replace("\n", " ")
            parts.add(if (oneLine.length > 80) oneLine.take(77) + "…" else oneLine)
        }
        if (shareLocation) {
            parts.add(if (language == "es") "📍 Ubicación" else "📍 Location")
        }
        if (isAnonymous) {
            parts.add(if (language == "es") "👤 Anónimo" else "👤 Anonymous")
        }
        if (parts.isEmpty()) {
            return if (language == "es") "Toca para ver detalles" else "Tap to view details"
        }
        return parts.joinToString(" · ")
    }
}
