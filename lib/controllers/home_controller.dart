import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/ai_service.dart';

class HomeController extends ChangeNotifier {
  final UserService _userService;
  final AiService _aiService;
  
  bool _isLoading = false;
  String? _errorMessage;
  AnalizSonucu? _sonAnalizSonucu;
  List<AnalizSonucu> _analizGecmisi = [];
  Map<String, dynamic> _kategoriDegisimleri = {};
  List<String> _kisisellestirilmisTavsiyeler = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AnalizSonucu? get sonAnalizSonucu => _sonAnalizSonucu;
  List<AnalizSonucu> get analizGecmisi => _analizGecmisi;
  Map<String, dynamic> get kategoriDegisimleri => _kategoriDegisimleri;
  List<String> get kisisellestirilmisTavsiyeler => _kisisellestirilmisTavsiyeler;

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

  // Yükleme durumunu güncelleme
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Hata mesajını temizleme
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Hata mesajını ayarlama
  void _setError(String error) {
    _errorMessage = error;
    debugPrint(error);
    notifyListeners();
  }
} 