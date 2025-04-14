# My App

Flutter ile geliştirilmiş mesaj analiz uygulaması.

## Kurulum Talimatları

### Gereksinimler
- Flutter 3.10.0 veya daha yüksek sürüm
- Dart 3.0.0 veya daha yüksek sürüm
- Android Studio / VS Code 
- Android SDK (Android için)
- Xcode 14+ (iOS için)

### Fork Sonrası Kurulum Adımları

1. **Projeyi klonlayın:**
   ```bash
   git clone https://github.com/KULLANICIADI/my_app.git
   cd my_app
   ```

2. **Bağımlılıkları yükleyin:**
   ```bash
   flutter pub get
   ```

3. **Firebase Yapılandırması:**
   - Android için: `android/app/google-services.json` dosyasını kendi Firebase projenizden alıp yerleştirin
   - iOS için: `ios/Runner/GoogleService-Info.plist` dosyasını kendi Firebase projenizden alıp yerleştirin

4. **Ortam Değişkenleri:**
   Proje kök dizininde `.env` dosyası oluşturun ve şu değişkenleri tanımlayın:
   ```
   # Firebase konfigürasyonu
   FIREBASE_PROJECT_ID=sizin-proje-id
   FIREBASE_STORAGE_BUCKET=sizin-bucket-adınız.appspot.com

   # AI Servisleri
   GEMINI_API_KEY=sizin-api-anahtarınız
   GEMINI_MODEL=gemini-2.0-flash
   GEMINI_MAX_TOKENS=1024

   # Uygulama Ayarları
   APP_ENV=development
   MAX_MESSAGES_PER_DAY=10
   ```

5. **iOS Kurulumu:**
   ```bash
   cd ios
   pod install --repo-update
   cd ..
   ```

6. **Projeyi Çalıştırın:**
   ```bash
   flutter run
   ```

## Platform Özellikleri ve Notlar

### Android
- Minimum Android SDK: 21 (Android 5.0)
- Hedef Android SDK: 33 (Android 13)
- Google Play Servisleri gerektirir
- Kamera ve depolama izinleri gerektirir

### iOS
- Minimum iOS sürümü: 12.0
- Kamera ve fotoğraf kütüphanesi izinleri gerektirir

## Yaygın Sorunlar ve Çözümleri

### iOS Sorunları:
1. **Pod kurulum hataları:** 
   ```bash
   cd ios
   pod deintegrate
   pod install --repo-update
   ```

2. **Firebase kurulum hataları:** `GoogleService-Info.plist` dosyasının doğru yerde olduğundan emin olun.

### Android Sorunları:
1. **Google Services hatası:** `google-services.json` dosyasının doğru yerde olduğundan emin olun.

2. **Gradle sürümü uyumsuzluğu:** `android/gradle/wrapper/gradle-wrapper.properties` dosyasını güncel sürüm ile değiştirin.

## İletişim
Sorunlarınız için GitHub Issues üzerinden veya [email@example.com](mailto:email@example.com) adresinden bize ulaşabilirsiniz.
