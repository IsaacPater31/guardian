package com.example.guardian

import android.content.Context
import android.graphics.Color

/**
 * Tipos de emergencia alineados con [lib/core/alert_detail_catalog.dart] y
 * [lib/models/emergency_types.dart] (Firestore `alertType` y gesto radial).
 * Las notificaciones en segundo plano usan las mismas claves y títulos que la app.
 */
object EmergencyTypes {

    private var context: Context? = null

    fun initialize(context: Context) {
        this.context = context
    }

    /**
     * Catálogo canónico: claves = valor `alertType` en Firestore (mismo que Flutter).
     */
    val catalogTypes: Map<String, EmergencyType> = mapOf(
        "HEALTH" to EmergencyType(
            type = "HEALTH",
            icon = "🏥",
            color = Color.parseColor("#26C6DA"),
            title = "HEALTH",
        ),
        "HOME_HELP" to EmergencyType(
            type = "HOME_HELP",
            icon = "🏠",
            color = Color.parseColor("#66BB6A"),
            title = "HOME_HELP",
        ),
        "POLICE" to EmergencyType(
            type = "POLICE",
            icon = "🚔",
            color = Color.parseColor("#1565C0"),
            title = "POLICE",
        ),
        "FIRE" to EmergencyType(
            type = "FIRE",
            icon = "🔥",
            color = Color.parseColor("#E53935"),
            title = "FIRE",
        ),
        "SECURITY_BREACH" to EmergencyType(
            type = "SECURITY_BREACH",
            icon = "🛡️",
            color = Color.parseColor("#C62828"),
            title = "SECURITY_BREACH",
        ),
        "ROAD_EMERGENCY" to EmergencyType(
            type = "ROAD_EMERGENCY",
            icon = "🚗",
            color = Color.parseColor("#FF7043"),
            title = "ROAD_EMERGENCY",
        ),
        "ENVIRONMENTAL" to EmergencyType(
            type = "ENVIRONMENTAL",
            icon = "🌿",
            color = Color.parseColor("#43A047"),
            title = "ENVIRONMENTAL",
        ),
        "ACCOMPANIMENT" to EmergencyType(
            type = "ACCOMPANIMENT",
            icon = "👥",
            color = Color.parseColor("#8E24AA"),
            title = "ACCOMPANIMENT",
        ),
        "HARASSMENT" to EmergencyType(
            type = "HARASSMENT",
            icon = "🛡️",
            color = Color.parseColor("#EC407A"),
            title = "HARASSMENT",
        ),
        "URGENCY" to EmergencyType(
            type = "URGENCY",
            icon = "🚨",
            color = Color.parseColor("#F44336"),
            title = "URGENCY",
        ),
    )

    /**
     * Gesto radial (5 direcciones) + centro toque rápido — misma asignación que
     * [EmergencyTypes.radialDirectionToType] en Dart.
     */
    val types: Map<String, EmergencyType> = mapOf(
        "up" to catalogTypes.getValue("HOME_HELP"),
        "left" to catalogTypes.getValue("HARASSMENT"),
        "downLeft" to catalogTypes.getValue("SECURITY_BREACH"),
        "downRight" to catalogTypes.getValue("ROAD_EMERGENCY"),
        "right" to catalogTypes.getValue("HEALTH"),
        "center" to catalogTypes.getValue("URGENCY"),
    )

    fun getTypeByDirection(direction: String): EmergencyType? = types[direction]

    /**
     * Resuelve por `alertType` de Firestore; acepta alias heredados.
     */
    fun getTypeByName(typeName: String): EmergencyType? {
        val key = normalizeAliasToCanonicalKey(typeName)
        return catalogTypes[key]
    }

    private fun getCurrentLanguage(): String {
        val ctx = context ?: return "es"
        return try {
            val flutterPrefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            var lang = flutterPrefs.getString("flutter.selected_language", null)
            if (lang == null) {
                for (k in flutterPrefs.all.keys) {
                    if (k.contains("selected_language")) {
                        lang = flutterPrefs.getString(k, null)
                        break
                    }
                }
            }
            if (lang != null) {
                ctx.getSharedPreferences("flutter_localization", Context.MODE_PRIVATE)
                    .edit().putString("language", lang).apply()
                return lang
            }
            ctx.getSharedPreferences("flutter_localization", Context.MODE_PRIVATE)
                .getString("language", "es") ?: "es"
        } catch (_: Exception) {
            "es"
        }
    }

    /**
     * Misma lógica que [AlertModel.fromFirestore]: quick + HEALTH antiguo → URGENCY.
     * Unifica alias viejos (p. ej. vial) con claves actuales.
     */
    fun normalizeAlertTypeForNotification(alertType: String, flowType: String): String {
        var t = alertType.trim()
        if (flowType == "quick" && t == "HEALTH") return "URGENCY"
        t = when (t) {
            "VIAL EMERGENCY" -> "ROAD_EMERGENCY"
            else -> t
        }
        return t
    }

    private fun normalizeAliasToCanonicalKey(typeName: String): String {
        val t = typeName.trim()
        if (t == "VIAL EMERGENCY") return "ROAD_EMERGENCY"
        return t
    }

    private val spanishTitles = mapOf(
        "HEALTH" to "🏥 Sanitaria",
        "HOME_HELP" to "🏠 Ayuda en casa",
        "POLICE" to "🚔 Policía",
        "FIRE" to "🔥 Bomberos",
        "SECURITY_BREACH" to "🛡️ Brecha de seguridad",
        "ROAD_EMERGENCY" to "🚗 Emergencia vial",
        "ENVIRONMENTAL" to "🌿 Ambiental",
        "ACCOMPANIMENT" to "👥 Acompañamiento",
        "HARASSMENT" to "🛡️ Acoso",
        "URGENCY" to "🚨 Urgencia",
        // Legacy / datos antiguos en Firestore (conviven con clientes viejos)
        "ROBBERY" to "🚨 Robo reportado",
        "ACCIDENT" to "🚗 Accidente reportado",
        "UNSAFETY" to "⚠️ Zona insegura",
        "PHYSICAL RISK" to "🚨 Riesgo físico",
        "PUBLIC SERVICES EMERGENCY" to "🏗️ Emergencia servicios públicos",
        "STREET ESCORT" to "👥 Acompañamiento solicitado",
        "ASSISTANCE" to "🆘 Asistencia necesaria",
        "EMERGENCY" to "🚨 Emergencia general",
        "VIAL EMERGENCY" to "🚗 Emergencia vial",
    )

    private val englishTitles = mapOf(
        "HEALTH" to "🏥 Health emergency",
        "HOME_HELP" to "🏠 Home help",
        "POLICE" to "🚔 Police",
        "FIRE" to "🔥 Firefighters",
        "SECURITY_BREACH" to "🛡️ Security breach",
        "ROAD_EMERGENCY" to "🚗 Road emergency",
        "ENVIRONMENTAL" to "🌿 Environmental",
        "ACCOMPANIMENT" to "👥 Accompaniment",
        "HARASSMENT" to "🛡️ Harassment",
        "URGENCY" to "🚨 Urgency",
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

data class EmergencyType(
    val type: String,
    val icon: String,
    val color: Int,
    val title: String,
)
