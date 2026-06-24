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
