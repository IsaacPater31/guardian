package com.example.guardian

import android.content.Context

/** Lectura unificada del idioma activo (Flutter → prefs nativas). */
object LocaleHelper {
    fun getCurrentLanguage(context: Context): String {
        return try {
            val locale = GuardianNativeConfig.Locale
            val flutterPrefs = context.getSharedPreferences(
                locale.PREFS_FLUTTER,
                Context.MODE_PRIVATE,
            )
            var lang = flutterPrefs.getString(locale.KEY_FLUTTER_SELECTED_LANGUAGE, null)
            if (lang == null) {
                for (key in flutterPrefs.all.keys) {
                    if (key.contains("selected_language")) {
                        lang = flutterPrefs.getString(key, null)
                        break
                    }
                }
            }
            if (lang != null) {
                context.getSharedPreferences(locale.PREFS_NATIVE, Context.MODE_PRIVATE)
                    .edit()
                    .putString(locale.KEY_LANGUAGE, lang)
                    .apply()
                return lang
            }
            context.getSharedPreferences(locale.PREFS_NATIVE, Context.MODE_PRIVATE)
                .getString(locale.KEY_LANGUAGE, locale.DEFAULT_LANGUAGE)
                ?: locale.DEFAULT_LANGUAGE
        } catch (_: Exception) {
            GuardianNativeConfig.Locale.DEFAULT_LANGUAGE
        }
    }
}
