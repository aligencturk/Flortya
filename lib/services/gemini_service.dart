import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:get_it/get_it.dart';

/// Gemini API ile etkileşim kurmak için kullanılan servis sınıfı
class GeminiService {
  late final GenerativeModel _model;
  String? _apiKey;
  
  /// Oluşturucu, API anahtarını dotenv'den ya da parametre olarak alır
  GeminiService({String? apiKey}) {
    _apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'];
    
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('UYARI: Gemini API anahtarı bulunamadı. .env dosyasında GEMINI_API_KEY tanımladığınızdan emin olun.');
      return;
    }
    
    // Gemini modelini başlat
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: _apiKey!,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
    );
  }
  
  /// Gemini servisini singleton olarak kaydet
  static void register() {
    if (!GetIt.instance.isRegistered<GeminiService>()) {
      GetIt.instance.registerSingleton<GeminiService>(GeminiService());
    }
  }
  
  /// Singleton instance'ı al
  static GeminiService get instance => GetIt.instance<GeminiService>();
  
  /// Metin analizi yap
  Future<Map<String, dynamic>?> analizYap(String metin) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('Gemini API anahtarı tanımlanmamış');
      return null;
    }
    
    try {
      final prompt = _analizPromptOlustur(metin);
      final response = await _model.generateContent([Content.text(prompt)]);
      
      // Yanıtı kontrol et
      if (response.text == null || response.text!.isEmpty) {
        debugPrint('Gemini API boş yanıt döndü');
        return null;
      }
      
      // JSON yanıtını parse et
      try {
        final jsonText = _jsonVerisiniAyikla(response.text!);
        final Map<String, dynamic> sonuc = json.decode(jsonText);
        return sonuc;
      } catch (e) {
        debugPrint('JSON parse hatası: $e');
        return {
          'error': 'JSON parse edilemedi: $e',
          'raw_response': response.text,
        };
      }
    } catch (e) {
      debugPrint('Gemini API hatası: $e');
      return {
        'error': 'API hatası: $e',
      };
    }
  }
  
  /// JSON verisini metinden ayıkla
  String _jsonVerisiniAyikla(String metin) {
    // Eğer metin direkt olarak JSON formatında ise
    if (metin.trim().startsWith('{') && metin.trim().endsWith('}')) {
      return metin.trim();
    }
    
    // JSON kod bloğunu bul
    final RegExp jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = jsonRegex.firstMatch(metin);
    
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim() ?? '{}';
    }
    
    // JSON kod bloğu bulunamazsa { ile başlayan kısmı bul
    final RegExp curlyRegex = RegExp(r'({[\s\S]*})');
    final curlyMatch = curlyRegex.firstMatch(metin);
    
    if (curlyMatch != null) {
      return curlyMatch.group(0)?.trim() ?? '{}';
    }
    
    throw Exception('Metinde JSON formatı bulunamadı');
  }
  
  /// Analiz için prompt metni oluştur
  String _analizPromptOlustur(String metin) {
    return '''
    Aşağıdaki mesajlaşma sohbetini analiz et ve JSON formatında yanıt ver. 
    Analiz etmen gereken sohbet:
    
    $metin
    
    JSON formatında aşağıdaki yapıda bir analiz sonucu dön:
    
    ```json
    {
      "sohbetGenelHavasi": "samimi|soğuk|ilgili|ilgisiz|pasif-agresif",
      "sonMesajTonu": "sempatik|umursamaz|nötr|soğuk|sert|pasif-agresif",
      "etki": {
        "olumlu": 40,
        "nötr": 30,
        "olumsuz": 30
      },
      "anlikTavsiye": "Kısa ve öz tavsiye",
      "yenidenYazim": "Son mesajın daha iyi yazılmış versiyonu",
      "karsiTarafYorumu": "Karşı tarafın bu mesaja muhtemel yorumu",
      "strateji": "İletişimi geliştirmek için strateji önerisi"
    }
    ```
    
    Sadece JSON döndür, başka açıklama ekleme.
    ''';
  }
} 