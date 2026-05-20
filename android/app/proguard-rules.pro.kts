# Smart Auth plugin rules
-keep class fman.ge.smart_auth.** { *; }
-keep class * implements fman.ge.smart_auth.** { *; }

# Google Play Services Auth credentials
-keep class com.google.android.gms.auth.api.credentials.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Keep all GMS classes that might be used by reflection
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }

# Keep all classes that have @Keep annotation
-keep @androidx.annotation.Keep class * { *; }
-keep class * {
    @androidx.annotation.Keep *;
}

# Keep Flutter engine classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# General rules for reflection and annotations
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }
-keep class kotlin.** { *; }

# Keep resource classes
-keep class **.R
-keep class **.R$* { *; }