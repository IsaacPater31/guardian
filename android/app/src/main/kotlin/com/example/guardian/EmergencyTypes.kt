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
        return context?.let { ctx ->
            val prefs = ctx.getSharedPreferences("flutter_localization", Context.MODE_PRIVATE)
            prefs.getString("language", "es") ?: "es"
        } ?: "es"
    }
    
    /**
     * Títulos en español
     */
    private val spanishTitles = mapOf(
        "ROBBERY" to "🚨 Robo Reportado",
        "FIRE" to "🔥 Incendio Reportado",
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
        "ROBBERY" to "🚨 Robbery Reported",
        "FIRE" to "🔥 Fire Reported",
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
        
        // Agregar descripción
        if (!description.isNullOrEmpty()) {
            body.append(description)
        }
        
        // Agregar información adicional según idioma
        if (shareLocation) {
            val locationText = if (language == "es") "📍 Ubicación incluida" else "📍 Location included"
            body.append("\n").append(locationText)
        }
        
        if (isAnonymous) {
            val anonymousText = if (language == "es") "👤 Reporte anónimo" else "👤 Anonymous report"
            body.append("\n").append(anonymousText)
        }
        
        return body.toString()
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
