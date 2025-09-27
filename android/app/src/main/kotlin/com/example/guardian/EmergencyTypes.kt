package com.example.guardian

import android.graphics.Color

/**
 * Clase centralizada para manejar todos los tipos de emergencia en Android
 * Elimina la duplicación de datos entre GuardianBackgroundService y otros componentes
 */
object EmergencyTypes {
    
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
     * Obtiene el título de notificación por tipo de alerta
     */
    fun getNotificationTitle(alertType: String): String {
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
    
    /**
     * Construye el cuerpo de la notificación
     */
    fun buildNotificationBody(
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
