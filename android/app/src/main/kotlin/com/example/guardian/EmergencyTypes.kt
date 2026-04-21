package com.example.guardian

import android.content.Context
import android.graphics.Color

/**
 * Clase centralizada para manejar todos los tipos de emergencia en Android
 * Elimina la duplicación de datos entre GuardianBackgroundService y otros componentes
 */
object EmergencyTypes {
    
    private var context: Context? = null
    
    fun initialize(context: Context) {
        this.context = context
    }
    
    /**
     * Mapa con todos los tipos de emergencia y sus configuraciones
     */
    val types = mapOf(
        "up" to EmergencyType(
            type = "STREET ESCORT",
            icon = "👥",
            color = Color.BLUE,
            title = "👥 Acompañamiento Solicitado"
        ),
        "upLeft" to EmergencyType(
            type = "ROBBERY",
            icon = "🚨",
            color = Color.RED,
            title = "🚨 Robo Reportado"
        ),
        "left" to EmergencyType(
            type = "UNSAFETY",
            icon = "⚠️",
            color = Color.parseColor("#FF9800"), // Orange
            title = "⚠️ Zona Insegura"
        ),
        "downLeft" to EmergencyType(
            type = "PHYSICAL RISK",
            icon = "🚨",
            color = Color.parseColor("#9C27B0"), // Purple
            title = "🚨 Riesgo Físico"
        ),
        "down" to EmergencyType(
            type = "PUBLIC SERVICES EMERGENCY",
            icon = "🏗️",
            color = Color.parseColor("#FFC107"), // Yellow
            title = "🏗️ Emergencia Servicios Públicos"
        ),
        "downRight" to EmergencyType(
            type = "VIAL EMERGENCY",
            icon = "🚦",
            color = Color.parseColor("#00BCD4"), // Cyan
            title = "🚦 Emergencia Vial"
        ),
        "right" to EmergencyType(
            type = "ASSISTANCE",
            icon = "🆘",
            color = Color.parseColor("#4CAF50"), // Green
            title = "🆘 Asistencia Necesaria"
        ),
        "upRight" to EmergencyType(
            type = "FIRE",
            icon = "🔥",
            color = Color.parseColor("#F44336"), // Red
            title = "🔥 Incendio Reportado"
        ),
        "center" to EmergencyType(
            type = "EMERGENCY",
            icon = "🚨",
            color = Color.parseColor("#E91E63"), // Pink
            title = "🚨 Emergencia General"
        )
    )
    
    /**
     * Obtiene el tipo de emergencia por dirección del gesto
     */
    fun getTypeByDirection(direction: String): EmergencyType? {
        return types[direction]
    }
    
    /**
     * Obtiene el tipo de emergencia por nombre
     */
    fun getTypeByName(typeName: String): EmergencyType? {
        return types.values.find { it.type == typeName }
    }
    
    /**
     * Función para obtener el idioma actual
     */
    private fun getCurrentLanguage(): String {
        val ctx = context ?: return "es"
        return try {
            val flutterPrefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            var lang = flutterPrefs.getString("flutter.selected_language", null)
            if (lang == null) {
                for (key in flutterPrefs.all.keys) {
                    if (key.contains("selected_language")) {
                        lang = flutterPrefs.getString(key, null)
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
     * Títulos en español
     */
    private val spanishTitles = mapOf(
        "HEALTH" to "🏥 Alerta sanitaria",
        "HOME_HELP" to "🏠 Ayuda en casa",
        "POLICE" to "🚔 Policía",
        "FIRE" to "🔥 Bomberos / incendio",
        "ACCOMPANIMENT" to "👥 Acompañamiento",
        "ENVIRONMENTAL" to "🌿 Emergencia ambiental",
        "ROAD_EMERGENCY" to "🚗 Emergencia vial",
        "URGENCY" to "🚨 Urgencia",
        "HARASSMENT" to "🛡️ Acoso",
        "ROBBERY" to "🚨 Robo Reportado",
        "ACCIDENT" to "🚗 Accidente Reportado",
        "STREET ESCORT" to "👥 Acompañamiento Solicitado",
        "UNSAFETY" to "⚠️ Zona Insegura",
        "PHYSICAL RISK" to "🚨 Riesgo Físico",
        "PUBLIC SERVICES EMERGENCY" to "🏗️ Emergencia Servicios Públicos",
        "VIAL EMERGENCY" to "🚦 Emergencia Vial",
        "ASSISTANCE" to "🆘 Asistencia Necesaria",
        "EMERGENCY" to "🚨 Emergencia General"
    )
    
    /**
     * Títulos en inglés
     */
    private val englishTitles = mapOf(
        "HEALTH" to "🏥 Health emergency",
        "HOME_HELP" to "🏠 Home help",
        "POLICE" to "🚔 Police",
        "FIRE" to "🔥 Fire department",
        "ACCOMPANIMENT" to "👥 Escort / accompaniment",
        "ENVIRONMENTAL" to "🌿 Environmental emergency",
        "ROAD_EMERGENCY" to "🚗 Road emergency",
        "URGENCY" to "🚨 Urgency",
        "HARASSMENT" to "🛡️ Harassment",
        "ROBBERY" to "🚨 Robbery Reported",
        "ACCIDENT" to "🚗 Accident Reported",
        "STREET ESCORT" to "👥 Street Escort Requested",
        "UNSAFETY" to "⚠️ Unsafe Area",
        "PHYSICAL RISK" to "🚨 Physical Risk",
        "PUBLIC SERVICES EMERGENCY" to "🏗️ Public Services Emergency",
        "VIAL EMERGENCY" to "🚦 Traffic Emergency",
        "ASSISTANCE" to "🆘 Assistance Needed",
        "EMERGENCY" to "🚨 General Emergency"
    )
    
    /**
     * Obtiene el título de notificación por tipo de alerta
     */
    fun getNotificationTitle(alertType: String): String {
        val language = getCurrentLanguage()
        val titles = if (language == "es") spanishTitles else englishTitles
        return titles[alertType] ?: if (language == "es") "🚨 Alerta de Emergencia" else "🚨 Emergency Alert"
    }
    
    /**
     * Construye el cuerpo de la notificación
     */
    fun buildNotificationBody(
        alertType: String,
        description: String?,
        isAnonymous: Boolean,
        shareLocation: Boolean
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

    /** Short single-line summary for collapsed notification view. */
    fun buildNotificationSummary(
        description: String?,
        isAnonymous: Boolean,
        shareLocation: Boolean
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

/**
 * Clase de datos para representar un tipo de emergencia
 */
data class EmergencyType(
    val type: String,
    val icon: String,
    val color: Int,
    val title: String
)
