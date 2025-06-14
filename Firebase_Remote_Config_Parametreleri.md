# Firebase Remote Config Parametreleri Rehberi

Bu dokümanda Firebase Console'da oluşturmanız gereken tüm Remote Config parametreleri listelenmiştir.

## 🔧 Platform Specific Parametreler

### Hoş Geldin Mesajları
<!-- Welcome message parametreleri kaldırıldı -->

### Versiyon Kontrolü - Android
- `minimum_version_android` (string) - Android için minimum versiyon (örn: "1.2.0")
- `force_update_version_android` (string) - Android için zorunlu güncelleme versiyonu (örn: "1.0.0") 
- `play_store_url` (string) - Google Play Store URL'si

### Versiyon Kontrolü - iOS  
- `minimum_version_ios` (string) - iOS için minimum versiyon (örn: "1.2.0")
- `force_update_version_ios` (string) - iOS için zorunlu güncelleme versiyonu (örn: "1.0.0")
- `app_store_url` (string) - Apple App Store URL'si

### Güncelleme Mesajları
- `update_message` (string) - Genel güncelleme mesajı
- `update_message_android` (string) - Android özel güncelleme mesajı
- `update_message_ios` (string) - iOS özel güncelleme mesajı

## 📱 Kampanya Parametreleri

### Genel Kampanyalar
```json
{
  "parametre_adi": "active_campaigns",
  "tip": "string",
  "deger": "[{\"id\":\"1\",\"title\":\"Yaz Kampanyası\",\"message\":\"Yeni yaz kampanyamızı kaçırmayın!\",\"type\":\"banner\",\"startDate\":\"2024-06-01T00:00:00Z\",\"endDate\":\"2024-08-31T23:59:59Z\",\"isActive\":true,\"targetPlatforms\":[\"android\",\"ios\"],\"actionUrl\":\"https://example.com/campaign\",\"actionText\":\"Detaylara Göz At\",\"priority\":1}]"
}
```

### Platform Özel Kampanyalar
```json
{
  "parametre_adi": "active_campaigns_android",
  "tip": "string", 
  "deger": "[{\"id\":\"android_1\",\"title\":\"Android Özel\",\"message\":\"Android kullanıcıları için özel kampanya\",\"type\":\"popup\",\"startDate\":\"2024-06-01T00:00:00Z\",\"endDate\":\"2024-12-31T23:59:59Z\",\"isActive\":true,\"priority\":2}]"
}
```

```json
{
  "parametre_adi": "active_campaigns_ios", 
  "tip": "string",
  "deger": "[{\"id\":\"ios_1\",\"title\":\"iOS Özel\",\"message\":\"iOS kullanıcıları için özel kampanya\",\"type\":\"popup\",\"startDate\":\"2024-06-01T00:00:00Z\",\"endDate\":\"2024-12-31T23:59:59Z\",\"isActive\":true,\"priority\":2}]"
}
```

## ⚙️ Uygulama Yapılandırması

### Bakım Modu
- `maintenance_mode` (boolean) - Bakım modu aktif/pasif (true/false)
- `maintenance_message` (string) - Bakım modu mesajı

### Platform Özel Özellikler
- `enabled_features_android` (string) - Android için aktif özellikler (virgülle ayrılmış)
- `enabled_features_ios` (string) - iOS için aktif özellikler (virgülle ayrılmış)
- `disabled_features_android` (string) - Android için pasif özellikler (virgülle ayrılmış)  
- `disabled_features_ios` (string) - iOS için pasif özellikler (virgülle ayrılmış)

### API Yapılandırması
- `api_timeout` (string) - API timeout süresi (saniye) (örn: "30")
- `max_retries` (string) - Maksimum deneme sayısı (örn: "3")

### UI Yapılandırması
<!-- Show welcome message parametresi kaldırıldı -->
- `default_theme` (string) - Varsayılan tema ("light", "dark", "system")

## 📝 Örnek Parametreler (Test için)

<!-- Hoş geldin mesajı parametresi kaldırıldı -->

### 2. Android Minimum Versiyon
```
Parametre Adı: minimum_version_android  
Değer: "1.0.0"
Açıklama: Android için minimum desteklenen versiyon
```

### 3. iOS Minimum Versiyon
```
Parametre Adı: minimum_version_ios
Değer: "1.0.0" 
Açıklama: iOS için minimum desteklenen versiyon
```

### 4. Android Zorunlu Güncelleme
```
Parametre Adı: force_update_version_android
Değer: "0.9.0"
Açıklama: Bu versiyondan eski olanlar zorunlu güncelleme gerektirir
```

### 5. Google Play Store URL
```
Parametre Adı: play_store_url
Değer: "https://play.google.com/store/apps/details?id=com.rivorya.flortya"
Açıklama: Google Play Store'daki uygulama sayfası
```

### 6. Güncelleme Mesajı
```
Parametre Adı: update_message
Değer: "Yeni bir güncelleme mevcut! Daha iyi deneyim için uygulamanızı güncelleyin."
Açıklama: Güncelleme dialog'unda gösterilen mesaj
```

### 7. Basit Kampanya Örneği
```
Parametre Adı: active_campaigns
Değer: [{"id":"test_1","title":"Test Kampanyası","message":"Bu bir test kampanyasıdır","type":"banner","startDate":"2024-01-01T00:00:00Z","endDate":"2024-12-31T23:59:59Z","isActive":true,"priority":1}]
Açıklama: Aktif kampanyalar listesi (JSON formatında)
```

## 🚀 Hızlı Kurulum İçin Öncelikli Parametreler

Sistemi test etmek için önce şu parametreleri oluşturun:

<!-- welcome_message parametresi kaldırıldı -->
2. `minimum_version_android` - "1.0.0"  
3. `force_update_version_android` - "0.9.0"
4. `play_store_url` - Play Store URL'iniz
5. `update_message` - "Yeni güncelleme mevcut!"

## 📋 Kampanya JSON Şeması

Kampanya parametreleri için JSON şeması:

```json
[
  {
    "id": "benzersiz_id",
    "title": "Kampanya Başlığı", 
    "message": "Kampanya mesajı",
    "imageUrl": "https://example.com/image.jpg", // opsiyonel
    "type": "banner|popup|notification|discount|feature",
    "startDate": "2024-01-01T00:00:00Z",
    "endDate": "2024-12-31T23:59:59Z", 
    "isActive": true,
    "metadata": {}, // opsiyonel ek veri
    "targetPlatforms": ["android", "ios"], // opsiyonel
    "actionUrl": "https://example.com/action", // opsiyonel
    "actionText": "Detayları Gör", // opsiyonel
    "priority": 1 // 1-10 arası öncelik
  }
]
```

## 🎯 Platform Conditions (Koşullar)

Firebase Console'da parametreleri oluştururken platform koşulları da ekleyebilirsiniz:

### Android Koşulu
- Condition name: `Android Users`
- Rules: `app.platformName == 'android'`

### iOS Koşulu  
- Condition name: `iOS Users`
- Rules: `app.platformName == 'ios'`

Bu koşulları kullanarak platform-specific değerler verebilirsiniz.

## ⚡ Test Önerileri

1. İlk olarak basit parametrelerle başlayın
2. Parametreleri oluşturduktan sonra "Publish changes" butonuna tıklayın
3. Uygulamayı yeniden başlatarak değişiklikleri test edin
4. Loglarda Remote Config'in parametreleri çektiğini kontrol edin

## 🔍 Troubleshooting

- Parametreler çalışmıyorsa "Publish changes" yaptığınızdan emin olun
- Parametre adlarını büyük/küçük harf duyarlı olarak kontrol edin
- JSON formatındaki parametrelerde syntax hatası olup olmadığını kontrol edin
- Firebase App Check'in düzgün çalıştığından emin olun 