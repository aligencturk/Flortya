import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Firebase Authentication hatalarını detaylıca loglama
  void logFirebaseAuthError({
    required String source, // Hangi servis/viewmodel
    required String operation, // Hangi işlem (signUpWithEmail, signInWithEmail vs.)
    required String userEmail, // Kullanıcının e-posta adresi
    required FirebaseAuthException firebaseError,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    
    // Renkli ve okunabilir format oluştur
    final divider = '═' * 100;
    final subDivider = '─' * 80;
    
    String errorReport = '''
🔥 $divider
🔥 ⚠️  FIREBASE AUTHENTICATION HATASI ⚠️ 
🔥 $divider
🔥 
🔥 �� ZAMAN: $timestamp
🔥 📍 KAYNAK: $source
🔥 ⚙️  İŞLEM: $operation
🔥 📧 E-POSTA: $userEmail
🔥 
🔥 $subDivider
🔥 ❌ HATA BİLGİLERİ:
🔥 $subDivider
🔥 🏷️  HATA KODU: ${firebaseError.code}
🔥 💬 HATA MESAJI: ${firebaseError.message ?? 'Mesaj yok'}
🔥 🔗 CREDENTIAL: ${firebaseError.credential?.toString() ?? 'Credential yok'}
🔥 📧 E-POSTA: ${firebaseError.email ?? 'E-posta bilgisi yok'}
🔥 📞 TELEFON: ${firebaseError.phoneNumber ?? 'Telefon bilgisi yok'}
🔥 🔑 TENANT ID: ${firebaseError.tenantId ?? 'Tenant ID yok'}
🔥 
🔥 $subDivider
🔥 🔍 DETAYLAR:
🔥 $subDivider
🔥 🛠️  FULL ERROR: $firebaseError
🔥 📊 ERROR TYPE: ${firebaseError.runtimeType}
🔥 🔗 ERROR CODE TYPE: ${firebaseError.code.runtimeType}
🔥 ''';

    // Ek veriler varsa ekle
    if (additionalData != null && additionalData.isNotEmpty) {
      errorReport += '''
🔥 
🔥 $subDivider
🔥 📝 EK VERİLER:
🔥 $subDivider
''';
      additionalData.forEach((key, value) {
        errorReport += '🔥 📌 $key: $value\n';
      });
    }

    // Stack trace varsa ekle
    if (stackTrace != null) {
      errorReport += '''
🔥 
🔥 $subDivider
🔥 📚 STACK TRACE:
🔥 $subDivider
🔥 $stackTrace
🔥 ''';
    }

    errorReport += '''
🔥 $divider
🔥 🔥 FIREBASE AUTH ERROR LOG SONU 🔥
🔥 $divider
''';

    // Logger ile hata seviyesinde logla
    _logger.e(errorReport);
  }

  // E-posta kayıt hatalarını özel olarak loglama
  void logEmailRegistrationError({
    required String source,
    required String userEmail,
    required String displayName,
    required FirebaseAuthException firebaseError,
    StackTrace? stackTrace,
    String? firstName,
    String? lastName,
  }) {
    final additionalData = <String, dynamic>{
      'displayName': displayName,
      'firstName': firstName ?? 'Belirtilmemiş',
      'lastName': lastName ?? 'Belirtilmemiş',
    };

    logFirebaseAuthError(
      source: source,
      operation: 'E-POSTA KAYIT (signUpWithEmail)',
      userEmail: userEmail,
      firebaseError: firebaseError,
      stackTrace: stackTrace,
      additionalData: additionalData,
    );
  }

  // E-posta giriş hatalarını özel olarak loglama
  void logEmailSignInError({
    required String source,
    required String userEmail,
    required FirebaseAuthException firebaseError,
    StackTrace? stackTrace,
  }) {
    logFirebaseAuthError(
      source: source,
      operation: 'E-POSTA GİRİŞ (signInWithEmail)',
      userEmail: userEmail,
      firebaseError: firebaseError,
      stackTrace: stackTrace,
    );
  }
} 