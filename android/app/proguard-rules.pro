# ── R8 keep rules ────────────────────────────────────────────────────────────
#
# This file didn't exist before — the release build was relying purely on R8's
# default rules, with nothing telling it about Flutter's own Play Store
# integration or any of the native SDKs this app pulls in. That's the classic
# cause of "works as a sideloaded APK, crashes immediately when installed from
# the Play Store": Play Store-distributed builds route through Flutter's
# PlayStoreDeferredComponentManager / Play Core split-install classes, and
# without a keep rule R8 strips them as apparently-unused, so the app crashes
# on FlutterActivity's very first frame — every time, on every device, but
# only for the Play Store-installed copy. See:
# https://github.com/flutter/flutter/issues/68587

# ── Flutter's Play Store / deferred-components integration ──────────────────
-keep class io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.app.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.FlutterEngine { *; }
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ── Firebase / Google Play Services (firebase_core, firebase_auth) ──────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ── Google Sign-In / Sign in with Apple ──────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.api.client.** { *; }
-dontwarn com.google.api.client.**

# ── ML Kit pose detection (google_mlkit_pose_detection) ──────────────────────
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_pose** { *; }
-dontwarn com.google.mlkit.**

# ── Razorpay checkout (razorpay_flutter) — required by Razorpay's own docs ──
-keepclassmembers class * implements com.razorpay.PaymentResultListener { *; }
-keepclassmembers class * implements com.razorpay.PaymentResultWithDataListener { *; }
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-optimizations !method/removal/parameter
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn proguard.annotation.KeepClassMembers
-dontwarn proguard.annotation.Keep

# ── flutter_local_notifications + the Gson it uses to persist scheduled ─────
# reminders. Without -keepattributes Signature, R8 drops the generic type
# info Gson's TypeToken needs, and loading the scheduled-notification cache
# throws (getSuperclassTypeParameter) — the immediate show() works but every
# scheduled morning/evening reminder silently fails.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod
-dontwarn com.google.errorprone.annotations.**
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

# ── in_app_purchase (Play Billing) ───────────────────────────────────────────
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**
