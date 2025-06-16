import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/premium_utils.dart';
import 'ad_service.dart';

/// Premium kontrolleri ve reklam yönetimi için merkezi servis
class PremiumControllerService {
  /// Premium kullanıcı kontrolü yaparak reklam gösterip göstermeyeceğine karar verir
  /// Premium kullanıcı ise direkt callback'i çağırır, değilse reklam gösterir
  static Future<void> checkPremiumAndShowAd({
    required Timestamp? premiumExpiry,
    required Function onCompleted,
    Function? onAdSkipped,
  }) async {
    // Premium kontrolü
    final bool isPremium = PremiumUtils.isPremiumUser(premiumExpiry);
    
    if (isPremium) {
      // Premium kullanıcı - direkt özelliği aç
      onCompleted();
    } else {
      // Normal kullanıcı - reklam göster
      await AdService.loadRewardedAd(() {
        onCompleted();
      });
    }
  }
  
  /// Premium kullanıcı olup olmadığını kontrol eder
  static bool isPremium(Timestamp? premiumExpiry) {
    return PremiumUtils.isPremiumUser(premiumExpiry);
  }
  
  /// Premium durumunu string olarak döner
  static String getPremiumStatusText(Timestamp? premiumExpiry) {
    return PremiumUtils.getPremiumStatusText(premiumExpiry);
  }
} 