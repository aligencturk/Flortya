import 'package:cloud_firestore/cloud_firestore.dart';

/// Premium kullanıcı kontrolü için yardımcı fonksiyonlar
class PremiumUtils {
  /// Kullanıcının premium olup olmadığını kontrol eder
  /// Premium expiry tarihi bugünden önce ya da null ise false döner
  static bool isPremiumUser(Timestamp? premiumExpiry) {
    if (premiumExpiry == null) {
      return false;
    }
    
    final DateTime expiryDate = premiumExpiry.toDate();
    final DateTime now = DateTime.now();
    
    // Bugünden önceyse premium değil
    return expiryDate.isAfter(now);
  }
  
  /// Premium kalan süreyi gün olarak döner
  static int getPremiumRemainingDays(Timestamp? premiumExpiry) {
    if (premiumExpiry == null) return 0;
    
    final DateTime expiryDate = premiumExpiry.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = expiryDate.difference(now);
    
    return difference.inDays.clamp(0, double.infinity).toInt();
  }
  
  /// Premium durumunu string olarak döner
  static String getPremiumStatusText(Timestamp? premiumExpiry) {
    if (isPremiumUser(premiumExpiry)) {
      final remainingDays = getPremiumRemainingDays(premiumExpiry);
      return 'Premium Üyelik Aktif ($remainingDays gün kaldı)';
    } else {
      return 'Normal Üyelik';
    }
  }
} 