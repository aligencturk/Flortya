import 'package:flutter/material.dart';
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
  
  // Mesaj koçu analizi geçmişi
  List<MessageCoachAnalysis> _analizGecmisi = [];
  List<MessageCoachAnalysis> get analizGecmisi => _analizGecmisi;
  
  // UI metinleri
  String get baslik => 'Mesaj Koçu';
  String get aciklamaBaslik => 'Sohbet Analizi';
  String get aciklamaMetni => 'Sohbet geçmişinizi analiz etmek için kopyala-yapıştır yapın. Mesaj Koçu sohbetin genel havasını ve son mesajınızın etkisini analiz edecek.';
  String get dosyaSecmeButonMetni => 'Dosyadan Yükle';
  String get yuklemeMetni => 'Sohbet analiz ediliyor...';
  
  // Analiz sonuçlarını temizle
  void analizSonuclariniSifirla() {
    _mevcutAnaliz = null;
    _hataMesaji = null;
    _analizTamamlandi = false;
    notifyListeners();
  }
  
  // Analiz geçmişini temizle
  void analizGecmisiniSifirla() {
    _analizGecmisi = [];
    notifyListeners();
  }
  
  // Sohbeti analiz et
  Future<void> sohbetiAnalizeEt(String sohbetIcerigi) async {
    if (sohbetIcerigi.trim().isEmpty) {
      _hataMesaji = 'Analiz için geçerli bir sohbet geçmişi gereklidir.';
      notifyListeners();
      return;
    }
    
    _yukleniyor = true;
    _analizTamamlandi = false;
    _hataMesaji = null;
    notifyListeners();
    
    try {
      _logger.i('Sohbet analizi başlatılıyor...');
      final analizSonucu = await _aiService.sohbetiAnalizeEt(sohbetIcerigi);
      
      if (analizSonucu == null) {
        _hataMesaji = 'Sohbet analizi yapılamadı. Lütfen tekrar deneyin.';
        _yukleniyor = false;
        notifyListeners();
        return;
      }
      
      // Analiz sonucundaki alanların geçerli olup olmadığını kontrol et
      if (_analizSonucuGecersiziMi(analizSonucu)) {
        _logger.w('Geçersiz analiz sonucu, varsayılan değerler kullanılacak');
        
        // Default olarak varsayalım
        final defaultEtki = {'sempatik': 40, 'kararsız': 30, 'olumsuz': 30};
        
        // Son mesaj etkisinin olup olmadığını kontrol et
        Map<String, int> sonMesajEtkisi = defaultEtki;
        if (analizSonucu.sonMesajEtkisi != null && analizSonucu.sonMesajEtkisi!.isNotEmpty) {
          sonMesajEtkisi = analizSonucu.sonMesajEtkisi!;
        }
        
        // Analiz sonucunu varsayılan ama sert değerlerle güçlendir
        _mevcutAnaliz = MessageCoachAnalysis(
          analiz: 'Sohbet içeriği çok az. Daha fazla mesaj gerekiyor.',
          oneriler: ['Daha fazla yazışma ekleyin', 'Konuşmayı devam ettirin'],
          etki: {'Sempatik': 50, 'Kararsız': 30, 'Olumsuz': 20},
          sohbetGenelHavasi: 'Analiz yapılamadı',
          genelYorum: 'Yeterli konuşma verisi yok',
          sonMesajTonu: 'Belirlenemedi',
          sonMesajEtkisi: {'sempatik': 33, 'kararsız': 33, 'olumsuz': 34},
          direktYorum: 'Sohbet içeriği çok az. En az 5-10 mesaj gerekiyor.',
          cevapOnerileri: ['Ne düşündüğünü açıkça söylemek istiyorum. Bu durum benim için önemli ve senin de dürüst olmanı beklerim.'],
        );
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
  
  // Analiz sonucunun eksik veya geçersiz alanları olup olmadığını kontrol et
  bool _analizSonucuGecersiziMi(MessageCoachAnalysis analiz) {
    // Temel alanların varlığını kontrol et
    final sohbetGenelHavasi = analiz.sohbetGenelHavasi;
    final sonMesajTonu = analiz.sonMesajTonu;
    final direktYorum = analiz.direktYorum;
    final sonMesajEtkisi = analiz.sonMesajEtkisi;
    final cevapOnerileri = analiz.cevapOnerileri;
    
    // Geçersiz ifadeleri içeriyor mu kontrol et
    final gecersizIfadeler = [
      'analiz edilemedi', 
      'yetersiz içerik', 
      'yapılamadı', 
      'alınamadı', 
      'belirlenemedi', 
      'json',
      'hata',
      'geçersiz'
    ];
    
    // Tüm gerekli alanların null olmadığını kontrol et
    if (sohbetGenelHavasi == null || 
        sonMesajTonu == null || 
        direktYorum == null ||
        sonMesajEtkisi == null ||
        cevapOnerileri == null) {
      _logger.w('Analiz sonucunda eksik alanlar var');
      return true;
    }
    
    // Boş veya varsayılan değerler içerip içermediğini kontrol et
    if (sohbetGenelHavasi.isEmpty || 
        sonMesajTonu.isEmpty || 
        direktYorum.isEmpty ||
        sonMesajEtkisi.isEmpty) {
      _logger.w('Analiz sonucunda boş alanlar var');
      return true;
    }
    
    // Geçersiz ifadeleri kontrol et
    for (final ifade in gecersizIfadeler) {
      if ((sohbetGenelHavasi.toLowerCase().contains(ifade)) || 
          (sonMesajTonu.toLowerCase().contains(ifade)) || 
          (direktYorum.toLowerCase().contains(ifade))) {
        _logger.w('Analiz sonucunda geçersiz ifadeler var: $ifade');
        return true;
      }
    }
    
    // Error kelimesini içeriyor mu kontrol et
    if (analiz.analiz.toLowerCase().contains('error') ||
        analiz.analiz.toLowerCase().contains('hata')) {
      _logger.w('Analiz sonucunda hata ifadesi var');
      return true;
    }
    
    // sonMesajEtkisi'nin toplam 100 olup olmadığını kontrol et (± 10 tolerans)
    if (sonMesajEtkisi.isNotEmpty) {
      final total = sonMesajEtkisi.values.fold(0, (sum, value) => sum + value);
      if (total < 90 || total > 110) {
        _logger.w('Son mesaj etkisi toplamı 100 değil: $total');
        return true;
      }
    }
    
    // Tüm kontrollerden geçti, analiz geçerli
    return false;
  }
  
  // Örnek sohbet içeriği oluştur (Test için)
  String ornekSohbetIcerigiOlustur() {
    return '''
Ali: Merhaba, bugün nasılsın?

Ben: İyiyim, biraz yoğunum sadece. Sen nasılsın?

Ali: Ben de iyiyim. Aslında seninle konuşmak istediğim bir konu vardı.

Ben: Nedir? Dinliyorum.

Ali: Geçen hafta sözünü ettiğin o etkinliğe gitmek ister misin? Cumartesi günü boş musun?

Ben: Bilmiyorum, programıma bakmam lazım ama sanırım o gün bir şey vardı.

Ali: Ne zaman kesin bir cevap verebilirsin? Biletleri önceden almam gerekiyor da.

Ben: Yarın kesin söylerim, kontrol edip sana yazarım.
    ''';
  }
  
  // Geçerli bir sohbet içeriği olup olmadığını kontrol et
  bool sohbetGecerliMi(String sohbetIcerigi) {
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
  
  // Formatlanmış analiz sonucu döndürme (HomeController'dan taşındı)
  Future<String> formatliAnalizYap(String messageText) async {
    _yukleniyor = true;
    _analizTamamlandi = false;
    _hataMesaji = null;
    notifyListeners();
    
    try {
      // Boş mesaj kontrolü
      if (messageText.trim().isEmpty) {
        _hataMesaji = 'Yüklenen veriden sağlıklı bir analiz yapılamadı, lütfen daha net mesaj içerikleri gönderin.';
        _yukleniyor = false;
        notifyListeners();
        return _hataMesaji!;
      }
      
      // Servis üzerinden analiz isteği
      final analizSonucu = await _aiService.sohbetiAnalizeEt(messageText);
      
      if (analizSonucu == null) {
        _hataMesaji = 'Analiz yapılamadı';
        _yukleniyor = false;
        notifyListeners();
        return _hataMesaji!;
      }
      
      _mevcutAnaliz = analizSonucu;
      
      // Analiz geçmişine ekle
      _analizGecmisiniGuncelle(_mevcutAnaliz!);
      
      _analizTamamlandi = true;
      _yukleniyor = false;
      notifyListeners();
      
      // Formatlanmış sonucu döndür
      return analizSonucu.getFormattedAnalysis();
    } catch (e) {
      _logger.e('Formatlanmış analiz hatası', e);
      _hataMesaji = 'Analiz sırasında bir hata oluştu: $e';
      _yukleniyor = false;
      notifyListeners();
      return "Analiz sırasında bir hata oluştu, lütfen tekrar deneyin.";
    }
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