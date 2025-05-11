import 'package:shared_preferences/shared_preferences.dart';

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