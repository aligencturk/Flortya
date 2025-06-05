import 'dart:async';

/// Event Bus sınıfı, uygulama içinde farklı widget'lar arasında
/// haberleşmeyi sağlayan basit bir olay yayıncısıdır.
class EventBusService {
  // Singleton yapı için
  static final EventBusService _instance = EventBusService._internal();
  
  // Fabrika kurucusu, var olan örneği döndürür
  factory EventBusService() {
    return _instance;
  }
  
  // Private kurucu
  EventBusService._internal();
  
  // Event stream controller
  final StreamController _eventController = StreamController.broadcast();
  
  // Event stream'ine abone olmak için
  Stream get eventStream => _eventController.stream;
  
  // Olay yayınlamak için
  void emit(dynamic event) {
    _eventController.sink.add(event);
  }
  
  // Servisi temizlemek için
  void dispose() {
    _eventController.close();
  }
}

/// Uygulama içindeki olayları tanımlayan sınıf
class AppEvents {
  // Wrapped hikayeleri sıfırlama olayı
  static const String resetWrappedStories = 'reset_wrapped_stories';
  
  // Diğer olaylar buraya eklenebilir
  static const String refreshHomeData = 'refresh_home_data';
  static const String userLoggedIn = 'user_logged_in';
  static const String userLoggedOut = 'user_logged_out';
} 