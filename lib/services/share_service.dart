import 'package:flutter/services.dart';

class ShareService {
  static const MethodChannel _channel = MethodChannel('com.rivorya.flortya/share');
  
  // Paylaşılan veriyi almak için
  static Future<Map<String, dynamic>?> getSharedData() async {
    try {
      final result = await _channel.invokeMethod('getSharedData');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      print('Paylaşılan veri alınırken hata: $e');
      return null;
    }
  }
  
  // Bekleyen intent var mı kontrol et
  static Future<bool> hasPendingIntent() async {
    try {
      final result = await _channel.invokeMethod('checkPendingIntent');
      return result ?? false;
    } catch (e) {
      print('Bekleyen intent kontrolü hatası: $e');
      return false;
    }
  }
  
  // Bekleyen intent'i işle
  static Future<Map<String, dynamic>?> processPendingIntent() async {
    try {
      final result = await _channel.invokeMethod('processPendingIntent');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      print('Bekleyen intent işleme hatası: $e');
      return null;
    }
  }
  
  // Intent dinleyicileri
  static Function(Map<String, dynamic>)? _newIntentCallback;
  static Function(Map<String, dynamic>)? _hotIntentCallback;
  
  // Yeni intent geldiğinde dinlemek için
  static void setNewIntentListener(Function(Map<String, dynamic>) callback) {
    _newIntentCallback = callback;
    _setupMethodCallHandler();
  }
  
  // Hot intent (uygulama açıkken gelen intent) dinleyicisi
  static void setHotIntentListener(Function(Map<String, dynamic>) callback) {
    _hotIntentCallback = callback;
    _setupMethodCallHandler();
  }
  
  // Tek method call handler ile tüm intent'leri yönet
  static void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      final data = Map<String, dynamic>.from(call.arguments ?? {});
      
      print('🔔 ShareService: Method call received - ${call.method}');
      print('🔔 ShareService: Data: $data');
      
      switch (call.method) {
        case 'onNewIntent':
          print('📱 ShareService: Calling new intent callback');
          _newIntentCallback?.call(data);
          break;
        case 'onHotIntent':
          print('🔥 ShareService: Calling HOT intent callback');
          _hotIntentCallback?.call(data);
          break;
        default:
          print('❓ ShareService: Unknown method call: ${call.method}');
      }
    });
  }
  
  // Paylaşılan içeriği işle
  static String? processSharedContent(Map<String, dynamic> sharedData) {
    final type = sharedData['type'] as String?;
    
    switch (type) {
      case 'text':
        return sharedData['text'] as String?;
      case 'file':
        return sharedData['content'] as String?;
      case 'multiple_text':
        final texts = sharedData['texts'] as List<dynamic>?;
        return texts?.join('\n');
      case 'multiple_files':
        final contents = sharedData['contents'] as List<dynamic>?;
        return contents?.join('\n');
      default:
        return null;
    }
  }
} 