# ==============================================================================
# VitalUp Production ProGuard / R8 Rules
# ==============================================================================

# 1. Google ML Kit & Google Play Services Auth (Google Sign-In)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# 2. Isar Community Database & Native Libs
-keep class dev.isar.** { *; }
-dontwarn dev.isar.**
-keepclassmembers class * extends dev.isar.IsarCollection { *; }

# 3. Mapbox Maps Flutter
-keep class com.mapbox.** { *; }
-dontwarn com.mapbox.**

# 4. Local Authentication (Biometrics / Fingerprint / Face)
-keep class io.flutter.plugins.localauth.** { *; }
-dontwarn io.flutter.plugins.localauth.**

# 5. Android Health Connect
-keep class androidx.health.** { *; }
-dontwarn androidx.health.**

# 6. Flutter Foreground Task & Audio Session
-keep class com.pravera.flutter_foreground_task.** { *; }
-dontwarn com.pravera.flutter_foreground_task.**
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

# 7. Kotlin Coroutines & Reflection
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**
