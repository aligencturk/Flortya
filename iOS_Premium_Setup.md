# iOS Premium Setup - App Store Connect Konfigürasyonu

## 🍎 Apple App Store Connect Kurulumu

### 1. App Store Connect'te In-App Purchase Ürünlerini Tanımlama

App Store Connect Developer Portal'a giriş yapın ve aşağıdaki ürün kimliklerini tanımlayın:

#### 📦 Ürün Kimlikleri (Product IDs)
```
- flortya_premium_weekly_ios     (Haftalık Plan)
- flortya_premium_monthly_ios    (Aylık Plan) 
- flortya_premium_yearly_ios     (Yıllık Plan)
```

#### 💰 Önerilen Fiyatlar
- **Haftalık**: $6.99 / €6.99 / ₺49.99
- **Aylık**: $19.99 / €19.99 / ₺149.99  
- **Yıllık**: $99.99 / €99.99 / ₺999.99

### 2. In-App Purchase Türü
- **Auto-Renewable Subscriptions** seçilmelidir
- **Subscription Group**: "Flortya Premium"

### 3. Localization (Yerelleştirme)

#### Türkçe (tr-TR)
- **Haftalık Plan**
  - Display Name: "Haftalık Premium"
  - Description: "Flörtya Premium özelliklerine haftalık erişim"
  
- **Aylık Plan**
  - Display Name: "Aylık Premium" 
  - Description: "Flörtya Premium özelliklerine aylık erişim - En popüler!"
  
- **Yıllık Plan**
  - Display Name: "Yıllık Premium"
  - Description: "Flörtya Premium özelliklerine yıllık erişim - En büyük tasarruf!"

#### İngilizce (en-US)
- **Weekly Plan**
  - Display Name: "Weekly Premium"
  - Description: "Weekly access to Flortya Premium features"
  
- **Monthly Plan**
  - Display Name: "Monthly Premium"
  - Description: "Monthly access to Flortya Premium features - Most popular!"
  
- **Yearly Plan**
  - Display Name: "Yearly Premium" 
  - Description: "Yearly access to Flortya Premium features - Best value!"

### 4. Subscription Benefits (Abonelik Faydaları)

App Store Connect'te şu faydaları ekleyin:

```
✅ Reklamsız kullanım
✅ Sınırsız mesaj analizi
✅ Wrapped özet analizleri  
✅ Görsel OCR analizi
✅ TXT dosyası analizi
✅ İlişki danışmanlığı
✅ Alternatif mesaj önerileri
✅ Yanıt senaryoları
✅ Premium müşteri desteği
```

### 5. Entitlements ve Permissions

`ios/Runner/Runner.entitlements` dosyasında şunlar tanımlanmıştır:

```xml
<key>com.apple.developer.in-app-payments</key>
<array>
    <string>merchant.com.rivorya.flortya</string>
</array>
```

### 6. Test Flight Testing

#### Test Hesapları
App Store Connect'te Sandbox test kullanıcıları oluşturun:
- Test kullanıcıları için farklı ülke/bölge ayarları
- Premium özelliklerin test edilmesi

#### Test Senaryoları
- ✅ Haftalık plan satın alma
- ✅ Aylık plan satın alma  
- ✅ Yıllık plan satın alma
- ✅ Satın alımları geri yükleme (Restore Purchases)
- ✅ Premium özelliklerin kilidi açılması
- ✅ Plan değiştirme

### 7. Production Release Checklist

#### App Store Connect'te
- [ ] In-App Purchase ürünleri "Ready for Sale" durumunda
- [ ] Tax information tamamlandı
- [ ] Banking information tamamlandı  
- [ ] Paid Applications Agreement kabul edildi
- [ ] App privacy details güncellendi

#### Kod Tarafında
- [ ] iOS ürün kimlikleri doğru tanımlandı
- [ ] Platform detection çalışıyor
- [ ] Restore purchases fonksiyonu test edildi
- [ ] Error handling implement edildi
- [ ] Debug logları production için temizlendi

### 8. Revenue Sharing

Apple App Store:
- **Apple komisyonu**: %30 (ilk yıl), %15 (ikinci yıl ve sonrası)
- **Developer geliri**: %70 (ilk yıl), %85 (ikinci yıl ve sonrası)

### 9. Troubleshooting

#### Yaygın Sorunlar
1. **"Products not found"** hatası
   - App Store Connect'te ürünler "Ready for Sale" durumunda mı?
   - Ürün kimlikleri kod ile eşleşiyor mu?
   
2. **Sandbox testing sorunları** 
   - Test hesabı sandbox kullanıcısı mı?
   - Gerçek Apple ID ile test yapmıyor musunuz?

3. **Restore purchases çalışmıyor**
   - Transaction history kontrolü
   - Receipt validation

### 10. Analytics ve Monitoring

#### App Store Connect Analytics
- Subscription performance
- Conversion rates  
- Churn rates
- Revenue tracking

#### Firebase Analytics Events
```dart
// Premium subscription events
FirebaseAnalytics.instance.logEvent(
  name: 'premium_subscription_started',
  parameters: {
    'plan_type': 'monthly',
    'platform': 'ios',
    'price': '19.99'
  }
);
```

---

## 🔄 Next Steps

1. App Store Connect'te ürünleri tanımlayın
2. Test Flight'ta test edin  
3. Production'a deploy edin
4. Analytics'i monitör edin
5. Revenue'yu takip edin

Bu konfigürasyon tamamlandığında iOS kullanıcıları App Store üzerinden premium abonelik satın alabilecekler. 