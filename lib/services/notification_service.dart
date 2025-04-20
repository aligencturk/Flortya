import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/logger_service.dart';

class NotificationService {
  final LoggerService _logger = LoggerService();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
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
      String? token = await _firebaseMessaging.getToken();
      _logger.i('FCM Token: $token');
      
      // Yerel bildirimler için kanal oluştur
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'daily_advice_channel',
        'Günlük Tavsiyeler',
        description: 'Günlük tavsiye bildirimleri için kanal',
        importance: Importance.high,
      );
      
      // Kanal Android'e kaydet
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
          
      // Yerel bildirimleri başlat
      await _flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      
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
        AndroidNotification? android = message.notification?.android;
        
        if (notification != null && android != null) {
          _flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
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
  
  // Günlük tavsiye bildirimi gönder
  Future<void> showDailyAdviceNotification(String title, String body) async {
    try {
      // Yerel bildirim göster
      await _flutterLocalNotificationsPlugin.show(
        0, // Bildirim ID'si
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_advice_channel',
            'Günlük Tavsiyeler',
            channelDescription: 'Günlük tavsiye kartları bildirimleri',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      _logger.i('Günlük tavsiye bildirimi gönderildi: $title');
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