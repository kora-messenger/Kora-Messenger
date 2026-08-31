# ═══ Kora Messenger ProGuard / R8 Rules ═══

# ── Flutter engine ──
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Kora native plugins (must not be obfuscated) ──
-keep class com.kora.messenger.** { *; }
-keep class com.kora.messenger.notifications.** { *; }

# ── WebRTC (flutter_webrtc) ──
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.** { *; }
-dontwarn org.webrtc.**

# ── ML Kit Translate (on-demand language model download) ──
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_translate.** { *; }
-dontwarn com.google.mlkit.**

# ── Firebase Messaging ──
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── speech_to_text plugin ──
-keep class com.csdcorp.** { *; }

# ── record plugin ──
-keep class com.llfbandit.** { *; }

# ── permission_handler ──
-keep class com.baseflow.** { *; }

# ── shared_preferences ──
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── path_provider ──
-keep class io.flutter.plugins.pathprovider.** { *; }

# ── Keep native method declarations (JNI bridges) ──
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── Keep enum values (used by Flutter platform channels) ──
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ── Keep Parcelable creators ──
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# ── Keep serializable classes (used by notification payloads) ──
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
