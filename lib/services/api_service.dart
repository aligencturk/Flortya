import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/analysis_result_model.dart';
import 'package:firebase_core/firebase_core.dart';

// Firebase kullanımına göre düzenlenmiş ConfigService
class ConfigService {
  String? getApiUrl() {
    return 'https://firebaseapi.com';  // Firebase için gerekiyorsa
  }
  
  String? getApiKey() {
    return '';  // Firebase için API key gerekmeyebilir
  }
  
  String? getFirebaseProjectId() {
    return 'your-firebase-project-id';
  }
}

class ApiService {
  final Logger _logger = Logger();
  final ConfigService _configService = ConfigService();

  // Mesaj analizi için wrapper metodu
  Future<AnalysisResult?> analyzeMessage(String text) async {
    try {
      _logger.i('analyzeMessage çağrıldı, analyzeText fonksiyonuna yönlendiriliyor');
      
      // API'den analiz sonucunu al
      final Map<String, dynamic>? apiResult = await analyzeText(text);
      
      if (apiResult == null) {
        _logger.e('analyzeText null sonuç döndürdü');
        return null;
      }
      
      // AnalysisResult nesnesine dönüştür
      _logger.i('API yanıtı alındı, AnalysisResult nesnesine dönüştürülüyor');
      
      try {
        return AnalysisResult.fromMap(apiResult);
      } catch (e) {
        _logger.e('API yanıtı AnalysisResult nesnesine dönüştürülemedi: $e');
        return null;
      }
    } catch (e) {
      _logger.e('analyzeMessage işleminde hata: $e');
      return null;
    }
  }

  // API ile doğrudan iletişim kuran asıl metod
  Future<Map<String, dynamic>?> analyzeText(String text) async {
    try {
      _logger.i('Metin analizi isteği gönderiliyor: ${text.substring(0, min(30, text.length))}...');
      
      if (text.isEmpty) {
        _logger.e('Analiz için boş metin gönderildi');
        return null;
      }
      
      // API URL'yi yapılandırmadan al
      final apiUrl = ConfigService().getApiUrl();
      if (apiUrl == null || apiUrl.isEmpty) {
        _logger.e('API URL yapılandırması bulunamadı');
        return null;
      }
      
      // İstek için gerekli parametreleri hazırla
      final requestBody = {
        'text': text,
        'language': 'tr', // Varsayılan dil Türkçe
      };
      
      // API isteği gönder
      final response = await http.post(
        Uri.parse('$apiUrl/analyze'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_configService.getApiKey() ?? ""}',
        },
        body: jsonEncode(requestBody),
      );
      
      // Yanıt durumunu kontrol et
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        _logger.i('Metin analizi başarılı: Duygu ve konu bilgileri alındı');
        return responseData;
      } else {
        _logger.e('API isteği başarısız oldu: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Metin analizi sırasında hata oluştu: $e');
      return null;
    }
  }
} 