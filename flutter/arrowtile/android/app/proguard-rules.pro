# Arrowtile (Flutter) — R8 kuralları
# Flutter motoru, google_mobile_ads, in_app_purchase (Play Billing) ve UMP kendi tüketici (consumer) kurallarını getirir;
# ek kural gerekmez. Hata raporlarında satır numarası için:
-keepattributes SourceFile,LineNumberTable

# --- Açılış çökmesi düzeltmesi (Samsung A53 / emülatör API 34) ---
# google_mobile_ads → play-services-ads → WorkManager, veritabanını (Room) yansıma ile
# `WorkDatabase_Impl` adıyla oluşturur. R8 tam modda bu sınıfın kurucusunu sildiği için
# uygulama açılır açılmaz "Failed to create an instance of androidx.work.impl.WorkDatabase"
# hatasıyla kapanıyordu. Room veritabanı uygulamalarının kurucuları korunur.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.** extends androidx.room.RoomDatabase { *; }

# --- Firebase Crashlytics (docs/19) ---
# Firebase SDK'ları kendi tüketici kurallarını getirir. Crashlytics: istisna sınıf adları okunur kalsın; SourceFile/LineNumberTable
# yukarıda korunuyor; R8 eşleme dosyasını Crashlytics Gradle eklentisi release derlemesinde otomatik yükler (google-services.json varsa).
-keep public class * extends java.lang.Exception
