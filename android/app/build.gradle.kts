plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // Plugin de Firebase
    id("dev.flutter.flutter-gradle-plugin") // Este debe ir al final
}

android {
    namespace = "com.example.guardian"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // HABILITA DESUGARING
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.guardian"
        minSdk = 23 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // Puedes cambiar esto por uno de producción
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.2.0"))

    // Módulos de Firebase que usarás
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging")

    // WorkManager para tareas en segundo plano más robustas
    implementation("androidx.work:work-runtime-ktx:2.8.1")

    // AGREGAR ESTA LÍNEA PARA DESUGARING
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

}
