import 'package:shared_preferences/shared_preferences.dart';

/// İlişki değerlendirmesi özelliklerine erişim kontrolü yapan servis sınıfı
class RelationshipAccessService {
  // Anahtar sabitleri
  static const String RELATIONSHIP_TEST_COUNT_KEY = 'relationshipTestCount';
  static const String RELATIONSHIP_TEST_DATE_KEY = 'relationshipTestDate';
  static const String RELATIONSHIP_TEST_AD_VIEWED_KEY = 'relationshipTestAdViewed';
  static const String REPORT_VIEW_COUNT_KEY = 'reportViewCount';
  static const String REPORT_REGENERATE_COUNT_KEY = 'reportRegenerateCount';
  static const String UNLOCKED_SUGGESTIONS_KEY = 'unlockedSuggestions';

  // İlişki testi kullanım sayısını kontrol et
  Future<int> getRelationshipTestCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? dateStr = prefs.getString(RELATIONSHIP_TEST_DATE_KEY);
    final DateTime now = DateTime.now();
    final String today = "${now.year}-${now.month}-${now.day}";

    // Tarih değişmişse sayacı sıfırla (günlük sayaç)
    if (dateStr == null || dateStr != today) {
      await prefs.setString(RELATIONSHIP_TEST_DATE_KEY, today);
      await prefs.setInt(RELATIONSHIP_TEST_COUNT_KEY, 0);
      await prefs.setBool(RELATIONSHIP_TEST_AD_VIEWED_KEY, false);
      return 0;
    }

    // Mevcut kullanım sayısını döndür
    return prefs.getInt(RELATIONSHIP_TEST_COUNT_KEY) ?? 0;
  }

  // İlişki testi kullanım hakkını artır
  Future<bool> incrementRelationshipTestCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int currentCount = await getRelationshipTestCount();
    return prefs.setInt(RELATIONSHIP_TEST_COUNT_KEY, currentCount + 1);
  }

  // Reklam izleme durumunu kaydet
  Future<bool> setRelationshipTestAdViewed(bool viewed) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(RELATIONSHIP_TEST_AD_VIEWED_KEY, viewed);
  }

  // Reklam izleme durumunu kontrol et
  Future<bool> getRelationshipTestAdViewed() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(RELATIONSHIP_TEST_AD_VIEWED_KEY) ?? false;
  }

  // İlişki testi kullanma hakkı var mı?
  Future<bool> canUseRelationshipTest(bool isPremium) async {
    // Premium kullanıcılar her zaman kullanabilir
    if (isPremium) return true;

    // Mevcut kullanım sayısını al
    final int count = await getRelationshipTestCount();
    
    // İlk 3 hak ücretsiz
    if (count < 3) return true;
    
    // 3-6 arası hak için reklam izlenmiş mi kontrol et
    if (count >= 3 && count < 6) {
      final bool adViewed = await getRelationshipTestAdViewed();
      return adViewed;
    }
    
    // 6'dan fazla kullanım için premium gerekli
    return false;
  }

  // Rapor görüntüleme sayısını al
  Future<int> getReportViewCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(REPORT_VIEW_COUNT_KEY) ?? 0;
  }

  // Rapor görüntüleme sayısını artır
  Future<bool> incrementReportViewCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int currentCount = await getReportViewCount();
    return prefs.setInt(REPORT_VIEW_COUNT_KEY, currentCount + 1);
  }

  // Rapor görüntüleme hakkı var mı?
  Future<bool> canViewReport(bool isPremium) async {
    // Premium kullanıcılar her zaman görüntüleyebilir
    if (isPremium) return true;
    
    // Standart kullanıcılar için reklam her seferinde gerekli
    return true; // Her zaman reklam izleyerek açabilirler
  }

  // Rapor yeniden oluşturma sayısını al
  Future<int> getReportRegenerateCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(REPORT_REGENERATE_COUNT_KEY) ?? 0;
  }

  // Rapor yeniden oluşturma sayısını artır
  Future<bool> incrementReportRegenerateCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int currentCount = await getReportRegenerateCount();
    return prefs.setInt(REPORT_REGENERATE_COUNT_KEY, currentCount + 1);
  }

  // Raporu yeniden oluşturma hakkı var mı?
  Future<bool> canRegenerateReport(bool isPremium) async {
    // Premium kullanıcılar her zaman yeniden oluşturabilir
    if (isPremium) return true;
    
    // Standart kullanıcılar için 1 kez reklam izleyerek açabilirler
    final int count = await getReportRegenerateCount();
    return count < 1;
  }

  // Belirli bir öneriyi açma durumunu kaydet
  Future<bool> unlockSuggestion(int index) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Açılmış önerilerin listesini al
    final List<String> unlockedSuggestions = prefs.getStringList(UNLOCKED_SUGGESTIONS_KEY) ?? [];
    
    // Bu öneri daha önce açılmamışsa ekle
    if (!unlockedSuggestions.contains(index.toString())) {
      unlockedSuggestions.add(index.toString());
      return prefs.setStringList(UNLOCKED_SUGGESTIONS_KEY, unlockedSuggestions);
    }
    
    return true;
  }

  // Bir öneri kilidinin açılıp açılmadığını kontrol et
  Future<bool> isSuggestionUnlocked(int index, bool isPremium) async {
    // Premium kullanıcılar için tüm öneriler açık
    if (isPremium) return true;
    
    // İlk öneri herkese açık
    if (index == 0) return true;
    
    // Diğerleri için kayıtlı durumu kontrol et
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> unlockedSuggestions = prefs.getStringList(UNLOCKED_SUGGESTIONS_KEY) ?? [];
    
    return unlockedSuggestions.contains(index.toString());
  }

  // Açılan önerilerin listesini al
  Future<List<String>> getUnlockedSuggestions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(UNLOCKED_SUGGESTIONS_KEY) ?? [];
  }

  // Test amaçlı tüm verileri sıfırla
  Future<void> resetAllData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(RELATIONSHIP_TEST_COUNT_KEY);
    await prefs.remove(RELATIONSHIP_TEST_DATE_KEY);
    await prefs.remove(RELATIONSHIP_TEST_AD_VIEWED_KEY);
    await prefs.remove(REPORT_VIEW_COUNT_KEY);
    await prefs.remove(REPORT_REGENERATE_COUNT_KEY);
    await prefs.remove(UNLOCKED_SUGGESTIONS_KEY);
  }
} 