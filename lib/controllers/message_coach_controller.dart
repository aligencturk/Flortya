import 'package:flutter/material.dart';
import 'dart:io';
import '../models/message_coach_analysis.dart';
import '../models/past_message_coach_analysis.dart';
import '../models/message_coach_visual_analysis.dart';
import '../services/ai_service.dart';
import '../services/logger_service.dart';
import '../services/message_coach_service.dart';
import '../services/premium_service.dart';

class MessageCoachController extends ChangeNotifier {
  final AiService _aiService = AiService();
  final LoggerService _logger = LoggerService();
  final MessageCoachService _mesajKocuService = MessageCoachService();
  final PremiumService _premiumService = PremiumService();
  
  MessageCoachAnalysis? _analysis;
  MessageCoachAnalysis? get analysis => _analysis;
  
  String _errorMessage = '';
  String get errorMessage => _errorMessage;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  bool _analizTamamlandi = false;
  bool get analizTamamlandi => _analizTamamlandi;
  
  // Görsel analizi ile ilgili değişkenler
  File? _gorselDosya;
  File? get gorselDosya => _gorselDosya;
  
  bool _gorselModu = false;
  bool get gorselModu => _gorselModu;
  
  String? _gorselOcrSonucu;
  String? get gorselOcrSonucu => _gorselOcrSonucu;
  
  // Mesaj koçu analizi geçmişi
  List<MessageCoachAnalysis> _analizGecmisi = [];
  List<MessageCoachAnalysis> get analizGecmisi => _analizGecmisi;
  
  // UI metinleri
  String get baslik => 'Mesaj Koçu';
  String get aciklamaBaslik => 'Sohbet Analizi';
  String get aciklamaMetni => 'Sohbet geçmişinizi analiz etmek için kopyala-yapıştır yapın veya bir görsel yükleyin. Mesaj Koçu sohbetin genel havasını ve son mesajınızın etkisini analiz edecek.';
  String get dosyaSecmeButonMetni => 'Dosyadan Yükle';
  String get yuklemeMetni => _gorselModu 
      ? 'Görsel analiz ediliyor...' 
      : 'Sohbet analiz ediliyor...';
  
  String? _currentUserId;
  
  // Premium bilgileri
  int _kalanGorselAnalizHakki = 3;
  bool _reklamGoruldu = false;
  
  int get kalanGorselAnalizHakki => _kalanGorselAnalizHakki;
  bool get reklamGoruldu => _reklamGoruldu;
  
  // Kullanıcı ID'sini set etme metodu
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    _logger.i('Kullanıcı ID ayarlandı: $userId');
    
    // Kullanıcı ID'si ayarlandığında kalan hak bilgisini güncelle
    _gorselAnalizHakkiniGuncelle();
  }
  
  // Görsel analiz hakkını güncelleme
  Future<void> _gorselAnalizHakkiniGuncelle() async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        _kalanGorselAnalizHakki = 5; // Default olarak 5 hak (3 yerine 5 kullanım)
        return;
      }
      
      // Kullanıcının premium olup olmadığını kontrol et
      // Bu kısmı AuthViewModel üzerinden almanız gerekebilir, şimdilik false kabul ediyoruz
      bool isPremium = false; // Bu değerin gerçek değerini almalısınız
      
      if (isPremium) {
        _kalanGorselAnalizHakki = -1; // -1 sınırsız anlamına gelir
      } else {
        int kullanilan = await _premiumService.getDailyVisualOcrCount();
        _kalanGorselAnalizHakki = 5 - kullanilan; // 5 hak (3 yerine 5 kullanım)
        if (_kalanGorselAnalizHakki < 0) _kalanGorselAnalizHakki = 0;
      }
      
      notifyListeners();
    } catch (e) {
      _logger.e('Görsel analiz hakkı güncellenirken hata: $e');
    }
  }
  
  // Analiz sonuçlarını temizle
  void analizSonuclariniSifirla() {
    _analysis = null;
    _errorMessage = '';
    _analizTamamlandi = false;
    _gorselDosya = null;
    _gorselOcrSonucu = null;
    notifyListeners();
  }
  
  // Analiz geçmişini temizle
  void analizGecmisiniSifirla() {
    _analizGecmisi = [];
    notifyListeners();
  }
  
  // Görsel modu değiştirme (açma/kapama)
  void gorselModunuDegistir() {
    _gorselModu = !_gorselModu;
    _logger.i('Görsel modu değiştirildi: $_gorselModu');
    
    // Mevcut analiz sonuçlarını temizle
    analizSonuclariniSifirla();
    notifyListeners();
  }
  
  // Görsel belirle
  void gorselBelirle(File gorsel) {
    _gorselDosya = gorsel;
    _gorselModu = true;
    _logger.i('Görsel belirlendi: ${gorsel.path}');
    notifyListeners();
  }
  
  // Görsel modunu temizle
  void gorselModunuTemizle() {
    _gorselModu = false;
    _gorselDosya = null;
    _gorselOcrSonucu = null;
    notifyListeners();
  }

  // OCR sonucunu ayarla
  void gorselMetniniBelirle(String ocrMetni) {
    _gorselOcrSonucu = ocrMetni;
    notifyListeners();
  }

  // Analiz sonucunun geçersiz olup olmadığını kontrol et
  bool _analizSonucuGecersiziMi(MessageCoachAnalysis analiz) {
    // Sadece boş veya net hata mesajları olan alanları kontrol et
    
    // Sohbet genel havası kontrolü - sadece açık hata durumları
    if (analiz.sohbetGenelHavasi == null || 
        analiz.sohbetGenelHavasi!.isEmpty || 
        analiz.sohbetGenelHavasi!.toLowerCase() == 'analiz edilemedi' || 
        analiz.sohbetGenelHavasi!.toLowerCase() == 'null' ||
        analiz.sohbetGenelHavasi!.toLowerCase().contains('yeterli içerik') ||
        analiz.sohbetGenelHavasi!.toLowerCase().contains('için yeterli') ||
        analiz.sohbetGenelHavasi!.toLowerCase().contains('için yet')) {
      return true;
    }
    
    // Genel yorum kontrolü - sadece açık hata durumları
    if (analiz.genelYorum == null || 
        analiz.genelYorum!.isEmpty || 
        analiz.genelYorum!.toLowerCase() == 'analiz sonucu alınamadı' || 
        analiz.genelYorum!.toLowerCase().contains('alınamadı') ||
        analiz.genelYorum!.toLowerCase() == 'null') {
      return true;
    }
    
    // Son mesaj tonu kontrolü - sadece açık hata durumları
    if (analiz.sonMesajTonu == null || 
        analiz.sonMesajTonu!.isEmpty || 
        analiz.sonMesajTonu!.toLowerCase() == 'belirlenemedi' || 
        analiz.sonMesajTonu!.toLowerCase() == 'analiz edilemedi' ||
        analiz.sonMesajTonu!.toLowerCase().contains('yeterli') ||
        analiz.sonMesajTonu!.toLowerCase() == 'null') {
      return true;
    }
    
    // Direkt yorum kontrolü - sadece boş veya null durumları
    if (analiz.direktYorum == null || 
        analiz.direktYorum!.isEmpty || 
        analiz.direktYorum! == 'null') {
      return true;
    }
    
    // Son mesaj etkisi kontrolü - sadece boş veya format hatası durumları
    if (analiz.sonMesajEtkisi == null || analiz.sonMesajEtkisi!.isEmpty) {
      return true;
    }
    
    // Herhangi bir alanda JSON veya API hatası varsa
    final List<String> hataKelimeleri = ['json error', 'api hatası', 'error:', 'exception:'];
    
    // Hata kelimelerini ara
    for (final kelime in hataKelimeleri) {
      if ((analiz.direktYorum != null && analiz.direktYorum!.toLowerCase().contains(kelime)) ||
          (analiz.genelYorum != null && analiz.genelYorum!.toLowerCase().contains(kelime))) {
        return true;
      }
    }
    
    return false;
  }
  
  // Sohbet içeriği geçerli mi kontrol et
  bool sohbetGecerliMi(String sohbet) {
    if (sohbet.trim().isEmpty) {
      return false;
    }
    
    if (sohbet.length < 10) {
      _logger.w('Sohbet içeriği çok kısa: ${sohbet.length} karakter');
      return false;
    }
    
    return true;
  }
  
  // Örnek sohbet içeriği oluştur
  String ornekSohbetIcerigiOlustur() {
    // Rastgele örnek sohbet oluştur
    final List<String> ornekSohbetler = [
      '''
Ben: Merhaba, nasılsın?
Karşı taraf: İyiyim, sen nasılsın?
Ben: Ben de iyiyim. Bugün neler yaptın?
Karşı taraf: İşten geldim, biraz yorgunum. Sen?
Ben: Ben de bugün çok yoğundum. Akşam bir şeyler yapmak ister misin?
Karşı taraf: Bu akşam biraz dinlenmek istiyorum, yarın olsa?
Ben: Tabii, yarın olabilir. Ne yapmak istersin?
Karşı taraf: Sinemaya gidebiliriz.
Ben: Güzel fikir. Saat 7'de müsait misin?
Karşı taraf: Evet, olur. 7'de sinema önünde buluşalım.
      ''',
      
      '''
Ben: Geçen gün konuştuğumuz konu hakkında düşündüm.
Karşı taraf: Hangi konu?
Ben: Tatil planı yapmamız gerektiğini söylemiştim ya.
Karşı taraf: Hatırladım. Ne düşündün?
Ben: Belki bir hafta sonu Antalya'ya gidebiliriz?
Karşı taraf: Hmm, bilmiyorum, biraz pahalı olabilir şu aralar.
Ben: Tamam, bütçeye uygun bir şeyler düşünürüz o zaman.
Karşı taraf: Bence şehir dışına çıkmadan da güzel vakit geçirebiliriz.
Ben: Önerin var mı?
Karşı taraf: Piknik yapabiliriz mesela.
      ''',
      
      '''
Ben: Son mesajımı görmediğin için merak ettim, iyi misin?
Karşı taraf: Evet, iyiyim. Sadece biraz yoğundum.
Ben: Tamam, önemli bir şey yoktu zaten. Ne zaman müsait olursun?
Karşı taraf: Bu hafta sonu müsaitim.
Ben: Harika! Kahve içmek ister misin?
Karşı taraf: Olur, Cumartesi öğleden sonra uygun olur benim için.
Ben: Benim için de uygun. Saat 2'de Park Cafe'de buluşalım mı?
Karşı taraf: Tamam, orada görüşürüz.
      '''
    ];
    
    // Rastgele bir örnek seç
    return ornekSohbetler[DateTime.now().millisecond % ornekSohbetler.length];
  }
  
  // Metin açıklaması tabanlı analiz (görsel olmadan)
  Future<bool> metinAciklamasiIleAnalizeEt(String aciklama) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      _analizTamamlandi = false;
      notifyListeners();
      
      _logger.i('Metin açıklaması ile analiz başlatılıyor: $aciklama');
      
      // Açıklama boş kontrolü
      if (aciklama.trim().isEmpty) {
        _setError('Lütfen bir açıklama yazın');
        return false;
      }
      
      // AiService üzerinden analiz yap - yeni eklenen metodu kullan
      final analiz = await _aiService.sadeceMesajAnalizeEt(aciklama);
      
      if (analiz == null) {
        _setError('Analiz yapılamadı. Lütfen tekrar deneyin.');
        return false;
      }
      
      // Analiz sonucunu ayarla
      _analysis = analiz;
      _analizTamamlandi = true;
      
      // Analiz sonucunu kullanıcı verilerine kaydet
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        await _mesajKocuService.saveMessageCoachAnalysis(
          userId: _currentUserId!,
          sohbetIcerigi: '', // Metin açıklamısı analizi olduğu için boş
          aciklama: aciklama,
          analysis: analiz
        );
        _logger.i('Metin açıklaması analizi kullanıcı verilerine kaydedildi');
      }
      
      // Analizi geçmişe ekle
      _analizGecmisiniGuncelle(analiz);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _logger.e('Metin açıklaması analizi hatası', e);
      _setError('Beklenmeyen bir hata oluştu: $e');
      return false;
    }
  }
  
  // Görsel ile analiz et
  Future<void> gorselIleAnalizeEt(File gorselDosyasi, String aciklama) async {
    try {
      // Önişlem kontrolü
      bool isPremium = false;
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        // Kullanıcının premium olup olmadığını kontrol et
        // Bu kısmı AuthViewModel üzerinden almanız gerekebilir, şimdilik false kabul ediyoruz
        isPremium = false; // Bu değerin gerçek değerini almalısınız
      }
      
      // Premium değilse görsel OCR kullanım hakkını kontrol et
      if (!isPremium) {
        bool canUseVisualOcr = await _premiumService.canUseFeature(PremiumFeature.VISUAL_OCR, isPremium);
        
        if (!canUseVisualOcr) {
          _errorMessage = 'Günlük görsel analiz hakkınız doldu. Premium üyelik ile sınırsız kullanabilirsiniz.';
          notifyListeners();
          return;
        }
        
        // Reklam gösterme kontrolü
        bool isFirstTime = await _premiumService.isFirstTimeVisualOcr();
        
        if (isFirstTime) {
          // İlk kullanımda reklam gösterme
          _logger.i('İlk görsel analizi kullanımı: reklam gösterilmiyor');
          await _premiumService.markFirstTimeVisualOcrUsed(); // İlk kullanımı işaretle
        } else {
          // İlk kullanım değilse, reklam göster
          _reklamGoruldu = true;
          _logger.i('Reklam gösteriliyor...');
          
          // Burada reklam gösterildiğini simüle ediyoruz
          // Gerçek entegrasyonda AdMob, Unity Ads vb. kullanılacak
          await Future.delayed(const Duration(seconds: 2)); // Reklam yükleme simülasyonu
          
          // Gerçek uygulama için burada bir callback olacak
          // Reklam izlendikten sonra devam edecek
          _logger.i('Reklam izleme tamamlandı');
        }
        
        // Kullanım sayısını artır
        await _premiumService.incrementDailyVisualOcrCount();
        
        // Kalan hak bilgisini güncelle
        await _gorselAnalizHakkiniGuncelle();
        
        // Günlük limit durumunu kontrol et ve kullanıcıya bilgi ver
        if (_kalanGorselAnalizHakki <= 0) {
          _logger.i('Günlük görsel analiz hakkı doldu. Premium teklif edilecek.');
        } else {
          _logger.i('Kalan görsel analiz hakkı: $_kalanGorselAnalizHakki');
        }
      }
      
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();
      
      // Görsel dosyasını ayarla
      _gorselDosya = gorselDosyasi;
      
      // Görsel ile analiz servisini çağır
      final sonuc = await _mesajKocuService.sohbetGoruntusunuAnalizeEt(gorselDosyasi, aciklama);
      
      if (sonuc == null) {
        _errorMessage = 'Analiz sonucu alınamadı, lütfen tekrar deneyin';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      if (sonuc.isAnalysisRedirect) {
        // Görsel analizi yerine metin analizi yönlendirmesi varsa
        _logger.i('Görsel analizi yerine metin analizi yönlendirmesi yapılıyor');
        
        // Bu durumda metni AI'dan dönen yönlendirme mesajı olarak kullan
        _analysis = MessageCoachAnalysis(
          analiz: "Görsel analiz edilemedi",
          oneriler: [],
          etki: {'Nötr': 100},
          sohbetGenelHavasi: "Görsel analiz edilemedi",
          direktYorum: sonuc.redirectMessage ?? "Görsel analiz edilemedi, lütfen tekrar deneyin",
          sonMesajTonu: "Nötr"
        );
      } else {
        // Görsel analiz sonucunu MessageCoachAnalysis formatına dönüştür
        final String gulmeIfadeleriNotu = ""; // Boş gülme ifadeleri notu
        _analysis = _gorselAnalizdenMesajAnalizineDonus(sonuc, aciklama, gulmeIfadeleriNotu);
        _logger.i('Görsel analiz sonucu başarıyla MessageCoachAnalysis formatına dönüştürüldü');
      }
      
      // İşlem tamamlandığında reklam durumunu sıfırla
      _reklamGoruldu = false;
      
      // Kullanıcı oturum açmışsa geçmişe kaydet
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        await _mesajKocuService.saveVisualMessageCoachAnalysis(
          userId: _currentUserId!,
          aciklama: aciklama,
          analysis: sonuc
        );
      }
      
      _analizTamamlandi = true;
      _isLoading = false;
      notifyListeners();
      
      _logger.i('Görsel analizi tamamlandı, UI güncelleniyor');
    } catch (e) {
      _logger.e('Görsel analiz hatası: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      _reklamGoruldu = false; // Hata durumunda reklam durumunu sıfırla
      notifyListeners();
    }
  }
  
  // Metinde gülmeyi temsil eden anlamsız harf dizilerini (keyboard smash) tespit eden yardımcı fonksiyon
  List<String> _gulmeIfadeleriniTespit(String metin) {
    List<String> tespitiEdilenIfadeler = [];
    
    // Metni kelimelere ayır
    final List<String> kelimeler = metin.split(RegExp(r'[\s,.!?]+'));
    
    // Bilinen gülme kalıpları
    final List<RegExp> bilinenGulmeKaliplari = [
      RegExp(r'h[aei]+h[aei]+h[aei]+', caseSensitive: false), // hahaha, hehehe, hihihi
      RegExp(r'(s+j+s+j+|j+s+j+s+)', caseSensitive: false),   // sjsj, sjsjsj, jsjs
      RegExp(r'k+s+k+s+', caseSensitive: false),              // ksks, ksksk
      RegExp(r'(a+s+d+|d+s+a+)', caseSensitive: false),       // asdasd, dsa
      RegExp(r'l+o+l+', caseSensitive: false),                // lol
      RegExp(r'(p+t+r+|m+r+b+)', caseSensitive: false),       // ptr, mrb
      RegExp(r'(x+d+|d+x+)', caseSensitive: false),           // xd, xdxd
      RegExp(r'j+d+m', caseSensitive: false),                 // jdm
      RegExp(r'l+m+a+o+', caseSensitive: false),              // lmao
    ];
    
    for (String kelime in kelimeler) {
      // En az 4 karakter uzunluğunda olmalı - bazı gülme ifadeleri 3 karakter (xd, lol) olabilir, minimum karakter sayısını düşürelim
      if (kelime.length < 3) continue;
      
      // Öncelikle bilinen gülme ifadelerini kontrol et
      bool bilinenGulmeIfadesi = false;
      for (RegExp kalip in bilinenGulmeKaliplari) {
        if (kalip.hasMatch(kelime)) {
          tespitiEdilenIfadeler.add(kelime);
          bilinenGulmeIfadesi = true;
          break;
        }
      }
      
      // Bilinen bir gülme ifadesi yakalandıysa diğer kontrolleri atla
      if (bilinenGulmeIfadesi) continue;
      
      // Emojileri gülme ifadesi olarak tanıma
      if (RegExp(r':D|;\)|:\)|:p|:P', caseSensitive: false).hasMatch(kelime)) {
        tespitiEdilenIfadeler.add(kelime);
        continue;
      }
      
      // Sadece harflerden oluşmalı (rakam veya özel karakter olmamalı)
      if (!RegExp(r'^[a-zA-ZğüşıöçĞÜŞİÖÇ]+$').hasMatch(kelime)) continue;
      
      // Anlamsız harf dizisi tanıma kriterleri:
      
      // 1. Kelime 4+ karakter ve ardışık 3+ sesli harf içermemelidir (anlamsız harf dizilerinde sesli harfler genelde dağınıktır)
      bool ardisikSesliHarfVar = RegExp(r'[aeıioöuüAEIİOÖUÜ]{3,}').hasMatch(kelime);
      if (ardisikSesliHarfVar) continue;
      
      // 2. Standart Türkçe kelimeler bir harfin 3+ kez tekrarını genelde içermez
      bool ayniHarfTekrari = RegExp(r'(.)\1{2,}').hasMatch(kelime);
      if (ayniHarfTekrari) {
        // Ancak, "hahahaha" gibi tekrarlar gülme olabilir
        if (RegExp(r'(ha)+|(he)+|(hi)+', caseSensitive: false).hasMatch(kelime)) {
          tespitiEdilenIfadeler.add(kelime);
          continue;
        }
        // Normal bir kelimede olmamalı
        continue;
      }
      
      // 3. Harflerin dağılımı düzgün olmamalı - aynı harfler rastgele dağılır
      Set<String> benzersizHarfler = kelime.split('').toSet();
      double benzersizOrani = benzersizHarfler.length / kelime.length;
      
      // 4. Tekrar eden iki harf grubu olmamalı (aşırı düzenli bir kelime değil)
      bool tekrarEdenIkiliVar = false;
      for (int i = 0; i < kelime.length - 1; i++) {
        String ikili = kelime.substring(i, i + 2);
        if (kelime.indexOf(ikili, i + 2) != -1) {
          tekrarEdenIkiliVar = true;
          break;
        }
      }
      
      // 5. Kelime en az %60 oranında benzersiz harflerden oluşmalı ve tekrar eden ikili olmamalı
      if (benzersizOrani >= 0.6 && !tekrarEdenIkiliVar) {
        // Bu muhtemelen bir gülme ifadesidir (keyboard smash)
        tespitiEdilenIfadeler.add(kelime);
      }
    }
    
    return tespitiEdilenIfadeler;
  }
  
  // Görsel analiz sonuçlarını MessageCoachAnalysis formatına dönüştürme
  MessageCoachAnalysis _gorselAnalizdenMesajAnalizineDonus(
      MessageCoachVisualAnalysis gorselAnaliz, 
      String aciklama, 
      String gulmeIfadeleriNotu) {
    // Alternatif mesaj önerilerini cevap önerilerine dönüştür
    List<String> cevapOnerileri = gorselAnaliz.alternativeMessages;
    
    // Potansiyel partner yanıtlarından olumlu ve olumsuz senaryoları al
    String? olumluCevap;
    String? olumsuzCevap;
    if (gorselAnaliz.partnerResponses.isNotEmpty) {
      olumluCevap = gorselAnaliz.partnerResponses.isNotEmpty ? gorselAnaliz.partnerResponses[0] : null;
      olumsuzCevap = gorselAnaliz.partnerResponses.length > 1 ? gorselAnaliz.partnerResponses[1] : null;
    }
    
    // Açıklamada gülme ifadeleri var mı kontrol et
    List<String> gulmeIfadeleri = _gulmeIfadeleriniTespit(aciklama);
    bool gulmeIfadesiVarMi = gulmeIfadeleri.isNotEmpty || gulmeIfadeleriNotu.isNotEmpty;
    
    // Gülme ifadesi varsa mesaj tonunu ve analizi güncelle
    String mesajTonu = 'Görsel';
    String? genelYorum = gorselAnaliz.konumDegerlendirmesi;
    
    if (gulmeIfadesiVarMi) {
      mesajTonu = 'Esprili/Eğlenceli';
      
      // Önemli: Yeni talimatımız gereği, gülme ifadelerini direkt belirteceğiz
      if (genelYorum == null || genelYorum.isEmpty) {
        genelYorum = "Mesajda güldüğün anlaşılıyor. Bu samimi ve eğlenceli bir ton kattığını gösteriyor.";
      } 
      else if (!genelYorum.toLowerCase().contains("gül") && 
               !genelYorum.toLowerCase().contains("esprili") && 
               !genelYorum.toLowerCase().contains("espri") &&
               !genelYorum.toLowerCase().contains("mizah")) {
        genelYorum = "$genelYorum Ayrıca mesajında güldüğün anlaşılıyor, bu samimi ve eğlenceli bir ton katıyor.";
      }
    }
    
    // Etki değerlerini ayarla
    Map<String, int> etkiDegerleri = {'Görsel': 100};
    if (gulmeIfadesiVarMi) {
      etkiDegerleri = {
        'Eğlenceli': 70,
        'Samimi': 20,
        'Rahat': 10,
      };
    }
    
    // Gördüğüm kadarıyla, görsel analizindeki robotumsu dil (kullanıcı şunu demiş, partner bunu demiş) 
    // konumDegerlendirmesi, alternativeMessages ve partnerResponses kısımlarında olabilir.
    // Bu metinleri daha doğal hale getirelim:
    
    // Konumun değerlendirmesini iyileştir (çok robotumsu ise)
    String iyilestirilmisGenelYorum = genelYorum ?? "";
    // "Kullanıcı" ve "partner" kelimelerinin kullanımını daha doğal hale getir
    iyilestirilmisGenelYorum = iyilestirilmisGenelYorum
        .replaceAll("Kullanıcı şunu demiş:", "Görsel analiz sonucuna göre")
        .replaceAll("Partner şunu demiş:", "Karşındaki kişi")
        .replaceAll("Kullanıcı:", "Sen:")
        .replaceAll("Partner:", "Karşındaki kişi:");
    
    // "Anlamsız harf dizileri" ifadesini "gülme" olarak değiştir
    // Kapsamlı regex ifadeleri kullanarak tüm olası varyasyonları yakala
    iyilestirilmisGenelYorum = iyilestirilmisGenelYorum
        .replaceAll(RegExp(r'[Aa]nlamsız harf diz[ie][ls][ie]ri', caseSensitive: false), 'Gülme ifadeleri')
        .replaceAll(RegExp(r'[Aa]nlamsız harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlamsız dizi[^a-zA-Z]*', caseSensitive: false), 'gülme ')
        .replaceAll(RegExp(r'[Rr]astgele harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Kk]eyboard smash', caseSensitive: false), 'gülme ifadesi')
        .replaceAll(RegExp(r'[Kk]armaşık harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlamsız.*karakter', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlamsız.*yazı', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlaşılmaz.*harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Rr]astgele.*karakter', caseSensitive: false), 'Gülme ifadesi');
    
    // Tüm metindeki "anlamsız harf dizelerini" "gülme ifadeleriyle" değiştir
    for (String gulmeIfade in gulmeIfadeleri) {
      if (iyilestirilmisGenelYorum.contains(gulmeIfade)) {
        iyilestirilmisGenelYorum = iyilestirilmisGenelYorum
            .replaceAll("$gulmeIfade gibi anlamsız harf dizileri", "gülme ifadeleri")
            .replaceAll("$gulmeIfade gibi anlamsız harfler", "gülme ifadeleri")
            .replaceAll("$gulmeIfade şeklinde anlamsız karakterler", "gülme ifadeleri");
      }
    }
    
    // Direkt yorum için farklı bir içerik oluştur (hata tespiti ve tavsiyeler)
    String direktYorumIcerigi = "";
    
    if (gulmeIfadesiVarMi) {
      // Gülme ifadesi varsa, samimi ve eğlenceli bir ton tavsiye et, artık gülme ifadesinden bahsedebiliriz
      direktYorumIcerigi = "Mesajında güldüğün anlaşılıyor, bu sohbetin havasının samimi ve eğlenceli olduğunu gösteriyor. Bu tür mesajlaşmalarda karşındaki kişi rahat hissediyor olabilir. Böyle durumlarda benzer bir ton kullanman iletişimi güçlendirebilir. Karşılık verirken mizahi veya samimi bir yaklaşım sergilemen iyi olabilir.";
    } else if (iyilestirilmisGenelYorum.isNotEmpty) {
      // Genel yorumdan gelişim noktaları ve tavsiyeleri çıkar
      if (iyilestirilmisGenelYorum.contains("ancak") || iyilestirilmisGenelYorum.contains("fakat")) {
        // Eğer "ancak" veya "fakat" içeriyorsa, o kısımları direkt yorum olarak kullan
        List<String> parcalar = iyilestirilmisGenelYorum.split(RegExp(r'(ancak|fakat)'));
        if (parcalar.length > 1) {
          direktYorumIcerigi = "Geliştirilebilecek noktalar: ${parcalar[1].trim()}";
        }
      } else {
        // Yoksa, genel tavsiyeleri ekle
        direktYorumIcerigi = "Bu mesajlaşmada şunlara dikkat etmen faydalı olabilir: Karşındaki kişinin tepkilerini dikkatle izle ve iletişim tonunu ona göre ayarla. Açık ve net bir ifade kullan, yanlış anlaşılmaları önle.";
      }
    } else {
      direktYorumIcerigi = "Bu görsel analiz sonucunda özel bir gelişim noktası tespit edilmedi. Genel iletişim tavsiyesi olarak açık ve net olmaya, karşındaki kişinin tepkilerine dikkat etmeye devam et.";
    }
    
    // "Anlamsız harf" ifadelerini direkt yorumdan da temizle
    direktYorumIcerigi = direktYorumIcerigi
        .replaceAll(RegExp(r'[Aa]nlamsız harf diz[ie][ls][ie]ri', caseSensitive: false), 'Gülme ifadeleri')
        .replaceAll(RegExp(r'[Aa]nlamsız harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlamsız dizi[^a-zA-Z]*', caseSensitive: false), 'gülme ')
        .replaceAll(RegExp(r'[Rr]astgele harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Kk]eyboard smash', caseSensitive: false), 'gülme ifadesi')
        .replaceAll(RegExp(r'[Kk]armaşık harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlamsız.*karakter', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlamsız.*yazı', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlaşılmaz.*harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Rr]astgele.*karakter', caseSensitive: false), 'Gülme ifadesi');
    
    // Olumlu ve olumsuz cevap tahminlerini iyileştir
    String? iyilestirilmisOlumluCevap = olumluCevap;
    String? iyilestirilmisOlumsuzCevap = olumsuzCevap;
    
    if (iyilestirilmisOlumluCevap != null) {
      iyilestirilmisOlumluCevap = iyilestirilmisOlumluCevap
          .replaceAll("Partner:", "")
          .replaceAll("Partner şöyle cevap verebilir:", "")
          .replaceAll("Olumlu senaryo:", "");
      
      // Anlamsız harf ifadelerini gülme olarak değiştir
      iyilestirilmisOlumluCevap = iyilestirilmisOlumluCevap
          .replaceAll(RegExp(r'[Aa]nlamsız harf diz[ie][ls][ie]ri', caseSensitive: false), 'Gülme ifadeleri')
          .replaceAll(RegExp(r'[Aa]nlamsız harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlamsız dizi[^a-zA-Z]*', caseSensitive: false), 'gülme ')
          .replaceAll(RegExp(r'[Rr]astgele harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Kk]eyboard smash', caseSensitive: false), 'gülme ifadesi')
          .replaceAll(RegExp(r'[Kk]armaşık harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlamsız.*karakter', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlamsız.*yazı', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlaşılmaz.*harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Rr]astgele.*karakter', caseSensitive: false), 'Gülme ifadesi');
      
      if (!iyilestirilmisOlumluCevap.contains("yanıt") && 
          !iyilestirilmisOlumluCevap.contains("cevap") &&
          !iyilestirilmisOlumluCevap.contains("tepki")) {
        iyilestirilmisOlumluCevap = "Olumlu bir tepki alabilirsin: $iyilestirilmisOlumluCevap";
      }
    }
    
    if (iyilestirilmisOlumsuzCevap != null) {
      iyilestirilmisOlumsuzCevap = iyilestirilmisOlumsuzCevap
          .replaceAll("Partner:", "")
          .replaceAll("Partner şöyle cevap verebilir:", "")
          .replaceAll("Olumsuz senaryo:", "");
      
      // Anlamsız harf ifadelerini gülme olarak değiştir
      iyilestirilmisOlumsuzCevap = iyilestirilmisOlumsuzCevap
          .replaceAll(RegExp(r'[Aa]nlamsız harf diz[ie][ls][ie]ri', caseSensitive: false), 'Gülme ifadeleri')
          .replaceAll(RegExp(r'[Aa]nlamsız harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlamsız dizi[^a-zA-Z]*', caseSensitive: false), 'gülme ')
          .replaceAll(RegExp(r'[Rr]astgele harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Kk]eyboard smash', caseSensitive: false), 'gülme ifadesi')
          .replaceAll(RegExp(r'[Kk]armaşık harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlamsız.*karakter', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlamsız.*yazı', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlaşılmaz.*harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Rr]astgele.*karakter', caseSensitive: false), 'Gülme ifadesi');
      
      if (!iyilestirilmisOlumsuzCevap.contains("yanıt") && 
          !iyilestirilmisOlumsuzCevap.contains("cevap") &&
          !iyilestirilmisOlumsuzCevap.contains("tepki")) {
        iyilestirilmisOlumsuzCevap = "Olumsuz bir tepki alma ihtimalin de var: $iyilestirilmisOlumsuzCevap";
      }
    }
    
    // Alternatif mesaj önerilerini iyileştir
    List<String> iyilestirilmisCevapOnerileri = [];
    for (String oneri in cevapOnerileri) {
      // Önerilerdeki robotumsu dili temizle
      String iyilestirilmisOneri = oneri
          .replaceAll("Kullanıcı şöyle yazabilir:", "")
          .replaceAll("Kullanıcı:", "")
          .replaceAll("Öneri:", "")
          .replaceAll("Alternatif:", "")
          .trim();
      
      // Anlamsız harf ifadelerini gülme olarak değiştir
      iyilestirilmisOneri = iyilestirilmisOneri
          .replaceAll(RegExp(r'[Aa]nlamsız harf diz[ie][ls][ie]ri', caseSensitive: false), 'Gülme ifadeleri')
          .replaceAll(RegExp(r'[Aa]nlamsız harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlamsız dizi[^a-zA-Z]*', caseSensitive: false), 'gülme ')
          .replaceAll(RegExp(r'[Rr]astgele harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Kk]eyboard smash', caseSensitive: false), 'gülme ifadesi')
          .replaceAll(RegExp(r'[Kk]armaşık harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlamsız.*karakter', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlamsız.*yazı', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Aa]nlaşılmaz.*harf', caseSensitive: false), 'Gülme ifadesi')
          .replaceAll(RegExp(r'[Rr]astgele.*karakter', caseSensitive: false), 'Gülme ifadesi');
      
      // Eğer öneri bu şekilde başlamıyorsa, bir öneride bulunduğumuzu belirtelim
      if (!iyilestirilmisOneri.contains("öner") && 
          !iyilestirilmisOneri.contains("dene") && 
          !iyilestirilmisOneri.contains("yazabil")) {
        iyilestirilmisOneri = "Şöyle yazabilirsin: $iyilestirilmisOneri";
      }
      
      iyilestirilmisCevapOnerileri.add(iyilestirilmisOneri);
    }
    
    // Anlık tavsiyeyi iyileştir
    String anlikTavsiye = gulmeIfadesiVarMi 
      ? "Karşı taraf eğlenceli ve rahat bir mod içerisinde olabilir. Mesajında güldüğün anlaşılıyor, benzer bir ton ile cevap verebilirsin."
      : iyilestirilmisGenelYorum;
    
    // Anlık tavsiyede de anlamsız harf ifadelerini temizle
    anlikTavsiye = anlikTavsiye
        .replaceAll(RegExp(r'[Aa]nlamsız harf diz[ie][ls][ie]ri', caseSensitive: false), 'Gülme ifadeleri')
        .replaceAll(RegExp(r'[Aa]nlamsız harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlamsız dizi[^a-zA-Z]*', caseSensitive: false), 'gülme ')
        .replaceAll(RegExp(r'[Rr]astgele harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Kk]eyboard smash', caseSensitive: false), 'gülme ifadesi')
        .replaceAll(RegExp(r'[Kk]armaşık harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlamsız.*karakter', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlamsız.*yazı', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Aa]nlaşılmaz.*harf', caseSensitive: false), 'Gülme ifadesi')
        .replaceAll(RegExp(r'[Rr]astgele.*karakter', caseSensitive: false), 'Gülme ifadesi');
    
    // Eğer hiç cevap önerisi yoksa, bazı genel öneriler ekle
    if (iyilestirilmisCevapOnerileri.isEmpty && anlikTavsiye.isNotEmpty) {
      iyilestirilmisCevapOnerileri.add("Bu duruma uygun bir şekilde: ${anlikTavsiye.contains(".") ? anlikTavsiye.split(".")[0] : anlikTavsiye}");
    }
    
    return MessageCoachAnalysis(
      analiz: iyilestirilmisGenelYorum.isEmpty ? 'Görsel analiz tamamlandı' : iyilestirilmisGenelYorum,
      genelYorum: iyilestirilmisGenelYorum,
      oneriler: iyilestirilmisCevapOnerileri,
      direktYorum: direktYorumIcerigi, // Farklı içerik: hata tespiti ve tavsiyeler
      etki: etkiDegerleri,
      cevapOnerileri: iyilestirilmisCevapOnerileri, // Bunlara dokunmuyoruz, aynen bırakıyoruz
      sohbetGenelHavasi: gulmeIfadesiVarMi ? 'Eğlenceli' : 'Görsel Analiz',
      sonMesajTonu: mesajTonu,
      sonMesajEtkisi: etkiDegerleri,
      olumluCevapTahmini: iyilestirilmisOlumluCevap,
      olumsuzCevapTahmini: iyilestirilmisOlumsuzCevap,
      anlikTavsiye: anlikTavsiye,
    );
  }
  
  // Analiz geçmişini güncelle
  void _analizGecmisiniGuncelle(MessageCoachAnalysis analiz) {
    // Mevcut analizi geçmişe ekle (en fazla 10 analiz tut)
    _analizGecmisi.insert(0, analiz);
    if (_analizGecmisi.length > 10) {
      _analizGecmisi = _analizGecmisi.sublist(0, 10);
    }
    notifyListeners();
  }
  
  // Kullanıcının mesaj koçu geçmişini getirme
  Future<List<PastMessageCoachAnalysis>> mesajKocuGecmisiniGetir() async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        _logger.w('Mesaj koçu geçmişi getirilemedi: Kullanıcı oturum açmamış');
        return [];
      }
      
      return await _mesajKocuService.getUserMessageCoachHistory(_currentUserId!);
    } catch (e) {
      _logger.e('Mesaj koçu geçmişi getirilirken hata oluştu', e);
      return [];
    }
  }
  
  // Mesaj koçu geçmişini temizleme
  Future<bool> mesajKocuGecmisiniTemizle() async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        _logger.w('Mesaj koçu geçmişi temizlenemedi: Kullanıcı oturum açmamış');
        return false;
      }
      
      await _mesajKocuService.clearMessageCoachHistory(_currentUserId!);
      _logger.i('Mesaj koçu geçmişi temizlendi');
      return true;
    } catch (e) {
      _logger.e('Mesaj koçu geçmişi temizlenirken hata oluştu', e);
      return false;
    }
  }
  
  // Hata mesajı ayarlama yardımcı metodu
  void _setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  // Sohbet içeriğini analiz etme
  Future<bool> sohbetiAnalizeEt(String sohbetIcerigi) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      _analizTamamlandi = false;
      notifyListeners();
      
      _logger.i('Sohbet analizi başlatılıyor: ${sohbetIcerigi.length} karakter');
      
      // Sohbet içeriği boş kontrolü
      if (!sohbetGecerliMi(sohbetIcerigi)) {
        _setError('Lütfen geçerli bir sohbet içeriği girin');
        return false;
      }
      
      // Sohbet analizi yap
      final analiz = await _aiService.sohbetiAnalizeEt(sohbetIcerigi);
      
      if (analiz == null) {
        _setError('Sohbet analizi yapılamadı. Lütfen tekrar deneyin.');
        return false;
      }
      
      // Analiz geçersiz mi?
      if (_analizSonucuGecersiziMi(analiz)) {
        _setError('Sohbet analizi geçersiz. Lütfen farklı bir sohbet içeriği deneyin.');
        return false;
      }
      
      // Analiz sonucunu ayarla
      _analysis = analiz;
      _analizTamamlandi = true;
      
      // Analiz sonucunu kullanıcı verilerine kaydet
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        await _mesajKocuService.saveMessageCoachAnalysis(
          userId: _currentUserId!,
          sohbetIcerigi: sohbetIcerigi,
          aciklama: 'Sohbet analizi',
          analysis: analiz
        );
        _logger.i('Sohbet analizi kullanıcı verilerine kaydedildi');
      }
      
      // Analizi geçmişe ekle
      _analizGecmisiniGuncelle(analiz);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _logger.e('Sohbet analizi hatası', e);
      _setError('Beklenmeyen bir hata oluştu: $e');
      return false;
    }
  }
} 
