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
        return MessageCoachAnalysis(
          analiz: 'API yapılandırma hatası: $apiError. Lütfen uygulama ayarlarını kontrol edin.',
          oneriler: ['Ayarları kontrol edin ve tekrar deneyin.'],
          etki: {'Hata': 100},
        );
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
        "cevapOnerisi": "(İsteğe Bağlı) Doğrudan, kibarlaştırılmamış kısa bir cevap önerisi"
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
            // JSON bulunamadı, default değerlerle analiz oluştur
            return MessageCoachAnalysis(
              analiz: 'Sohbet analizi yapıldı.',
              oneriler: ['Daha açık ifadeler kullan.', 'Mesajlarını kısa tut.'],
              etki: {'Sempatik': 50, 'Kararsız': 30, 'Olumsuz': 20},
              sohbetGenelHavasi: 'Samimi',
              genelYorum: 'Sohbetin havası kesinlikle kötü. Kendini daha net ifade et ve lafı dolandırma.',
              sonMesajTonu: 'Sempatik',
              sonMesajEtkisi: {'sempatik': 50, 'kararsız': 30, 'olumsuz': 20},
              direktYorum: 'Resmen karşı tarafı sıkıyorsun. Bu kadar dolaylı konuşmayı bırak ve direkt ne istiyorsan söyle.',
              cevapOnerisi: 'Merhaba, durumum tam olarak şu. Bana karşı ne hissettiğini bilmek istiyorum.',
            );
          }
          
          final jsonStr = jsonMatch.group(0);
          if (jsonStr == null) {
            _logger.e('JSON içeriği çıkarılamadı', aiContent);
            // JSON içeriği çıkarılamadı, default değerlerle analiz oluştur
            return MessageCoachAnalysis(
              analiz: 'Sohbet analizi yapıldı.',
              oneriler: ['Daha açık ifadeler kullan.', 'Mesajlarını kısa tut.'],
              etki: {'Sempatik': 50, 'Kararsız': 30, 'Olumsuz': 20},
              sohbetGenelHavasi: 'Samimi',
              genelYorum: 'Konuşma stilin berbat. Karşı taraf ne dediğini anlayamıyor olmalı.',
              sonMesajTonu: 'Soğuk',
              sonMesajEtkisi: {'sempatik': 30, 'kararsız': 40, 'olumsuz': 30},
              direktYorum: 'Bu kadar bariz kaçamak cevaplar verince kimse seni ciddiye almayacak.',
              cevapOnerisi: 'Bu konudaki düşüncemi doğrudan söyleyeyim: evet, öyle düşünüyorum ve şunları yapmalıyız.',
            );
          }
          
          final Map<String, dynamic> analysisData = jsonDecode(jsonStr);
          
          // Eksik alanlar için varsayılan değerler ekle
          // "sohbetGenelHavasi" alanı eksikse ekle
          if (!analysisData.containsKey('sohbetGenelHavasi') || 
              analysisData['sohbetGenelHavasi'] == null || 
              analysisData['sohbetGenelHavasi'].toString().contains('analiz edilemedi') ||
              analysisData['sohbetGenelHavasi'].toString().contains('yetersiz içerik')) {
            analysisData['sohbetGenelHavasi'] = 'Soğuk';
          }
          
          // "genelYorum" alanı eksikse ekle
          if (!analysisData.containsKey('genelYorum') || 
              analysisData['genelYorum'] == null ||
              analysisData['genelYorum'].toString().contains('analiz edilemedi') ||
              analysisData['genelYorum'].toString().contains('yetersiz içerik')) {
            analysisData['genelYorum'] = 'İletişimin berbat. Bu kadar baştan savma yazınca karşı tarafın ilgisini nasıl çekmeyi bekliyorsun?';
          }
          
          // "sonMesajTonu" alanı eksikse ekle
          if (!analysisData.containsKey('sonMesajTonu') || 
              analysisData['sonMesajTonu'] == null || 
              analysisData['sonMesajTonu'].toString().contains('analiz edilemedi') ||
              analysisData['sonMesajTonu'].toString().contains('yetersiz içerik')) {
            analysisData['sonMesajTonu'] = 'Umursamaz';
          }
          
          // "direktYorum" alanı eksikse ekle
          if (!analysisData.containsKey('direktYorum') || 
              analysisData['direktYorum'] == null || 
              analysisData['direktYorum'].toString().contains('analiz edilemedi') ||
              analysisData['direktYorum'].toString().contains('yetersiz içerik')) {
            analysisData['direktYorum'] = 'Mesajların çok zayıf ve etkileyici değil. Karşı taraf sen yazdıkça sıkılıyor ve muhtemelen başka biriyle konuşmayı tercih ediyor.';
          }
          
          // "cevapOnerisi" alanı eksikse ekle
          if (!analysisData.containsKey('cevapOnerisi') || 
              analysisData['cevapOnerisi'] == null || 
              analysisData['cevapOnerisi'].toString().contains('analiz edilemedi') ||
              analysisData['cevapOnerisi'].toString().contains('yetersiz içerik')) {
            analysisData['cevapOnerisi'] = 'Bu durumu ciddiye alıyorum ve seninle açıkça konuşmak istiyorum. Ne düşündüğünü bilmek istiyorum, lütfen bana dürüstçe söyle.';
          }
          
          // "sonMesajEtkisi" alanı eksikse ekle
          if (!analysisData.containsKey('sonMesajEtkisi') || analysisData['sonMesajEtkisi'] == null) {
            analysisData['sonMesajEtkisi'] = {
              'sempatik': 50,
              'kararsız': 30,
              'olumsuz': 20
            };
          }
          
          // Alanların tiplerini kontrol et ve düzelt
          if (analysisData['sonMesajEtkisi'] is Map) {
            final Map<String, dynamic> etkiMap = Map<String, dynamic>.from(analysisData['sonMesajEtkisi']);
            final Map<String, int> normalizeEtki = {};
            
            // String değerli etkileri sayıya çevir
            etkiMap.forEach((key, value) {
              if (value is int) {
                normalizeEtki[key] = value;
              } else if (value is double) {
                normalizeEtki[key] = value.toInt();
              } else if (value is String) {
                // Sayısal değer içeren string'i int'e çevir
                normalizeEtki[key] = int.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ?? 33;
              } else {
                normalizeEtki[key] = 33; // Varsayılan değer
              }
            });
            
            analysisData['sonMesajEtkisi'] = normalizeEtki;
          }
          
          return MessageCoachAnalysis.from(analysisData);
        } catch (jsonError) {
          _logger.e('AI yanıtını JSON formatına çevirirken hata: $jsonError');
          _logger.e('Hatalı yanıt: $aiContent');
          
          // Hata durumunda varsayılan değerler
          return MessageCoachAnalysis(
            analiz: 'Sohbet analizi yapılırken bir hata oluştu. Lütfen tekrar deneyin.',
            oneriler: ['Daha kısa bir sohbet geçmişi deneyin.', 'Farklı bir metin biçimi kullanın.'],
            etki: {'Hata': 100},
            sohbetGenelHavasi: 'Belirlenemedi',
            genelYorum: 'Sohbet analizi yapılamadı. Teknik bir hata oluştu.',
            sonMesajTonu: 'Belirlenemedi',
            sonMesajEtkisi: {'sempatik': 33, 'kararsız': 33, 'olumsuz': 34},
            direktYorum: 'Analiz yapılamadığı için yorum verilemiyor.',
            cevapOnerisi: 'Merhaba, mesajını aldım. Biraz daha konuşalım.',
          );
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return MessageCoachAnalysis(
          analiz: 'API yanıt hatası: ${response.statusCode}',
          oneriler: ['Daha sonra tekrar deneyin.', 'İnternet bağlantınızı kontrol edin.'],
          etki: {'Hata': 100},
          sohbetGenelHavasi: 'Belirlenemedi',
          genelYorum: 'Sohbet analizi yapılamadı. API hatası oluştu.',
          sonMesajTonu: 'Belirlenemedi',
          sonMesajEtkisi: {'sempatik': 33, 'kararsız': 33, 'olumsuz': 34},
          direktYorum: 'API hatası nedeniyle analiz yapılamıyor.',
          cevapOnerisi: 'Merhaba, mesajını aldım. Biraz daha konuşalım.',
        );
      }
    } catch (e) {
      _logger.e('Sohbet analizi hatası', e);
      
      return MessageCoachAnalysis(
        analiz: 'Beklenmeyen bir hata: $e',
        oneriler: ['Tekrar deneyin.', 'Uygulama desteğine başvurun.'],
        etki: {'Hata': 100},
        sohbetGenelHavasi: 'Belirlenemedi',
        genelYorum: 'Sohbet analizi yapılamadı. Beklenmeyen bir hata oluştu.',
        sonMesajTonu: 'Belirlenemedi',
        sonMesajEtkisi: {'sempatik': 33, 'kararsız': 33, 'olumsuz': 34},
        direktYorum: 'Beklenmeyen bir hata nedeniyle analiz yapılamıyor.',
        cevapOnerisi: 'Merhaba, mesajını aldım. Biraz daha konuşalım.',
      );
    }
  }
} 