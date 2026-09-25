# Keep SLF4J classes used by Pusher and other dependencies
-keep class org.slf4j.** { *; }
-dontwarn org.slf4j.**

# Keep Pusher classes
-keep class com.pusher.** { *; }
-dontwarn com.pusher.**

# Keep Agora classes
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep annotation classes
-keepattributes *Annotation*

# General rules
-keepattributes Signature
-keepattributes Exceptions

# ── flutter_local_notifications ──────────────────────────────────────────
# The plugin serialises its scheduled-notification and notification-details
# models with Gson, which resolves fields reflectively. R8 renames them, and
# because `isMinifyEnabled` is on for release only, the failure shows up
# exclusively in release builds - the same shape as "works on my machine,
# broken on the tester's phone". Keeping the package also keeps the
# TypeToken subclasses whose generic signatures Gson reads.
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Gson itself: generic signatures and the fields it reflects over.
-keepattributes InnerClasses
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ── FCM ──────────────────────────────────────────────────────────────────
# The messaging service is resolved from the manifest by name, so it must not
# be renamed or stripped; without it a closed app receives nothing.
-keep class com.google.firebase.messaging.** { *; }
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }
