import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/logger_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

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
      rethrow; // Hata yeniden fırlatılarak, çağıran kod tarafından yakalanabilir
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
      // iOS için APNS token kontrolü
      if (Platform.isIOS) {
        try {
          // iOS cihazlarda FCM token almadan önce APNS token kontrolü yapılmalı
          // APNS token almaya çalış, eğer hata verirse bunu yakala ama uygulamayı durdurma
          String? apnsToken = await _firebaseMessaging.getAPNSToken();
          _logger.i('APNS Token: $apnsToken');
          
          // APNS token null olabilir (simülatör vb. durumlarda)
          if (apnsToken == null) {
            _logger.w('APNS token alınamadı. Uygulama iOS simülatöründe çalışıyor olabilir veya push bildirimleri kullanılamıyor.');
            return; // APNS token alınamadıysa, FCM token almaya çalışma
          }
        } catch (e) {
          _logger.w('APNS token alınırken hata: $e');
          return; // APNS token hatası durumunda FCM token almaya çalışma
        }
      }
      
      // FCM token alma işlemi
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _fcmToken = token;
        _logger.i('FCM Token alındı: $token');
        
        // Firestore'a kaydet
        await _saveFcmTokenToFirestore(token);
      } else {
        _logger.w('FCM Token alınamadı (null)');
      }
    } catch (e) {
      _logger.e('FCM token alınırken hata: $e');
      // Bu hata yeniden fırlatılmıyor, böylece uygulama çalışmaya devam edebilir
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
  
  // Yerel bildirim göster (bildirim izni olmayan durumlar için)
  Future<void> showLocalNotification(String title, String body) async {
    try {
      _logger.i('Yerel bildirim gösteriliyor: $title - $body');
      
      // Bu sadece bir log kaydı olarak kalacak, gerçek bir yerel bildirim göstermek için
      // flutter_local_notifications gibi bir paket kullanmak gerekir.
      
      // Şu anda Firestore üzerinden kaydediyoruz, kullanıcı uygulama açtığında görmesi için
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _firestore.collection('user_notifications').add({
          'userId': currentUser.uid,
          'title': title,
          'body': body,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _logger.i('Yerel bildirim Firestore\'a kaydedildi');
      }
    } catch (e) {
      _logger.e('Yerel bildirim gösterme hatası: $e');
    }
  }
  
  // FCM konu aboneliği (örn. tüm kullanıcılara bildirim göndermek için)
  Future<void> subscribeToTopic(String topic) async {
    try {
      // iOS platformu için FCM token kontrolü
      if (Platform.isIOS && _fcmToken == null) {
        _logger.w('FCM token olmadığı için "$topic" konusuna abone olunamadı');
        return;
      }
      
      await _firebaseMessaging.subscribeToTopic(topic);
      _logger.i('$topic konusuna abone olundu');
    } catch (e) {
      _logger.e('"$topic" konusuna abone olunurken hata: $e');
      rethrow; // Ana uygulamanın hata yakalayabilmesi için
    }
  }
  
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      // iOS platformu için FCM token kontrolü
      if (Platform.isIOS && _fcmToken == null) {
        _logger.w('FCM token olmadığı için "$topic" konusundan abonelik kaldırılamadı');
        return;
      }
      
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      _logger.i('$topic konusundan abonelik kaldırıldı');
    } catch (e) {
      _logger.e('"$topic" konusundan abonelik kaldırılırken hata: $e');
    }
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