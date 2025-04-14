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
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  // Info seviyesinde log
  void i(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  // Warning seviyesinde log
  void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  // Error seviyesinde log
  void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  // Çok ayrıntılı seviyede log
  void v(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.v(message, error: error, stackTrace: stackTrace);
  }

  // Kritik seviyede log
  void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
} 