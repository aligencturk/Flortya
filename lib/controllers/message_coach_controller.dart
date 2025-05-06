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
    _logger.i('Görsel modu: $_gorselModu');
    
    // Mevcut analiz sonuçlarını temizle
    analizSonuclariniSifirla();
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
  
  // Görsel tabanlı analiz
  Future<bool> gorselIleAnalizeEt(File gorselDosya, String aciklama) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      _analizTamamlandi = false;
      _gorselModu = true;
      _gorselDosya = gorselDosya;
      notifyListeners();
      
      _logger.i('Görsel analizi başlatılıyor: ${gorselDosya.path}, Açıklama: $aciklama');
      
      // Görsel kontrolü
      if (gorselDosya.lengthSync() <= 0) {
        _setError('Geçersiz görsel dosyası');
        return false;
      }
      
      // Yeni eklenen metodu kullan - görsel ve açıklama ile analiz
      final analiz = await _aiService.gorselVeAciklamaAnalizeEt(gorselDosya, aciklama);
      
      if (analiz == null) {
        _setError('Görsel analizi yapılamadı. Lütfen tekrar deneyin.');
        return false;
      }
      
      // Analiz sonucunu ayarla
      _analysis = analiz;
      _analizTamamlandi = true;
      
      // Analiz sonucunu kullanıcı verilerine kaydet (görsel dosyası ile)
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        try {
          // Görseli depoya yükleme (basitleştirilmiş, servisin desteklediği metodları kullan)
          final String imageUrl = await _mesajKocuService.fileUploadToStorage(
            dosya: gorselDosya,
            klasor: 'mesaj_kocu_gorseller',
            userId: _currentUserId!
          );
          
          // Analiz sonucunu kaydet
          await _mesajKocuService.saveMessageCoachAnalysis(
            userId: _currentUserId!,
            sohbetIcerigi: '',
            aciklama: aciklama,
            imageUrl: imageUrl,
            analysis: analiz
          );
          
          _logger.i('Görsel analizi kullanıcı verilerine kaydedildi');
        } catch (e) {
          _logger.e('Görsel analizi kaydetme hatası', e);
          // Analize devam et ama kaydetme hatasını log'la
        }
      }
      
      // Analizi geçmişe ekle
      _analizGecmisiniGuncelle(analiz);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _logger.e('Görsel analizi hatası', e);
      _setError('Beklenmeyen bir hata oluştu: $e');
      return false;
    }
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