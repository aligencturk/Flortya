import 'package:shared_preferences/shared_preferences.dart';

class PremiumService {
  static const String DAILY_VISUAL_OCR_COUNT_KEY = 'dailyVisualOcrCount';
  static const String DAILY_VISUAL_OCR_DATE_KEY = 'dailyVisualOcrDate';
  static const String TXT_ANALYSIS_USED_COUNT_KEY = 'txtAnalysisUsedCount';
  static const String WRAPPED_OPENED_ONCE_KEY = 'wrappedOpenedOnce';
  static const String FIRST_TIME_VISUAL_OCR_KEY = 'firstTimeVisualOcr';

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

  // TXT analizi kullanım sayısını kontrol et
  Future<int> getTxtAnalysisUsedCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(TXT_ANALYSIS_USED_COUNT_KEY) ?? 0;
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
    }
  }

  // Özellikleri sıfırla (test amaçlı)
  Future<void> resetFeatureUsage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(DAILY_VISUAL_OCR_COUNT_KEY);
    await prefs.remove(DAILY_VISUAL_OCR_DATE_KEY);
    await prefs.remove(TXT_ANALYSIS_USED_COUNT_KEY);
    await prefs.remove(WRAPPED_OPENED_ONCE_KEY);
    await prefs.remove(FIRST_TIME_VISUAL_OCR_KEY);
  }
}

// Premium özellikleri tanımlayan enum
enum PremiumFeature {
  VISUAL_OCR,      // Görselden analiz
  TXT_ANALYSIS,    // TXT dosyasından analiz
  WRAPPED_ANALYSIS, // Spotify Wrapped tarzı analiz
  CONSULTATION     // Danışma
} 