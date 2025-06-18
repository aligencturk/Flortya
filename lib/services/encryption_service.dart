import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';

/// Analiz verilerini şifrelemek ve çözmek için servis
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  late Encrypter _encrypter;
  late IV _iv;
  bool _isInitialized = false;
  final LoggerService _logger = LoggerService();

  /// Kullanıcı kimliğinden şifreleme anahtarı türet ve servisi başlat
  void initializeWithUserId(String userId) {
    try {
      // Kullanıcı ID'sinden güvenli bir anahtar türet + uygulama özel salt
      final keyString = '${userId}_FlörtyaSecretSalt2024!_AnalysisEncryption';
      final keyBytes = sha256.convert(utf8.encode(keyString)).bytes;
      final key = Key(Uint8List.fromList(keyBytes));
      
      // Sabit IV kullan (aynı veri her zaman aynı şekilde şifrelensin)
      final ivString = '${userId}_FlörtyaIV2024';
      final ivBytes = sha256.convert(utf8.encode(ivString)).bytes.take(16).toList();
      _iv = IV(Uint8List.fromList(ivBytes));
      
      _encrypter = Encrypter(AES(key));
      _isInitialized = true;

      _logger.i('Şifreleme servisi kullanıcı ID\'si ile başlatıldı: ${userId.substring(0, 8)}...');
    } catch (e) {
      _logger.e('Şifreleme servisi başlatma hatası: $e');
      _isInitialized = false;
    }
  }

  /// Otomatik olarak mevcut kullanıcı ile başlat
  void initializeWithCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      initializeWithUserId(user.uid);
    } else {
      _logger.w('Şifreleme servisi başlatılamadı: Oturum açmış kullanıcı yok');
      _isInitialized = false;
    }
  }

  /// JSON verilerini şifrele
  String encryptJson(Map<String, dynamic> data) {
    if (!_isInitialized) {
      initializeWithCurrentUser();
      if (!_isInitialized) {
        _logger.e('Şifreleme başarısız: Servis başlatılamadı');
        return jsonEncode(data); // Şifrelemeden gönder
      }
    }

    try {
      final jsonString = jsonEncode(data);
      final encrypted = _encrypter.encrypt(jsonString, iv: _iv);
      _logger.d('Veri başarıyla şifrelendi');
      return encrypted.base64;
    } catch (e) {
      _logger.e('Şifreleme hatası: $e');
      return jsonEncode(data); // Hata durumunda şifrelemeden gönder
    }
  }

  /// Şifreli JSON verilerini çöz
  Map<String, dynamic> decryptJson(String encryptedData) {
    if (!_isInitialized) {
      initializeWithCurrentUser();
      if (!_isInitialized) {
        _logger.e('Şifre çözme başarısız: Servis başlatılamadı');
        try {
          return jsonDecode(encryptedData);
        } catch (e) {
          return {};
        }
      }
    }

    try {
      final encrypted = Encrypted.fromBase64(encryptedData);
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);
      final data = jsonDecode(decrypted);
      _logger.d('Veri başarıyla çözüldü');
      return data as Map<String, dynamic>;
    } catch (e) {
      _logger.e('Şifre çözme hatası: $e');
      // Hata durumunda düz JSON parse etmeye çalış
      try {
        return jsonDecode(encryptedData);
      } catch (e2) {
        _logger.e('JSON parse hatası: $e2');
        return {};
      }
    }
  }

  /// String verilerini şifrele
  String encryptString(String data) {
    if (!_isInitialized) {
      initializeWithCurrentUser();
      if (!_isInitialized) {
        _logger.e('Şifreleme başarısız: Servis başlatılamadı');
        return data; // Şifrelemeden gönder
      }
    }

    try {
      final encrypted = _encrypter.encrypt(data, iv: _iv);
      _logger.d('String başarıyla şifrelendi');
      return encrypted.base64;
    } catch (e) {
      _logger.e('String şifreleme hatası: $e');
      return data; // Hata durumunda şifrelemeden gönder
    }
  }

  /// Şifreli string verilerini çöz
  String decryptString(String encryptedData) {
    if (!_isInitialized) {
      initializeWithCurrentUser();
      if (!_isInitialized) {
        _logger.e('Şifre çözme başarısız: Servis başlatılamadı');
        return encryptedData;
      }
    }

    try {
      final encrypted = Encrypted.fromBase64(encryptedData);
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);
      _logger.d('String başarıyla çözüldü');
      return decrypted;
    } catch (e) {
      _logger.e('String şifre çözme hatası: $e');
      return encryptedData; // Hata durumunda düz veriyi döndür
    }
  }

  /// Servisi sıfırla
  void reset() {
    _isInitialized = false;
    _logger.i('Şifreleme servisi sıfırlandı');
  }

  /// Servis hazır durumda mı?
  bool get isInitialized => _isInitialized;
} 