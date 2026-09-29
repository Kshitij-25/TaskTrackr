# ── flutter_local_notifications ─────────────────────────────────────────────
# Scheduled notifications are serialised with Gson; keep generic signatures
# and the plugin's models or scheduled/boot-restored reminders crash.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# ── Firebase / Google Play services ────────────────────────────────────────
-keepattributes EnclosingMethod,InnerClasses
-dontwarn com.google.android.gms.**

# ── Flutter deferred components (unused, but referenced by the engine) ─────
-dontwarn com.google.android.play.core.**
