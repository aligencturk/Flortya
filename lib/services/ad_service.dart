import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'logger_service.dart';

/// AdMob reklamlarını yönetmek için kullanılan servis sınıfı.
class AdService {
  static final LoggerService _logger = LoggerService();
  
  /// Test cihazı ID'leri
  static final List<String> testDevices = [''];
  
  /// Ödüllü reklam test ID'si (Android)
  static const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  
  /// Ödüllü reklamı yükler ve tamamlandığında callback çağırır
  static Future<void> loadRewardedAd(Function onAdCompleted) async {
    _logger.i('Ödüllü reklam yükleniyor...');
    
    // Hata olması durumunda callback'i çağırmadan çık
    void _handleError(String message) {
      _logger.e('Reklam hatası: $message');
      // Kullanıcıya hata mesajı gösterme kodunu buraya ekleyebilirsiniz
    }
    
    try {
      RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _logger.i('Ödüllü reklam yüklendi');
            
            // Reklam kapatıldığında yapılacak işlemler
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (RewardedAd ad) {
                _logger.i('Reklam kapatıldı');
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
                _logger.e('Reklam gösterme hatası: ${error.message}');
                ad.dispose();
                _handleError('Reklam gösterilemedi');
              },
              onAdShowedFullScreenContent: (RewardedAd ad) {
                _logger.i('Reklam tam ekran gösterildi');
              },
            );
            
            // Reklamı göster
            ad.show(
              onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
                _logger.i('Kullanıcı ödül kazandı: ${rewardItem.amount} ${rewardItem.type}');
                // Ödül kazanıldığında callback'i çağır
                onAdCompleted();
              },
            );
          },
          onAdFailedToLoad: (LoadAdError error) {
            _logger.e('Reklam yükleme hatası: ${error.message}');
            _handleError('Reklam yüklenemedi');
          },
        ),
      );
    } catch (e) {
      _logger.e('Beklenmeyen reklam hatası: $e');
      _handleError('Reklam işlemi sırasında hata oluştu');
    }
  }
} 