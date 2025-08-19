# 🔧 Servicio Nativo de Android - Notificación Persistente

## 🚨 **Problema Identificado**

Cuando se cerraba la aplicación en Android, la notificación persistente del background service también se cerraba, no se mantenía en el panel de notificaciones.

## 🔍 **Causa del Problema**

El `AndroidBackgroundService` de Flutter no era un verdadero **Foreground Service** nativo de Android, sino un servicio que dependía de la aplicación Flutter. Cuando la app se cerraba, el servicio también se detenía.

## ✅ **Solución Implementada**

### **1. Servicio Nativo de Android (`GuardianBackgroundService.kt`)**

```kotlin
class GuardianBackgroundService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_SERVICE" -> startForegroundService()
            "STOP_SERVICE" -> stopForegroundService()
        }
        return START_STICKY // El servicio se reiniciará si es eliminado
    }
    
    private fun startForegroundService() {
        // Crear notificación persistente
        val notification = createPersistentNotification()
        
        // Iniciar servicio en primer plano
        startForeground(NOTIFICATION_ID, notification)
        
        // Iniciar escucha de alertas de Firestore
        startAlertsListener()
    }
}
```

### **2. Características del Servicio Nativo:**

✅ **START_STICKY**: Se reinicia automáticamente si el sistema lo elimina
✅ **Foreground Service**: Mantiene la notificación persistente
✅ **Firestore Listener**: Escucha alertas directamente desde Firestore
✅ **Notificaciones Independientes**: Maneja notificaciones sin depender de Flutter
✅ **Vibración y Sonido**: Notificaciones con vibración y sonido personalizados

### **3. Comunicación Flutter-Nativo (`MethodChannel`)**

```kotlin
// MainActivity.kt
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
    when (call.method) {
        "startService" -> {
            val intent = Intent(this, GuardianBackgroundService::class.java).apply {
                action = "START_SERVICE"
            }
            startService(intent)
            result.success(true)
        }
        "stopService" -> {
            val intent = Intent(this, GuardianBackgroundService::class.java).apply {
                action = "STOP_SERVICE"
            }
            startService(intent)
            result.success(true)
        }
        "isServiceRunning" -> {
            result.success(GuardianBackgroundService.isRunning())
        }
    }
}
```

### **4. Servicio Flutter (`NativeBackgroundService.dart`)**

```dart
class NativeBackgroundService {
  static const MethodChannel _channel = MethodChannel('guardian_background_service');
  
  static Future<bool> startService() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final bool result = await _channel.invokeMethod('startService');
      return result;
    } on PlatformException catch (e) {
      return false;
    }
  }
}
```

## 🔧 **Archivos Modificados/Creados**

### **Nuevos Archivos:**
1. `android/app/src/main/kotlin/com/example/guardian/GuardianBackgroundService.kt`
   - Servicio nativo de Android
   - Foreground Service con notificación persistente
   - Listener de Firestore para alertas

2. `lib/services/native_background_service.dart`
   - Comunicación con el servicio nativo
   - Method channel para controlar el servicio

### **Archivos Modificados:**
1. `android/app/src/main/AndroidManifest.xml`
   - Agregado servicio nativo
   - Permisos de FOREGROUND_SERVICE

2. `android/app/src/main/kotlin/com/example/guardian/MainActivity.kt`
   - Method channel para comunicación
   - Control del servicio nativo

3. `lib/services/background/android_background_service.dart`
   - Usa el servicio nativo en lugar del servicio Flutter
   - Delegación de responsabilidades

## 🎯 **Comportamiento Final**

### **✅ Cuando la App está Abierta:**
- **HomeController**: Maneja notificaciones locales
- **BackgroundService**: Usa servicio nativo
- **Notificación Persistente**: Visible en panel

### **✅ Cuando la App está Cerrada:**
- **Servicio Nativo**: Sigue ejecutándose
- **Notificación Persistente**: Se mantiene en panel
- **Firestore Listener**: Sigue escuchando alertas
- **Notificaciones de Alerta**: Se muestran normalmente

### **✅ Cuando llega una Nueva Alerta:**
1. **Servicio Nativo** detecta la alerta en Firestore
2. **Crea notificación** con título, cuerpo, vibración y sonido
3. **Muestra notificación** en el panel de Android
4. **Usuario puede tocar** para abrir la app

## 🔧 **Permisos Requeridos**

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.INTERNET" />
```

## 🎉 **Beneficios**

✅ **Notificación Persistente**: Se mantiene aunque la app se cierre
✅ **Servicio Independiente**: No depende de la aplicación Flutter
✅ **Escucha Continua**: Siempre escucha nuevas alertas
✅ **Notificaciones Ricas**: Con vibración, sonido y acciones
✅ **Reinicio Automático**: Si el sistema elimina el servicio
✅ **Experiencia Nativa**: Comportamiento estándar de Android

## 🚀 **Resultado**

**¡Ahora la notificación persistente se mantiene en el panel de Android incluso cuando la aplicación está cerrada!**

El servicio nativo de Android garantiza que Guardian siga escuchando alertas y mostrando notificaciones de manera confiable, proporcionando una experiencia de usuario consistente y profesional.
