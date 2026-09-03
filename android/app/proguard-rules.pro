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
