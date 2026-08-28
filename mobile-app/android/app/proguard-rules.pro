# Flutter wrapper rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve app custom symbols
-keep class com.leitnerplatform.mobile_app.** { *; }

# Preserve SQLCipher if configured
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Preserve metadata for reflection and platform channels
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Keep native methods and classes containing them
-keepclasseswithmembernames class * {
    native <methods>;
}

-keep class * {
    native <methods>;
}

# Suppress warnings for missing Play Core classes used by Flutter's deferred components
-dontwarn com.google.android.play.core.**

# Flutter Local Notifications Plugin
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class androidx.core.app.NotificationManagerCompat** { *; }
-keep class androidx.media.app.NotificationCompat** { *; }

# Google Play Services SMS Retriever & User Consent API
-keep class com.google.android.gms.auth.api.phone.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class fman.ge.smart_auth.** { *; }
-dontwarn com.google.android.gms.auth.api.phone.**
-dontwarn fman.ge.smart_auth.**
