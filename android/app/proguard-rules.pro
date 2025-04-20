-keep class com.google.mlkit.vision.text.latin.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.common.** { *; }

# ML Kit Text Recognition modelleri için keep kuralları (sadece Latin için)
-keepclasseswithmembernames class com.google.mlkit.vision.text.latin.TextRecognizerOptions { *; }
-keep class com.google.android.gms.vision.text.** { *; }

# Diğer dil modellerini kullanmadığımız için bu modellerin kaldırıldığını belirt
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.** 