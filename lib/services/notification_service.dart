import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/logger_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final LoggerService _logger = LoggerService();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // FCM token
  String? _fcmToken;
  
  // Getter for FCM token
  String? get fcmToken => _fcmToken;
  
  // Singleton örneği
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  // Bildirim servisini başlat
  Future<void> initialize() async {
    try {
      // Firebase Messaging izinleri
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      _logger.i('Bildirim izin durumu: ${settings.authorizationStatus}');
      
      // FCM Token al
      await _updateFcmToken();
      
      // Token değişimini dinle
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _logger.i('FCM Token yenilendi: $newToken');
        _saveFcmTokenToFirestore(newToken);
      });
      
      // Ön planda FCM bildirimleri için yapılandırma
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Arka planda mesaj işleme
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Ön planda mesaj işleme
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _logger.i('Ön planda bildirim alındı: ${message.notification?.title}');
        
        RemoteNotification? notification = message.notification;
        
        if (notification != null) {
          _showNativeNotification(notification);
        }
      });
      
      // Bildirime tıklandığında işlem
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _logger.i('Bildirim tıklandı: ${message.notification?.title}');
        // Burada bildirimlere tıklandığında uygulama içinde yönlendirme yapılabilir
      });
      
    } catch (e) {
      _logger.e('Bildirim servisi başlatılırken hata: $e');
    }
  }
  
  // Yerel platformda bildirim göster (Android/iOS)
  void _showNativeNotification(RemoteNotification notification) {
    // Bu fonksiyon Flutter'ın kendi bildirim mekanizmasını kullanır
    // Native bildirimler Firebase Cloud Messaging tarafından otomatik olarak gösterilecek
    _logger.i('Bildirim alındı: ${notification.title}');
    
    // Burada ekstra işlemler gerekirse ekleyebilirsiniz
    // Örneğin: bildirim sayısını güncelleme, ses çalma vb.
  }
  
  // FCM token'ı al ve kaydet
  Future<void> _updateFcmToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _fcmToken = token;
        _logger.i('FCM Token alındı: $token');
        
        // Firestore'a kaydet
        await _saveFcmTokenToFirestore(token);
      }
    } catch (e) {
      _logger.e('FCM token alınırken hata: $e');
    }
  }
  
  // FCM token'ı Firestore'a kaydet
  Future<void> _saveFcmTokenToFirestore(String token) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userId = currentUser.uid;
        
        // Kullanıcı dokümanını güncelle
        await _firestore.collection('users').doc(userId).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        
        _logger.i('FCM token Firestore\'a kaydedildi. Kullanıcı: $userId');
      } else {
        _logger.w('Kullanıcı oturum açmadığı için FCM token kaydedilemedi');
      }
    } catch (e) {
      _logger.e('FCM token Firestore\'a kaydedilirken hata: $e');
    }
  }
  
  // Kullanıcı oturum açtığında token'ı güncelle
  Future<void> updateFcmTokenOnLogin(String userId) async {
    try {
      if (_fcmToken != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmTokens': FieldValue.arrayUnion([_fcmToken!]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        _logger.i('Oturum açma sırasında FCM token güncellendi. Kullanıcı: $userId');
      } else {
        _logger.w('FCM token null olduğu için güncelleme yapılamadı');
        await _updateFcmToken();
      }
    } catch (e) {
      _logger.e('Oturum açma sırasında FCM token güncellenirken hata: $e');
    }
  }
  
  // Kullanıcı oturumu kapattığında token'ı temizle
  Future<void> removeFcmTokenOnLogout(String userId) async {
    try {
      if (_fcmToken != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmTokens': FieldValue.arrayRemove([_fcmToken!]),
        });
        _logger.i('Oturum kapatma sırasında FCM token kaldırıldı. Kullanıcı: $userId');
      }
    } catch (e) {
      _logger.e('Oturum kapatma sırasında FCM token kaldırılırken hata: $e');
    }
  }
  
  // Günlük tavsiye bildirimi gönder
  Future<void> showDailyAdviceNotification(String title, String body) async {
    try {
      // Bu metod artık doğrudan Firebase Console üzerinden veya bir backend aracılığıyla gönderilecek
      // Burada, backend'e bildirim gönderme isteği yapılabilir
      _logger.i('Günlük tavsiye bildirimi isteği gönderildi: $title');
      
      // NOT: Gerçek uygulamada, burada bir API çağrısı yaparak backend'e bildirim gönderme isteği yapabilirsiniz
      // Örnek: await _apiService.sendNotificationRequest(title, body);
    } catch (e) {
      _logger.e('Günlük tavsiye bildirimi gösterme hatası: $e');
    }
  }
  
  // FCM konu aboneliği (örn. tüm kullanıcılara bildirim göndermek için)
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    _logger.i('$topic konusuna abone olundu');
  }
  
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    _logger.i('$topic konusundan abonelik kaldırıldı');
  }
  
  // Bildirim gösterme fonksiyonu - başarı durumu için
  void showSuccessNotification(BuildContext context, String title, String message) {
    showSnackBar(context, message, backgroundColor: Colors.green);
    _logger.i('BAŞARI: $title - $message');
  }
  
  // Bildirim gösterme fonksiyonu - hata durumu için
  void showErrorNotification(BuildContext context, String title, String message) {
    showSnackBar(context, message, backgroundColor: Colors.red);
    _logger.e('HATA: $title - $message');
  }
  
  // Bildirim gösterme fonksiyonu - uyarı durumu için
  void showWarningNotification(BuildContext context, String title, String message) {
    showSnackBar(context, message, backgroundColor: Colors.orange);
    _logger.w('UYARI: $title - $message');
  }
  
  // Bildirim gösterme fonksiyonu - bilgi durumu için
  void showInfoNotification(BuildContext context, String title, String message) {
    showSnackBar(context, message, backgroundColor: Colors.blue);
    _logger.i('BİLGİ: $title - $message');
  }
  
  // Snackbar gösterimi için yardımcı metot
  void showSnackBar(BuildContext context, String message, {Color backgroundColor = Colors.black, Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }
  
  // Toast bildirim gösterimi için metot (platform spesifik uygulamalar için)
  void showToast(String message) {
    // Platform spesifik toast gösterimi buraya eklenecek
    print('TOAST: $message');
  }
}

// Arka plan mesaj işleyici
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Bu metot arka planda çağrıldığında initialize edilmiş olmayacağı için
  // burada herhangi bir instance erişimine dikkat edin
  print('Arka planda bildirim alındı: ${message.notification?.title}');
} 