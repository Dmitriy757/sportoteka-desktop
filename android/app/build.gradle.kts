plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // важно!
}

android {
    namespace = "com.example.sportoteka"
    compileSdk = 36

    // Лучше держать версию NDK, которую использует Unity 6000.5.
    // Если Gradle начнет ругаться, можно вернуть 27.0.12077973.
    ndkVersion = "28.2.13676358"

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

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.sportoteka"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
        multiDexEnabled = true

        // Unity: ограничиваем ABI, чтобы Flutter и Unity собирали одну архитектуру.
        ndk {
            abiFilters += setOf("arm64-v8a")
        }
    }

    // Фикс дубля libc++_shared.so: Unity + pdfium-android.
    packagingOptions {
        pickFirst("lib/arm64-v8a/libc++_shared.so")
        pickFirst("lib/armeabi-v7a/libc++_shared.so")
        pickFirst("lib/x86/libc++_shared.so")
        pickFirst("lib/x86_64/libc++_shared.so")
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

    buildFeatures {
        buildConfig = true
    }
}

dependencies {

    // Play Services
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    implementation("androidx.browser:browser:1.5.0")
    implementation("androidx.multidex:multidex:2.0.1")

    // Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:32.7.4"))

    // NotificationCompat и расширения
    implementation("androidx.core:core-ktx:1.13.1")

    // Desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
