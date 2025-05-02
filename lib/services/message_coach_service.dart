import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/message_coach_analysis.dart';
import 'logger_service.dart';

class MessageCoachService {
  final LoggerService _logger = LoggerService();
  
  // Gemini API anahtarını ve ayarlarını .env dosyasından alma
  String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get _geminiModel => dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.0-flash';
  int get _geminiMaxTokens => int.tryParse(dotenv.env['GEMINI_MAX_TOKENS'] ?? '1024') ?? 1024;
  
  // API anahtarını kontrol et ve tam URL'i hazırla
  String _getApiUrl() {
    final apiKey = _geminiApiKey;
    if (apiKey.isEmpty) {
      _logger.e('Gemini API anahtarı bulunamadı. .env dosyasını kontrol edin.');
      throw Exception('API anahtarı eksik veya geçersiz. Lütfen .env dosyasını kontrol edin ve GEMINI_API_KEY değerini ayarlayın.');
    }
    
    final model = _geminiModel;
    if (model.isEmpty) {
      _logger.e('Gemini model adı bulunamadı. .env dosyasını kontrol edin.');
      throw Exception('Model adı eksik veya geçersiz. Lütfen .env dosyasını kontrol edin ve GEMINI_MODEL değerini ayarlayın.');
    }
    
    return 'https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$apiKey';
  }

  // Sohbeti analiz etme
  Future<MessageCoachAnalysis?> sohbetiAnalizeEt(String sohbetIcerigi) async {
    try {
      _logger.i('Sohbet analizi başlatılıyor...');
      
      // Sohbet içeriğini kontrol etme
      if (sohbetIcerigi.trim().isEmpty) {
        _logger.w('Boş sohbet içeriği, analiz yapılamıyor');
        return null;
      }
      
      // API anahtarını kontrol et ve tam URL oluştur
      String apiUrl;
      try {
        apiUrl = _getApiUrl();
        _logger.i('API URL oluşturuldu ve geçerlilik kontrolü yapıldı');
      } catch (apiError) {
        _logger.e('API URL oluşturulurken hata: $apiError');
        return null;
      }
      
      // Sohbetin uzunluğunu kontrol et
      if (sohbetIcerigi.length > 12000) {
        _logger.w('Sohbet içeriği çok uzun (${sohbetIcerigi.length} karakter). Kısaltılıyor...');
        sohbetIcerigi = "${sohbetIcerigi.substring(0, 12000)}...";
      }
      
      // Analiz için prompt oluşturma
      final prompt = '''
      Kullanıcı mesaj koçu sayfasında bir sohbet geçmişini gönderdi.
      Bu sadece Mesaj Koçu analizine özeldir ve başka bir analizle (ilişki analizi gibi) bağlantılı değildir.

      Görevin:
      1. Sohbetin genel havasını analiz etmek: soğukluk, samimiyet, pasif-agresiflik, ilgisizlik gibi.
      2. Son mesaja ayrıca özel bir analiz yapmak.
      3. Küstah, dürüst ve doğrudan yorumlar vermek.
      4. Kullanıcının mesajı üzerinden net, yüzdesel bir etki tahmini yapmak: (% sempati, % kararsızlık, % olumsuzluk gibi).
      5. Gerekirse doğrudan kısa bir cevap önerisinde bulunmak.

      ÖNEMLİ:
      - Her durumda mutlaka analiz yap, içerik ne kadar az olursa olsun. "Analiz edilemedi" veya "yetersiz içerik" gibi ifadeler kullanma.
      - Mutlaka küstah ve doğrudan yorumlar yap, nazik olmaktan kaçın.
      - Son mesaj tonu için mutlaka bir değer belirle (Sert/Soğuk/Sempatik/Umursamaz/İlgisiz) ve asla "Analiz edilemedi" deme.

      Kurallar:
      - Sağdaki mesajlar kullanıcıya, soldaki mesajlar karşı tarafa aittir.
      - Sohbet akışı yukarıdan aşağı doğru ilerler.
      - Gereksiz uzun açıklamalara girmeden kısa, açık ve net yorumlar yap.
      - Lafı dolandırmadan yaz. Gerekirse eleştirilerini sert bir dille yap.

      Analiz için sohbet içeriği:
      ```
      ${sohbetIcerigi}
      ```

      Lütfen aşağıdaki JSON formatında yanıt ver:
      {
        "sohbetGenelHavasi": "(Soğuk/Samimi/Pasif-agresif/İlgisiz)",
        "genelYorum": "(1-2 cümlede kısa, sert ve doğrudan)",
        "sonMesajTonu": "(Sert/Soğuk/Sempatik/Umursamaz/İlgisiz)",
        "sonMesajEtkisi": {
          "sempatik": X,
          "kararsız": Y,
          "olumsuz": Z
        },
        "direktYorum": "(Kısa, net ve gerekiyorsa acımasız bir yorum)",
        "cevapOnerileri": "(İsteğe Bağlı) Doğrudan, kibarlaştırılmamış kısa bir cevap önerisi"
      }

      Önemli: Cevabını SADECE JSON formatında ver, başka açıklama yapma.
      Cevabında "Analiz edilemedi", "yetersiz içerik" veya benzeri ifadeler KULLANMA.
      İçerik ne kadar az olursa olsun mutlaka bir yorum yap ve değerleri doldur.
      ''';
      
      // Gemini API'ye istek gönderme
      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': prompt
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': _geminiMaxTokens
        }
      });
      
      _logger.d('Sohbet analizi API isteği gönderiliyor');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
      _logger.d('API yanıtı - status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null) {
          _logger.e('AI yanıtı boş veya beklenen formatta değil', data);
          return null;
        }
        
        _logger.d('AI yanıt metni: $aiContent');
        
        // AI yanıtını JSON formatına çevirip analiz nesnesine dönüştürme
        try {
          // JSON içeriğini çıkar - bazen AI yanıtı JSON bloğu dışında açıklama da içerebilir
          final jsonRegExp = RegExp(r'{[\s\S]*}');
          final jsonMatch = jsonRegExp.firstMatch(aiContent);
          
          if (jsonMatch == null) {
            _logger.e('JSON formatı bulunamadı', aiContent);
            return null;
          }
          
          final jsonStr = jsonMatch.group(0);
          if (jsonStr == null) {
            _logger.e('JSON içeriği çıkarılamadı', aiContent);
            return null;
          }
          
          Map<String, dynamic> analysisData;
          try {
            analysisData = jsonDecode(jsonStr);
          } catch (jsonError) {
            _logger.e('JSON decode hatası: $jsonError', jsonStr);
            // JSON decode hatası durumunda, düzeltme denemesi yap
            final cleanedJsonStr = _jsonuDuzelt(jsonStr);
            try {
              analysisData = jsonDecode(cleanedJsonStr);
            } catch (e) {
              _logger.e('Temizlenmiş JSON dahi decode edilemedi: $e');
              return null;
            }
          }
          
          return MessageCoachAnalysis.from(analysisData);
        } catch (jsonError) {
          _logger.e('AI yanıtını JSON formatına çevirirken hata: $jsonError');
          _logger.e('Hatalı yanıt: $aiContent');
          return null;
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Sohbet analizi hatası', e);
      return null;
    }
  }
  
  // JSON içindeki sorunları düzelten yardımcı metod
  String _jsonuDuzelt(String jsonStr) {
    // Hatalı şekilde escape edilen tırnak işaretlerini düzelt
    String temiz = jsonStr.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
    
    // Tırnak işaretleri içindeki tırnak işaretlerini düzelt
    temiz = temiz.replaceAll('\\n', ' ');
    
    // Gereksiz boşlukları temizle
    temiz = temiz.replaceAll(RegExp(r'\s+'), ' ');
    
    return temiz;
  }
  
  // Analiz ifadelerini düzelten yardımcı metod
  void _analizeIfadeleriDuzelt(Map<String, dynamic> data) {
    // "sohbetGenelHavasi" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('sohbetGenelHavasi') || 
        data['sohbetGenelHavasi'] == null || 
        _yetersizIfadeIceriyor(data['sohbetGenelHavasi'].toString())) {
      data['sohbetGenelHavasi'] = 'Samimi';
    }
    
    // "genelYorum" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('genelYorum') || 
        data['genelYorum'] == null ||
        _yetersizIfadeIceriyor(data['genelYorum'].toString())) {
      data['genelYorum'] = 'İletişim tarzının geliştirilmesi gerekiyor. Mesajların çok sıradan ve etkileyici değil.';
    }
    
    // "sonMesajTonu" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('sonMesajTonu') || 
        data['sonMesajTonu'] == null || 
        _yetersizIfadeIceriyor(data['sonMesajTonu'].toString())) {
      data['sonMesajTonu'] = 'Sempatik';
    }
    
    // "direktYorum" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('direktYorum') || 
        data['direktYorum'] == null || 
        _yetersizIfadeIceriyor(data['direktYorum'].toString())) {
      data['direktYorum'] = 'Mesajların zayıf ve ilgi çekici değil. Daha net ve etkileyici bir iletişim kurmalısın.';
    }
    
    // "cevapOnerileri" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('cevapOnerileri') || 
        data['cevapOnerileri'] == null || 
        !_listeyeCevrilebilir(data['cevapOnerileri'])) {
      data['cevapOnerileri'] = [
        'Seninle açıkça konuşmak istiyorum. Ne düşündüğünü bilmek istiyorum.',
        'Konuşmamız benim için önemli, devam edelim.',
        'Anladım, şimdi ne yapabiliriz?'
      ];
    } else if (data['cevapOnerileri'] is String) {
      // String ise listeye çevir
      data['cevapOnerileri'] = [data['cevapOnerileri']];
    }
    
    // "sonMesajEtkisi" alanı kontrolü ve düzeltmesi
    if (!data.containsKey('sonMesajEtkisi') || 
        data['sonMesajEtkisi'] == null || 
        !(data['sonMesajEtkisi'] is Map)) {
      data['sonMesajEtkisi'] = {
        'sempatik': 50,
        'kararsız': 30,
        'olumsuz': 20
      };
    } else {
      // Var olan sonMesajEtkisi'ni doğrula
      final Map<String, dynamic> etkiMap = Map<String, dynamic>.from(data['sonMesajEtkisi']);
      final Map<String, int> normalizeEtki = {};
      
      // Değeri olmayan etkiler için varsayılan ekle
      if (!etkiMap.containsKey('sempatik')) {
        normalizeEtki['sempatik'] = 40;
      }
      if (!etkiMap.containsKey('kararsız')) {
        normalizeEtki['kararsız'] = 30;
      }
      if (!etkiMap.containsKey('olumsuz')) {
        normalizeEtki['olumsuz'] = 30;
      }
      
      // String değerli etkileri sayıya çevir
      etkiMap.forEach((key, value) {
        if (value is int) {
          normalizeEtki[key] = value;
        } else if (value is double) {
          normalizeEtki[key] = value.toInt();
        } else if (value is String) {
          // Sayısal değer içeren string'i int'e çevir
          final temiz = value.toString().replaceAll(RegExp(r'[^\d]'), '');
          normalizeEtki[key] = temiz.isNotEmpty ? int.tryParse(temiz) ?? 33 : 33;
        } else {
          normalizeEtki[key] = 33; // Varsayılan değer
        }
      });
      
      data['sonMesajEtkisi'] = normalizeEtki;
    }
  }
  
  // Bir ifadenin "yetersiz" veya "analiz edilemedi" gibi ifadeler içerip içermediğini kontrol eder
  bool _yetersizIfadeIceriyor(String ifade) {
    final String kucukIfade = ifade.toLowerCase();
    return kucukIfade.contains('analiz edilemedi') || 
           kucukIfade.contains('yetersiz içerik') || 
           kucukIfade.contains('belirlenemedi') ||
           kucukIfade.contains('henüz analiz') ||
           kucukIfade == 'null' ||
           ifade.isEmpty;
  }

  // Bir değerin listeye çevrilebilir olup olmadığını kontrol eder
  bool _listeyeCevrilebilir(dynamic deger) {
    return deger is List || 
           (deger is String && deger.isNotEmpty && !_yetersizIfadeIceriyor(deger));
  }
} 