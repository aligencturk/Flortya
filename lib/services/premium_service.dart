import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class PremiumService {
  static const String DAILY_VISUAL_OCR_COUNT_KEY = 'dailyVisualOcrCount';
  static const String DAILY_VISUAL_OCR_DATE_KEY = 'dailyVisualOcrDate';
  static const String TXT_ANALYSIS_USED_COUNT_KEY = 'txtAnalysisUsedCount';
  static const String WRAPPED_OPENED_ONCE_KEY = 'wrappedOpenedOnce';
  static const String FIRST_TIME_VISUAL_OCR_KEY = 'firstTimeVisualOcr';
  
  // Metin modu için yeni sabitler
  static const String MESSAGE_COACH_FIRST_USE_KEY = 'messageCoachFirstUse';
  static const String MESSAGE_COACH_AD_VIEWED_KEY = 'messageCoachAdViewed';
  static const String ALTERNATIVE_SUGGESTIONS_UNLOCKED_KEY = 'alternativeSuggestionsUnlocked';
  static const String RESPONSE_SCENARIOS_UNLOCKED_KEY = 'responseScenariosUnlocked';
  
  // Görsel modu için yeni sabitler
  static const String VISUAL_MODE_AD_VIEWED_KEY = 'visualModeAdViewed';
  static const String VISUAL_MODE_FIRST_USE_COMPLETED_KEY = 'visualModeFirstUseCompleted';  // Görsel mod ilk kullanım anahtarı
  static const String POSITIVE_RESPONSE_SCENARIO_UNLOCKED_KEY = 'positiveResponseScenarioUnlocked';
  static const String NEGATIVE_RESPONSE_SCENARIO_UNLOCKED_KEY = 'negativeResponseScenarioUnlocked';
  static const String VISUAL_ALTERNATIVE_SUGGESTIONS_UNLOCKED_KEY = 'visualAlternativeSuggestionsUnlocked';
  static const String MESSAGE_COACH_TEXTS_UNLOCKED_KEY = 'messageCoachTextsUnlocked';
  // Her bir mesaj koçu metin önerisi için ayrı kilit anahtarı ön eki
  static const String MESSAGE_COACH_TEXT_ITEM_UNLOCKED_PREFIX = 'messageCoachTextItem_';
  // Olumlu ve olumsuz yanıt senaryoları için ayrı kilit anahtarları
  static const String POSITIVE_RESPONSE_UNLOCKED_KEY = 'positiveResponseUnlocked';
  static const String NEGATIVE_RESPONSE_UNLOCKED_KEY = 'negativeResponseUnlocked';

  // Android (Google Play Store) ürün kimlikleri
  static const Set<String> androidUrunKimlikleri = {
    'flortya_premium_weekly',
    'flortya_premium_monthly',
    'flortya_premium_yearly',
  };
  
  // iOS (App Store) ürün kimlikleri
  static const Set<String> iosUrunKimlikleri = {
    'flortya_premium_weekly_ios',
    'flortya_premium_monthly_ios',
    'flortya_premium_yearly_ios',
  };
  
  // Platform'a göre ürün kimliklerini döndür
  static Set<String> get urunKimlikleri {
    if (Platform.isIOS) {
      return iosUrunKimlikleri;
    } else {
      return androidUrunKimlikleri;
    }
  }

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ProductDetails> urunler = [];
  bool satinAlmaVarMi = false;

  // In-App Purchase sistemini başlat
  Future<bool> inAppPurchaseBaslat() async {
    try {
      satinAlmaVarMi = await _inAppPurchase.isAvailable();
      if (!satinAlmaVarMi) {
        return false;
      }

      // Ürün bilgilerini yükle
      await urunleriYukle();
      return true;
    } catch (e) {
      debugPrint('In-App Purchase başlatma hatası: $e');
      return false;
    }
  }

  // Platform'a göre ürün bilgilerini yükle (App Store veya Google Play Store)
  Future<void> urunleriYukle() async {
    try {
      final String storeName = Platform.isIOS ? 'App Store' : 'Google Play Store';
      final Set<String> platformUrunKimlikleri = urunKimlikleri;
      
      debugPrint('🛒 $storeName\'dan ürün bilgileri yükleniyor...');
      debugPrint('📋 Platform: ${Platform.isIOS ? 'iOS' : 'Android'}');
      debugPrint('📋 Aranacak ürün kimlikleri: $platformUrunKimlikleri');
      
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(platformUrunKimlikleri);
      
      if (response.error != null) {
        debugPrint('❌ Ürün sorgusu hatası: ${response.error}');
        debugPrint('🔍 Error code: ${response.error!.code}');
        debugPrint('📄 Error details: ${response.error!.details}');
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Bulunamayan ürün kimlikleri: ${response.notFoundIDs}');
        if (Platform.isIOS) {
          debugPrint('💡 iOS için App Store Connect\'te bu ürün kimliklerinin tanımlandığından emin olun');
        }
      }

      urunler = response.productDetails;
      debugPrint('✅ ${urunler.length} ürün başarıyla yüklendi ($storeName)');
      
      for (final product in urunler) {
        debugPrint('💰 Ürün: ${product.id} - ${product.price} - ${product.title}');
      }
      
      // Ürünleri plan sırasına göre sırala (haftalık, aylık, yıllık)
      urunler.sort((a, b) {
        Map<String, int> siralamaMap = Platform.isIOS ? {
          'flortya_premium_weekly_ios': 0,
          'flortya_premium_monthly_ios': 1,
          'flortya_premium_yearly_ios': 2,
        } : {
          'flortya_premium_weekly': 0,
          'flortya_premium_monthly': 1,
          'flortya_premium_yearly': 2,
        };
        return (siralamaMap[a.id] ?? 999).compareTo(siralamaMap[b.id] ?? 999);
      });
      
      debugPrint('🔄 Ürünler sıralandı');
      
    } catch (e) {
      debugPrint('❌ Ürün yükleme hatası: $e');
      debugPrint('📱 Platform: ${Platform.isIOS ? 'iOS' : 'Android'}');
      debugPrint('📱 In-App Purchase mevcut: $satinAlmaVarMi');
    }
  }

  // Satın alma işlemini başlat (platform'a göre farklı yöntemler)
  Future<void> satinAlmaBaslat(ProductDetails urun) async {
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: urun);
      
      if (Platform.isIOS) {
        // iOS için subscription satın alma
        debugPrint('🍎 iOS App Store satın alma başlatılıyor: ${urun.id}');
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // Android için normal satın alma
        debugPrint('🤖 Google Play Store satın alma başlatılıyor: ${urun.id}');
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      debugPrint('Satın alma başlatma hatası: $e');
      toastMesajGoster('Satın alma başlatılamadı: $e', false);
    }
  }

  // Satın alma sonuçlarını dinle
  Stream<List<PurchaseDetails>> get satinAlinan => _inAppPurchase.purchaseStream;

  // Satın alma işlemini tamamla ve Firestore'a kaydet
  Future<void> satinAlmaTamamla(PurchaseDetails purchase) async {
    try {
      if (purchase.status == PurchaseStatus.purchased) {
        // Firestore'a premium bilgilerini kaydet
        await kullaniciyaPremiumVer(purchase.productID);
        
        // Purchase'ı tamamlandı olarak işaretle
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
        
        toastMesajGoster('Premium aktif!', true);
      } else if (purchase.status == PurchaseStatus.error) {
        toastMesajGoster('Satın alma başarısız: ${purchase.error?.message}', false);
      } else if (purchase.status == PurchaseStatus.canceled) {
        toastMesajGoster('Satın alma iptal edildi', false);
      }
    } catch (e) {
      debugPrint('Satın alma tamamlama hatası: $e');
      toastMesajGoster('Satın alma tamamlanamadı: $e', false);
    }
  }

  // Kullanıcıya premium ver ve Firestore'a kaydet
  Future<void> kullaniciyaPremiumVer(String urunKimlik) async {
    try {
      final User? kullanici = _auth.currentUser;
      if (kullanici == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }

      // Premium süresini ürün tipine göre hesapla (platform bağımsız)
      final DateTime now = DateTime.now();
      DateTime premiumExpiry;
      
      // Ürün kimliğinden plan tipini belirle
      String planTipi = _urunKimligindenPlanTipiBelirle(urunKimlik);
      
      switch (planTipi) {
        case 'weekly':
          // Haftalık: 7 gün
          premiumExpiry = now.add(const Duration(days: 7));
          break;
        case 'monthly':
          // Aylık: 30 gün (daha güvenli)
          premiumExpiry = now.add(const Duration(days: 30));
          break;
        case 'yearly':
          // Yıllık: 365 gün (artık yıl durumlarından kaçınmak için)
          premiumExpiry = now.add(const Duration(days: 365));
          break;
        default:
          // Varsayılan olarak 30 gün
          premiumExpiry = now.add(const Duration(days: 30));
      }

      await _firestore.collection('users').doc(kullanici.uid).update({
        'isPremium': true,
        'premiumPlan': urunKimlik,
        'premiumDate': Timestamp.now(),
        'premiumExpiry': Timestamp.fromDate(premiumExpiry), // Son kullanma tarihi eklendi
      });
      
      debugPrint('Premium bilgileri Firestore\'a kaydedildi: $urunKimlik');
      debugPrint('Premium son kullanma tarihi: $premiumExpiry');
    } catch (e) {
      debugPrint('Firestore premium kaydetme hatası: $e');
      throw e;
    }
  }

  // Ürün kimliğinden plan tipini belirle (platform bağımsız)
  String _urunKimligindenPlanTipiBelirle(String urunKimlik) {
    if (urunKimlik.contains('weekly')) {
      return 'weekly';
    } else if (urunKimlik.contains('monthly')) {
      return 'monthly';
    } else if (urunKimlik.contains('yearly')) {
      return 'yearly';
    }
    return 'monthly'; // Varsayılan
  }

  // Platform bilgisi getir
  String getPlatformInfo() {
    if (Platform.isIOS) {
      return 'iOS App Store';
    } else if (Platform.isAndroid) {
      return 'Google Play Store';
    } else {
      return 'Bilinmeyen Platform';
    }
  }

  // Premium özellik kontrolü için platform bağımsız kimlik çeviri
  String _normalizeProductId(String urunKimlik) {
    // iOS sonekini kaldır platform bağımsız karşılaştırma için
    return urunKimlik.replaceAll('_ios', '');
  }

  // iOS için abonelik durumu kontrolü
  Future<bool> validateIOSSubscription() async {
    if (!Platform.isIOS) return true; // Android için true döndür
    
    try {
      debugPrint('🍎 iOS abonelik durumu kontrol ediliyor...');
      
      // iOS için restore purchases yap
      await _inAppPurchase.restorePurchases();
      
      // Purchase stream'den gelen güncellemeleri bekle
      // Bu fonksiyon asenkron olarak çalışır
      debugPrint('✅ iOS restore purchases başlatıldı');
      return true;
      
    } catch (e) {
      debugPrint('❌ iOS abonelik validasyon hatası: $e');
      return false;
    }
  }

  // Platform'a göre abonelik durumu kontrolü
  Future<bool> validateSubscriptionStatus() async {
    if (Platform.isIOS) {
      return await validateIOSSubscription();
    } else {
      // Android için farklı validasyon yöntemi
      return true; // Şimdilik true döndür
    }
  }

  // Plan adını Türkçe'ye çevir (platform bağımsız)
  String planAdiCevir(String urunKimlik) {
    String planTipi = _urunKimligindenPlanTipiBelirle(urunKimlik);
    switch (planTipi) {
      case 'weekly':
        return 'Haftalık';
      case 'monthly':
        return 'Aylık';
      case 'yearly':
        return 'Yıllık';
      default:
        return 'Bilinmeyen';
    }
  }

  // Plan açıklamasını getir (platform bağımsız)
  String planAciklamasiAl(String urunKimlik) {
    String planTipi = _urunKimligindenPlanTipiBelirle(urunKimlik);
    switch (planTipi) {
      case 'weekly':
        return 'Haftalık premium erişim';
      case 'monthly':
        return 'Aylık premium erişim\n%33 tasarruf';
      case 'yearly':
        return 'Yıllık premium erişim\n%58 tasarruf';
      default:
        return '';
    }
  }

  // En popüler plan mı kontrol et (platform bağımsız)
  bool enPopulerPlanMi(String urunKimlik) {
    String planTipi = _urunKimligindenPlanTipiBelirle(urunKimlik);
    return planTipi == 'monthly';
  }

  // Toast mesajı göster
  void toastMesajGoster(String mesaj, bool basarili) {
    Fluttertoast.showToast(
      msg: mesaj,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: basarili ? Colors.green : Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // Günlük görsel OCR kullanım sayısını kontrol et
  Future<int> getDailyVisualOcrCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? dateStr = prefs.getString(DAILY_VISUAL_OCR_DATE_KEY);
    final DateTime now = DateTime.now();
    final String today = "${now.year}-${now.month}-${now.day}";

    // Eğer bugün ilk kez kullanılıyorsa, sayacı sıfırla
    if (dateStr == null || dateStr != today) {
      await prefs.setString(DAILY_VISUAL_OCR_DATE_KEY, today);
      await prefs.setInt(DAILY_VISUAL_OCR_COUNT_KEY, 0);
      return 0;
    }

    // Mevcut kullanım sayısını döndür
    return prefs.getInt(DAILY_VISUAL_OCR_COUNT_KEY) ?? 0;
  }

  // Görsel OCR kullanım sayısını artır
  Future<bool> incrementDailyVisualOcrCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int currentCount = await getDailyVisualOcrCount();
    return prefs.setInt(DAILY_VISUAL_OCR_COUNT_KEY, currentCount + 1);
  }

  // İlk kez görsel analiz kullandı mı?
  Future<bool> isFirstTimeVisualOcr() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(FIRST_TIME_VISUAL_OCR_KEY) ?? false);
  }

  // İlk kullanım kaydını yap
  Future<bool> markFirstTimeVisualOcrUsed() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(FIRST_TIME_VISUAL_OCR_KEY, true);
  }

  // Görsel analiz için reklam gerekli mi kontrol et
  Future<bool> isAdRequiredForVisualOcr() async {
    // İlk kullanım kontrolü
    final bool isFirstTime = await isFirstTimeVisualOcr();
    if (isFirstTime) {
      // İlk kullanımsa reklam gerektirmez
      return false;
    }
    
    // İlk değilse her kullanımda reklam gerektirir
    return true;
  }
  
  // Görsel mod reklam izlendi mi kontrolü
  Future<bool> isVisualModeAdViewed() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(VISUAL_MODE_AD_VIEWED_KEY) ?? false;
  }
  
  // Görsel mod reklam izlenme durumunu kaydet
  Future<bool> setVisualModeAdViewed(bool viewed) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(VISUAL_MODE_AD_VIEWED_KEY, viewed);
  }
  
  // Görsel mod ilk kullanım durumunu kontrol et
  Future<bool> isVisualModeFirstUseCompleted() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(VISUAL_MODE_FIRST_USE_COMPLETED_KEY) ?? false;
  }
  
  // Görsel mod ilk kullanımı tamamlandı olarak işaretle
  Future<bool> markVisualModeFirstUseCompleted() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(VISUAL_MODE_FIRST_USE_COMPLETED_KEY, true);
  }
  
  // Olumlu yanıt senaryosu kilidi açık mı kontrolü
  Future<bool> isPositiveResponseScenarioUnlocked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(POSITIVE_RESPONSE_SCENARIO_UNLOCKED_KEY) ?? false;
  }
  
  // Olumlu yanıt senaryosu kilidini aç
  Future<bool> unlockPositiveResponseScenario() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(POSITIVE_RESPONSE_SCENARIO_UNLOCKED_KEY, true);
  }
  
  // Olumsuz yanıt senaryosu kilidi açık mı kontrolü
  Future<bool> isNegativeResponseScenarioUnlocked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(NEGATIVE_RESPONSE_SCENARIO_UNLOCKED_KEY) ?? false;
  }
  
  // Olumsuz yanıt senaryosu kilidini aç
  Future<bool> unlockNegativeResponseScenario() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(NEGATIVE_RESPONSE_SCENARIO_UNLOCKED_KEY, true);
  }
  
  // Görsel mod alternatif öneriler kilidi açık mı kontrolü
  Future<bool> isVisualAlternativeSuggestionsUnlocked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(VISUAL_ALTERNATIVE_SUGGESTIONS_UNLOCKED_KEY) ?? false;
  }
  
  // Görsel mod alternatif öneriler kilidini aç
  Future<bool> unlockVisualAlternativeSuggestions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(VISUAL_ALTERNATIVE_SUGGESTIONS_UNLOCKED_KEY, true);
  }

  // Mesaj koçu metin önerileri kilidi açık mı kontrolü
  Future<bool> isMessageCoachTextsUnlocked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(MESSAGE_COACH_TEXTS_UNLOCKED_KEY) ?? false;
  }
  
  // Mesaj koçu metin önerileri kilidini aç
  Future<bool> unlockMessageCoachTexts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(MESSAGE_COACH_TEXTS_UNLOCKED_KEY, true);
  }

  // Mesaj koçu metin önerileri için belirli bir öğe kilidi açık mı kontrolü
  Future<bool> isMessageCoachTextItemUnlocked(int index) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$MESSAGE_COACH_TEXT_ITEM_UNLOCKED_PREFIX$index') ?? false;
  }
  
  // Mesaj koçu metin önerileri için belirli bir öğenin kilidini aç
  Future<bool> unlockMessageCoachTextItem(int index) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool('$MESSAGE_COACH_TEXT_ITEM_UNLOCKED_PREFIX$index', true);
  }

  // TXT analizi kullanım sayısını kontrol et
  Future<int> getTxtAnalysisUsedCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(TXT_ANALYSIS_USED_COUNT_KEY) ?? 0;
  }

  // Alternatif öneriler için reklam izleme durumunu kaydet
  Future<bool> setAlternativeSuggestionsAdViewed(bool viewed) async {
    // Bu metod her alternatif öneri gösteriminde çağrılacak
    // Her alternatif öneri gösterimi için reklam izlenmeli olduğundan,
    // burada bir kayıt tutmaya gerek yok, görüntüleme anında reklam gösterilecek
    return true; // İşlem başarılı
  }

  // TXT analizi kullanım sayısını artır
  Future<bool> incrementTxtAnalysisUsedCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int currentCount = await getTxtAnalysisUsedCount();
    return prefs.setInt(TXT_ANALYSIS_USED_COUNT_KEY, currentCount + 1);
  }

  // Wrapped analiz açıldı mı kontrol et
  Future<bool> getWrappedOpenedOnce() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(WRAPPED_OPENED_ONCE_KEY) ?? false;
  }

  // Wrapped analizin açıldığını kaydet
  Future<bool> setWrappedOpenedOnce() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(WRAPPED_OPENED_ONCE_KEY, true);
  }
  
  // Mesaj koçu ilk kullanım mı?
  Future<bool> isFirstTimeMessageCoach() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(MESSAGE_COACH_FIRST_USE_KEY) ?? false);
  }
  
  // Mesaj koçu ilk kullanımı işaretle
  Future<bool> markMessageCoachFirstUseComplete() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(MESSAGE_COACH_FIRST_USE_KEY, true);
  }
  
  // Mesaj koçu için reklam izlendi mi?
  Future<bool> isMessageCoachAdViewed() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(MESSAGE_COACH_AD_VIEWED_KEY) ?? false;
  }
  
  // Mesaj koçu reklam izlenme durumunu işaretle
  Future<bool> setMessageCoachAdViewed(bool viewed) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(MESSAGE_COACH_AD_VIEWED_KEY, viewed);
  }
  
  // Alternatif öneri kilidi açık mı?
  Future<bool> areAlternativeSuggestionsUnlocked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(ALTERNATIVE_SUGGESTIONS_UNLOCKED_KEY) ?? false;
  }
  
  // Alternatif öneri kilidini aç
  Future<bool> unlockAlternativeSuggestions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(ALTERNATIVE_SUGGESTIONS_UNLOCKED_KEY, true);
  }
  
  // Yanıt senaryoları kilidi açık mı?
  Future<bool> areResponseScenariosUnlocked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(RESPONSE_SCENARIOS_UNLOCKED_KEY) ?? false;
  }
  
  // Yanıt senaryoları kilidini aç
  Future<bool> unlockResponseScenarios() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(RESPONSE_SCENARIOS_UNLOCKED_KEY, true);
  }
  
  // Özellikleri sıfırla (test amaçlı)
  Future<void> resetFeatureUsage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(DAILY_VISUAL_OCR_COUNT_KEY);
    await prefs.remove(DAILY_VISUAL_OCR_DATE_KEY);
    await prefs.remove(TXT_ANALYSIS_USED_COUNT_KEY);
    await prefs.remove(WRAPPED_OPENED_ONCE_KEY);
    await prefs.remove(FIRST_TIME_VISUAL_OCR_KEY);
    
    // Mesaj koçu ile ilgili verileri de sıfırla
    await prefs.remove(MESSAGE_COACH_FIRST_USE_KEY);
    await prefs.remove(MESSAGE_COACH_AD_VIEWED_KEY);
    await prefs.remove(ALTERNATIVE_SUGGESTIONS_UNLOCKED_KEY);
    await prefs.remove(RESPONSE_SCENARIOS_UNLOCKED_KEY);
    await prefs.remove(MESSAGE_COACH_TEXTS_UNLOCKED_KEY);
    await prefs.remove(POSITIVE_RESPONSE_UNLOCKED_KEY);
    await prefs.remove(NEGATIVE_RESPONSE_UNLOCKED_KEY);
    
    // Mesaj koçu metin öğe kilitlerini sıfırlama
    // Son 50 index için kontrol et ve sil
    for (int i = 0; i < 50; i++) {
      await prefs.remove('$MESSAGE_COACH_TEXT_ITEM_UNLOCKED_PREFIX$i');
    }
    
    // Görsel mod ile ilgili verileri sıfırla
    await prefs.remove(VISUAL_MODE_AD_VIEWED_KEY);
    await prefs.remove(POSITIVE_RESPONSE_SCENARIO_UNLOCKED_KEY);
    await prefs.remove(NEGATIVE_RESPONSE_SCENARIO_UNLOCKED_KEY);
    await prefs.remove(VISUAL_ALTERNATIVE_SUGGESTIONS_UNLOCKED_KEY);
  }

  // Kullanıcının belirli bir özelliği kullanabilme durumunu kontrol et
  Future<bool> canUseFeature(PremiumFeature feature, bool isPremium) async {
    if (isPremium) {
      return true; // Premium kullanıcı her zaman kullanabilir
    }

    switch (feature) {
      case PremiumFeature.VISUAL_OCR:
        final int count = await getDailyVisualOcrCount();
        return count < 5; // Günde 5 kullanım hakkı
      
      case PremiumFeature.TXT_ANALYSIS:
        final int count = await getTxtAnalysisUsedCount();
        return count < 3; // Toplam 3 kullanım hakkı
      
      case PremiumFeature.WRAPPED_ANALYSIS:
        final bool openedOnce = await getWrappedOpenedOnce();
        return !openedOnce; // Sadece 1 kez açılabilir
      
      case PremiumFeature.CONSULTATION:
        return false; // Danışma özelliği sadece premium için
        
      case PremiumFeature.MESSAGE_COACH:
        // İlk kullanım ücretsiz, sonraki kullanımlar reklam gerektirir
        bool isFirstTime = await isFirstTimeMessageCoach();
        if (isFirstTime) {
          return true;
        }
        
        // Reklam izlendiyse kullanabilir
        bool adViewed = await isMessageCoachAdViewed();
        return adViewed;
        
      case PremiumFeature.ALTERNATIVE_SUGGESTIONS:
        // Alternatif öneriler için reklam gereklidir
        return await areAlternativeSuggestionsUnlocked();
        
      case PremiumFeature.RESPONSE_SCENARIOS:
        // Yanıt senaryoları için reklam gereklidir
        return await areResponseScenariosUnlocked();
        
      case PremiumFeature.VISUAL_MODE:
        // Görsel mod için ilk kullanım kontrolü
        bool isFirstUseCompleted = await isVisualModeFirstUseCompleted();
        // İlk kullanım tamamlanmamışsa kullanabilir (1 kez için)
        // İlk kullanım tamamlanmışsa sadece premium kullanıcılar kullanabilir
        return !isFirstUseCompleted || isPremium;
        
      case PremiumFeature.VISUAL_ALTERNATIVE_SUGGESTIONS:
        // Görsel mod alternatif öneriler için her seferinde reklam gerekli
        return await isVisualAlternativeSuggestionsUnlocked();
        
      case PremiumFeature.VISUAL_POSITIVE_SCENARIO:
        // Olumlu yanıt senaryosu için 1 kez reklam gerekli
        return await isPositiveResponseScenarioUnlocked();
        
      case PremiumFeature.VISUAL_NEGATIVE_SCENARIO:
        // Olumsuz yanıt senaryosu için 1 kez reklam gerekli
        return await isNegativeResponseScenarioUnlocked();
    }
  }

  // Olumlu yanıt senaryosu kilidi açık mı kontrolü
  Future<bool> isPositiveResponseUnlocked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(POSITIVE_RESPONSE_UNLOCKED_KEY) ?? false;
  }
  
  // Olumlu yanıt senaryosu kilidini aç
  Future<bool> unlockPositiveResponse() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(POSITIVE_RESPONSE_UNLOCKED_KEY, true);
  }
  
  // Olumsuz yanıt senaryosu kilidi açık mı kontrolü
  Future<bool> isNegativeResponseUnlocked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(NEGATIVE_RESPONSE_UNLOCKED_KEY) ?? false;
  }
  
  // Olumsuz yanıt senaryosu kilidini aç
  Future<bool> unlockNegativeResponse() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(NEGATIVE_RESPONSE_UNLOCKED_KEY, true);
  }
}

// Premium özellikleri tanımlayan enum
enum PremiumFeature {
  VISUAL_OCR,           // Görsel analizi
  TXT_ANALYSIS,         // Metin dosyası analizi
  WRAPPED_ANALYSIS,     // Wrapped tarzı analiz
  CONSULTATION,         // Danışma
  MESSAGE_COACH,        // Mesaj koçu
  ALTERNATIVE_SUGGESTIONS, // Alternatif öneriler
  RESPONSE_SCENARIOS,    // Yanıt senaryoları
  VISUAL_MODE,           // Görsel mod
  VISUAL_ALTERNATIVE_SUGGESTIONS, // Görsel mod alternatif öneriler
  VISUAL_POSITIVE_SCENARIO, // Görsel mod olumlu senaryo
  VISUAL_NEGATIVE_SCENARIO, // Görsel mod olumsuz senaryo
} 