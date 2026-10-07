# Application package
-keep class datingconnect.app.** { *; }

# Play Billing Library
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Image picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Country picker
-keep class com.hemanthraj.country_picker.** { *; }

# Cached network image
-keep class io.flutter.plugins.cached_network_image.** { *; }

# Ignore missing Play Core classes
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
