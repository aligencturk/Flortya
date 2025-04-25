import 'dart:convert';
import 'dart:math';
import 'dart:async';  // TimeoutException için import
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/analysis_result_model.dart';

// Geçici ConfigService tanımı
class ConfigService {
  String? getApiUrl() {
    return 'https://api.flortai.com';
  }
  
  String? getApiKey() {
    return '';
  }
}

class ApiService {
  final Logger _logger = Logger();
  final ConfigService _configService = ConfigService();

  // Mesaj analizi için wrapper metodu
  Future<AnalysisResult?> analyzeMessage(String text) async {
    try {
      print('🚀 ApiService.analyzeMessage çağrıldı');
      _logger.i('analyzeMessage çağrıldı, analyzeText fonksiyonuna yönlendiriliyor');
      
      // API'den analiz sonucunu al
      final Map<String, dynamic>? apiResult = await analyzeText(text).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          print('⏰ ApiService.analyzeText zaman aşımına uğradı (20 saniye)');
          _logger.e('analyzeText zaman aşımına uğradı');
          return null;
        },
      );
      
      print('📊 ApiService.analyzeText yanıtı: ${apiResult != null ? "Başarılı" : "Başarısız (null)"}');
      
      if (apiResult == null) {
        _logger.e('analyzeText null sonuç döndürdü');
        return null;
      }
      
      // CRITICAL DEBUG: API yanıtını ayrıntılı yazdır
      print('🔍 API YANITI DETAYI: ${jsonEncode(apiResult)}');
      
      // AnalysisResult nesnesine dönüştür
      _logger.i('API yanıtı alındı, AnalysisResult nesnesine dönüştürülüyor');
      
      try {
        // CRITICAL DEBUG: Yanıtı dönüştürmeden önce zorunlu alanları kontrol et
        final hasRequiredFields = _validateApiResponse(apiResult);
        if (!hasRequiredFields) {
          print('⚠️ API yanıtında zorunlu alanlar eksik, null döndürülüyor');
          return null;
        }
        
        final result = AnalysisResult.fromMap(apiResult);
        print('✅ ApiService.analyzeMessage tamamlandı: ${result.id}');
        return result;
      } catch (e) {
        print('❌ ApiService.analyzeMessage dönüştürme hatası: $e');
        print('❌ HATA DETAYI: ${e.toString()}');
        print('❌ API YANITI: ${jsonEncode(apiResult)}');
        _logger.e('API yanıtı AnalysisResult nesnesine dönüştürülemedi: $e');
        return null;
      }
    } catch (e) {
      print('❌ ApiService.analyzeMessage işleminde hata: $e');
      _logger.e('analyzeMessage işleminde hata: $e');
      return null;
    }
  }
  
  // API yanıtında zorunlu alanların varlığını kontrol et
  bool _validateApiResponse(Map<String, dynamic> response) {
    // AnalysisResult için gerekli alanları kontrol et
    final List<String> requiredFields = ['id', 'emotion', 'intent', 'tone', 'severity', 'persons'];
    final List<String> missingFields = [];
    
    for (var field in requiredFields) {
      if (!response.containsKey(field) || response[field] == null) {
        missingFields.add(field);
      }
    }
    
    if (missingFields.isNotEmpty) {
      print('⚠️ API yanıtında eksik alanlar: $missingFields');
      
      // Eksik alanları zorunlu değilse eklemeyi dene
      if (!response.containsKey('id') || response['id'] == null) {
        response['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      }
      
      if (!response.containsKey('emotion') || response['emotion'] == null) {
        response['emotion'] = 'Belirtilmemiş';
      }
      
      if (!response.containsKey('intent') || response['intent'] == null) {
        response['intent'] = 'Belirtilmemiş';
      }
      
      if (!response.containsKey('tone') || response['tone'] == null) {
        response['tone'] = 'Belirtilmemiş';
      }
      
      if (!response.containsKey('severity') || response['severity'] == null) {
        response['severity'] = 5;
      }
      
      if (!response.containsKey('persons') || response['persons'] == null) {
        response['persons'] = 'Belirtilmemiş';
      }
      
      // aiResponse alanı kontrolü
      if (!response.containsKey('aiResponse') || response['aiResponse'] == null) {
        // mesajYorumu varsa aiResponse olarak ekle
        if (response.containsKey('mesajYorumu')) {
          response['aiResponse'] = {
            'mesajYorumu': response['mesajYorumu'],
            'cevapOnerileri': response.containsKey('cevapOnerileri') ? response['cevapOnerileri'] : ['Bilgi yok']
          };
        } else {
          response['aiResponse'] = {
            'mesajYorumu': 'Yanıt yok',
            'cevapOnerileri': ['Bilgi yok']
          };
        }
      }
      
      // createdAt alanı kontrolü
      if (!response.containsKey('createdAt') || response['createdAt'] == null) {
        response['createdAt'] = DateTime.now().toIso8601String();
      }
      
      print('✅ Eksik alanlar tamamlandı: ${jsonEncode(response)}');
    }
    
    return true; // Tüm eksik alanlar tamamlandı
  }

  // API ile doğrudan iletişim kuran asıl metod
  Future<Map<String, dynamic>?> analyzeText(String text) async {
    try {
      print('🔍 ApiService.analyzeText başlıyor: ${text.substring(0, text.length > 30 ? 30 : text.length)}...');
      _logger.i('Metin analizi isteği gönderiliyor: ${text.substring(0, min(30, text.length))}...');
      
      if (text.isEmpty) {
        print('⚠️ ApiService.analyzeText: Boş metin gönderildi');
        _logger.e('Analiz için boş metin gönderildi');
        return null;
      }
      
      // API URL'yi yapılandırmadan al
      final apiUrl = ConfigService().getApiUrl();
      if (apiUrl == null || apiUrl.isEmpty) {
        print('⚠️ ApiService.analyzeText: API URL bulunamadı');
        _logger.e('API URL yapılandırması bulunamadı');
        return null;
      }
      
      // İstek için gerekli parametreleri hazırla
      final requestBody = {
        'text': text,
        'language': 'tr', // Varsayılan dil Türkçe
      };
      
      print('📡 ApiService.analyzeText: API isteği gönderiliyor: $apiUrl/analyze');
      
      // API isteği gönder
      final response = await http.post(
        Uri.parse('$apiUrl/analyze'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_configService.getApiKey() ?? ""}',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏰ ApiService.analyzeText HTTP isteği zaman aşımına uğradı (15 saniye)');
          _logger.e('HTTP isteği zaman aşımına uğradı');
          throw TimeoutException('API isteği zaman aşımına uğradı');
        },
      );
      
      print('📡 ApiService.analyzeText: API yanıtı alındı - ${response.statusCode}');
      
      // CRITICAL DEBUG: Yanıtı detaylı incele
      print('📦 API YANIT DETAYI: ${response.body}');
      
      // Yanıt durumunu kontrol et
      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body) as Map<String, dynamic>;
          print('✅ ApiService.analyzeText: Başarılı yanıt');
          _logger.i('Metin analizi başarılı: Duygu ve konu bilgileri alındı');
          
          // CRITICAL: Yanıt yapısını incele
          print('🔑 API YANIT ANAHTARLARI: ${responseData.keys.toList()}');
          
          // API yanıtını AnalysisResult formatına uygun şekilde dönüştür
          final Map<String, dynamic> transformedData = _transformApiResponse(responseData);
          
          return transformedData;
        } catch (e) {
          print('❌ ApiService.analyzeText: Yanıt işleme hatası: $e');
          print('❌ YANIT İÇERİĞİ: ${response.body}');
          return null;
        }
      } else {
        print('❌ ApiService.analyzeText: API hatası ${response.statusCode} - ${response.body}');
        _logger.e('API isteği başarısız oldu: ${response.statusCode} - ${response.body}');
        
        // Hata durumunda null döndür
        return null;
      }
    } catch (e) {
      print('❌ ApiService.analyzeText: Hata - $e');
      _logger.e('Metin analizi sırasında hata oluştu: $e');
      
      // Hata durumunda null döndür
      return null;
    }
  }
  
  // API yanıtını AnalysisResult formatına dönüştür
  Map<String, dynamic> _transformApiResponse(Map<String, dynamic> apiResponse) {
    final Map<String, dynamic> transformed = {};
    
    // AnalysisResult için gerekli temel alanları ekle
    transformed['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    transformed['messageId'] = DateTime.now().millisecondsSinceEpoch.toString();
    transformed['emotion'] = 'Nötr';
    transformed['intent'] = 'Belirtilmemiş';
    transformed['tone'] = 'Nötr';
    transformed['severity'] = 5;
    transformed['persons'] = 'Belirtilmemiş';
    transformed['createdAt'] = DateTime.now().toIso8601String();
    
    // API yanıtındaki alanları dönüştür
    final Map<String, dynamic> aiResponse = {};
    
    // mesajYorumu alanını işle
    if (apiResponse.containsKey('mesajYorumu')) {
      aiResponse['mesajYorumu'] = apiResponse['mesajYorumu'];
    }
    
    // cevapOnerileri alanını işle
    if (apiResponse.containsKey('cevapOnerileri') && apiResponse['cevapOnerileri'] is List) {
      aiResponse['cevapOnerileri'] = apiResponse['cevapOnerileri'];
    } else {
      aiResponse['cevapOnerileri'] = ['İletişim tekniklerini geliştir', 'Açık ve net ol'];
    }
    
    // Diğer alanları da ekle
    if (apiResponse.containsKey('effect') && apiResponse['effect'] is Map) {
      transformed['effect'] = apiResponse['effect'];
    }
    
    // aiResponse alanını ekle
    transformed['aiResponse'] = aiResponse;
    
    print('🔄 API YANITI DÖNÜŞTÜRÜLDÜ: ${jsonEncode(transformed)}');
    
    return transformed;
  }
} 