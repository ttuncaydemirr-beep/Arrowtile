# Arrowtile — R8 kuralları
# WebView JavaScript arayüzü: @JavascriptInterface metodları yansıma (reflection) ile çağrılır;
# adları ve imzaları değişirse oyun (game/js/ads.js) köprüyü bulamaz.
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-keep class com.arrowtile.puzzle.AndroidBridge { <init>(...); }
-keepclassmembers class com.arrowtile.puzzle.AndroidBridge {
    @android.webkit.JavascriptInterface <methods>;
}
# Google Mobile Ads, UMP ve Play Billing kendi tüketici (consumer) kurallarını getirir; ek kural gerekmez.
# Hata raporlarında satır numarası için (isteğe bağlı):
-keepattributes SourceFile,LineNumberTable
