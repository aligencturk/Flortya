import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_coach_visual_analysis.dart';
import '../services/message_coach_service.dart';
import '../services/logger_service.dart';

/// Mesaj koçu görsel analiz kontrolcüsü için durum
@immutable
class MesajKocuGorselDurumu {
  final bool yukleniyor;
  final bool hataVar;
  final String? hataMesaji;
  final File? secilenGorsel;
  final MessageCoachVisualAnalysis? analiz;
  final String? userId;
  
  const MesajKocuGorselDurumu({
    this.yukleniyor = false,
    this.hataVar = false,
    this.hataMesaji,
    this.secilenGorsel,
    this.analiz,
    this.userId,
  });
  
  MesajKocuGorselDurumu copyWith({
    bool? yukleniyor,
    bool? hataVar,
    String? hataMesaji,
    File? secilenGorsel,
    MessageCoachVisualAnalysis? analiz,
    String? userId,
  }) {
    return MesajKocuGorselDurumu(
      yukleniyor: yukleniyor ?? this.yukleniyor,
      hataVar: hataVar ?? this.hataVar,
      hataMesaji: hataMesaji ?? this.hataMesaji,
      secilenGorsel: secilenGorsel ?? this.secilenGorsel,
      analiz: analiz ?? this.analiz,
      userId: userId ?? this.userId,
    );
  }
  
  /// Yeni durumla resetleme
  MesajKocuGorselDurumu reset() {
    return MesajKocuGorselDurumu(userId: this.userId);
  }
  
  /// Yükleme durumuna geçiş
  MesajKocuGorselDurumu yuklemeBaslat() {
    return copyWith(
      yukleniyor: true,
      hataVar: false,
      hataMesaji: null,
      analiz: null,
    );
  }
  
  /// Hata durumuna geçiş
  MesajKocuGorselDurumu hataOlustur(String mesaj) {
    return copyWith(
      yukleniyor: false,
      hataVar: true,
      hataMesaji: mesaj,
      analiz: null,
    );
  }
  
  /// Başarılı durum
  MesajKocuGorselDurumu basarili(MessageCoachVisualAnalysis analiz) {
    return copyWith(
      yukleniyor: false,
      hataVar: false,
      hataMesaji: null,
      analiz: analiz,
    );
  }
}

/// Mesaj koçu görsel analiz kontrolcüsü sağlayıcısı
final mesajKocuGorselKontrolProvider = StateNotifierProvider<MesajKocuGorselKontrol, MesajKocuGorselDurumu>((ref) {
  return MesajKocuGorselKontrol(
    MessageCoachService(), 
    LoggerService()
  );
});

/// Mesaj koçu görsel analiz kontrolcüsü
class MesajKocuGorselKontrol extends StateNotifier<MesajKocuGorselDurumu> {
  final MessageCoachService _mesajKocuServisi;
  final LoggerService _logServisi;
  
  MesajKocuGorselKontrol(this._mesajKocuServisi, this._logServisi) 
      : super(const MesajKocuGorselDurumu());
  
  /// Kullanıcı ID'sini ayarla
  void kullaniciIdAyarla(String userId) {
    state = state.copyWith(userId: userId);
    _logServisi.i('Mesaj koçu görsel kontrolcüsüne kullanıcı ID ayarlandı: $userId');
  }
  
  /// Görsel dosyasını ayarla
  void gorselDosyasiAyarla(File? gorselDosyasi) {
    if (gorselDosyasi == null) {
      state = state.copyWith(secilenGorsel: null);
      return;
    }
    
    state = state.copyWith(secilenGorsel: gorselDosyasi);
    _logServisi.i('Mesaj koçu için görsel dosyası seçildi: ${gorselDosyasi.path}');
  }
  
  /// Sohbet görüntüsünü analiz et
  Future<void> gorselAnalizeEt(String aciklama) async {
    try {
      // Görsel kontrolü
      if (state.secilenGorsel == null) {
        state = state.hataOlustur('Lütfen önce bir sohbet görüntüsü yükleyin.');
        return;
      }
      
      // Açıklama kontrolü
      if (aciklama.trim().isEmpty) {
        state = state.hataOlustur('Lütfen bir açıklama girin.');
        return;
      }
      
      // Yükleme durumunu ayarla
      state = state.yuklemeBaslat();
      _logServisi.i('Görsel analizi başlatılıyor. Açıklama: $aciklama');
      
      // Servisi çağır
      final analiz = await _mesajKocuServisi.sohbetGoruntusunuAnalizeEt(
        state.secilenGorsel!,
        aciklama
      );
      
      if (analiz == null) {
        state = state.hataOlustur('Analiz sonucu alınamadı.');
        return;
      }
      
      // Analiz sonucunu ayarla
      state = state.basarili(analiz);
      _logServisi.i('Görsel analizi tamamlandı');
      
      // Analiz sonuçlarını Firebase'e kaydet
      if (state.userId != null && state.userId!.isNotEmpty) {
        await _mesajKocuServisi.saveVisualMessageCoachAnalysis(
          userId: state.userId!,
          aciklama: aciklama,
          analysis: analiz,
          // Şimdilik görsel URL'i kaydetmiyoruz
        );
        _logServisi.i('Görsel analizi Firebase\'e kaydedildi');
      } else {
        _logServisi.w('Görsel analizi kaydedilemedi: Kullanıcı oturum açmamış');
      }
      
    } catch (e) {
      _logServisi.e('Görsel analizi hatası', e);
      state = state.hataOlustur(e.toString());
    }
  }
  
  /// Durumu sıfırla
  void durumSifirla() {
    // Kullanıcı ID'sini koruyarak durumu sıfırla
    state = state.reset();
    _logServisi.i('Mesaj koçu görsel durumu sıfırlandı');
  }
} 