import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_coach_visual_analysis.dart';
import '../services/message_coach_service.dart';
import '../services/logger_service.dart';
import '../services/premium_service.dart';

/// Mesaj koçu görsel analiz kontrolcüsü için durum
@immutable
class MesajKocuGorselDurumu {
  final bool yukleniyor;
  final bool hataVar;
  final String? hataMesaji;
  final File? secilenGorsel;
  final MessageCoachVisualAnalysis? analiz;
  final String? userId;
  final bool isPremium;
  
  // Kilitleme durumları
  final bool alternativeMessagesUnlocked;
  final bool positiveScenarioUnlocked;
  final bool negativeScenarioUnlocked;
  
  const MesajKocuGorselDurumu({
    this.yukleniyor = false,
    this.hataVar = false,
    this.hataMesaji,
    this.secilenGorsel,
    this.analiz,
    this.userId,
    this.isPremium = false,
    this.alternativeMessagesUnlocked = false,
    this.positiveScenarioUnlocked = false,
    this.negativeScenarioUnlocked = false,
  });
  
  MesajKocuGorselDurumu copyWith({
    bool? yukleniyor,
    bool? hataVar,
    String? hataMesaji,
    File? secilenGorsel,
    MessageCoachVisualAnalysis? analiz,
    String? userId,
    bool? isPremium,
    bool? alternativeMessagesUnlocked,
    bool? positiveScenarioUnlocked,
    bool? negativeScenarioUnlocked,
  }) {
    return MesajKocuGorselDurumu(
      yukleniyor: yukleniyor ?? this.yukleniyor,
      hataVar: hataVar ?? this.hataVar,
      hataMesaji: hataMesaji ?? this.hataMesaji,
      secilenGorsel: secilenGorsel ?? this.secilenGorsel,
      analiz: analiz ?? this.analiz,
      userId: userId ?? this.userId,
      isPremium: isPremium ?? this.isPremium,
      alternativeMessagesUnlocked: alternativeMessagesUnlocked ?? this.alternativeMessagesUnlocked,
      positiveScenarioUnlocked: positiveScenarioUnlocked ?? this.positiveScenarioUnlocked,
      negativeScenarioUnlocked: negativeScenarioUnlocked ?? this.negativeScenarioUnlocked,
    );
  }
  
  /// Yeni durumla resetleme
  MesajKocuGorselDurumu reset() {
    return MesajKocuGorselDurumu(
      userId: userId,
      isPremium: isPremium,
    );
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
    LoggerService(),
    PremiumService()
  );
});

/// Mesaj koçu görsel analiz kontrolcüsü
class MesajKocuGorselKontrol extends StateNotifier<MesajKocuGorselDurumu> {
  final MessageCoachService _mesajKocuServisi;
  final LoggerService _logServisi;
  final PremiumService _premiumService;
  
  MesajKocuGorselKontrol(
    this._mesajKocuServisi, 
    this._logServisi,
    this._premiumService
  ) : super(const MesajKocuGorselDurumu());
  
  /// Kullanıcı ID'sini ayarla
  void kullaniciIdAyarla(String userId, {bool isPremium = false}) {
    state = state.copyWith(userId: userId, isPremium: isPremium);
    _logServisi.i('Mesaj koçu görsel kontrolcüsüne kullanıcı ID ayarlandı: $userId, Premium: $isPremium');
    
    // Premium değilse durumları kontrol et
    if (!isPremium) {
      _reklamVeErisimDurumlariniKontrolEt();
    }
  }
  
  /// Premium durumunu güncelle
  void premiumDurumunuGuncelle(bool isPremium) {
    state = state.copyWith(isPremium: isPremium);
    _logServisi.i('Premium durumu güncellendi: $isPremium');
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
  
  /// Görsel mod için reklam izleme durumunu kontrol et
  Future<bool> gorselModIcinReklamIzlenmismi() async {
    if (state.isPremium) return true;
    return await _premiumService.isVisualModeAdViewed();
  }
  
  /// Görsel mod için reklam izlendiğini işaretle
  Future<void> gorselModReklamIzlendi() async {
    await _premiumService.setVisualModeAdViewed(true);
    _logServisi.i('Görsel mod için reklam izlendi olarak işaretlendi');
  }
  
  /// Alternatif öneriler kilidi açık mı kontrol et
  Future<bool> alternativeMessagesKilidiAcikmi() async {
    if (state.isPremium) return true;
    if (state.alternativeMessagesUnlocked) return true;
    return await _premiumService.isVisualAlternativeSuggestionsUnlocked();
  }
  
  /// Alternatif öneriler kilidini aç
  Future<void> alternativeMessagesKilidiniAc() async {
    await _premiumService.unlockVisualAlternativeSuggestions();
    state = state.copyWith(alternativeMessagesUnlocked: true);
    _logServisi.i('Görsel mod alternatif öneriler kilidi açıldı');
  }
  
  /// Olumlu senaryo kilidi açık mı kontrol et
  Future<bool> olumluSenaryoKilidiAcikmi() async {
    if (state.isPremium) return true;
    if (state.positiveScenarioUnlocked) return true;
    return await _premiumService.isPositiveResponseScenarioUnlocked();
  }
  
  /// Olumlu senaryo kilidini aç
  Future<void> olumluSenaryoKilidiniAc() async {
    await _premiumService.unlockPositiveResponseScenario();
    state = state.copyWith(positiveScenarioUnlocked: true);
    _logServisi.i('Görsel mod olumlu senaryo kilidi açıldı');
  }
  
  /// Olumsuz senaryo kilidi açık mı kontrol et
  Future<bool> olumsuzSenaryoKilidiAcikmi() async {
    if (state.isPremium) return true;
    if (state.negativeScenarioUnlocked) return true;
    return await _premiumService.isNegativeResponseScenarioUnlocked();
  }
  
  /// Olumsuz senaryo kilidini aç
  Future<void> olumsuzSenaryoKilidiniAc() async {
    await _premiumService.unlockNegativeResponseScenario();
    state = state.copyWith(negativeScenarioUnlocked: true);
    _logServisi.i('Görsel mod olumsuz senaryo kilidi açıldı');
  }
  
  /// Reklam ve erişim durumlarını kontrol et
  Future<void> _reklamVeErisimDurumlariniKontrolEt() async {
    if (state.isPremium) return;
    
    bool alternativesUnlocked = await _premiumService.isVisualAlternativeSuggestionsUnlocked();
    bool positiveUnlocked = await _premiumService.isPositiveResponseScenarioUnlocked();
    bool negativeUnlocked = await _premiumService.isNegativeResponseScenarioUnlocked();
    
    state = state.copyWith(
      alternativeMessagesUnlocked: alternativesUnlocked,
      positiveScenarioUnlocked: positiveUnlocked,
      negativeScenarioUnlocked: negativeUnlocked
    );
    
    _logServisi.i('Görsel mod durumları: Alt mesajlar: $alternativesUnlocked, ' 
                + 'Olumlu senaryo: $positiveUnlocked, Olumsuz senaryo: $negativeUnlocked');
  }
  
  /// Görsel analizi başlat
  Future<void> gorselAnalizeEt(String aciklama) async {
    try {
      // Görsel kontrolü
      if (state.secilenGorsel == null) {
        _logServisi.w('Görsel analizi başlatılamadı: Görsel seçilmemiş');
        state = state.hataOlustur('Lütfen önce bir sohbet görüntüsü yükleyin.');
        return;
      }
      
      // Açıklama kontrolü
      if (aciklama.trim().isEmpty) {
        _logServisi.w('Görsel analizi başlatılamadı: Açıklama boş');
        state = state.hataOlustur('Lütfen bir açıklama girin.');
        return;
      }
      
      // Premium değilse erişim kontrolü yap
      if (!state.isPremium) {
        // İlk kullanım kontrolü
        bool isFirstUseCompleted = await _premiumService.isVisualModeFirstUseCompleted();
        
        if (isFirstUseCompleted) {
          // İlk kullanım tamamlanmış, premium gerekli
          _logServisi.i('Görsel mod için premium gerekiyor, ilk kullanım hakkı tükenmiş');
          state = state.hataOlustur('Bu özelliği kullanmak için Premium üyelik gerekiyor. İlk kullanım hakkınızı kullanmışsınız.');
          return;
        }
        
        bool visualModeAdViewed = await _premiumService.isVisualModeAdViewed();
        
        if (!visualModeAdViewed) {
          // Reklam gösterme gereksinimi - görsel analizden önce reklam izlenmesi gerektiğini belirt
          _logServisi.i('Görsel mod için reklam izlenmesi gerekiyor');
          return;
        }
      }
      
      // Yükleme durumunu ayarla
      state = state.yuklemeBaslat();
      _logServisi.i('Görsel analizi başlatılıyor. Görsel: ${state.secilenGorsel!.path}, Açıklama: $aciklama');
      
      // Servisi çağır
      _logServisi.d('MessageCoachService.sohbetGoruntusunuAnalizeEt çağrılıyor');
      final analiz = await _mesajKocuServisi.sohbetGoruntusunuAnalizeEt(
        state.secilenGorsel!,
        aciklama
      );
      
      if (analiz == null) {
        _logServisi.e('Analiz sonucu null döndü');
        state = state.hataOlustur('Analiz sonucu alınamadı.');
        return;
      }
      
      // Analiz sonucunu ayarla
      state = state.basarili(analiz);
      _logServisi.i('Görsel analizi tamamlandı: ${analiz.isAnalysisRedirect ? 'Yönlendirme' : 'Başarılı analiz'}');
      
      // Premium olmayan kullanıcı için ilk kullanımı tamamlandı olarak işaretle
      if (!state.isPremium) {
        await _premiumService.markVisualModeFirstUseCompleted();
        _logServisi.i('Premium olmayan kullanıcı için görsel mod ilk kullanım tamamlandı olarak işaretlendi');
      }
      
      // Analiz sonuçlarını Firebase'e kaydet
      if (state.userId != null && state.userId!.isNotEmpty) {
        _logServisi.d('Görsel analizi Firebase\'e kaydediliyor: ${state.userId}');
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
      
    } catch (e, stackTrace) {
      _logServisi.e('Görsel analizi hatası', e);
      _logServisi.e('Stack trace: $stackTrace');
      state = state.hataOlustur(e.toString());
    }
  }
  
  /// Durumu sıfırla
  void durumSifirla() {
    // Kullanıcı ID'sini ve premium durumunu koruyarak durumu sıfırla
    String? userId = state.userId;
    bool isPremium = state.isPremium;
    bool alternativeMessagesUnlocked = state.alternativeMessagesUnlocked;
    bool positiveScenarioUnlocked = state.positiveScenarioUnlocked;
    bool negativeScenarioUnlocked = state.negativeScenarioUnlocked;
    
    state = MesajKocuGorselDurumu(
      userId: userId,
      isPremium: isPremium,
      alternativeMessagesUnlocked: alternativeMessagesUnlocked,
      positiveScenarioUnlocked: positiveScenarioUnlocked,
      negativeScenarioUnlocked: negativeScenarioUnlocked,
    );
    _logServisi.i('Mesaj koçu görsel durumu sıfırlandı');
  }
} 