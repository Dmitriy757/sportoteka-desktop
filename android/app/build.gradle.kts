plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // важно!
}

android {
    namespace = "com.example.sportoteka"
    compileSdk = 36
    ndkVersion = "27.0.12077973"
    externalNativeBuild {
    cmake {
        version = "3.31.1"
    }
}

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions { jvmTarget = "11" }

    defaultConfig {
    applicationId = "com.example.sportoteka"
    minSdk = 22
    targetSdk = 36
    versionCode = flutter.versionCode.toInt()
    versionName = flutter.versionName
    multiDexEnabled = true

    // ✅ Unity: ограничиваем ABI (самый частый фикс чёрного экрана/виса на лого)
    ndk {
        abiFilters += setOf("arm64-v8a")
    }
}
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    buildFeatures { buildConfig = true }
}

dependencies {
    // Play Services (оставь, если нужно)
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    implementation("androidx.browser:browser:1.5.0")
    implementation("androidx.multidex:multidex:2.0.1")

    // Firebase BOM + Messaging (+ Analytics по желанию)
    implementation(platform("com.google.firebase:firebase-bom:32.7.4"))
  

    // NotificationCompat и расширения
    implementation("androidx.core:core-ktx:1.13.1")

    // Desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // УДАЛИТЬ: лишняя stdlib, её тянет плагин Kotlin
    // implementation("org.jetbrains.kotlin:kotlin-stdlib:1.8.21")
}

flutter { source = "../.." }
