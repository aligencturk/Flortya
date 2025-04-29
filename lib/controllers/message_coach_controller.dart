import 'package:flutter/material.dart';
import '../models/message_coach_analysis.dart';
import '../services/message_coach_service.dart';
import '../services/logger_service.dart';

class MessageCoachController extends ChangeNotifier {
  final MessageCoachService _mesajKocuService = MessageCoachService();
  final LoggerService _logger = LoggerService();
  
  MessageCoachAnalysis? _mevcutAnaliz;
  MessageCoachAnalysis? get mevcutAnaliz => _mevcutAnaliz;
  
  String? _hataMesaji;
  String? get hataMesaji => _hataMesaji;
  
  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;
  
  bool _analizTamamlandi = false;
  bool get analizTamamlandi => _analizTamamlandi;
  
  // UI metinleri
  String get baslik => 'Mesaj Koçu';
  String get aciklamaBaslik => 'Sohbet Analizi';
  String get aciklamaMetni => 'Sohbet geçmişinizi analiz etmek için kopyala-yapıştır yapın. Mesaj Koçu sohbetin genel havasını ve son mesajınızın etkisini analiz edecek.';
  String get dosyaSecmeButonMetni => 'Dosyadan Yükle';
  String get yuklemeMetni => 'Sohbet analiz ediliyor...';
  
  // Sohbet analizi sonuçlarını sıfırla
  void analizSonuclariniSifirla() {
    _mevcutAnaliz = null;
    _hataMesaji = null;
    _analizTamamlandi = false;
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
      final analizSonucu = await _mesajKocuService.sohbetiAnalizeEt(sohbetIcerigi);
      
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
          analiz: analizSonucu.analiz,
          oneriler: analizSonucu.oneriler,
          etki: analizSonucu.etki,
          sohbetGenelHavasi: 'Soğuk',
          genelYorum: 'İletişimin berbat. Bu kadar baştan savma mesajları kimse ciddiye almaz.',
          sonMesajTonu: 'Umursamaz',
          sonMesajEtkisi: sonMesajEtkisi,
          direktYorum: 'Yazma stilin çok zayıf. Karşı taraf seninle iletişim kurmakta zorlanıyor ve muhtemelen başka biriyle konuşmayı tercih ediyor.',
          cevapOnerisi: 'Ne düşündüğünü açıkça söylemek istiyorum. Bu durum benim için önemli ve senin de dürüst olmanı beklerim.',
        );
      } else {
        _mevcutAnaliz = analizSonucu;
      }
      
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
  
  // Analiz sonucunun eksik veya geçersiz alanları olup olmadığını kontrol et
  bool _analizSonucuGecersiziMi(MessageCoachAnalysis analiz) {
    final sohbetGenelHavasi = analiz.sohbetGenelHavasi;
    final sonMesajTonu = analiz.sonMesajTonu;
    final direktYorum = analiz.direktYorum;
    
    // Geçersiz ifadeleri içeriyor mu kontrol et
    final gecersizIfadeler = ['analiz edilemedi', 'yetersiz içerik', 'yapılamadı', 'alınamadı'];
    
    if (sohbetGenelHavasi == null || 
        sonMesajTonu == null || 
        direktYorum == null) {
      return true;
    }
    
    // Geçersiz ifadeleri kontrol et
    for (final ifade in gecersizIfadeler) {
      if (sohbetGenelHavasi.toLowerCase().contains(ifade) || 
          sonMesajTonu.toLowerCase().contains(ifade) || 
          direktYorum.toLowerCase().contains(ifade)) {
        return true;
      }
    }
    
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
} 