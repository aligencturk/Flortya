import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../models/message_coach_analysis.dart';
import '../services/ai_service.dart';
import '../services/logger_service.dart';

class MessageCoachController extends ChangeNotifier {
  final AiService _aiService = AiService();
  final LoggerService _logger = LoggerService();
  
  MessageCoachAnalysis? _mevcutAnaliz;
  MessageCoachAnalysis? get mevcutAnaliz => _mevcutAnaliz;
  
  String? _hataMesaji;
  String? get hataMesaji => _hataMesaji;
  
  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;
  
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
  
  // Analiz sonuçlarını temizle
  void analizSonuclariniSifirla() {
    _mevcutAnaliz = null;
    _hataMesaji = null;
    _analizTamamlandi = false;
    _gorselModu = false;
    _gorselDosya = null;
    _gorselOcrSonucu = null;
    notifyListeners();
  }
  
  // Analiz geçmişini temizle
  void analizGecmisiniSifirla() {
    _analizGecmisi = [];
    notifyListeners();
  }
  
  // Görsel belirle
  void gorselBelirle(File gorsel) {
    _gorselDosya = gorsel;
    _gorselModu = true;
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
  
  // Görsel dosyasından sohbeti analiz et
  Future<void> gorseliAnalizeEt(File gorselDosya, String? ocrMetni) async {
    if (gorselDosya == null && (ocrMetni == null || ocrMetni.trim().isEmpty)) {
      _hataMesaji = 'Analiz için geçerli bir görsel veya OCR metni gereklidir.';
      notifyListeners();
      return;
    }
    
    _yukleniyor = true;
    _analizTamamlandi = false;
    _hataMesaji = null;
    _gorselModu = true;
    notifyListeners();
    
    try {
      _logger.i('Görsel sohbet analizi başlatılıyor...');
      
      String icerik = ocrMetni ?? '';
      if (icerik.trim().isEmpty) {
        _hataMesaji = 'Görselden sohbet metni çıkarılamadı.';
        _yukleniyor = false;
        notifyListeners();
        return;
      }
      
      // Gemini API ile görseli analiz et
      final analizSonucu = await _aiService.sohbetiAnalizeEt(icerik, isImage: true);
      
      if (analizSonucu == null) {
        _hataMesaji = 'Görsel analizi yapılamadı. Lütfen tekrar deneyin.';
        _yukleniyor = false;
        notifyListeners();
        return;
      }
      
      // Analiz sonucundaki alanların geçerli olup olmadığını kontrol et
      if (_analizSonucuGecersiziMi(analizSonucu)) {
        _logger.w('Geçersiz görsel analiz sonucu - API hatası.');
        _hataMesaji = 'API yanıtı geçersiz. Lütfen tekrar deneyin.';
        _yukleniyor = false;
        notifyListeners();
        return;
      } else {
        _mevcutAnaliz = analizSonucu;
      }
      
      // Analiz geçmişine ekle
      _analizGecmisiniGuncelle(_mevcutAnaliz!);
      
      _analizTamamlandi = true;
      _yukleniyor = false;
      
      _logger.i('Görsel sohbet analizi tamamlandı.');
      notifyListeners();
      
    } catch (e) {
      _logger.e('Görsel sohbet analizi hatası', e);
      _hataMesaji = 'Beklenmeyen bir hata oluştu: $e';
      _yukleniyor = false;
      notifyListeners();
    }
  }
  
  // Sohbeti analiz et
  Future<void> sohbetiAnalizeEt(String sohbetIcerigi) async {
    // Görsel modundaysak görsel analizi fonksiyonunu çağır
    if (_gorselModu && _gorselDosya != null && _gorselOcrSonucu != null) {
      await gorseliAnalizeEt(_gorselDosya!, _gorselOcrSonucu);
      return;
    }
    
    if (sohbetIcerigi.trim().isEmpty) {
      _hataMesaji = 'Analiz için geçerli bir sohbet geçmişi gereklidir.';
      notifyListeners();
      return;
    }
    
    _yukleniyor = true;
    _analizTamamlandi = false;
    _hataMesaji = null;
    _gorselModu = false;
    notifyListeners();
    
    try {
      _logger.i('Sohbet analizi başlatılıyor...');
      
      // Gemini API ile sohbeti analiz et
      final analizSonucu = await _aiService.sohbetiAnalizeEt(sohbetIcerigi, isImage: false);
      
      if (analizSonucu == null) {
        _hataMesaji = 'Sohbet analizi yapılamadı. Lütfen tekrar deneyin.';
        _yukleniyor = false;
        notifyListeners();
        return;
      }
      
      // Analiz sonucundaki alanların geçerli olup olmadığını kontrol et
      if (_analizSonucuGecersiziMi(analizSonucu)) {
        _logger.w('Geçersiz analiz sonucu - API hatası.');
        _hataMesaji = 'API yanıtı geçersiz. Lütfen tekrar deneyin.';
        _yukleniyor = false;
        notifyListeners();
        return;
      } else {
        _mevcutAnaliz = analizSonucu;
      }
      
      // Analiz geçmişine ekle
      _analizGecmisiniGuncelle(_mevcutAnaliz!);
      
      _analizTamamlandi = true;
      _yukleniyor = false;
      
      _logger.i('Sohbet analizi tamamlandı.');
      notifyListeners();
      
    } catch (e) {
      _logger.e('Sohbet analizi hatası', e);
      _hataMesaji = 'Beklenmeyen bir hata oluştu: $e';
      _yukleniyor = false;
      notifyListeners();
    }
  }
  
  // Analiz geçmişine yeni analizi ekle (en son 10 analiz tutulur)
  void _analizGecmisiniGuncelle(MessageCoachAnalysis yeniAnaliz) {
    _analizGecmisi.add(yeniAnaliz);
    if (_analizGecmisi.length > 10) {
      _analizGecmisi = _analizGecmisi.sublist(_analizGecmisi.length - 10);
    }
  }
  
  // Örnek sohbet içeriği oluştur (Test için)
  String ornekSohbetIcerigiOlustur() {
    return '''
Ahmet: Selam, nasılsın bugün?

Zeynep: İyiyim aslında, ama biraz yorgunum. İş yoğundu bugün. Sen nasılsın?

Ahmet: Ben de iyiyim. Bu hafta sonu ne yapıyorsun? Belki bir şeyler yaparız?

Zeynep: Bilmiyorum henüz. Biraz dinlenmek istiyorum aslında.

Ahmet: Anladım. Ama çok uzun zamandır görüşemedik, özledim seni.

Zeynep: Biliyorum, haklısın. Belki Cumartesi bir şeyler yapabiliriz.

Ahmet: Harika! Ne yapmak istersin? Film izleyebilir ya da dışarıda bir yerlere gidebiliriz.

Zeynep: Hmm, bilmiyorum. Sen ne istersen.

Ahmet: O zaman yeni açılan o kafeye gidelim mi? Çok güzel diyorlar.

Zeynep: Tamam, olabilir. Saat kaçta buluşalım?
    ''';
  }
  
  // Geçerli bir sohbet içeriği olup olmadığını kontrol et
  bool sohbetGecerliMi(String sohbetIcerigi) {
    // Görsel modundaysak ve görsel dosyası varsa, daima geçerli kabul et
    if (_gorselModu && _gorselDosya != null) {
      return true;
    }
    
    if (sohbetIcerigi.trim().isEmpty) {
      return false;
    }
    
    // En az bir mesaj değişimi olmalı (en az 2 satır)
    final satirlar = sohbetIcerigi.split('\n').where((satir) => satir.trim().isNotEmpty).toList();
    if (satirlar.length < 2) {
      return false;
    }
    
    return true;
  }
  
  // Sohbet metnini temizle
  String sohbetMetniniTemizle(String sohbetIcerigi) {
    // Gereksiz boşlukları temizle
    String temizMetin = sohbetIcerigi.trim();
    
    // Ardışık boş satırları tek satıra indir
    temizMetin = temizMetin.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    
    return temizMetin;
  }
  
  // Önceki analiz sonuçlarını karşılaştırarak ilerleme raporu oluştur
  Map<String, dynamic> ilerlemeRaporuOlustur() {
    if (_analizGecmisi.length < 2) {
      return {'rapor': 'Karşılaştırma için yeterli analiz verisi yok', 'sonuc': 'Değerlendirme için en az 2 analiz gerekli'};
    }
    
    final sonAnaliz = _analizGecmisi.last;
    final oncekiAnaliz = _analizGecmisi[_analizGecmisi.length - 2];
    
    // Analiz sonuçlarını karşılaştırma
    final sohbetHavasiDegisti = sonAnaliz.sohbetGenelHavasi != oncekiAnaliz.sohbetGenelHavasi;
    final sonMesajTonuDegisti = sonAnaliz.sonMesajTonu != oncekiAnaliz.sonMesajTonu;
    
    // Etki değerlerini karşılaştır
    Map<String, int> etkiDegisimleri = {};
    if (sonAnaliz.sonMesajEtkisi != null && oncekiAnaliz.sonMesajEtkisi != null) {
      sonAnaliz.sonMesajEtkisi!.forEach((anahtar, deger) {
        final oncekiDeger = oncekiAnaliz.sonMesajEtkisi![anahtar] ?? 0;
        etkiDegisimleri[anahtar] = deger - oncekiDeger;
      });
    }
    
    // İlerleme açıklaması oluştur
    String ilerlemeAciklamasi = '';
    
    if (sohbetHavasiDegisti) {
      ilerlemeAciklamasi += 'Sohbet havası "${oncekiAnaliz.sohbetGenelHavasi}" durumundan "${sonAnaliz.sohbetGenelHavasi}" durumuna değişti. ';
    } else {
      ilerlemeAciklamasi += 'Sohbet havası aynı kaldı. ';
    }
    
    if (sonMesajTonuDegisti) {
      ilerlemeAciklamasi += 'Son mesaj tonu "${oncekiAnaliz.sonMesajTonu}" yerine "${sonAnaliz.sonMesajTonu}" olarak değişti. ';
    }
    
    // Etki değişimlerini açıklamaya ekle
    if (etkiDegisimleri.isNotEmpty) {
      ilerlemeAciklamasi += 'Etki değişimleri: ';
      etkiDegisimleri.forEach((anahtar, degisim) {
        final yonIsareti = degisim > 0 ? '+' : '';
        ilerlemeAciklamasi += '$anahtar: $yonIsareti$degisim%, ';
      });
      
      // Son virgülü kaldır
      ilerlemeAciklamasi = ilerlemeAciklamasi.substring(0, ilerlemeAciklamasi.length - 2);
    }
    
    // Genel değerlendirme
    String genelDegerlendirme = '';
    
    // Genel iyileşme/kötüleşme kontrolü
    int olumluDegisimSayisi = 0;
    int olumsuzDegisimSayisi = 0;
    
    etkiDegisimleri.forEach((anahtar, degisim) {
      if (anahtar.toLowerCase() == 'sempatik' || anahtar.toLowerCase() == 'olumlu') {
        if (degisim > 0) olumluDegisimSayisi++;
        else if (degisim < 0) olumsuzDegisimSayisi++;
      } else if (anahtar.toLowerCase() == 'olumsuz' || anahtar.toLowerCase() == 'kararsız') {
        if (degisim < 0) olumluDegisimSayisi++;
        else if (degisim > 0) olumsuzDegisimSayisi++;
      }
    });
    
    if (olumluDegisimSayisi > olumsuzDegisimSayisi) {
      genelDegerlendirme = 'İletişim becerilerin gelişiyor. Devam et!';
    } else if (olumluDegisimSayisi < olumsuzDegisimSayisi) {
      genelDegerlendirme = 'İletişim tarzında sorunlar var. İyileştirme için daha fazla çaba göstermelisin.';
    } else {
      genelDegerlendirme = 'İletişim tarzında belirgin bir değişiklik yok. Daha etkili iletişim kurmaya çalış.';
    }
    
    return {
      'rapor': ilerlemeAciklamasi,
      'sonuc': genelDegerlendirme,
      'degisimler': etkiDegisimleri,
    };
  }
} 