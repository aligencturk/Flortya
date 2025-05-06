import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../models/message_coach_analysis.dart';
import '../models/past_message_coach_analysis.dart';
import '../models/message_coach_visual_analysis.dart';
import '../services/ai_service.dart';
import '../services/logger_service.dart';
import '../services/message_coach_service.dart';

class MessageCoachController extends ChangeNotifier {
  final AiService _aiService = AiService();
  final LoggerService _logger = LoggerService();
  final MessageCoachService _mesajKocuService = MessageCoachService();
  
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
  
  // Kullanıcı ID'sini set etme metodu
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    _logger.i('Kullanıcı ID ayarlandı: $userId');
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
          sohbetIcerigi: '', // Metin açıklaması analizi olduğu için boş
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
  
  // Görsel ile analiz et - MessageCoachService üzerinden direkt çağrı
  Future<MessageCoachVisualAnalysis?> gorselIleAnalizeEt(File gorselDosya, String aciklama) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      _analizTamamlandi = false;
      notifyListeners();
      
      _logger.i('Görsel ile analiz başlatılıyor: ${gorselDosya.path}, Açıklama: $aciklama');
      
      // Görsel dosyasını ayarla
      _gorselDosya = gorselDosya;
      
      // Açıklama boş kontrolü
      if (aciklama.trim().isEmpty) {
        _setError('Lütfen bir açıklama yazın');
        return null;
      }
      
      // OCR işlemi yapıldıktan sonra metin içeriği alınacak
      String? ocrSonucu = _gorselOcrSonucu;
      
      // OCR sonucunda veya kullanıcı açıklamasında "keyboard smash" (anlamsız harf dizisi) 
      // var mı kontrol et ve bunu yapay zekaya bildir - fakat kullanıcıya söyleme talimatı ver
      String analizNotu = "";
      
      // OCR sonucunda gülme içeren anlamsız harf dizisi tespiti
      if (ocrSonucu != null && ocrSonucu.isNotEmpty) {
        final gulmeIfadeleri = _gulmeIfadeleriniTespit(ocrSonucu);
        if (gulmeIfadeleri.isNotEmpty) {
          analizNotu += "OCR metninde tespit edilen gülme ifadeleri: $gulmeIfadeleri. ";
          _logger.i("OCR sonucunda gülme ifadeleri tespit edildi: $gulmeIfadeleri");
        }
      }
      
      // Kullanıcı açıklamasında gülme içeren anlamsız harf dizisi tespiti
      final kullaniciGulmeIfadeleri = _gulmeIfadeleriniTespit(aciklama);
      if (kullaniciGulmeIfadeleri.isNotEmpty) {
        analizNotu += "Kullanıcı açıklamasında tespit edilen gülme ifadeleri: $kullaniciGulmeIfadeleri. ";
        _logger.i("Kullanıcı açıklamasında gülme ifadeleri tespit edildi: $kullaniciGulmeIfadeleri");
      }
      
      // Görsel analiz için özel sistem mesajı oluştur 
      // Yapay zekaya daha doğal bir üslup kullanmasını ve gülme ifadeleri hakkında bilgilendirme yapmasını söyleyen talimatlar
      String sistemTalimatlari = """
Bu bir görsel analizidir. Lütfen aşağıdaki kılavuza göre değerlendirme yap:

1. Robotumsu bir dil KULLANMA, "kullanıcı şunu demiş", "partner bunu demiş" gibi ifadeler kullanma.
2. Doğal ve akıcı bir dil kullan, sanki bir arkadaşına tavsiye veriyormuş gibi.
3. Metin analizi yaptığın zaman kullandığın doğal üslubu kullan.
4. Cevaplarını birinci şahıs olarak ver, "Burada..." veya "Bu durumda..." gibi başlayabilirsin.
5. ÖNEMLİ: Analiz içerisinde tespit edilen anlamsız harf dizilerinin (dsjsdlfsjgls gibi) "gülme anlamına geldiğini" ASLA doğrudan söyleme! Bu bilgiyi kullan ama kullanıcıya açıkça söyleme.
6. Genel sohbet analizi ile direkt yorum ve geliştirme kısımlarının içeriği farklı olmalı:
   - Genel sohbet analizi: Mevcut durumun tarafsız bir değerlendirmesi
   - Direkt yorum ve geliştirme: Hataların tespiti ve gelişim tavsiyeleri

Tüm yanıtlarını doğal, samimi ve insani bir üslupla ver.
""";
      
      // Eğer gülme ifadeleri tespit edildiyse, sistem talimatlarında ekstra bilgi ver
      if (analizNotu.isNotEmpty) {
        sistemTalimatlari += "\n\nTespit edilen gülme ifadeleri: $analizNotu Bu ifadeleri analizinde kullan ama kullanıcıya doğrudan 'Bu gülme ifadesi' gibi açıklamalar yapma.";
      }
      
      // Sistem talimatlarını açıklamaya ekle
      String zenginlestirilmisAciklama = "$sistemTalimatlari\n\nKullanıcı açıklaması: $aciklama";
      
      // OCR ve analiz işlemini başlat - doğrudan servis üzerinden
      final analiz = await _mesajKocuService.sohbetGoruntusunuAnalizeEt(
        gorselDosya, 
        zenginlestirilmisAciklama
      );
      
      if (analiz == null) {
        _setError('Görsel analiz yapılamadı. Lütfen tekrar deneyin.');
        return null;
      }
      
      // Görsel analiz sonuçlarını MessageCoachAnalysis formatına dönüştür
      // ve controller'ın analysis değişkenine ata
      _analysis = _gorselAnalizdenMesajAnalizineDonus(analiz, aciklama, analizNotu);
      
      // Firebase'e kaydet
      if (_currentUserId != null) {
        await _mesajKocuService.saveVisualMessageCoachAnalysis(
          userId: _currentUserId!,
          aciklama: aciklama, // Orijinal açıklamayı kaydet, talimatları kaydetme
          analysis: analiz,
        );
        _logger.i('Görsel analizi kaydedildi.');
      }
      
      _isLoading = false;
      _analizTamamlandi = true;
      notifyListeners();
      
      return analiz;
    } catch (e) {
      _logger.e('Görsel analiz hatası', e);
      _setError('Görsel analiz edilirken bir hata oluştu: ${e.toString()}');
      return null;
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
      olumluCevap = gorselAnaliz.partnerResponses.length > 0 ? gorselAnaliz.partnerResponses[0] : null;
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
      
      // Önemli: Yeni talimatımız gereği, gülme ifadelerini direkt olarak belirtmiyoruz
      // Bunun yerine tespiti kullanarak tonu ve havayı değiştiriyoruz
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
    
    // "Anlamsız harf dizileri" veya "gülme ifadeleri" hakkında doğrudan açıklamaları kaldır
    iyilestirilmisGenelYorum = iyilestirilmisGenelYorum
        .replaceAll(RegExp(r'Mesajda tespit edilen anlamsız harf dizileri.*?gülmeyi temsil ed[a-z]+\.*'), '')
        .replaceAll(RegExp(r'Bu tür harf dizileri genellikle.*?gülme ifadesi[a-z]+\.*'), '')
        .replaceAll(RegExp(r'.*?anlamsız harf dizileri genellikle yazışmada gülmeyi temsil ed[a-z]+\.*'), '');
    
    // Direkt yorum için farklı bir içerik oluştur (hata tespiti ve tavsiyeler)
    String direktYorumIcerigi = "";
    
    if (gulmeIfadesiVarMi) {
      // Gülme ifadesi varsa, samimi ve eğlenceli bir ton tavsiye et, ama gülme ifadelerinden bahsetme
      direktYorumIcerigi = "Sohbetin havasının samimi ve eğlenceli olduğu anlaşılıyor. Bu tür mesajlaşmalarda karşındaki kişi rahat hissediyor olabilir. Böyle durumlarda benzer bir ton kullanman iletişimi güçlendirebilir. Karşılık verirken mizahi veya samimi bir yaklaşım sergilemen iyi olabilir.";
    } else if (iyilestirilmisGenelYorum.isNotEmpty) {
      // Genel yorumdan gelişim noktaları ve tavsiyeleri çıkar
      if (iyilestirilmisGenelYorum.contains("ancak") || iyilestirilmisGenelYorum.contains("fakat")) {
        // Eğer "ancak" veya "fakat" içeriyorsa, o kısımları direkt yorum olarak kullan
        List<String> parcalar = iyilestirilmisGenelYorum.split(RegExp(r'(ancak|fakat)'));
        if (parcalar.length > 1) {
          direktYorumIcerigi = "Geliştirilebilecek noktalar: " + parcalar[1].trim();
        }
      } else {
        // Yoksa, genel tavsiyeleri ekle
        direktYorumIcerigi = "Bu mesajlaşmada şunlara dikkat etmen faydalı olabilir: Karşındaki kişinin tepkilerini dikkatle izle ve iletişim tonunu ona göre ayarla. Açık ve net bir ifade kullan, yanlış anlaşılmaları önle.";
      }
    } else {
      direktYorumIcerigi = "Bu görsel analiz sonucunda özel bir gelişim noktası tespit edilmedi. Genel iletişim tavsiyesi olarak açık ve net olmaya, karşındaki kişinin tepkilerine dikkat etmeye devam et.";
    }
    
    // Olumlu ve olumsuz cevap tahminlerini iyileştir
    String? iyilestirilmisOlumluCevap = olumluCevap;
    String? iyilestirilmisOlumsuzCevap = olumsuzCevap;
    
    if (iyilestirilmisOlumluCevap != null) {
      iyilestirilmisOlumluCevap = iyilestirilmisOlumluCevap
          .replaceAll("Partner:", "")
          .replaceAll("Partner şöyle cevap verebilir:", "")
          .replaceAll("Olumlu senaryo:", "");
      
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
      ? "Karşı taraf eğlenceli ve rahat bir mod içerisinde olabilir. Benzer bir ton ile cevap verebilirsin."
      : iyilestirilmisGenelYorum;
    
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