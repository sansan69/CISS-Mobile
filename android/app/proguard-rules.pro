# Keep the Flutter embedding and every plugin entry point reached through
# reflection from the manifest or the engine.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class id.flutter.** { *; }
-keep class com.baseflow.** { *; }
-keep class com.lyokone.** { *; }
-keep class com.icapps.** { *; }
-keep class com.pravera.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class androidx.camera.** { *; }

-dontwarn io.flutter.embedding.**
-dontwarn com.google.mlkit.**

# Keep annotations and generic signatures used by the plugins' JSON models.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
