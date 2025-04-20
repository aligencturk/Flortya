import 'package:logger/logger.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  late Logger _logger;

  // Singleton yapısı
  factory LoggerService() {
    return _instance;
  }

  LoggerService._internal() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2, // gösterilecek metod sayısı
        errorMethodCount: 8, // hata durumunda gösterilecek metod sayısı
        lineLength: 120, // maksimum satır uzunluğu
        colors: true, // renkleri etkinleştir
        printEmojis: true, // emojileri etkinleştir
        printTime: true, // zamanı yazdır
      ),
    );
  }

  // Debug seviyesinde log
  void d(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error != null) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    } else {
      _logger.d(message);
    }
  }

  // Info seviyesinde log
  void i(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error != null) {
      _logger.i(message, error: error, stackTrace: stackTrace);
    } else {
      _logger.i(message);
    }
  }

  // Warning seviyesinde log
  void w(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error != null) {
      _logger.w(message, error: error, stackTrace: stackTrace);
    } else {
      _logger.w(message);
    }
  }

  // Error seviyesinde log
  void e(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error is StackTrace) {
      // Kullanıcı hata yerine StackTrace geçmiş, doğru şekilde düzenliyoruz
      _logger.e(message, stackTrace: error);
    } else if (error != null) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    } else {
      _logger.e(message);
    }
  }

  // Çok ayrıntılı seviyede log
  void v(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error != null) {
      _logger.v(message, error: error, stackTrace: stackTrace);
    } else {
      _logger.v(message);
    }
  }

  // Kritik seviyede log
  void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error != null) {
      _logger.f(message, error: error, stackTrace: stackTrace);
    } else {
      _logger.f(message);
    }
  }
} 