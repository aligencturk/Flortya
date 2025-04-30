import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';
import '../models/message_coach_analysis.dart';
import '../services/user_service.dart';
import '../services/ai_service.dart';

/// Controller durumunu belirten enum
enum KontrolDurumu { yukleniyor, yuklendi, hata }

class HomeController extends ChangeNotifier {
  final UserService _userService;
  final AiService _aiService;
  final Logger _logger = Logger();
  
  bool _isLoading = false;
  String? _errorMessage;
  AnalizSonucu? _sonAnalizSonucu;
  List<AnalizSonucu> _analizGecmisi = [];
  Map<String, dynamic> _kategoriDegisimleri = {};
  List<String> _kisisellestirilmisTavsiyeler = [];
  KontrolDurumu _durum = KontrolDurumu.yuklendi;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AnalizSonucu? get sonAnalizSonucu => _sonAnalizSonucu;
  List<AnalizSonucu> get analizGecmisi => _analizGecmisi;
  Map<String, dynamic> get kategoriDegisimleri => _kategoriDegisimleri;
  List<String> get kisisellestirilmisTavsiyeler => _kisisellestirilmisTavsiyeler;
  KontrolDurumu get durum => _durum;

  HomeController({
    required UserService userService,
    required AiService aiService,
  }) : _userService = userService,
       _aiService = aiService {
    _initialize();
  }

  /// Controller'ı başlat ve verileri yükle
  Future<void> _initialize() async {
    await anaSayfayiGuncelle();
  }

  /// Ana sayfadaki tüm verileri günceller
  Future<void> anaSayfayiGuncelle() async {
    _setLoading(true);
    try {
      // Kullanıcı verilerini getir
      final kullanici = await _userService.getCurrentUser();
      if (kullanici != null) {
        _sonAnalizSonucu = kullanici.sonAnalizSonucu;
        _analizGecmisi = kullanici.analizGecmisi;
        
        // Kategori değişimlerini hesapla
        if (_analizGecmisi.length >= 2) {
          _kategoriDegisimleri = _hesaplaKategoriDegisimleri();
        }
        
        // Kişiselleştirilmiş tavsiyeleri güncelle
        if (_sonAnalizSonucu != null) {
          _kisisellestirilmisTavsiyeler = _sonAnalizSonucu!.kisiselestirilmisTavsiyeler;
        }
      }
    } catch (e) {
      _setError('Ana sayfa verileri güncellenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Yeni bir analiz sonucu ile ana sayfayı günceller
  Future<void> analizSonucuIleGuncelle(AnalizSonucu analizSonucu) async {
    _setLoading(true);
    try {
      // Son analiz sonucunu güncelle
      _sonAnalizSonucu = analizSonucu;
      
      // Analiz geçmişini güncelle (son 10 analizi tut)
      _analizGecmisi.add(analizSonucu);
      if (_analizGecmisi.length > 10) {
        _analizGecmisi = _analizGecmisi.sublist(_analizGecmisi.length - 10);
      }
      
      // Kategori değişimlerini hesapla
      if (_analizGecmisi.length >= 2) {
        _kategoriDegisimleri = _hesaplaKategoriDegisimleri();
      }
      
      // Kişiselleştirilmiş tavsiyeleri güncelle
      _kisisellestirilmisTavsiyeler = analizSonucu.kisiselestirilmisTavsiyeler;
      
      notifyListeners();
    } catch (e) {
      _setError('Analiz sonucu ile güncelleme yapılırken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Kategori puanlarının son iki analiz arasındaki değişimini hesaplar
  Map<String, dynamic> _hesaplaKategoriDegisimleri() {
    if (_analizGecmisi.length < 2) return {};
    
    final sonAnaliz = _analizGecmisi.last;
    final oncekiAnaliz = _analizGecmisi[_analizGecmisi.length - 2];
    
    Map<String, dynamic> degisimler = {};
    
    // Her kategori için değişimi hesapla
    sonAnaliz.kategoriPuanlari.forEach((kategori, puan) {
      final oncekiPuan = oncekiAnaliz.kategoriPuanlari[kategori] ?? 0;
      final degisim = puan - oncekiPuan;
      
      switch (kategori.toLowerCase()) {
        case 'destek':
          // Yalnızca destek ile ilgili cümleleri dikkate al
          degisimler[kategori] = {
            'onceki': oncekiPuan,
            'yeni': puan,
            'degisim': degisim,
            'yuzde': oncekiPuan > 0 ? (degisim / oncekiPuan * 100).toInt() : 0,
          };
          break;
        
        case 'guven':
          // Güven temelli cümleleri dikkate al
          degisimler[kategori] = {
            'onceki': oncekiPuan,
            'yeni': puan,
            'degisim': degisim,
            'yuzde': oncekiPuan > 0 ? (degisim / oncekiPuan * 100).toInt() : 0,
          };
          break;
          
        case 'saygi':
        case 'saygı':
          // Saygı ile ilgili ifadeleri değerlendir
          degisimler[kategori] = {
            'onceki': oncekiPuan,
            'yeni': puan,
            'degisim': degisim,
            'yuzde': oncekiPuan > 0 ? (degisim / oncekiPuan * 100).toInt() : 0,
          };
          break;
          
        case 'iletisim':
          // İletişim ile ilgili bölümleri baz al
          degisimler[kategori] = {
            'onceki': oncekiPuan,
            'yeni': puan,
            'degisim': degisim,
            'yuzde': oncekiPuan > 0 ? (degisim / oncekiPuan * 100).toInt() : 0,
          };
          break;
          
        case 'uyum':
          // Uyum diğer 4 kategorinin ortalaması olarak hesaplanır
          final uyumOnceki = (_hesaplaOrtalamaKategoriPuani(oncekiAnaliz.kategoriPuanlari, 'uyum')).toInt();
          final uyumYeni = (_hesaplaOrtalamaKategoriPuani(sonAnaliz.kategoriPuanlari, 'uyum')).toInt();
          final uyumDegisim = uyumYeni - uyumOnceki;
          
          degisimler[kategori] = {
            'onceki': uyumOnceki,
            'yeni': uyumYeni,
            'degisim': uyumDegisim,
            'yuzde': uyumOnceki > 0 ? (uyumDegisim / uyumOnceki * 100).toInt() : 0,
          };
          break;
      }
    });
    
    return degisimler;
  }
  
  /// Ortalama kategori puanını hesaplar (Uyum için kullanılır)
  double _hesaplaOrtalamaKategoriPuani(Map<String, int> kategoriPuanlari, String haricKategori) {
    int toplam = 0;
    int sayac = 0;
    
    kategoriPuanlari.forEach((kategori, puan) {
      if (kategori.toLowerCase() != haricKategori.toLowerCase()) {
        toplam += puan;
        sayac++;
      }
    });
    
    return sayac > 0 ? toplam / sayac : 0;
  }

  /// Kişiselleştirilmiş tavsiyeleri yeniden oluşturur
  Future<void> tavsiyeleriYenile() async {
    if (_sonAnalizSonucu == null) return;
    
    _setLoading(true);
    try {
      // Kullanıcı verilerini getir
      final kullanici = await _userService.getCurrentUser();
      if (kullanici != null) {
        // Yeni tavsiyeler oluştur
        final yeniTavsiyeler = await _aiService.kisisellestirilmisTavsiyelerOlustur(
          _sonAnalizSonucu!.iliskiPuani,
          _sonAnalizSonucu!.kategoriPuanlari,
          {'displayName': kullanici.displayName, 'preferences': kullanici.preferences}
        );
        
        // Yeni analiz sonucunu oluştur
        final yeniAnalizSonucu = _sonAnalizSonucu!.copyWith(
          kisiselestirilmisTavsiyeler: yeniTavsiyeler,
        );
        
        // Firestore'a kaydet
        await _userService.updateSonAnalizSonucu(yeniAnalizSonucu);
        
        // Yerel değişkenleri güncelle
        _sonAnalizSonucu = yeniAnalizSonucu;
        _kisisellestirilmisTavsiyeler = yeniTavsiyeler;
        
        notifyListeners();
      }
    } catch (e) {
      _setError('Tavsiyeler güncellenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Tüm analiz verilerini temizler
  Future<void> resetAnalizVerileri() async {
    try {
      debugPrint('resetAnalizVerileri çağrıldı');
      
      // Mevcut durumu kaydet
      final hadAnalysisData = _sonAnalizSonucu != null || _analizGecmisi.isNotEmpty || 
                               _kategoriDegisimleri.isNotEmpty || _kisisellestirilmisTavsiyeler.isNotEmpty;
      
      // Tüm değişkenleri temizle
      debugPrint('Analiz verileri temizleniyor...');
      _sonAnalizSonucu = null;
      _analizGecmisi = [];
      _kategoriDegisimleri = {};
      _kisisellestirilmisTavsiyeler = [];
      
      // Firestore'da kullanıcının analiz verilerini de temizle
      final currentUser = _userService.getCurrentAuthUser();
      if (currentUser != null) {
        // Veritabanı temizliği servisler/viewmodel'lar tarafından yapılacak
        // Burada sadece UI verilerini temizliyoruz
        debugPrint('UI analiz verileri temizlendi');
      }
      
      // Sadece değişiklik varsa bildirim yapma
      if (hadAnalysisData) {
        notifyListeners();
        debugPrint('Analiz verileri başarıyla temizlendi ve UI güncellemesi bildirildi');
      } else {
        debugPrint('Temizlenecek analiz verisi yoktu, UI bildirimi yapılmadı');
      }
    } catch (e) {
      debugPrint('Analiz verileri temizlenirken hata: $e');
      _setError('Analiz verileri temizlenirken beklenmeyen bir hata oluştu: $e');
      
      // Hata olsa da mevcut verileri temizlemeye çalış
      try {
        _sonAnalizSonucu = null;
        _analizGecmisi = [];
        _kategoriDegisimleri = {};
        _kisisellestirilmisTavsiyeler = [];
        notifyListeners();
        debugPrint('Hata sonrası temizleme tamamlandı');
      } catch (innerError) {
        debugPrint('Hata sonrası temizleme işleminde ikinci bir hata: $innerError');
      }
    }
  }
  
  /// İlişki verilerini temizler
  Future<void> resetRelationshipData() async {
    try {
      debugPrint('resetRelationshipData çağrıldı');
      
      // Verileri temizle - UI tarafındaki işlemler
      // İlişki veri temizliği servisler/viewmodel'lar tarafından yapılacak
      
      // Ana sayfayı güncelle - verilerin güncel halini yansıtmak için
      await anaSayfayiGuncelle();
      
      debugPrint('İlişki verileri UI tarafından temizlendi');
    } catch (e) {
      debugPrint('İlişki verileri temizlenirken hata: $e');
      _setError('İlişki verileri temizlenirken hata oluştu: $e');
    }
  }

  /// Kontrol durumunu ayarlar
  void setState(KontrolDurumu yeniDurum) {
    _durum = yeniDurum;
    notifyListeners();
  }

  /// @deprecated Bu metot artık MessageCoachController'a taşındı.
  /// Bunun yerine MessageCoachController.formatliAnalizYap() kullanın.
  Future<String> mesajKocuAnaliziYap(String messageText) async {
    debugPrint('UYARI: Bu metot artık kullanımdan kaldırılmıştır. Lütfen MessageCoachController.formatliAnalizYap() metodunu kullanın.');
    // Geriye dönük uyumluluk için işlevselliği koruyoruz, gelecek sürümlerde kaldırılacak
    
    try {
      // Varsayılan "analiz yapılamadı" mesajı
      String analizSonucu = "Analiz yapılamadı. Lütfen daha sonra tekrar deneyin.";
      
      // Mesaj içeriği boş kontrolü
      if (messageText.trim().isEmpty) {
        return "Yüklenen veriden sağlıklı bir analiz yapılamadı, lütfen daha net mesaj içerikleri gönderin.";
      }
      
      try {
        // API'den analiz isteği
        final sonuc = await _aiService.sohbetiAnalizeEt(messageText);
        if (sonuc != null) {
          // Map türündeki sonucu formatlanmış metin olarak dönüştür
          analizSonucu = _formatAnalysisResult(sonuc);
        }
      } catch (e) {
        _logger.e("Mesaj koçu analizi sırasında hata: $e");
        return "Analiz sırasında bir hata oluştu: $e";
      }
      
      return analizSonucu;
    } catch (e) {
      _logger.e("Mesaj koçu genel hata: $e");
      return "İşlem sırasında beklenmeyen bir hata oluştu: $e";
    }
  }

  // Analiz sonucunu formatlanmış metne dönüştürme
  String _formatAnalysisResult(dynamic sonuc) {
    try {
      Map<String, dynamic> sonucMap;
      
      // MessageCoachAnalysis nesnesini Map'e dönüştür
      if (sonuc is MessageCoachAnalysis) {
        sonucMap = {
          'sohbetGenelHavasi': sonuc.sohbetGenelHavasi,
          'sonMesajTonu': sonuc.sonMesajTonu,
          'direktYorum': sonuc.direktYorum,
          'cevapOnerileri': sonuc.cevapOnerileri
        };
      } else if (sonuc is Map<String, dynamic>) {
        sonucMap = sonuc;
      } else {
        return "Bilinmeyen analiz sonucu formatı";
      }
      
      final sohbetHavasi = sonucMap['sohbetGenelHavasi'] ?? 'Belirsiz';
      final sonMesajTonu = sonucMap['sonMesajTonu'] ?? 'Belirsiz';
      final direktYorum = sonucMap['direktYorum'] ?? 'Yorum alınamadı';
      
      // cevapOnerileri'nin bir liste olduğunu kontrol et
      String cevapOnerileriMetni = '';
      final cevapOnerileri = sonucMap['cevapOnerileri'];
      
      if (cevapOnerileri != null) {
        if (cevapOnerileri is Iterable) {
          // Liste ise değerleri birleştir
          cevapOnerileriMetni = (cevapOnerileri as Iterable).join('\n- ');
          if (cevapOnerileriMetni.isNotEmpty) {
            cevapOnerileriMetni = '- $cevapOnerileriMetni';
          }
        } else if (cevapOnerileri is String) {
          // String ise doğrudan kullan
          cevapOnerileriMetni = cevapOnerileri;
        }
      }
      
      return '''
Sohbet Genel Havası: $sohbetHavasi
Son Mesaj Tonu: $sonMesajTonu

Yorum: $direktYorum

${cevapOnerileriMetni.isNotEmpty ? 'Cevap Önerileri:\n$cevapOnerileriMetni' : ''}
'''.trim();
    } catch (e) {
      return "Analiz sonuçları formatlanırken hata oluştu: $e";
    }
  }

  // Mesaj koçu analizi yap - ana sayfayı güncellemeyen versiyonu
  Future<MessageCoachAnalysis?> analyzeChatCoach(String messageText) async {
    if (messageText.trim().isEmpty) {
      return null;
    }
    
    try {
      _logger.d('Mesaj koçu analizi başlatılıyor');
      
      // Analiz sonucunu al - sadece analiz yap, ana sayfayı güncelleme
      final sonuc = await _aiService.sohbetiAnalizeEt(messageText);
      _logger.d('Mesaj koçu analizi tamamlandı');
      
      return sonuc;
    } catch (e) {
      _logger.e('Mesaj koçu analizi hatası: $e');
      return null;
    }
  }

  // Yardımcı fonksiyonlar
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }
} 