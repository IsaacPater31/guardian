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
        "casa" to EmergencyType(
            type = "casa",
            icon = "🏠",
            color = Color.parseColor("#66BB6A"),
            title = "casa",
        ),
        "policial" to EmergencyType(
            type = "policial",
            icon = "🚔",
            color = Color.parseColor("#1565C0"),
            title = "policial",
        ),
        "FIRE" to EmergencyType(
            type = "FIRE",
            icon = "🔥",
            color = Color.parseColor("#E53935"),
            title = "FIRE",
        ),
        "seguridad" to EmergencyType(
            type = "seguridad",
            icon = "🛡️",
            color = Color.parseColor("#C62828"),
            title = "seguridad",
        ),
        "vial" to EmergencyType(
            type = "vial",
            icon = "🚗",
            color = Color.parseColor("#FF7043"),
            title = "vial",
        ),
        "ambiental" to EmergencyType(
            type = "ambiental",
            icon = "🌿",
            color = Color.parseColor("#43A047"),
            title = "ambiental",
        ),
        "ACCOMPANIMENT" to EmergencyType(
            type = "ACCOMPANIMENT",
            icon = "👥",
            color = Color.parseColor("#8E24AA"),
            title = "ACCOMPANIMENT",
        ),
        "acoso" to EmergencyType(
            type = "acoso",
            icon = "✋",
            color = Color.parseColor("#7B1FA2"),
            title = "acoso",
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
        "up" to catalogTypes.getValue("casa"),
        "left" to catalogTypes.getValue("acoso"),
        "downLeft" to catalogTypes.getValue("seguridad"),
        "downRight" to catalogTypes.getValue("vial"),
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

data class EmergencyType(
    val type: String,
    val icon: String,
    val color: Int,
    val title: String,
)
