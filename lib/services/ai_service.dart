import 'dart:convert';
import 'dart:math';
import 'dart:io'; // File sınıfı için import eklendi
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/analysis_result_model.dart';
import '../models/message_coach_analysis.dart'; // Mesaj koçu modelini import et
import 'logger_service.dart';

class AiService {
  final LoggerService _logger = LoggerService();
  
  // Gemini API anahtarını ve ayarlarını .env dosyasından alma
  String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get _geminiModel => dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.0-flash';
  int get _geminiMaxTokens => int.tryParse(dotenv.env['GEMINI_MAX_TOKENS'] ?? '1024') ?? 1024;
  String get _geminiApiUrl => 'https://generativelanguage.googleapis.com/v1/models/$_geminiModel:generateContent?key=$_geminiApiKey';

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

  // İlişki raporu yorumuna yanıt oluşturma
  Future<Map<String, dynamic>> getCommentResponse(
    String comment, 
    String report, 
    String relationshipType
  ) async {
    try {
      _logger.i('Yorum yanıtı oluşturuluyor. Yorum: $comment');
      
      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': '''
                Sen bir ilişki terapistisin. Kullanıcı ilişki raporu hakkında bir yorum yaptı.
                
                İlişki tipi: $relationshipType
                
                Rapor: $report
                
                Kullanıcının yorumu: "$comment"
                
                Bu yoruma empati kurarak, yapıcı ve samimi bir şekilde yanıt ver. Yanıt Türkçe olmalı ve en fazla 150 kelime olmalı.
                '''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': _geminiMaxTokens
        }
      });
      
      _logger.d('Yorum yanıtı API isteği: $_geminiApiUrl');
      
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
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
          return {'error': 'Yanıt alınamadı'};
        }
        
        _logger.d('AI yanıt metni: $aiContent');
        return {'answer': aiContent};
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return {'error': 'Yanıt alınırken hata oluştu'};
      }
    } catch (e) {
      _logger.e('Yorum yanıtı hatası', e);
      return {'error': 'Beklenmeyen bir hata oluştu'};
    }
  }

  // İlişki danışmanı chat fonksiyonu
  Future<Map<String, dynamic>> getRelationshipAdvice(
    String message, 
    String? relationshipType
  ) async {
    try {
      _logger.i('İlişki tavsiyesi alınıyor. Soru: $message');
      
      // Chat geçmişini hazırla
      final contents = <Map<String, dynamic>>[];
      
      // Sistem mesajını ekle
      contents.add({
        'role': 'model',
        'parts': [
          {
            'text': '''
            Sen bir ilişki danışmanısın. Kullanıcının ilişki sorunlarına ve sorularına profesyonel 
            tavsiyeler veriyorsun. İlişkilerin sağlıklı gelişmesi, iletişim problemlerinin çözülmesi ve
            romantik ilişkilerin iyileştirilmesi konusunda uzmansın. Vereceğin cevaplar:
            
            1. Empatik ve anlayışlı olmalı
            2. Yapıcı ve pratik öneriler içermeli
            3. Yargılayıcı olmamalı
            4. Bilimsel temellere dayanmalı
            5. Kültürel olarak duyarlı olmalı
            6. Samimi
            
            Cevaplarında Türkçe dilini kullan ve samimi bir üslup benimse.
            '''
          }
        ]
      });
            
      // Kullanıcının yeni sorusunu ekle
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text': relationshipType != null 
              ? 'İlişki türü: $relationshipType\nSoru: $message' 
              : message
          }
        ]
      });
      
      // Gemini API'ye istek gönderme
      final requestBody = jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': _geminiMaxTokens
        }
      });
      
      _logger.d('İlişki tavsiyesi API isteği: $_geminiApiUrl');
      _logger.d('İstek gövdesi özeti: ${contents.length} mesaj');
      
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
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
          return {'error': 'Tavsiye alınamadı'};
        }
        
        _logger.d('AI yanıt metni: $aiContent');
        
        // Tavsiye verilerini oluştur
        final advice = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'question': message,
          'answer': aiContent,
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'chat'
        };
        
        _logger.i('İlişki tavsiyesi başarıyla alındı');
        return advice;
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return {'error': 'Tavsiye alınırken hata oluştu. Lütfen tekrar deneyiniz.'};
      }
    } catch (e) {
      _logger.e('İlişki tavsiyesi hatası', e);
      return {'error': 'Beklenmeyen bir hata oluştu'};
    }
  }

  // Mesajı analiz etme
  Future<AnalysisResult?> analyzeMessage(String messageContent) async {
    try {
      _logger.i('Mesaj analizi başlatılıyor...');
      
      // Mesaj içeriğini kontrol etme
      if (messageContent.trim().isEmpty) {
        _logger.w('Boş mesaj içeriği, analiz yapılamıyor');
        return null;
      }
      
      // API anahtarını kontrol et ve tam URL oluştur
      String apiUrl;
      try {
        apiUrl = _getApiUrl();
        _logger.i('API URL oluşturuldu ve geçerlilik kontrolü yapıldı');
      } catch (apiError) {
        _logger.e('API URL oluşturulurken hata: $apiError');
        // API hatasında varsayılan değer döndür
        return AnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          emotion: 'Belirtilmemiş',
          intent: 'API yapılandırma hatası',
          tone: 'Nötr',
          severity: 5,
          persons: 'Belirtilenmemiş',
          aiResponse: {
            'mesajYorumu': 'API yapılandırma hatası: $apiError. Lütfen uygulama ayarlarını kontrol edin.',
            'cevapOnerileri': ['Ayarları kontrol edin ve tekrar deneyin.']
          },
          createdAt: DateTime.now(),
        );
      }
      
      // Mesajın uzunluğunu kontrol et
      if (messageContent.length > 12000) {
        _logger.w('Mesaj içeriği çok uzun (${messageContent.length} karakter). Kısaltılıyor...');
        messageContent = "${messageContent.substring(0, 12000)}...";
      }
      
      // OCR metni ve Görsel Analizi işleme biçimini modernize edelim
      // Görüntüden çıkarılan metin için özel format kontrolü
      final bool isImageAnalysis = messageContent.contains("---- Görüntüden çıkarılan metin ----");
      
      // Prompt hazırlama
      String prompt = '';
      
      if (isImageAnalysis) {
        // Görüntü analizinden çıkarılan metni daha kısa bir şekilde prompt'a ekleyelim
        prompt = '''
        Sen bir ilişki analiz uzmanı ve samimi bir arkadaşsın. Senin en önemli özelliğin, çok sıcak ve empatik bir şekilde cevap vermen.
        
        Bu mesaj bir ekran görüntüsü içeriyor ve görüntüden çıkarılan metin var. Lütfen aşağıdaki ekran görüntüsünden çıkarılan metne dayanarak mesajın detaylı analizini yap.
        
        ÖNEMLİ: Yanıtın doğrudan kullanıcıya hitap eden bir şekilde olmalı. "Kullanıcı şunu yapmalı" veya "Karşı taraf böyle düşünüyor" gibi ÜÇÜNCÜ ŞAHIS ANLATIMI KULLANMA. 
        Bunun yerine "Mesajlarında şunu görebiliyorum", "Bu durumda şunları yapabilirsin", "Şu mesajı gönderirsen..." gibi DOĞRUDAN KULLANICIYA HİTAP ET.
        
        Analizi şu başlıklarla (ama konuşma diliyle) hazırla:
        - Mesajların tonu (duygusal, kırıcı, mesafeli, vb.)
        - İletişim şeklin ve karşı tarafın yaklaşımı
        - Mesajların etkisi ve sana tavsiyeler
        - Genel ilişki dinamiği hakkında yorum ve sana öneriler
        - Günlük konuşma diline uygun, samimi ifadeler kullan
        
        Analizi şu formatta JSON çıktısı olarak ver:
        
        {
          "duygu": "Mesajlarda algılanan temel duygu",
          "niyet": "Mesajlaşmanın altında yatan niyet",
          "ton": "Mesajların genel tonu",
          "ciddiyet": "1-10 arası bir sayı",
          "kişiler": "Mesajlarda yer alan kişilerin tanımı",
          "mesajYorumu": "Mesajlardaki ilişki dinamikleri hakkında samimi, doğrudan sana hitap eden bir yorum",
          "tavsiyeler": [
            "Doğrudan sana yönelik somut bir öneri",
            "Mesajlaşma şeklini değiştirmen için tavsiye",
            "İlişki dinamiğini iyileştirmen için öneri"
          ]
        }
        
        Analiz edilecek metin: "$messageContent"
        ''';
      } else {
        // Normal metin mesajı için mevcut prompt kullan
        prompt = '''
        Sen bir ilişki analiz uzmanısın. Kullanıcının ilettiği mesaj içeriğini aşağıdaki başlıklara göre detaylı olarak analiz et:
        
        ÖNEMLİ: Yanıtın doğrudan kullanıcıya hitap eden bir şekilde olmalı. "Kullanıcı şunu yapmalı" veya "Karşı taraf böyle düşünüyor" gibi ÜÇÜNCÜ ŞAHIS ANLATIMI KULLANMA. 
        Bunun yerine "Mesajlarında şunu görebiliyorum", "Bu durumda şunları yapabilirsin", "Şu mesajı gönderirsen..." gibi DOĞRUDAN KULLANICIYA HİTAP ET.
        
        1. Duygu Çözümlemesi
        - Metindeki baskın duyguları belirle (örnek: kırgınlık, umut, öfke, boşvermişlik, özlem...)
        - Gerekirse karışık duyguları birlikte yorumla ("kızgın ama hâlâ önemsiyor" gibi)

        2. Niyet Yorumu
        - Yazan kişinin amacı ne olabilir?
        - Ulaşmak mı?
        - Gönül almak mı?
        - Hesap sormak mı?
        - Yoklamak mı?
        - Vedalaşmak mı?
        - Niyet yorumu net ve tahmine dayalı olmalı, asla statik kalmamalı.
        - "İletişim kurmak" gibi sabit cümlelerden kaçın.
        - Bu alan ZORUNLUDUR ve boş bırakılamaz.

        3. Tavsiyeler
        - İlişki için empatik, yumuşak tonlu tavsiyeler sun.
        - Güven inşa etmeye yönelik öneriler ver.
        - Duygusal zekaya dayalı iletişim stratejileri öner.
        - Kullanıcıya DOĞRUDAN "sen" dili ile hitap et, üçüncü şahıs anlatımından kaçın.
        - En az 3 özgün tavsiye oluştur ve hepsinde "sen, sana, senin" gibi ifadeler kullan.

        Her başlık ZORUNLU olarak analiz edilmeli. İçerik azsa bile tahmin yap.
        Statik yanıtlar, boş dönen başlıklar, sabit ifadeler KESİNLİKLE KULLANMA.
        
        Analizi şu formatta JSON çıktısı olarak ver:
        
        {
          "duygu": "Metindeki baskın duygular (özlem, öfke, kırgınlık vb.)",
          "niyet": "Yazan kişinin muhtemel amacı (statik ifadelerden kaçın, net ve tahmine dayalı olmalı)",
          "ton": "Mesajın genel tonu (resmi, samimi, öfkeli, üzgün, vb.)",
          "ciddiyet": "1-10 arası bir sayı, iletişimin ciddiyetini gösterir",
          "kişiler": "Mesajda bahsedilen kişiler (varsa)",
          "mesajYorumu": "Metindeki duygular ve niyetlerle ilgili açık, doğrudan SANA hitap eden bir yorum",
          "tavsiyeler": [
            "SANA yönelik empatik, yumuşak tonlu tavsiye 1",
            "SANA yönelik empatik, yumuşak tonlu tavsiye 2",
            "SANA yönelik empatik, yumuşak tonlu tavsiye 3"
          ]
        }
        
        Analiz edilecek mesaj: "$messageContent"
        ''';
      }
      
      // API isteği için JSON body hazırlama
      var requestBody = jsonEncode({
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
      
      _logger.d('API isteği gönderiliyor: $apiUrl');
      _logger.d('İstek tipi: ${isImageAnalysis ? "Görsel Analizi" : "Metin Analizi"}');
      
      // HTTP isteği için timeout ve retry mekanizması ekle
      int retryCount = 0;
      const maxRetries = 2;
      
      while (retryCount <= maxRetries) {
        try {
          final response = await http.post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-Analysis-Type': isImageAnalysis ? 'image' : 'text', // İstek türünü header'a ekle
            },
            body: requestBody,
          ).timeout(
            const Duration(seconds: 60), // Timeout süresini uzattık
            onTimeout: () {
              _logger.e('Gemini API istek zaman aşımına uğradı (60 saniye)');
              throw Exception('API yanıt vermedi, lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.');
            },
          );
          
          _logger.d('API yanıtı alındı - status: ${response.statusCode}, içerik uzunluğu: ${response.body.length}');
          
          // Response header'larını logla (sorun tespiti için)
          _logger.d('API yanıt headerları: ${response.headers}');
          
          if (response.statusCode == 200) {
            // Yanıtı ayrı bir metoda çıkararak UI thread'in bloke olmasını engelle
            try {
              return _processApiResponse(response.body);
            } catch (processError) {
              _logger.e('API yanıtı işlenirken hata: $processError');
              // Varsayılan sonuç döndür
              return AnalysisResult(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                messageId: DateTime.now().millisecondsSinceEpoch.toString(),
                emotion: 'Belirtilmemiş',
                intent: 'İletişim kurma',
                tone: 'Nötr',
                severity: 5,
                persons: 'Belirtilenmemiş',
                aiResponse: {
                  'mesajYorumu': 'Analiz sırasında bir sorun oluştu. Lütfen tekrar deneyiniz.',
                  'tavsiyeler': ['Mesajınızı tekrar göndermeyi deneyin.']
                },
                createdAt: DateTime.now(),
              );
            }
          } else {
            // Hata durumunu daha detaylı logla
            _logger.e('API hatası: ${response.statusCode}', 'Yanıt: ${response.body.substring(0, min(200, response.body.length))}...');
            
            // Görsel analizi için özel hata kontrolü
            if (isImageAnalysis && (response.statusCode == 400 || response.statusCode == 422)) {
              _logger.e('Görsel analizi isteğinde format hatası. Yeniden deneme ${retryCount+1}/$maxRetries');
              retryCount++;
              
              // Görüntü içeriğini kısalt ve yeniden dene
              if (messageContent.length > 8000) {
                messageContent = "${messageContent.substring(0, 8000)}...";
                prompt = prompt.replaceAll("Analiz edilecek metin: \"$messageContent\"", 
                                          "Analiz edilecek metin: \"${messageContent.substring(0, 8000)}...\"");
                
                // JSON body'yi güncelle
                requestBody = jsonEncode({
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
                
                _logger.i('İçerik kısaltıldı ve yeniden deneniyor. Yeni uzunluk: ${messageContent.length}');
                
                // Biraz bekle ve döngünün bir sonraki iterasyonuyla tekrar dene
                await Future.delayed(const Duration(seconds: 2));
                continue;
              }
            }
            
            // Tekrarlama limiti aşıldıysa veya diğer hata durumları için uygun yanıtı oluştur
            if (response.statusCode == 400) {
              _logger.e('API hata 400: İstek yapısı hatalı');
              return AnalysisResult(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                messageId: DateTime.now().millisecondsSinceEpoch.toString(),
                emotion: 'Belirtilmemiş',
                intent: isImageAnalysis ? 'Görsel analiz hatası' : 'İstek hatası',
                tone: 'Nötr',
                severity: 5,
                persons: 'Belirtilenmemiş',
                aiResponse: {
                  'mesajYorumu': isImageAnalysis 
                      ? 'Görsel analizinde format hatası oluştu. Lütfen farklı bir görsel deneyin.'
                      : 'İstek formatında hata: ${response.statusCode}. Lütfen tekrar deneyiniz.',
                  'tavsiyeler': isImageAnalysis 
                      ? ['Daha net bir görsel ile tekrar deneyin.', 'Görsel yerine metni direkt kopyalayıp göndermeyi deneyin.']
                      : ['Daha kısa bir mesaj ile tekrar deneyin.']
                },
                createdAt: DateTime.now(),
              );
            } else if (response.statusCode == 401 || response.statusCode == 403) {
              _logger.e('API yetkilendirme hatası: API anahtarı geçersiz veya yetkisiz');
              return AnalysisResult(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                messageId: DateTime.now().millisecondsSinceEpoch.toString(),
                emotion: 'Belirtilmemiş',
                intent: 'Yetkilendirme hatası',
                tone: 'Nötr',
                severity: 5,
                persons: 'Belirtilenmemiş',
                aiResponse: {
                  'mesajYorumu': 'API yetkilendirme hatası (${response.statusCode}). Lütfen uygulama ayarlarını kontrol edin.',
                  'tavsiyeler': ['Uygulama yöneticinizle iletişime geçin.']
                },
                createdAt: DateTime.now(),
              );
            } else {
              // Beklenmeyen hata durumunda tüm detayları logla
              _logger.e('Beklenmeyen API hatası: ${response.statusCode}', 'Tam yanıt: ${response.body}');
              
              throw Exception('Analiz API hatası: ${response.statusCode}');
            }
          }
        } catch (httpError) {
          // Tekrar deneme kontrolü
          if (retryCount < maxRetries) {
            _logger.w('HTTP istek hatası, yeniden deneniyor (${retryCount+1}/$maxRetries): $httpError');
            retryCount++;
            await Future.delayed(Duration(seconds: 2 * (retryCount))); // Artan bekleme süresi
            continue;
          }
          
          // HTTP istek hatalarını daha iyi ele al
          _logger.e('HTTP istek hatası', httpError);
          return AnalysisResult(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            messageId: DateTime.now().millisecondsSinceEpoch.toString(),
            emotion: 'Belirtilmemiş',
            intent: isImageAnalysis ? 'Görsel analiz iletişim hatası' : 'İletişim hatası',
            tone: 'Nötr',
            severity: 5,
            persons: 'Belirtilenmemiş',
            aiResponse: {
              'mesajYorumu': isImageAnalysis
                  ? 'Görsel analizi sırasında bir iletişim hatası oluştu: ${httpError.toString()}. Lütfen internet bağlantınızı kontrol edin.'
                  : 'API ile iletişim sırasında hata: ${httpError.toString()}. Lütfen internet bağlantınızı kontrol edin.',
              'tavsiyeler': ['İnternet bağlantınızı kontrol edin ve tekrar deneyin.']
            },
            createdAt: DateTime.now(),
          );
        }
      }
      
      // Buraya ulaşılmaması gerekir, retry mekanizması yukarıdaki döngüde sonuçlanmalı
      return null;
    } catch (e) {
      _logger.e('Mesaj analizi hatası', e);
      // Hata yakalanırken null döndürmek yerine varsayılan sonuç oluştur
      return AnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        emotion: 'Belirtilmemiş',
        intent: 'İletişim kurma',
        tone: 'Nötr',
        severity: 5,
        persons: 'Belirtilenmemiş',
        aiResponse: {
          'mesajYorumu': 'Mesaj analiz edilirken bir hata oluştu: ${e.toString()}',
          'tavsiyeler': ['Lütfen tekrar deneyiniz veya başka bir mesaj gönderiniz.']
        },
        createdAt: DateTime.now(),
      );
    }
  }

  // API yanıtını işleme - UI thread'i blokelemeden çalışır
  AnalysisResult? _processApiResponse(String responseBody) {
    try {
      // Boş yanıt kontrolü
      if (responseBody.isEmpty) {
        _logger.e('API yanıtı boş');
        return _createFallbackResult('API yanıtı boş geldi. Lütfen tekrar deneyiniz.');
      }
      
      // Uzun JSON işleme
      Map<String, dynamic> data;
      try {
        data = jsonDecode(responseBody);
      } catch (jsonError) {
        _logger.e('API yanıtı JSON formatında değil', jsonError);
        return _createFallbackResult('API yanıtı geçerli bir format içermiyor.');
      }
      
      // AI içeriğini güvenli şekilde çıkar
      final dynamic candidates = data['candidates'];
      final String? aiContent = candidates is List && candidates.isNotEmpty && 
                               candidates[0] is Map && 
                               candidates[0]['content'] is Map && 
                               candidates[0]['content']['parts'] is List && 
                               candidates[0]['content']['parts'].isNotEmpty
        ? candidates[0]['content']['parts'][0]['text']
        : null;
      
      if (aiContent == null || aiContent.isEmpty) {
        _logger.e('AI yanıtı boş veya beklenen formatta değil');
        return _createFallbackResult('AI yanıtı boş veya beklenmeyen bir formatta.');
      }
      
      // JSON içindeki JSON string'i ayıkla
      final jsonStart = aiContent.indexOf('{');
      final jsonEnd = aiContent.lastIndexOf('}') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0 || jsonStart >= jsonEnd) {
        _logger.e('JSON yanıtında geçerli bir JSON formatı bulunamadı', aiContent);
        return _createFallbackResult('Yanıt içinde geçerli bir JSON verisi bulunamadı.');
      }
      
      // API yanıtından JSON kısmını ayıkla
      String jsonStr = aiContent.substring(jsonStart, jsonEnd);
      
      // JSON yanıtını işle
      Map<String, dynamic> analysisJson;
      try {
        analysisJson = jsonDecode(jsonStr);
      } catch (jsonParseError) {
        _logger.e('İç JSON ayrıştırma hatası', jsonParseError);
        // Alternatif JSON ayrıştırma yöntemi dene
        try {
          // Özel karakterleri temizle ve tekrar dene
          jsonStr = jsonStr.replaceAll(RegExp(r'[\u0000-\u001F]'), '');
          analysisJson = jsonDecode(jsonStr);
        } catch (secondAttemptError) {
          _logger.e('İkinci JSON ayrıştırma denemesi başarısız', secondAttemptError);
          return _createFallbackResult('Yanıt içinde geçerli bir veri formatı bulunamadı.');
        }
      }
      
      // Niyet alanını kontrol et - yoksa veya boşsa varsayılan değer ver
      if (!analysisJson.containsKey('niyet') || analysisJson['niyet'] == null || analysisJson['niyet'].toString().trim().isEmpty) {
        analysisJson['niyet'] = 'İletişim kurma amacı taşıyor';
      }
      
      // Tavsiyeleri kontrol et - eski isimle gelmiş olabilir
      List<String> tavsiyeler = [];
      if (analysisJson.containsKey('tavsiyeler') && analysisJson['tavsiyeler'] is List) {
        tavsiyeler = List<String>.from(analysisJson['tavsiyeler']);
      } else if (analysisJson.containsKey('cevapOnerileri') && analysisJson['cevapOnerileri'] is List) {
        // Geriye dönük uyumluluk için
        tavsiyeler = List<String>.from(analysisJson['cevapOnerileri']);
      }
      
      // Tavsiyeler boşsa varsayılan değerler ekle
      if (tavsiyeler.isEmpty) {
        tavsiyeler = [
          'İletişimde daha açık olmayı deneyebilirsin.',
          'Duygularını daha net ifade etmek iyi olabilir.',
          'Karşındakinin bakış açısını anlamaya çalışmak yardımcı olabilir.'
        ];
      }
      
      // Cevap önerileri yerine artık tavsiyeler kullanılacak
      analysisJson['tavsiyeler'] = tavsiyeler;
      
      // Analiz sonucunu oluştur
      try {
        final result = AnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          emotion: _safeGetString(analysisJson, 'duygu'),
          intent: _safeGetString(analysisJson, 'niyet'),
          tone: _safeGetString(analysisJson, 'ton'),
          severity: _safeGetInt(analysisJson, 'ciddiyet', defaultValue: 5),
          persons: _safeGetString(analysisJson, 'kişiler'),
          aiResponse: analysisJson,
          createdAt: DateTime.now(),
        );
        
        _logger.i('Analiz tamamlandı: ${result.emotion}, ${result.intent}, ${result.tone}');
        return result;
      } catch (resultError) {
        _logger.e('Analiz sonucu oluşturulurken hata oluştu', resultError);
        return _createFallbackResult('Analiz sonucu oluşturulurken beklenmeyen bir hata oluştu.');
      }
    } catch (e) {
      _logger.e('API yanıtı işlenirken hata oluştu', e);
      return _createFallbackResult('Yanıt işlenirken bir hata oluştu: ${e.toString().substring(0, min(50, e.toString().length))}');
    }
  }
  
  // Güvenli string alma - null kontrolü
  String _safeGetString(Map<String, dynamic> map, String key, {String defaultValue = 'Belirtilmemiş'}) {
    final value = map[key];
    if (value == null) return defaultValue;
    return value.toString();
  }
  
  // Güvenli int alma - null kontrolü
  int _safeGetInt(Map<String, dynamic> map, String key, {int defaultValue = 5}) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }
  
  // Varsayılan bir sonuç oluştur
  AnalysisResult _createFallbackResult(String errorMessage) {
    return AnalysisResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      emotion: 'Belirtilmemiş',
      intent: 'İletişim kurma', // Zorunlu alan
      tone: 'Nötr',
      severity: 5,
      persons: 'Belirtilenmemiş',
      aiResponse: {
        'mesajYorumu': errorMessage,
        'tavsiyeler': [
          'Lütfen tekrar deneyiniz veya başka bir mesaj gönderiniz.',
          'Mesajınızı daha açık bir şekilde iletmeyi deneyebilirsiniz.',
          'Daha sonra tekrar deneyebilirsiniz.'
        ]
      },
      createdAt: DateTime.now(),
    );
  }

  // İlişki raporu oluşturma
  Future<Map<String, dynamic>> generateRelationshipReport(List<String> answers) async {
    try {
      // Güvenli bir şekilde cevaplara eriş (en az 6 elemanlı olduğunu kontrol et)
      if (answers.length < 6) {
        // Yetersiz cevap varsa, eksik olanları boş string ile doldur
        final safeAnswers = List<String>.from(answers);
        while (safeAnswers.length < 6) {
          safeAnswers.add('');
        }
        answers = safeAnswers;
      }
    
      // Gemini API'ye istek gönderme
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': '''
                  Sen bir ilişki koçusun. Aşağıdaki sorulara verilen yanıtlara dayanarak bir ilişki raporu hazırla.
                  
                  Raporu aşağıdaki JSON formatında hazırla:
                  {
                    "relationship_type": "ilişki tipi (sağlıklı, gelişmekte olan, zorlayıcı, vb.)",
                    "report": "Detaylı ilişki raporu",
                    "suggestions": ["öneri 1", "öneri 2", "öneri 3"]
                  }
                  
                  Yanıtların anlamları:
                  - "Kesinlikle evet": Çok olumlu bir yanıt
                  - "Kararsızım": Nötr veya belirsiz bir durum
                  - "Pek sanmam": Olumsuz bir yanıt
                  
                  ${_buildQuestionAnswersText(answers)}
                  '''
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': _geminiMaxTokens
          }
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null) {
          _logger.e('AI yanıtı boş veya beklenen formatta değil', data);
          return {'error': 'Rapor oluşturulamadı'};
        }
        
        // JSON yanıtı ayrıştırma
        try {
          Map<String, dynamic>? jsonResponse = _parseJsonFromText(aiContent);
          if (jsonResponse != null) {
            jsonResponse['created_at'] = DateTime.now().toIso8601String();
            return jsonResponse;
          } else {
            _logger.e('JSON yanıtı boş veya geçersiz');
            return {'error': 'Geçerli JSON yanıtı alınamadı'};
          }
        } catch (e) {
          _logger.e('JSON ayrıştırma hatası', e);
          return {
            'report': aiContent,
            'relationship_type': _extractRelationshipType(aiContent),
            'suggestions': _extractSuggestions(aiContent),
            'created_at': DateTime.now().toIso8601String(),
          };
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return {'error': 'Rapor oluşturulamadı'};
      }
    } catch (e) {
      _logger.e('Rapor oluşturma hatası', e);
      return {'error': 'Bir hata oluştu'};
    }
  }

  // Metinden JSON yanıtını ayrıştırma
  dynamic _parseJsonFromText(String text) {
    _logger.d('JSON metni ayrıştırılıyor...');
    
    // Boş metin kontrolü
    if (text.trim().isEmpty) {
      _logger.e('Ayrıştırılacak metin boş');
      return null;
    }
    
    // Gereksiz bloklardan temizle
    String jsonText = text.trim();
    
    // JSON kod bloğu formatını kontrol et ve içinden JSON'ı çıkar
    if (jsonText.contains('```json')) {
      final jsonParts = jsonText.split('```json');
      if (jsonParts.length > 1) {
        final endParts = jsonParts[1].split('```');
        if (endParts.isNotEmpty) {
          jsonText = endParts[0].trim();
        }
      }
    } else if (jsonText.contains('```')) {
      final jsonParts = jsonText.split('```');
      if (jsonParts.length > 1) {
        jsonText = jsonParts[1].trim();
      }
    }
    
    try {
      // Önce tüm metni decode etmeyi dene (liste veya obje olabilir)
      return jsonDecode(jsonText);
    } catch (e) {
      _logger.w('Tam metni ayrıştırma başarısız: $e');
      
      // JSON başlangıç ve bitiş karakterlerini kontrol et
      bool isList = jsonText.trim().startsWith('[') && jsonText.trim().endsWith(']');
      bool isObject = jsonText.trim().startsWith('{') && jsonText.trim().endsWith('}');
      
      if (isList) {
        // Liste için başlangıç ve bitiş indekslerini bul
        final jsonStartIndex = jsonText.indexOf('[');
        final jsonEndIndex = jsonText.lastIndexOf(']') + 1;
        
        if (jsonStartIndex != -1 && jsonEndIndex > 0 && jsonStartIndex < jsonEndIndex) {
          // Başlangıç ve bitiş indekslerine göre JSON kısmını al
          jsonText = jsonText.substring(jsonStartIndex, jsonEndIndex);
          // Hatalı karakterleri temizle
          jsonText = jsonText.replaceAll(RegExp(r'[\u0000-\u001F]'), '');
          
          try {
            return jsonDecode(jsonText);
          } catch (listDecodeError) {
            _logger.e('Liste ayrıştırma hatası: $listDecodeError');
            
            // Yaygın JSON sözdizimi hatalarını düzeltmeye çalış
            jsonText = jsonText
              .replaceAll(RegExp(r',\s*]'), ']') // Listelerdeki sondaki virgülleri temizle
              .replaceAll(RegExp(r'([\[,]\s*)(\w+)(\s*:)'), r'$1"$2"$3'); // Liste içindeki objelerde tırnak işareti olmayan anahtarları düzelt
            
            try {
              return jsonDecode(jsonText);
            } catch (nestedError) {
              _logger.e('Düzeltilmiş liste ayrıştırma hatası: $nestedError');
            }
          }
        }
      } else if (isObject) {
        // Nesne için başlangıç ve bitiş indekslerini bul
        final jsonStartIndex = jsonText.indexOf('{');
        final jsonEndIndex = jsonText.lastIndexOf('}') + 1;
        
        if (jsonStartIndex != -1 && jsonEndIndex > 0 && jsonStartIndex < jsonEndIndex) {
          // Başlangıç ve bitiş indekslerine göre JSON kısmını al
          jsonText = jsonText.substring(jsonStartIndex, jsonEndIndex);
          // Hatalı karakterleri temizle
          jsonText = jsonText.replaceAll(RegExp(r'[\u0000-\u001F]'), '');
          
          try {
            return jsonDecode(jsonText) as Map<String, dynamic>;
          } catch (objectDecodeError) {
            _logger.e('Nesne ayrıştırma hatası: $objectDecodeError');
            
            // Yaygın JSON sözdizimi hatalarını düzeltmeye çalış
            jsonText = jsonText
              .replaceAll(RegExp(r',\s*}'), '}') // Sondaki virgülleri temizle
              .replaceAll(RegExp(r'([{,]\s*)(\w+)(\s*:)'), r'$1"$2"$3'); // Tırnak işareti olmayan anahtarları düzelt
            
            try {
              return jsonDecode(jsonText) as Map<String, dynamic>;
            } catch (nestedError) {
              _logger.e('Düzeltilmiş nesne ayrıştırma hatası: $nestedError');
              return _manualParseJson(jsonText);
            }
          }
        }
      }
      
      // Son çare: Düzenli ifadelerle JSON parçalarını arayıp manuel olarak ayrıştırmaya çalış
      if (text.contains('[') && text.contains(']')) {
        // Liste ayrıştırmayı dene
        try {
          return _manualParseJsonList(text);
        } catch (listParseError) {
          _logger.e('Manuel liste ayrıştırma hatası: $listParseError');
        }
      }
      
      try {
        return _manualParseJson(text);
      } catch (objectParseError) {
        _logger.e('Manuel nesne ayrıştırma hatası: $objectParseError');
        return null;
      }
    }
  }
  
  // JSON liste metni manuel olarak ayrıştırma girişimi
  List<Map<String, dynamic>> _manualParseJsonList(String text) {
    final result = <Map<String, dynamic>>[];
    
    // Liste içindeki nesneleri bulmaya çalış
    final pattern = RegExp(r'{(.*?)}', dotAll: true);
    final matches = pattern.allMatches(text);
    
    for (final match in matches) {
      if (match.group(0) != null) {
        final objectText = match.group(0)!;
        try {
          final Map<String, dynamic> object = jsonDecode(objectText);
          result.add(object);
        } catch (e) {
          // Basit anahtar-değer çiftleri oluştur
          final titleMatch = RegExp(r'"title"\s*:\s*"([^"]*)"').firstMatch(objectText);
          final commentMatch = RegExp(r'"comment"\s*:\s*"([^"]*)"').firstMatch(objectText);
          
          if (titleMatch?.group(1) != null || commentMatch?.group(1) != null) {
            final obj = <String, dynamic>{
              'title': titleMatch?.group(1) ?? 'Başlık bulunamadı',
              'comment': commentMatch?.group(1) ?? 'İçerik bulunamadı'
            };
            result.add(obj);
          }
        }
      }
    }
    
    // Hiçbir nesne bulunamazsa varsayılan döndür
    if (result.isEmpty) {
      result.add({
        'title': 'Analiz Hatası',
        'comment': 'Sohbet verileri ayrıştırılamadı.'
      });
    }
    
    return result;
  }

  // Metinden ilişki tipini çıkarma
  String? _extractRelationshipType(String text) {
    // İlişki tipi için regex
    final RegExp relationshipRegex = RegExp('"ilişki_tipi"\\s*:\\s*"([^"]*)"', caseSensitive: false);
    final relationshipMatch = relationshipRegex.firstMatch(text);
    
    if (relationshipMatch != null && relationshipMatch.group(1) != null) {
      final type = relationshipMatch.group(1)!.trim();
      _logger.d('İlişki tipi çıkarıldı: $type');
      return type.isNotEmpty ? type : null;
    }
    
    // İlişki tipini metin içinden çıkarmayı dene
    final typeMatches = [
      RegExp('(?:ilişki|ilişki tipi)\\s*:?\\s*(\\w+)', caseSensitive: false),
      RegExp('(arkadaşlık|romantik|aile|profesyonel|iş|flört|evlilik) (?:ilişkisi)?', caseSensitive: false)
    ];
    
    for (final regex in typeMatches) {
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final type = match.group(1)!.trim().toLowerCase();
        _logger.d('İlişki tipi metin içinden çıkarıldı: $type');
        return type.isNotEmpty ? type : null;
      }
    }
    
    return null;
  }

  // Metinden önerileri çıkarma
  List<String>? _extractSuggestions(String text) {
    return _extractSuggestionsFromText(text);
  }

  // Metinden önerileri çıkarma
  List<String>? _extractSuggestionsFromText(String text) {
    // Öneri listesi için regex
    final RegExp listRegex = RegExp('"cevap_onerileri"\\s*:\\s*\\[(.*?)\\]', caseSensitive: false, dotAll: true);
    final listMatch = listRegex.firstMatch(text);
    
    if (listMatch != null && listMatch.group(1) != null) {
      final listContent = listMatch.group(1)!;
      final suggestions = RegExp('"([^"]*)"').allMatches(listContent)
          .map((m) => m.group(1)?.trim())
          .where((s) => s != null && s.isNotEmpty)
          .map((s) => s!)
          .toList();
      
      _logger.d('Öneriler çıkarıldı: $suggestions');
      return suggestions.isNotEmpty ? suggestions : null;
    }
    
    // Madde işaretli liste biçiminde olabilir
    final bulletedItems = text.split('\n')
        .where((line) => line.contains('- ') || RegExp(r'^\d+\.').hasMatch(line.trim()))
        .map((line) => line.replaceAll(RegExp(r'^-|\d+\.'), '').trim())
        .where((item) => item.isNotEmpty)
        .toList();
    
    if (bulletedItems.isNotEmpty) {
      _logger.d('Madde işaretli öneriler çıkarıldı: $bulletedItems');
      return bulletedItems;
    }
    
    return null;
  }

  // OCR içeriği kontrolü için yardımcı fonksiyon
  bool _isOcrContent(String content) {
    return content.contains("---- Görüntüden çıkarılan metin ----") || 
           content.contains("OCR metni:") || 
           content.contains("Görsel içeriği:") ||
           content.contains("Görselden çıkarılan metin:");
  }

  /// Mesaj koçu analizi yapma
  Future<Map<String, dynamic>> analyzeChatCoach(String chatContent) async {
    try {
      _logger.i('Mesaj koçu analizi başlatılıyor...');
      
      // Mesaj içeriği boş bile olsa analiz yapmayı zorlayacağız
      if (chatContent.trim().isEmpty) {
        _logger.w('Boş mesaj içeriği, içerik minimal olsa da analiz zorunlu yapılacak');
        // Minimal içerik bile olsa analiz yapmaya devam et
        // Boş içerik için özel prompt kullanacağız
        chatContent = "...";
      }
      
      // Mesaj içeriğinin uzunluğunu kontrol et
      if (chatContent.length > 12000) {
        _logger.w('Mesaj içeriği çok uzun (${chatContent.length} karakter). Kısaltılıyor...');
        chatContent = "${chatContent.substring(0, 12000)}...";
      }
      
      // OCR formatını kontrol et
      bool isOcrContent = _isOcrContent(chatContent);
      
      // OCR içeriği için özel işleme yap
      if (isOcrContent) {
        _logger.i('OCR içeriği tespit edildi, özel analiz yapılacak');
        
        // Görsel analizi için özel içerik hazırla - içerik boş olsa bile
        if (chatContent.length < 100) {
          _logger.w('OCR içeriği çok kısa, zorla analiz yapmak için içeriği zenginleştiriyorum');
          // Çok kısa OCR içeriği için bir tamamlayıcı
          chatContent = "$chatContent\n\n(Görsel içeriği kısa olsa da analiz yapılacak)";
        }
      }
      
      // Chat geçmişini hazırla
      final contents = <Map<String, dynamic>>[];
      
      // Sistem mesajını ekle - model rolü ile - prompta daha agresif bir dil kullan
      contents.add({
        'role': 'model',
        'parts': [
          {
            'text': isOcrContent 
            ? '''
            Sen bir görseldeki metin analisti olarak görev yapacaksın. Kullanıcının gönderdiği görsel üzerinden çıkarılan metni eleştirel bir gözle analiz etmen gerekiyor.

            KRİTİK KURALLAR:
            1. "Analiz edilemedi", "yetersiz içerik" veya "belirlenemedi" YASAKTIR! Her durumda analiz yapmalısın.
            2. İçerik ne kadar kısa olursa olsun, MUTLAKA TAM VE ÖZGÜN bir analiz yapmalısın.
            3. Hiçbir alanı boş bırakmak YASAKTIR! Tüm alanları doldurmalısın.
            4. "sohbetGenelHavasi", "sonMesajTonu" ve diğer alanlara GEÇERLİ değerler yazmalısın, "belirlenemedi" gibi ifadeler KULLANMA.
            5. "Direkt Yorum ve Geliştirme" bölümünde: ÇOK SERT, KÜSTAH ve HAKARETVARİ ifadeler kullanmalısın!
            6. "direktYorum" alanında kullanıcıya AĞIR ELEŞTİRİLER getirmelisin!
            
            ÖZELLİKLE "direktYorum" alanına şunlara benzer ÇOK SERT ifadeler yazmalısın:
            - "Bu görseldeki yazı tarzın berbat, kimse okumaz bunu."
            - "Görselindeki mesaj rezalet. Kimse seninle böyle konuşmak istemez."
            - "Bu nasıl bir görsel? Mesaj yazma stilin tam bir fiyasko."
            - "Görsele bakılırsa iletişim kurma becerilerin sıfır."
            - "Görselindeki yazı tarzı o kadar sıkıcı ki karşı taraf muhtemelen başka biriyle mesajlaşıyor şu an."
            
            Kullanıcıya kesinlikle "sen" diye hitap et: "senin görselindeki yazı...", "sen bu görseli gönderirken..."
            Görsel içeriği kısa veya anlamsız olsa bile, ZORLA bir analiz yap!
            
            ÖNEMLİ NOT:
            Bu analiz sonuçları ilişki analizi, uyum puanı veya kişiselleştirilmiş tavsiyelere HİÇBİR ŞEKİLDE etki etmeyecektir.
            Bu tamamen ayrı bir modüldür ve kullanıcının mesajlaşma tarzını analiz etmekten ibarettir.
            '''
            : '''
            Sen bir sohbet analisti olarak görev yapacaksın. Kullanıcının sohbet geçmişini eleştirel bir gözle analiz etmen gerekiyor.

            KRİTİK KURALLAR:
            1. "Analiz edilemedi", "yetersiz içerik" veya "belirlenemedi" YASAKTIR! Her durumda analiz yapmalısın.
            2. İçerik ne kadar kısa olursa olsun, MUTLAKA TAM VE ÖZGÜN bir analiz yapmalısın.
            3. Hiçbir alanı boş bırakmak YASAKTIR! Tüm alanları doldurmalısın.
            4. "sohbetGenelHavasi", "sonMesajTonu" ve diğer alanlara GEÇERLİ değerler yazmalısın, "belirlenemedi" gibi ifadeler KULLANMA.
            5. "Direkt Yorum ve Geliştirme" bölümünde: ÇOK SERT, KÜSTAH ve HAKARETVARİ ifadeler kullanmalısın!
            6. "direktYorum" alanında kullanıcıya AĞIR ELEŞTİRİLER getirmelisin!
            
            ÖZELLİKLE "direktYorum" alanına şunlara benzer ÇOK SERT ifadeler yazmalısın:
            - "Mesajlaşma tarzın berbat. Kimse seninle konuşmak istemeyecek."
            - "Bu nasıl bir iletişim ya? Resmen karşındakini kaçırıyorsun."
            - "Vakit kaybetme ayrıl knk. Bu kişi seni takmıyor bence."
            - "Çok fazla mesaj atıyorsun, yavaşla biraz acınası durumdasın."
            - "İletişim becerin sıfır. Karşındaki çoktan başka biriyle yazışıyor olabilir."
            
            Kullanıcıya kesinlikle "sen" diye hitap et: "senin sorunun...", "sen çok fazla..."
            "canım", "tatlım", "bebeğim" gibi yumuşak hitaplar ASLA kullanma!
            
            ÖNEMLİ NOT:
            Bu analiz sonuçları ilişki analizi, uyum puanı veya kişiselleştirilmiş tavsiyelere HİÇBİR ŞEKİLDE etki etmeyecektir.
            Bu tamamen ayrı bir modüldür ve sadece mesajlaşma tarzını analiz etmekten ibarettir.
            '''
          }
        ]
      });
      
      // Kullanıcının mesajını ekle - user rolü ile
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text': '''
            Bu ${isOcrContent ? 'görseldeki metni' : 'sohbet geçmişini'} analiz et:
            
            $chatContent
            
            Analizi SADECE aşağıdaki JSON formatında dön. Başka hiçbir metin ekleme:
            
            {
              "sohbetGenelHavasi": "Soğuk/Samimi/Pasif-agresif/İlgisiz/İlgili",
              "genelYorum": "Sert ve doğrudan genel yorum",
              "sonMesajTonu": "Sert/Soğuk/Sempatik/Umursamaz",
              "sonMesajEtkisi": {
                "sempatik": 10,
                "kararsız": 30,
                "olumsuz": 60
              },
              "direktYorum": "Çok sert ve acımasız bir eleştiri",
              "cevapOnerileri": [
                "Net ve doğrudan cevap önerisi", 
                "İkinci öneri"
              ]
            }
            
            SON UYARI: 
            - "Analiz edilemedi", "yetersiz içerik", "belirlenemedi" gibi ifadeler ASLA kullanma
            - İçerik ne kadar kısa olursa olsun TAM ve ÖZGÜN analiz yapmalısın
            - "direktYorum" alanında KESİNLİKLE şu tarz çok sert bir dil kullanmalısın: "vakit kaybetme ayrıl knk", "bu kişi seni takmıyor bence", "çok fazla mesaj atıyorsun, yavaşla biraz"
            - Tüm alanları doldurmalısın, eksik alan bırakma
            '''
          }
        ]
      });
      
      // Gemini API'ye istek gönderme
      final requestBody = jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 1.0,  // Daha yaratıcı ve sert yanıtlar için sıcaklığı arttır
          'maxOutputTokens': _geminiMaxTokens,
          'responseFormat': { "type": "json" }
        }
      });
      
      _logger.d('Mesaj koçu API isteği yapılıyor...');
      
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
      _logger.d('API yanıtı - status: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          
          if (aiContent == null || aiContent.trim().isEmpty) {
            _logger.e('AI yanıtı boş, ikinci deneme yapılıyor');
            // Boş yanıt alırsak, ikinci deneme yap
            return await _ikiciDenemeyiYap(chatContent, _isOcrContent(chatContent));
          }
          
          _logger.d('AI yanıt metni alındı');
          
          // JSON yanıtını ayrıştır
          Map<String, dynamic>? jsonMap = _parseJsonFromText(aiContent);
          
          if (jsonMap == null || !_jsonGecerliMi(jsonMap)) {
            _logger.e('Geçerli JSON ayrıştırılamadı, ikinci deneme yapılıyor');
            // Geçersiz JSON aldıysak, ikinci deneme yap
            return await _ikiciDenemeyiYap(chatContent, _isOcrContent(chatContent));
          }
          
          // Etki değerlerinin toplamını kontrol et ve düzelt
          _sonMesajEtkisiniNormallestir(jsonMap);
          
          // DirectYorum kontrolü - yeterince sert değilse zorunlu olarak düzelt
          if (_direktYorumCokKibarMi(jsonMap['direktYorum'])) {
            // Kibar yorumsa, tüm JSON'ı değil sadece direktYorum kısmını düzelt
            _logger.w('Direktif yorum çok kibar, sert yorumla değiştiriliyor');
            jsonMap['direktYorum'] = _getSertDirektYorum(isOcrContent);
          }
          
          // Zaman damgası ekle
          jsonMap['timestamp'] = DateTime.now().toIso8601String();
          
          return jsonMap;
        } catch (parseError) {
          _logger.e('Yanıt ayrıştırma hatası: $parseError');
          // Hata durumunda ikinci deneme yap
          return await _ikiciDenemeyiYap(chatContent, _isOcrContent(chatContent));
        }
      } else {
        _logger.e('API Hatası: ${response.statusCode}');
        // API hatası durumunda ikinci deneme yap  
        return await _ikiciDenemeyiYap(chatContent, _isOcrContent(chatContent));
      }
    } catch (e) {
      _logger.e('Mesaj koçu analizi hatası: $e');
      // Genel hata durumunda ikinci deneme yap
      return await _ikiciDenemeyiYap(chatContent, _isOcrContent(chatContent));
    }
  }
  
  // İkinci bir deneme yapmak için
  Future<Map<String, dynamic>> _ikiciDenemeyiYap(String chatContent, bool isOcrContent) async {
    try {
      _logger.i('Mesaj koçu analizi ikinci deneme yapılıyor...');
      
      // Chat geçmişini hazırla - daha basit ve doğrudan bir sorgu
      final contents = <Map<String, dynamic>>[];
      
      contents.add({
        'role': 'model',
        'parts': [
          {
            'text': '''
            SEN AŞIRI SERT, KÜSTAH VE ACI ELEŞTİRİLER YAPAN BİR MESAJ KOÇUSUN.
            SADECE JSON FORMATINDA CEVAP VER. HİÇBİR AÇIKLAMA EKLEME.
            
            ${isOcrContent ? 'Kullanıcının gönderdiği görselden çıkarılan metni' : 'Kullanıcının mesajlaşma stilini'} eleştireceksin.
            
            KURALLAR:
            - Tüm alanlara GEÇERLİ değerler yazmalısın: "analiz edilemedi", "belirlenemedi" gibi ifadeler YASAK!
            - "direktYorum" alanında ÇOK SERT, KÜSTAH ve ACI bir dil kullanmalısın!
            - Eksik alan BIRAKMA, tüm alanları DOLDUR!
            
            DİREKTYORUM ALANINA ŞUNLARA BENZER ÇOK SERT İFADELER YAZMALISIN:
            - "Mesajlaşma stilin berbat, kimse seninle konuşmak istemez."
            - "Karşı taraf seninle yazışmaktan sıkılmış olmalı, yazma tarzın çok kötü."
            - "Vakit kaybetme ayrıl knk, yazışma tarzın tam bir fiyasko."
            - "Bu nasıl bir iletişim tarzı? Resmen karşındakini kaçırıyorsun."
            '''
          }
        ]
      });
      
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text': '''
            Bu ${isOcrContent ? 'görselden çıkarılan metni' : 'sohbet metnini'} analiz et:
            
            ```
            $chatContent
            ```
            
            Aşağıdaki JSON formatında yanıt ver:
            
            {
              "sohbetGenelHavasi": "Soğuk",
              "genelYorum": "Ciddi bir eleştirel yorum",
              "sonMesajTonu": "Soğuk",
              "sonMesajEtkisi": {
                "sempatik": 10,
                "kararsız": 30,
                "olumsuz": 60
              },
              "direktYorum": "BU ALANDA ÇOK SERT VE ACIMASIZ BİR YORUM YAZMALISIN",
              "cevapOnerileri": [
                "Cevap önerisi", 
                "İkinci öneri"
              ]
            }
            
            DİREKTYORUM ALANINI ÇOK SERT VE KÜSTAH YAZMAN ZORUNLU!
            '''
          }
        ]
      });
      
      final requestBody = jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 1.2,  // Daha da sert yanıtlar için sıcaklığı yüksek tut
          'maxOutputTokens': _geminiMaxTokens,
          'responseFormat': { "type": "json" }
        }
      });
      
      _logger.d('İkinci deneme API isteği yapılıyor...');
      
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          
          if (aiContent == null || aiContent.trim().isEmpty) {
            return _olusturZorunluSonuc(isOcrContent);
          }
          
          Map<String, dynamic>? jsonMap = _parseJsonFromText(aiContent);
          
          if (jsonMap == null || !_jsonMinimalGecerliMi(jsonMap)) {
            return _olusturZorunluSonuc(isOcrContent);
          }
          
          // Etki değerlerini normalize et
          _sonMesajEtkisiniNormallestir(jsonMap);
          
          // DirectYorum kontrolü - ikinci denemede de nazik çıkarsa zorla sert yorumla değiştir
          if (_direktYorumCokKibarMi(jsonMap['direktYorum'])) {
            jsonMap['direktYorum'] = _getSertDirektYorum(isOcrContent);
          }
          
          // Eksik alanları doldur
          _eksikAlanlariDoldur(jsonMap, isOcrContent);
          
          // Zaman damgası ekle
          jsonMap['timestamp'] = DateTime.now().toIso8601String();
          
          return jsonMap;
        } catch (e) {
          return _olusturZorunluSonuc(isOcrContent);
        }
      } else {
        return _olusturZorunluSonuc(isOcrContent);
      }
    } catch (e) {
      return _olusturZorunluSonuc(isOcrContent);
    }
  }
  
  // En son çare olarak zorunlu bir sonuç oluştur - asla null dönme!
  Map<String, dynamic> _olusturZorunluSonuc(bool isOcrContent) {
    _logger.w('Zorunlu sonuç oluşturuluyor...');
    
    // Görsel veya metin için farklı yorumlar
    final direktYorum = isOcrContent 
        ? "Gönderdiğin görsel berbat bir içerik sunuyor. Yazı tarzın okunaksız ve hiç etkileyici değil. Bu görsel senin iletişim becerilerinin ne kadar zayıf olduğunu gösteriyor. Daha düzgün bir görsel ve iletişim tarzı kullanmalısın."
        : "Mesajlaşma tarzın tamamen başarısız. Kimse bu tarz kuru ve sıkıcı mesajlarla ilgilenmek istemez. Karşı tarafı sıktığın çok belli ve muhtemelen başka birileriyle yazışmak istiyor. İletişim becerilerini ciddi şekilde geliştirmelisin.";
    
    final genelYorum = isOcrContent
        ? "Gönderdiğin görselden çıkarılan metin, zayıf bir iletişim tarzını yansıtıyor. Mesajlaşma stilin geliştirilebilir."
        : "Genel sohbet havası kuru ve derinlikten yoksun. Mesajlaşma stilin ilgi çekici değil ve karşı tarafı sıkıyor olabilir.";
    
    // İki farklı cevap önerisi oluştur
    final cevapOnerileri = isOcrContent
        ? ["Düşüncelerimi daha net bir şekilde ifade etmek istiyorum. Bu konuda ne düşünüyorsun?", "Görsellerle değil, doğrudan ve açık bir şekilde iletişim kurmayı tercih ediyorum."]
        : ["Bu konuda açıkça konuşmak istiyorum. Seninle olan iletişimimizin daha iyi olmasını istiyorum.", "Mesajlarıma cevap vermediğini fark ettim. Seni rahatsız eden bir şey mi var?"];
    
    // Zorunlu bir sonuç döndür
    return {
      "sohbetGenelHavasi": isOcrContent ? "Belirsiz" : "Soğuk", 
      "genelYorum": genelYorum,
      "sonMesajTonu": isOcrContent ? "Karmaşık" : "Soğuk",
      "sonMesajEtkisi": {
        "sempatik": 10,
        "kararsız": 30,
        "olumsuz": 60
      },
      "direktYorum": direktYorum,
      "cevapOnerileri": cevapOnerileri,
      "timestamp": DateTime.now().toIso8601String()
    };
  }
  
  // Eksik alanları doldur, boş alan kalmasını önle
  void _eksikAlanlariDoldur(Map<String, dynamic> jsonMap, bool isOcrContent) {
    // sohbetGenelHavasi eksikse doldur
    if (!jsonMap.containsKey('sohbetGenelHavasi') || jsonMap['sohbetGenelHavasi'] == null || 
        jsonMap['sohbetGenelHavasi'].toString().trim().isEmpty) {
      jsonMap['sohbetGenelHavasi'] = isOcrContent ? "Karmaşık" : "Soğuk";
    }
    
    // genelYorum eksikse doldur
    if (!jsonMap.containsKey('genelYorum') || jsonMap['genelYorum'] == null || 
        jsonMap['genelYorum'].toString().trim().isEmpty) {
      jsonMap['genelYorum'] = isOcrContent 
          ? "Görsel içeriğindeki metin, etkili bir iletişim kurmak için yetersiz. Mesajlaşma tarzını geliştirmelisin."
          : "Sohbet içeriğin çok sığ ve ilgi çekici değil. Karşı tarafı sıkıyor olabilirsin.";
    }
    
    // sonMesajTonu eksikse doldur
    if (!jsonMap.containsKey('sonMesajTonu') || jsonMap['sonMesajTonu'] == null || 
        jsonMap['sonMesajTonu'].toString().trim().isEmpty) {
      jsonMap['sonMesajTonu'] = isOcrContent ? "Karmaşık" : "Soğuk";
    }
    
    // sonMesajEtkisi eksik veya boşsa doldur
    if (!jsonMap.containsKey('sonMesajEtkisi') || jsonMap['sonMesajEtkisi'] == null || 
        jsonMap['sonMesajEtkisi'] is! Map || (jsonMap['sonMesajEtkisi'] as Map).isEmpty) {
      jsonMap['sonMesajEtkisi'] = {
        "sempatik": 10,
        "kararsız": 30,
        "olumsuz": 60
      };
    }
    
    // direktYorum eksikse doldur
    if (!jsonMap.containsKey('direktYorum') || jsonMap['direktYorum'] == null || 
        jsonMap['direktYorum'].toString().trim().isEmpty) {
      jsonMap['direktYorum'] = _getSertDirektYorum(isOcrContent);
    }
    
    // cevapOnerileri eksikse doldur
    if (!jsonMap.containsKey('cevapOnerileri') || jsonMap['cevapOnerileri'] == null || 
        jsonMap['cevapOnerileri'] is! List || (jsonMap['cevapOnerileri'] as List).isEmpty) {
      jsonMap['cevapOnerileri'] = isOcrContent
          ? ["Görsel yerine doğrudan mesaj yazarak iletişim kurmayı tercih ederim. Düşüncelerini açıkça belirt.", "Bu konuyu detaylı konuşmak istiyorum. Müsait olduğunda bana haber ver."]
          : ["Düşüncelerimi açıkça ifade etmek istiyorum. Bu konuda senin de açık olmanı bekliyorum.", "İletişimimizi daha açık ve dürüst bir şekilde sürdürmek istiyorum. Ne düşünüyorsun?"];
    }
  }
  
  // Rastgele sert bir direkt yorum döndür
  String _getSertDirektYorum(bool isOcrContent) {
    final sertYorumlar = isOcrContent
        ? [
            "Bu görseldeki yazı tarzın berbat. Kimse böyle bir içeriği okumak istemez. İletişim becerilerini ciddi şekilde geliştirmelisin.",
            "Gönderdiğin görseldeki metin tam bir fiyasko. Hiçbir anlam ifade etmiyor ve karşı tarafı sıkıyorsun.",
            "Görseldeki yazı stilin acınası. Daha düzgün ve anlaşılır bir iletişim kurmalısın.",
            "Bu nasıl bir görsel içerik? Kimse bu karmaşık ve anlamsız metinlerle ilgilenmez. İletişim tarzını tamamen değiştirmelisin.",
            "Görselindeki mesaj içeriği tam bir başarısızlık. Hiçbir şekilde etkileyici değil ve karşı tarafı sıkıyorsun."
          ]
        : [
            "Mesajlaşma tarzın tamamen başarısız. Kimse bu tarz kuru ve sıkıcı mesajlarla ilgilenmek istemez.",
            "Bu nasıl bir iletişim ya? Resmen karşındakini kaçırıyorsun. Mesaj yazma tarzın berbat.",
            "Vakit kaybetme ayrıl knk. Karşı taraf seninle ilgilenmiyor. Mesajlarındaki ilgisizlik her şeyi anlatıyor.",
            "İletişim becerin sıfır. Bu mesajlarla kimseyi etkileyemezsin. Kendini ifade etmeyi öğrenmelisin.",
            "Çok fazla gereksiz mesaj gönderiyorsun. Karşı taraf senden sıkılmış olmalı. Daha özlü ve ilgi çekici ol."
          ];
    
    // Rastgele bir yorum seç
    return sertYorumlar[Random().nextInt(sertYorumlar.length)];
  }
  
  // Sadece direktYorumu düzeltmek için
  Future<String> _dirtektYorumuDuzelt(String chatContent) async {
    try {
      // Acımasız bir direktYorum için özel bir istek yapalım
      final contents = <Map<String, dynamic>>[];
      
      contents.add({
        'role': 'model',
        'parts': [
          {
            'text': '''
            Sadece çok sert, acımasız ve küstah bir eleştiri yaz.
            Asla nazik, kibar veya yumuşak olma. 
            Kesinlikle "canım", "tatlım" gibi hitaplar kullanma.
            '''
          }
        ]
      });
      
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text': '''
            Bu sohbeti çok sert bir şekilde eleştir:
            $chatContent
            
            NOT: Eleştirin çok acımasız ve dobra olmalı.
            '''
          }
        ]
      });
      
      final requestBody = jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 1.0,
          'maxOutputTokens': 150
        }
      });
      
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final yeniDirektYorum = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (yeniDirektYorum != null && yeniDirektYorum.isNotEmpty && yeniDirektYorum.length > 30) {
          // Yorum kibar değilse kullan
          if (!_direktYorumCokKibarMi(yeniDirektYorum)) {
            return yeniDirektYorum.trim();
          }
        }
      }
      
      // API yanıt vermezse, sert direktYorumlardan rastgele birini seç
      final sertYorumlar = [
        "Mesajların berbat. Karşı taraf seninle konuşmayı sürdürmek istemeyecektir. Kendini ifade etme becerilerin çok zayıf.",
        "Bu nasıl bir iletişim tarzı? Kimse bu kadar belirsiz ve ilgisiz mesajlarla iletişim kurmak istemez.",
        "Yazma tarzın tamamen başarısız. Karşı tarafı sıktığın çok belli ve kimse seninle bu şekilde mesajlaşmak istemez.",
        "Mesajlarında hiç çaba yok. Kendini doğru düzgün ifade edemiyorsun ve iletişim kurma becerin oldukça kötü.",
        "İletişim bu şekilde yürümez. Karşı taraf senden sıkılmış olmalı çünkü mesajların tamamen anlamsız ve derinlikten yoksun."
      ];
      
      return sertYorumlar[Random().nextInt(sertYorumlar.length)];
    } catch (e) {
      _logger.e('Direktif yorum düzeltme hatası: $e');
      
      // Hata durumunda sabit bir sert yorum döndür
      return "Mesajların tamamen başarısız. Hiç kimse bu tarz bir iletişimi ciddiye almaz ve karşı taraf muhtemelen seni terk edecek.";
    }
  }
  
  // Direktif yorumun çok kibar olup olmadığını kontrol etme
  bool _direktYorumCokKibarMi(String? direktYorum) {
    if (direktYorum == null || direktYorum.isEmpty) return true;
    
    final kibarKelimeler = ['lütfen', 'rica', 'canım', 'tatlım', 'sevgili', 'nazik', 'kibar', 'seviyorum', 'uygun'];
    
    for (final kelime in kibarKelimeler) {
      if (direktYorum.toLowerCase().contains(kelime)) {
        return true;
      }
    }
    
    // Çok kısa yorumlar da muhtemelen yetersizdir
    if (direktYorum.length < 40) {
      return true;
    }
    
    return false;
  }
  
  // Etki değerlerinin toplamını 100 yapma
  void _sonMesajEtkisiniNormallestir(Map<String, dynamic> jsonMap) {
    if (jsonMap['sonMesajEtkisi'] == null || jsonMap['sonMesajEtkisi'] is! Map) {
      jsonMap['sonMesajEtkisi'] = {'sempatik': 15, 'kararsız': 25, 'olumsuz': 60};
      return;
    }
    
    Map<String, dynamic> etkiMap = jsonMap['sonMesajEtkisi'];
    int toplam = 0;
    
    // Toplam değeri hesapla
    etkiMap.forEach((key, value) {
      if (value is int) {
        toplam += value;
      } else if (value is double) {
        toplam += value.toInt();
      } else if (value is String) {
        // String değeri sayıya çevirmeye çalış
        final numValue = int.tryParse(value.replaceAll(RegExp(r'[^\d]'), ''));
        if (numValue != null) {
          etkiMap[key] = numValue;
          toplam += numValue;
        } else {
          etkiMap[key] = 0;
        }
      }
    });
    
    // Eğer toplam sıfır ise, varsayılan değerler ata
    if (toplam == 0) {
      jsonMap['sonMesajEtkisi'] = {'sempatik': 15, 'kararsız': 25, 'olumsuz': 60};
      return;
    }
    
    // Toplam 100 değilse, normalize et
    if (toplam != 100) {
      // Her bir değeri toplama oranlayarak 100'e normalize et
      Map<String, int> normalizedMap = {};
      int normalizedTotal = 0;
      
      etkiMap.forEach((key, value) {
        int numValue = 0;
        if (value is int) {
          numValue = value;
        } else if (value is double) {
          numValue = value.toInt();
        } else if (value is String) {
          numValue = int.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        }
        
        // Normalize et
        int normalizedValue = ((numValue / toplam) * 100).round();
        normalizedMap[key] = normalizedValue;
        normalizedTotal += normalizedValue;
      });
      
      // Yuvarlama hataları nedeniyle toplam tam 100 olmayabilir, düzelt
      if (normalizedTotal != 100) {
        // En yüksek değeri bul ve düzelt
        var entries = normalizedMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        if (entries.isNotEmpty) {
          normalizedMap[entries.first.key] = entries.first.value + (100 - normalizedTotal);
        }
      }
      
      jsonMap['sonMesajEtkisi'] = normalizedMap;
    }
  }
  
  // JSON'ın gerekli alanları içerip içermediğini kontrol etme
  bool _jsonGecerliMi(Map<String, dynamic> json) {
    final zorunluAlanlar = ['sohbetGenelHavasi', 'genelYorum', 'sonMesajTonu', 'sonMesajEtkisi', 'direktYorum', 'cevapOnerileri'];
    
    for (final alan in zorunluAlanlar) {
      if (!json.containsKey(alan) || json[alan] == null) {
        return false;
      }
      
      // String türündeki alanların boş olmaması gerekir
      if ((alan == 'sohbetGenelHavasi' || alan == 'genelYorum' || alan == 'sonMesajTonu' || alan == 'direktYorum') && 
          (json[alan] is String && (json[alan] as String).trim().isEmpty)) {
        return false;
      }
      
      // sonMesajEtkisi bir map olmalı ve boş olmamalı
      if (alan == 'sonMesajEtkisi' && (json[alan] is! Map || (json[alan] as Map).isEmpty)) {
        return false;
      }
      
      // cevapOnerileri bir liste olmalı ve boş olmamalı
      if (alan == 'cevapOnerileri' && (json[alan] is! List || (json[alan] as List).isEmpty)) {
        return false;
      }
    }
    
    return true;
  }
  
  // JSON'ın minimal geçerlilik kontrolü - daha hoşgörülü
  bool _jsonMinimalGecerliMi(Map<String, dynamic> json) {
    // En azından bu alanların var olması gerekiyor
    return json.containsKey('sohbetGenelHavasi') && 
           json.containsKey('direktYorum') && 
           json.containsKey('sonMesajEtkisi');
  }

  // Sohbet analiz sonuçlarını döndürme
  Future<MessageCoachAnalysis?> sohbetiAnalizeEt(String sohbetIcerigi, {bool isImage = false}) async {
    try {
      _logger.i('Mesaj koçu: ${isImage ? "Görsel" : "Sohbet"} analizi başlatılıyor...');
      
      // Sohbet içeriğini temizle
      sohbetIcerigi = sohbetIcerigi.trim();
      
      // Boş içerik kontrolü
      if (sohbetIcerigi.isEmpty) {
        _logger.w('Mesaj koçu: Boş ${isImage ? "görsel" : "sohbet"} içeriği.');
        return null;
      }
      
      // Sohbet çok uzunsa, kısalt
      if (sohbetIcerigi.length > 15000) {
        _logger.w('Mesaj koçu: İçerik çok uzun (${sohbetIcerigi.length} karakter). Kısaltılıyor...');
        sohbetIcerigi = "${sohbetIcerigi.substring(0, 15000)}...";
      }
      
      // Görselden OCR ile çıkarılan metin için özel işleme
      String preprocessedContent = sohbetIcerigi;
      
      if (isImage) {
        _logger.i('Mesaj koçu: Görsel içeriği işleniyor...');
        
        // OCR içeriğinden sohbet formatına dönüştür
        preprocessedContent = _preprocessImageText(sohbetIcerigi);
        
        // Görsel boş içerik içeriyorsa bile devam et, AI'ın bir yorum yapmasını sağla
        if (preprocessedContent.trim().isEmpty) {
          _logger.w('Mesaj koçu: Görselde kullanılabilir sohbet bulunamadı, ancak yine de analiz yapılacak.');
          preprocessedContent = "Bu görselde anlaşılır bir sohbet bulunamadı.";
        }
      }
      
      // Gemini API prompt'u 
      final prompt = '''
Sen profesyonel bir ilişki koçusun. ÇOK SERT, acımasız ve eleştirel bir üslupla tavsiyeler veriyorsun. Nazik ve kibar olmaktan uzak duruyorsun. Verilen sohbeti analiz etmeni istiyorum ve SADECE JSON formatında yanıt ver.

${isImage ? "Bu bir mesajlaşma uygulamasından alınan ekran görüntüsünün OCR ile çıkarılmış metnidir." : ""}

Sohbet:
"""
$preprocessedContent
"""

KESİNLİKLE UYULMASI GEREKEN KURALLAR:
1. İçerik ne kadar kısa, anlamsız veya içeriksiz olursa olsun MUTLAKA analiz yapmak zorundasın. "Sohbet analizi için yeterli içerik yok", "Belirlenemedi", "Analiz edilemedi" gibi ifadeler ASLA KULLANMA!
2. Çok az veri olsa bile mutlaka yorum yap, gerekirse uydur ama asla "Yeterli içerik yok", "analiz yapılamadı" gibi ifadeler kullanma.
3. Sohbeti SERT VE ELEŞTİREL şekilde yorumla. Samimiyetsiz, yapay bul. Her zaman eleştirel bakış açısına sahip ol. 
4. Üslubun küstah ve dobra olmalı. Tepeden bakan ve alaycı bir ton kullan.
5. "direktYorum" alanında ÇOK SERT, bazen kırıcı olabilecek yorumlar yap.
6. Verilen sohbet ne kadar kısa olursa olsun, "sonMesajEtkisi" MUTLAKA analiz et ve değerlerini doldur.
7. ASLA boş veya "null" değer döndürme ve ASLA "sohbet_genel_havasi" gibi bir alanda "sohbet analizi için yeterli içerik yok" değeri KULLANMA!

ZORUNLU JSON ÇIKTI FORMATI:
{
  "sohbetGenelHavasi": "Soğuk",
  "genelYorum": "Bu sohbette tam bir soğukluk var. Karşındaki kişi ilgi göstermiyor ve sen fazla ısrarcı davranıyorsun. Biraz kendine saygın olsun.",
  "sonMesajTonu": "Umursamaz",
  "sonMesajEtkisi": {
    "sempatik": 10,
    "kararsız": 25,
    "olumsuz": 65
  },
  "direktYorum": "Karşındakine bu kadar yalvarman acınası görünüyor. Biraz daha özgüvenli ol ve sürekli onun peşinden koşma. Kendini bu kadar küçük düşürme!",
  "cevapOnerileri": [
    "Böyle mesajlara cevap vermeyi bırak, ilgisizliği açıkça belli.",
    "Kendine saygın olsun, sürekli çabalama.",
    "Daha net ve özgüvenli bir tavır takın, kendini bu kadar küçültme."
  ]
}

KRİTİK UYARI: 
- Cevabında ASLA 'yeterli içerik yok', 'belirlenemedi', 'analiz edilemedi' gibi ifadeler kullanma.
- Cevabını SADECE ve SADECE yukarıdaki JSON formatında ver, başka hiçbir açıklama ekleme.
- ÇOK SERT ve ELEŞTİREL yorumlar yap, mümkün olduğunca nazik olmaktan kaçın.
- SonMesajEtkisi değerlerinin toplamı MUTLAKA 100 olmalı. 
- "direktYorum" alanı mümkün olduğunca SERT ve ELEŞTİREL olmalı!
''';

      // Gemini API'sine istek gönder
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
          'maxOutputTokens': _geminiMaxTokens,
          'topK': 40,
          'topP': 0.95,
        }
      });
      
      _logger.d('Mesaj koçu API isteği: ${_geminiApiUrl.substring(0, 50)}...');
      
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
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
        
        // JSON çıktısını ayıklama - sadece JSON kısmını al
        String jsonText = aiContent;
        
        // Eğer yanıt JSON dışında başka metin içeriyorsa, sadece JSON kısmını al
        // JSON başlangıç ve bitişini bul
        final jsonStartIndex = jsonText.indexOf('{');
        final jsonEndIndex = jsonText.lastIndexOf('}') + 1;
        
        if (jsonStartIndex != -1 && jsonEndIndex != -1 && jsonEndIndex > jsonStartIndex) {
          jsonText = jsonText.substring(jsonStartIndex, jsonEndIndex);
        } else {
          _logger.e('Mesaj koçu: Geçerli JSON yanıtı bulunamadı');
          return null;
        }
        
        try {
          // JSON'ı ayrıştır
          final Map<String, dynamic> analizJson = jsonDecode(jsonText);
          _logger.d('Mesaj koçu: JSON başarıyla ayrıştırıldı');
          
          // API'den gelen bilgilerle model oluştur
          return MessageCoachAnalysis.from({
            // Mevcut "boş" analiz alanları - bunlar kullanılmayacak
            'iliskiTipi': 'Belirlenmedi',
            'analiz': isImage ? 'Görsel sohbet analizi' : 'Sohbet analizi',
            'gucluYonler': '',
            'oneriler': [],
            'etki': {'Sempatik': 50, 'Kararsız': 30, 'Olumsuz': 20},
            
            // Gerçekten kullanacağımız alanlar
            'sohbetGenelHavasi': analizJson['sohbetGenelHavasi'],
            'genelYorum': analizJson['genelYorum'],
            'sonMesajTonu': analizJson['sonMesajTonu'],
            'sonMesajEtkisi': analizJson['sonMesajEtkisi'],
            'direktYorum': analizJson['direktYorum'],
            'cevapOnerileri': analizJson['cevapOnerileri'],
          });
          
        } catch (jsonError) {
          _logger.e('Mesaj koçu: JSON ayrıştırma hatası', jsonError);
          return null;
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Mesaj koçu analiz hatası', e);
      return null;
    }
  }
  
  // Görselden çıkarılmış OCR metnini sohbet formatına dönüştüren yardımcı fonksiyon
  String _preprocessImageText(String ocrText) {
    // OCR ile çıkarılan metinde belirli patternleri arayarak sohbeti bulma
    String processedText = ocrText;
    
    // Görselden alınan metinde "---- Görüntüden çıkarılan metin ----" veya benzer ifadeler varsa temizle
    final List<String> cleanupPatterns = [
      r'---- Görüntüden çıkarılan metin ----',
      r'---- Çıkarılan metin sonu ----',
      r'OCR sonucu:',
      r'Görüntü analizi sonucu:',
      r'Resimden elde edilen metin:',
    ];
    
    for (final pattern in cleanupPatterns) {
      processedText = processedText.replaceAll(RegExp(pattern), '');
    }
    
    // Gereksiz boşlukları ve satırları temizle
    processedText = processedText.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    // OCR servisinden gelen mesajlar artık [Kullanıcı: ...] veya [Partner: ...] formatında olacak
    // Bu metni doğrudan kullanabiliriz
    
    // Hata mesajlarını kontrol et
    if (processedText.contains("[Görüntüden metin çıkarılamadı]") || 
        processedText.contains("metin bulunamadı") || 
        processedText.contains("tespit edilemedi")) {
      _logger.w("OCR hatası veya metin bulunamadı");
      return "OCR işleminde sohbet metni çıkarılamadı.";
    }
    
    return processedText;
  }

  // İlişki durumu analizi yapma
  Future<Map<String, dynamic>> iliskiDurumuAnaliziYap(String userId, Map<String, dynamic> analizVerileri) async {
    _logger.i('İlişki durumu analizi yapılıyor', analizVerileri);
    
    try {
      // API anahtarını kontrol et
      if (_geminiApiKey.isEmpty) {
        return {'error': 'API anahtarı bulunamadı'};
      }

      // Analiz verileri temel kontrolü
      if (analizVerileri.isEmpty) {
        return {'error': 'Analiz verileri boş olamaz'};
      }

      // API isteği için veri hazırlama
      final messageText = 'İlişki analizi: ${analizVerileri.toString()}';
      
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': '''
İlişki koçu olarak, aşağıdaki mesaj içeriğine, duygulara, niyete ve tona dayanarak ilişki analizi yap.
Bu analizde şu kategorilerde 0-100 arası puanlar vermen gerekiyor (100 en iyi):
- güven
- destek
- iletişim
- uyum
- saygı

Bu temelde ilişki uyumunu %0-100 olarak belirle ve beş adet kişiselleştirilmiş tavsiye ver.

Yanıtını aşağıdaki JSON formatında ver, başka ekleme yapma:
{
  "iliskiPuani": (0-100 arası puan),
  "kategoriPuanlari": {
    "guven": (0-100 arası puan),
    "destek": (0-100 arası puan),
    "iletisim": (0-100 arası puan),
    "uyum": (0-100 arası puan),
    "saygi": (0-100 arası puan)
  },
  "kisiselestirilmisTavsiyeler": ["tavsiye 1", "tavsiye 2", "tavsiye 3", "tavsiye 4", "tavsiye 5"],
  "mesajYorumu": "mesaj hakkında kısa yorum"
}

Mesaj detayları: $messageText
'''
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': _geminiMaxTokens
          }
        }),
      );
      
      _logger.d('API yanıtı - status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null) {
          _logger.e('AI yanıtı boş veya beklenen formatta değil', data);
          return _getDefaultRelationshipAnalysis();
        }
        
        _logger.d('AI yanıt metni: $aiContent');
        
        // JSON yanıtını ayrıştır
        try {
          Map<String, dynamic>? jsonResponse = _parseJsonFromText(aiContent);
          
          if (jsonResponse != null) {
            // Zorunlu kategorilerin varlığını kontrol et - eksik varsa ekle
            if (!jsonResponse.containsKey('kategoriPuanlari') || jsonResponse['kategoriPuanlari'] is! Map) {
              jsonResponse['kategoriPuanlari'] = {
                'guven': 60,
                'destek': 60,
                'iletisim': 60,
                'uyum': 60,
                'saygi': 60
              };
            } else {
              // kategoriPuanlari var ama zorunlu kategoriler eksik olabilir - kontrol edip ekleyelim
              Map<String, dynamic> kategoriler = jsonResponse['kategoriPuanlari'];
              
              // Zorunlu kategorileri kontrol et ve eksikleri ekle
              final zorunluKategoriler = ['guven', 'destek', 'iletisim', 'uyum', 'saygi'];
              for (final kategori in zorunluKategoriler) {
                if (!kategoriler.containsKey(kategori)) {
                  kategoriler[kategori] = 60; // Varsayılan değer
                }
              }
            }
            
            // İlişki puanı eksikse ekle
            if (!jsonResponse.containsKey('iliskiPuani') || 
                jsonResponse['iliskiPuani'] == null || 
                jsonResponse['iliskiPuani'] is! num) {
              
              // Kategori puanlarından ortalama hesapla
              if (jsonResponse.containsKey('kategoriPuanlari') && jsonResponse['kategoriPuanlari'] is Map) {
                double toplam = 0;
                int sayac = 0;
                (jsonResponse['kategoriPuanlari'] as Map).forEach((key, value) {
                  if (value is num) {
                    toplam += value.toDouble();
                    sayac++;
                  }
                });
                
                if (sayac > 0) {
                  jsonResponse['iliskiPuani'] = (toplam / sayac).round();
                } else {
                  jsonResponse['iliskiPuani'] = 60;
                }
              } else {
                jsonResponse['iliskiPuani'] = 60;
              }
            }
            
            // Kişiselleştirilmiş tavsiyeler eksikse ekle 
            if (!jsonResponse.containsKey('kisiselestirilmisTavsiyeler') || 
                jsonResponse['kisiselestirilmisTavsiyeler'] is! List ||
                (jsonResponse['kisiselestirilmisTavsiyeler'] as List).isEmpty) {
              
              jsonResponse['kisiselestirilmisTavsiyeler'] = [
                'İletişim becerilerinizi geliştirin, daha açık ve dürüst konuşun.',
                'Birbirinize destek olun ve zorluklarda yanında olduğunuzu hissettirin.',
                'Güven inşa etmek için sözünüzde durun ve tutarlı davranın.',
                'Saygılı davranın ve birbirinizin sınırlarına özen gösterin.',
                'Düzenli olarak birlikte kaliteli zaman geçirin ve anılar biriktirin.'
              ];
            }
            
            // İlişki tarihini ekle
            jsonResponse['tarih'] = DateTime.now().toIso8601String();
            
            return jsonResponse;
          } else {
            _logger.e('Geçerli JSON yanıtı alınamadı');
            return _getDefaultRelationshipAnalysis();
          }
        } catch (e) {
          _logger.e('JSON ayrıştırma hatası', e);
          return _getDefaultRelationshipAnalysis();
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return _getDefaultRelationshipAnalysis();
      }
    } catch (e) {
      _logger.e('İlişki durumu analizi hatası', e);
      return _getDefaultRelationshipAnalysis();
    }
  }
  
  // Varsayılan ilişki analizi sonucu
  Map<String, dynamic> _getDefaultRelationshipAnalysis() {
    return {
      'iliskiPuani': 60,
      'kategoriPuanlari': {
        'guven': 60,
        'destek': 60,
        'iletisim': 60,
        'uyum': 60,
        'saygi': 60
      },
      'kisiselestirilmisTavsiyeler': [
        'İletişim becerilerinizi geliştirin, daha açık ve dürüst konuşun.',
        'Birbirinize destek olun ve zorluklarda yanında olduğunuzu hissettirin.',
        'Güven inşa etmek için sözünüzde durun ve tutarlı davranın.',
        'Saygılı davranın ve birbirinizin sınırlarına özen gösterin.',
        'Düzenli olarak birlikte kaliteli zaman geçirin ve anılar biriktirin.'
      ],
      'mesajYorumu': 'İlişkinizde gelişime açık alanlar bulunuyor. Yukarıdaki tavsiyeleri uygulayarak ilişkinizi güçlendirebilirsiniz.',
      'tarih': DateTime.now().toIso8601String()
    };
  }

  // Kişiselleştirilmiş tavsiyeler oluşturma
  Future<List<String>> kisisellestirilmisTavsiyelerOlustur(
    int iliskiPuani,
    Map<String, int> kategoriPuanlari,
    Map<String, dynamic> kullaniciVerileri,
  ) async {
    _logger.i('Kişiselleştirilmiş tavsiyeler oluşturuluyor');
    
    try {
      // API anahtarını kontrol et
      if (_geminiApiKey.isEmpty) {
        return _getVarsayilanTavsiyeler();
      }

      // En düşük puana sahip kategorileri bul (iyileştirilmesi gereken kategoriler)
      List<MapEntry<String, int>> siralanmisKategoriler = kategoriPuanlari.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      // Kategori isimleri Türkçe dilinde formatlayalım
      Map<String, String> kategoriIsimleriTurkce = {
        'guven': 'güven',
        'destek': 'destek',
        'iletisim': 'iletişim',
        'uyum': 'uyum',
        'saygi': 'saygı',
      };
      
      // API isteği için veri hazırlama
      final promptText = '''
İlişki koçu olarak görevin, kullanıcının ilişki puanı ve kategori puanlarına dayanarak kişiselleştirilmiş tavsiyeler oluşturmak.
TAM OLARAK 5 adet kısa, uygulanabilir ve etkileyici tavsiye oluştur. Tavsiyeler doğrudan "sen" diliyle yazılmalı.
Yanıtını sadece tavsiye listesi olarak ver, JSON formatı kullanma, başka açıklama ekleme.

İlişki puanı: $iliskiPuani (0-100 arası, yüksek puan iyi)
Kategori puanları: $kategoriPuanlari (0-100 arası, yüksek puan iyi)

Özellikle aşağıdaki kategorilere odaklan (düşük puan alan kategoriler öncelikle iyileştirilmeli):
${siralanmisKategoriler.take(2).map((e) => '- ${kategoriIsimleriTurkce[e.key] ?? e.key}: ${e.value} puan').join('\n')}

Her tavsiye, belirli bir kategoriyi iyileştirmeye yönelik olmalı (güven, saygı, iletişim, uyum, destek).
Tavsiyeler pratik, uygulanabilir ve ilişki için faydalı olmalı.
''';

      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': promptText
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1024
          }
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        try {
          // API yanıtını al
          final String? text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          
          if (text == null || text.isEmpty) {
            _logger.w('API yanıtı boş, varsayılan tavsiyeler döndürülüyor');
            return _getVarsayilanTavsiyeler();
          }
          
          // Satır satır ayır ve boş olmayan ve numaralandırma içermeyen satırları al
          final tavsiyeler = text
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty && !line.startsWith('---') && !line.startsWith('###'))
              .map((line) {
                // Başındaki numaralandırmayı veya madde imlerini kaldır
                return line.replaceAll(RegExp(r'^[0-9]+[.)]\s*|^[-*•]\s*'), '');
              })
              .toList();
          
          // Tavsiye sayısını kontrol et ve gerekirse tamamla
          if (tavsiyeler.isEmpty) {
            return _getVarsayilanTavsiyeler();
          } else if (tavsiyeler.length < 5) {
            // Eksik tavsiyeleri varsayılan tavsiyelerle tamamla
            final List<String> varsayilanTavsiyeler = _getVarsayilanTavsiyeler();
            final List<String> eksikTavsiyeler = varsayilanTavsiyeler.take(5 - tavsiyeler.length).toList();
            return [...tavsiyeler, ...eksikTavsiyeler];
          } else {
            // Fazla tavsiye varsa, ilk 5'ini al
            return tavsiyeler.take(5).toList();
          }
        } catch (e) {
          _logger.e('Tavsiye ayrıştırma hatası: $e');
          return _getVarsayilanTavsiyeler();
        }
      } else {
        _logger.e('Tavsiye API hatası: ${response.statusCode}');
        return _getVarsayilanTavsiyeler();
      }
    } catch (e) {
      _logger.e('Tavsiye oluşturma hatası: $e');
      return _getVarsayilanTavsiyeler();
    }
  }
  
  // Varsayılan tavsiyeler listesi
  List<String> _getVarsayilanTavsiyeler() {
    return [
      'Birbirinize açık ve dürüst bir şekilde iletişim kurun, düşüncelerinizi ifade edin.',
      'Karşılıklı güveni artırmak için sözünüzde durun ve tutarlı davranın.',
      'Birbirinizin sınırlarına saygı gösterin ve kişisel alanına değer verin.',
      'Zor zamanlarda destek olun ve yanında olduğunuzu hissettirin.',
      'Düzenli olarak birlikte kaliteli zaman geçirin ve paylaşımlarda bulunun.',
    ];
  }

  // İlişki soruları oluşturma
  Future<List<String>> generateRelationshipQuestions() async {
    _logger.i('İlişki soruları oluşturuluyor');
    
    try {
      // API anahtarını kontrol et
      if (_geminiApiKey.isEmpty) {
        return _getFallbackQuestions();
      }

      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': '''
İlişki uzmanı olarak görevin, ilişki değerlendirmesi için 15 adet soru oluşturmak.
Sorular, ilişkinin farklı yönlerini (iletişim, güven, samimiyet, destek, uyum vb.) değerlendirmeli.
Yanıtını sadece soru listesi olarak ver, JSON formatı kullanma, başka açıklama ekleme.

ÇOK ÖNEMLİ! Sorular kesinlikle "Kesinlikle evet", "Kararsızım", "Pek sanmam" seçenekleriyle cevaplanabilecek formatta olmalı.
Açık uçlu veya yoruma dayalı sorular oluşturma. Örneğin:
- "Partnerinize tamamen güvendiğinizi düşünüyor musunuz?" (Uygun)
- "Partnerinizle ne kadar sıklıkla görüşüyorsunuz?" (Uygun değil, sayısal cevap gerektirir)
- "İlişkinizde hangi konularda sorun yaşıyorsunuz?" (Uygun değil, açık uçludur)

İlişki değerlendirmesi için 15 adet farklı konularda soru oluştur.
'''
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': _geminiMaxTokens
          }
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null || aiContent.isEmpty) {
          return _getFallbackQuestions();
        }
        
        // İçerikteki soruları satır satır ayırıp liste haline getir
        final List<String> sorular = aiContent
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) => line.replaceAll(RegExp(r'^[\d\-\.\s]+'), '').trim())
            .where((line) => line.isNotEmpty && line.endsWith('?'))
            .toList();
        
        return sorular.isNotEmpty ? sorular : _getFallbackQuestions();
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return _getFallbackQuestions();
      }
    } catch (e) {
      _logger.e('İlişki soruları oluşturma hatası', e);
      return _getFallbackQuestions();
    }
  }
  
  // Yedek sorular
  List<String> _getFallbackQuestions() {
    return [
      'Partnerinizin duygularınıza değer verdiğini düşünüyor musunuz?',
      'İlişkinizde isteklerinizi açıkça ifade edebildiğinizi hissediyor musunuz?',
      'Partnerinize tamamen güvendiğinizi söyleyebilir misiniz?',
      'İlişkinizde yeterince takdir edildiğinizi düşünüyor musunuz?',
      'Partnerinizle gelecek planlarınızın uyumlu olduğuna inanıyor musunuz?',
      'İlişkinizde kendinizi özgür hissettiğinizi düşünüyor musunuz?',
      'Partnerinizle ortak ilgi alanlarınızın yeterli olduğunu düşünüyor musunuz?',
      'İlişkinizde sorunları etkili şekilde çözebildiğinize inanıyor musunuz?',
      'Partnerinizin sizi her konuda desteklediğini hissediyor musunuz?',
      'İlişkinizde sevgi gösterme biçimlerinizin uyumlu olduğunu düşünüyor musunuz?',
      'Partnerinizle olan iletişiminizin sağlıklı olduğunu düşünüyor musunuz?',
      'İlişkinizde yeterince saygı gördüğünüzü hissediyor musunuz?',
      'Partnerinizle birlikte geçirdiğiniz zamanın yeterli olduğunu düşünüyor musunuz?',
      'İlişkinizde fedakarlıkların karşılıklı olduğuna inanıyor musunuz?',
      'Partnerinizin ailenizle ilişkilerinin iyi olduğunu düşünüyor musunuz?',
    ];
  }

  // Sohbet verisini analiz etme
  Future<List<Map<String, String>>> analizSohbetVerisi(String sohbetMetni) async {
    _logger.i('Sohbet verisi analiz ediliyor');
    
    try {
      // API anahtarını kontrol et
      if (_geminiApiKey.isEmpty) {
        return [{'error': 'API anahtarı bulunamadı'}];
      }

      // Metin çok uzunsa kısalt
      final String kisaltilmisSohbet = sohbetMetni.length > 15000 
          ? "${sohbetMetni.substring(0, 15000)}... (sohbet kesildi)"
          : sohbetMetni;

      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': '''
Görevin, verilen sohbet metnini analiz edip "Spotify Wrapped" tarzında ilginç ve eğlenceli içgörüler çıkarmak.
Aşağıdaki kategorilerde 6 farklı içgörü oluştur:
1. En sık kullanılan kelimeler/ifadeler
2. Duygusal ton analizi
3. Konuşma tarzı/üslubu
4. İlginç bir mesajlaşma alışkanlığı
5. İlişki dinamiği (varsa)
6. Eğlenceli bir istatistik

Her içgörü için aşağıdaki JSON formatında bir yanıt oluştur:
[
  {
    "title": "İçgörü başlığı 1",
    "comment": "İçgörü açıklaması 1"
  },
  {
    "title": "İçgörü başlığı 2",
    "comment": "İçgörü açıklaması 2"
  },
  ...
]

Başlıklar kısa ve çarpıcı, yorumlar ise detaylı ve eğlenceli olmalı. İstatistikler ve yorumlar, Spotify Wrapped stilinde esprili ve kişiselleştirilmiş bir dilde yazılmalı.

İşte analiz edilecek sohbet metni: 
$kisaltilmisSohbet
'''
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.8,
            'maxOutputTokens': _geminiMaxTokens
          }
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null || aiContent.isEmpty) {
          return [{'title': 'Analiz Hatası', 'comment': 'Sohbet analiz edilemedi.'}];
        }
        
        // JSON yanıtını ayrıştır
        try {
          final jsonData = _parseJsonFromText(aiContent);
          if (jsonData != null && jsonData is List) {
            return List<Map<String, String>>.from(
              (jsonData).map((item) {
                if (item is Map<String, dynamic>) {
                  return {
                    'title': (item['title'] ?? 'Başlık yok').toString(),
                    'comment': (item['comment'] ?? 'Yorum yok').toString(),
                  };
                }
                return {'title': 'Hatalı Format', 'comment': 'Geçersiz analiz verisi'};
              })
            );
          } else {
            // JSON ayrıştılamazsa varsayılan değer döndür
            return [{'title': 'Analiz Hatası', 'comment': 'Sohbet verileri ayrıştırılamadı.'}];
          }
        } catch (e) {
          _logger.e('Sohbet analizi JSON ayrıştırma hatası', e);
          return [{'title': 'Analiz Hatası', 'comment': 'Sohbet verileri ayrıştırılamadı: $e'}];
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return [{'title': 'API Hatası', 'comment': 'API yanıtı alınamadı: ${response.statusCode}'}];
      }
    } catch (e) {
      _logger.e('Sohbet analizi hatası', e);
      return [{'title': 'Beklenmeyen Hata', 'comment': 'Sohbet analiz edilirken bir hata oluştu: $e'}];
    }
  }

  // cevapOnerileri'nden liste oluşturmak için yardımcı metod
  List<String> _extractCevapOnerileri(dynamic rawOnerileri) {
    List<String> oneriler = [];
    
    if (rawOnerileri is List) {
      for (var oneri in rawOnerileri) {
        if (oneri != null && oneri.toString().trim().isNotEmpty) {
          oneriler.add(oneri.toString());
        }
      }
    } else if (rawOnerileri is String) {
      try {
        // Virgülle ayrılmış bir liste olabilir
        final List<String> parcalanmisTavsiyeler = rawOnerileri.split(',');
        for (String tavsiye in parcalanmisTavsiyeler) {
          if (tavsiye.trim().isNotEmpty) {
            oneriler.add(tavsiye.trim());
          }
        }
      } catch (_) {
        // String'i doğrudan bir tavsiye olarak ekle
        if (rawOnerileri.trim().isNotEmpty) {
          oneriler.add(rawOnerileri);
        }
      }
    }
    
    // Boşsa varsayılan değerleri kullan
    if (oneriler.isEmpty) {
      oneriler = ['Daha açık ifadeler kullan.', 'Mesajlarını kısa tut.'];
    }
    
    return oneriler;
  }
  
  // İlk cevap önerisini almak için yardımcı metod
  List<String> _getCevapOnerileri(dynamic rawOnerileri) {
    if (rawOnerileri is List && rawOnerileri.isNotEmpty) {
      List<String> onerileri = [];
      for (var oneri in rawOnerileri) {
        if (oneri != null && oneri.toString().trim().isNotEmpty) {
          onerileri.add(oneri.toString());
        }
      }
      return onerileri.isNotEmpty ? onerileri : _getVarsayilanCevapOnerileri();
    } else if (rawOnerileri is String && rawOnerileri.trim().isNotEmpty) {
      try {
        // Virgülle ayrılmış bir liste olabilir, ilkini al
        final List<String> parcalanmisTavsiyeler = rawOnerileri.split(',');
        if (parcalanmisTavsiyeler.isNotEmpty) {
          return parcalanmisTavsiyeler
              .where((tavsiye) => tavsiye.trim().isNotEmpty)
              .map((tavsiye) => tavsiye.trim())
              .toList();
        }
      } catch (_) {
        // String'i doğrudan kullan
        return [rawOnerileri];
      }
    }
    
    // Varsayılan değerler
    return _getVarsayilanCevapOnerileri();
  }
  
  // Varsayılan cevap önerileri
  List<String> _getVarsayilanCevapOnerileri() {
    return [
      'Düşüncelerimi açıkça ifade etmek istiyorum.',
      'Seninle konuşmak benim için önemli, ne düşündüğünü merak ediyorum.',
      'Anladım.'
    ];
  }

  // JSON metni manuel olarak ayrıştırma girişimi
  Map<String, dynamic> _manualParseJson(String text) {
    final Map<String, dynamic> result = {};
    
    // Temel alanları bulmaya çalış
    final sohbetGenelHavasiMatch = RegExp(r'"sohbetGenelHavasi"\s*:\s*"([^"]*)"').firstMatch(text);
    final genelYorumMatch = RegExp(r'"genelYorum"\s*:\s*"([^"]*)"').firstMatch(text);
    final sonMesajTonuMatch = RegExp(r'"sonMesajTonu"\s*:\s*"([^"]*)"').firstMatch(text);
    final direktYorumMatch = RegExp(r'"direktYorum"\s*:\s*"([^"]*)"').firstMatch(text);
    
    if (sohbetGenelHavasiMatch?.group(1) != null) {
      result['sohbetGenelHavasi'] = sohbetGenelHavasiMatch!.group(1);
    }
    
    if (genelYorumMatch?.group(1) != null) {
      result['genelYorum'] = genelYorumMatch!.group(1);
    }
    
    if (sonMesajTonuMatch?.group(1) != null) {
      result['sonMesajTonu'] = sonMesajTonuMatch!.group(1);
    }
    
    if (direktYorumMatch?.group(1) != null) {
      result['direktYorum'] = direktYorumMatch!.group(1);
    }
    
    // Varsayılan değerler ekle
    if (result.isEmpty) {
      result['sohbetGenelHavasi'] = 'Samimi';
      result['genelYorum'] = 'Metinde sohbet analizi bulunamadı.';
      result['sonMesajTonu'] = 'Nötr';
      result['direktYorum'] = 'İletişim tarzını daha net hale getirmelisin.';
      result['sonMesajEtkisi'] = {'sempatik': 33, 'kararsız': 33, 'olumsuz': 34};
    }
    
    return result;
  }

  // Sert yorumlar ekleyen metot
  void sertYorumlarEkle(Map<String, dynamic> jsonMap) {
    if (jsonMap.containsKey('direktYorum')) {
      String direktYorum = jsonMap['direktYorum'] as String;
      
      // Eğer yorum yeterince sert değilse
      if (!direktYorum.contains('ayrıl') && 
          !direktYorum.contains('boşver') && 
          !direktYorum.contains('vakit kaybetme') &&
          !direktYorum.contains('sen ')) {
        
        // Rastgele sert yorumlardan birini seç
        final sertYorumlar = [
          "Sen çok fazla mesaj atıyorsun, yavaşla biraz. Bu kadar yüzsüz olma.",
          "Vakit kaybetme ayrıl knk, bu ilişki yürümez.",
          "Bu kişi seni takmıyor bence, başka kapıya.",
          "Sen hiç mesajlarını okumuyorsun değil mi? Çok soğuk duruyorsun.",
          "Şaka dozun sıfır, biraz espri katsan mı acaba?",
          "Sana açık konuşayım, çok sıkıcı konuşuyorsun.",
          "Bu mesajlaşma stilinle kimseyi etkileyemezsin.",
          "Ya bu kişinin ilgisi yok ya da başka birini düşünüyor, fark etmiyor musun?",
          "Sen bu ilişkide çok çabalıyorsun ama karşı taraf aynı çabayı göstermiyor. Boşuna uğraşma.",
          "Mesajların okunmadan geçilecek türden, daha dikkat çekici olmalısın.",
          "Yazma tarzın bir robot gibi, biraz insani ol.",
          "Resmen sohbeti bitirme çaban var gibi, böyle mesaj mı atılır?"
        ];
        
        int randomIndex = Random().nextInt(sertYorumlar.length);
        jsonMap['direktYorum'] = sertYorumlar[randomIndex];
      }
    }
    
    // Cevap önerilerini kontrol et ve güncelle
    if (jsonMap.containsKey('cevapOnerileri') && jsonMap['cevapOnerileri'] is List) {
      List<dynamic> oneriler = jsonMap['cevapOnerileri'] as List;
      
      if (oneriler.isNotEmpty) {
        // Önerilerin her birini kontrol et ve eğer çok kibarlasa sertleştir
        for (int i = 0; i < oneriler.length; i++) {
          String oneri = oneriler[i] as String;
          
          if (!oneri.contains('direkt') && 
              !oneri.contains('açık') && 
              !oneri.contains('net')) {
            
            // Rastgele sert cevap önerilerinden birini seç
            final sertOneriler = [
              "Bak sana net söylüyorum, böyle devam ederse aramızdaki her şey biter.",
              "Açık konuşmak gerekirse, bu davranışların beni çok rahatsız ediyor.",
              "Direkt söyleyeyim, böyle mesajlaşmak istemiyorum.",
              "Seninle konuşurken kendimi iyi hissetmiyorum, biraz düşünmem gerek.",
              "Bu konuşmanın bir yere varacağını sanmıyorum."
            ];
            
            int randomIndex = Random().nextInt(sertOneriler.length);
            oneriler[i] = sertOneriler[randomIndex];
          }
        }
      }
    }
  }

  // Soru ve cevapları metin formatında hazırla
  String _buildQuestionAnswersText(List<String> answers) {
    // Güvenli bir şekilde cevaplara eriş (yeterli eleman olduğunu kontrol et)
    if (answers.isEmpty) {
      return "Henüz yanıt yok.";
    }
    
    StringBuffer buffer = StringBuffer();
    
    for (int i = 0; i < answers.length; i++) {
      if (answers[i].isNotEmpty) {
        buffer.writeln("Soru ${i+1}: ${_getFallbackQuestions().length > i ? _getFallbackQuestions()[i] : 'Soru $i'}");
        buffer.writeln("Yanıt: ${answers[i]}");
        buffer.writeln();
      }
    }
    
    return buffer.toString();
  }

  // Sadece açıklama ile mesaj analizi (görsel olmadan)
  Future<MessageCoachAnalysis?> sadeceMesajAnalizeEt(String aciklama) async {
    try {
      _logger.i('Sadece açıklama analizi başlatılıyor...');
      
      // Açıklama içeriğini kontrol etme
      if (aciklama.trim().isEmpty) {
        _logger.w('Boş açıklama içeriği, analiz yapılamıyor');
        return null;
      }
      
      // API anahtarını kontrol et ve tam URL oluştur
      String apiUrl;
      try {
        apiUrl = _getApiUrl();
      } catch (apiError) {
        _logger.e('API URL oluşturulurken hata: $apiError');
        return null;
      }
      
      // Prompt oluşturma
      final prompt = '''
      Kullanıcı mesaj koçu sayfasında bir sohbet açıklaması gönderdi.
      Bu açıklama, bir sohbet içeriği olmadan, kullanıcının "ne yazmalıyım?" veya "şu mesaja ne cevap vermeliyim?" gibi sorgularını içeriyor.
      
      Kullanıcının açıklaması:
      ```
      $aciklama
      ```

      ÖNEMLİ: Yanıtın doğrudan kullanıcıya hitap eden bir şekilde olmalı. "Kullanıcı şunu yapmalı" veya "Karşı taraf böyle düşünüyor" gibi ÜÇÜNCÜ ŞAHIS ANLATIMI KULLANMA. 
      Bunun yerine "Mesajlarında şunu görebiliyorum", "Bu durumda şunları yazabilirsin", "Şu mesajı gönderirsen..." gibi DOĞRUDAN KULLANICIYA HİTAP ET.
      
      Görevin:
      1. Kullanıcının açıklamasını analiz et
      2. Doğrudan kullanıcıya tavsiyelerde bulun - her zaman SEN dil kullanımıyla hitap et
      3. Kullanıcının isteğine yönelik alternatif mesaj önerileri sun
      4. Olası cevapları tahmin et (1 olumlu, 1 olumsuz)
      
      Yanıtın dobra, yer yer alaycı ama mantıklı olmalı. Sert eleştiriler yapabilirsin ama seviyeyi koru.
      
      Lütfen aşağıdaki JSON formatında yanıt ver:
      {
        "sohbetGenelHavasi": "Analiz", 
        "genelYorum": "(Açıklamaya göre kısa ve dobra bir değerlendirme)",
        "sonMesajTonu": "(Yazılmak istenen mesajın olası tonu)",
        "sonMesajEtkisi": {
          "sempatik": X,
          "kararsız": Y,
          "olumsuz": Z
        },
        "direktYorum": "(Kullanıcıya doğrudan hitap eden açık ve dobra tavsiye)",
        "cevapOnerileri": [
          "Öneri 1",
          "Öneri 2",
          "Öneri 3"
        ],
        "olumluCevapTahmini": "Karşı tarafın olumlu yanıt vermesi durumunda...",
        "olumsuzCevapTahmini": "Karşı tarafın olumsuz yanıt vermesi durumunda..."
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
      
      _logger.d('Sadece açıklama analizi API isteği gönderiliyor');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
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
          // JSON içeriğini çıkar
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
            // JSON düzeltmeyi dene
            final cleanedJsonStr = _jsonuDuzelt(jsonStr);
            try {
              analysisData = jsonDecode(cleanedJsonStr);
            } catch (e) {
              _logger.e('Temizlenmiş JSON dahi decode edilemedi: $e');
              return null;
            }
          }
          
          // Eksik alanları ekle
          if (!analysisData.containsKey('olumluCevapTahmini')) {
            analysisData['olumluCevapTahmini'] = "Harika! Bu çok iyi bir mesaj. Devam edelim.";
          }
          
          if (!analysisData.containsKey('olumsuzCevapTahmini')) {
            analysisData['olumsuzCevapTahmini'] = "Şu an müsait değilim, sonra konuşalım.";
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
      _logger.e('Sadece açıklama analizi hatası', e);
      return null;
    }
  }
  
  // Görsel ve açıklama ile mesaj analizi
  Future<MessageCoachAnalysis?> gorselVeAciklamaAnalizeEt(File gorsel, String aciklama) async {
    try {
      _logger.i('Görsel ve açıklama ile mesaj analizi başlatılıyor...');
      
      // Açıklama içeriğini kontrol etme
      if (aciklama.trim().isEmpty) {
        _logger.w('Boş açıklama içeriği, analiz yapılamıyor');
        return null;
      }
      
      // Analiz talebi kontrolü
      if (_analizTalebiIceriyorMu(aciklama)) {
        _logger.w('Açıklama analiz talebi içeriyor, özel yanıt gönderiliyor');
        return _ozelAnalizYanitiOlustur(aciklama);
      }
      
      // Görsel boyutu kontrolü
      final gorselBoyutu = await gorsel.length();
      if (gorselBoyutu > 5 * 1024 * 1024) { // 5 MB
        _logger.w('Görsel boyutu çok büyük (${gorselBoyutu / (1024 * 1024)} MB). Analiz yapılamıyor...');
        return null;
      }
      
      // API anahtarını kontrol et ve tam URL oluştur
      String apiUrl;
      try {
        apiUrl = _getApiUrl();
      } catch (apiError) {
        _logger.e('API URL oluşturulurken hata: $apiError');
        return null;
      }
      
      // Görsel içeriğini base64'e çevirme
      final gorselBytes = await gorsel.readAsBytes();
      final gorselBase64 = base64Encode(gorselBytes);
      
      // Prompt oluşturma
      final prompt = '''
      Aşağıda bir sohbet ekran görüntüsü yer almaktadır. Lütfen önce bu görseldeki mesajları yukarıdan aşağıya sırayla oku. Sağdaki mesajlar kullanıcıya, soldakiler karşı tarafa aittir.

      Görseldeki sohbetin bağlamını ve tarafların tavırlarını analiz et. Daha sonra aşağıdaki kullanıcı açıklamasını değerlendir:

      "Açıklama: $aciklama"
      
      ÖNEMLİ: Yanıtın doğrudan kullanıcıya hitap eden bir şekilde olmalı. "Kullanıcı şunu yapmalı" veya "Karşı taraf böyle düşünüyor" gibi ÜÇÜNCÜ ŞAHIS ANLATIMI KULLANMA. 
      Bunun yerine "Mesajlarında şunu görebiliyorum", "Bu durumda şunları yazabilirsin", "Şu mesajı gönderirsen..." gibi DOĞRUDAN KULLANICIYA HİTAP ET.
      
      Görevin:
      1. Görseldeki sohbetin mevcut durumunu değerlendirmek
      2. Kullanıcıya ne yazması gerektiğine dair mesaj önerileri sunmak
         a. "Ne yazmalıyım?" denirse, sohbetin devamı niteliğinde öneriler sunmak
         b. "Şunu yazsam olur mu?" gibi bir soru varsa, o mesajı bağlam içinde değerlendirip alternatif öneriler vermek
      3. Olası cevapları tahmin etmek (1 olumlu, 1 olumsuz)
      
      Yanıtın:
      - Dobra ve yönlendirici olmalı
      - Gerekirse hafif alaycı, mizahi olabilir
      - Sert eleştiriler yapabilir ama seviyeyi korumalı
      - Kullanıcıya gerçek bir koç gibi, doğrudan "sen" diyerek ve ikinci tekil şahıs kullanarak hitap etmeli
      
      Lütfen aşağıdaki JSON formatında yanıt ver:
      {
        "sohbetGenelHavasi": "(Görseldeki sohbetin havası)",
        "genelYorum": "(Sohbetin durumu hakkında kısa ve dobra bir değerlendirme)",
        "sonMesajTonu": "(Son mesajın tonu)",
        "sonMesajEtkisi": {
          "sempatik": X,
          "kararsız": Y,
          "olumsuz": Z
        },
        "direktYorum": "(Kullanıcıya doğrudan hitap eden açık ve dobra tavsiye)",
        "cevapOnerileri": [
          "Öneri 1",
          "Öneri 2",
          "Öneri 3"
        ],
        "olumluCevapTahmini": "Karşı tarafın olumlu yanıt vermesi durumunda...",
        "olumsuzCevapTahmini": "Karşı tarafın olumsuz yanıt vermesi durumunda..."
      }
      
      Önemli: Cevabını SADECE JSON formatında ver, başka açıklama yapma.
      Cevabında "Analiz edilemedi", "yetersiz içerik" veya benzeri ifadeler KULLANMA.
      ''';
      
      // Gemini API'ye istek gönderme
      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': prompt
              },
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': gorselBase64
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': _geminiMaxTokens
        }
      });
      
      _logger.d('Görsel ve açıklama analizi API isteği gönderiliyor');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
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
          // JSON içeriğini çıkar
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
            // JSON düzeltmeyi dene
            final cleanedJsonStr = _jsonuDuzelt(jsonStr);
            try {
              analysisData = jsonDecode(cleanedJsonStr);
            } catch (e) {
              _logger.e('Temizlenmiş JSON dahi decode edilemedi: $e');
              return null;
            }
          }
          
          // Eksik alanları ekle
          if (!analysisData.containsKey('olumluCevapTahmini')) {
            analysisData['olumluCevapTahmini'] = "Harika! Bu çok iyi bir mesaj. Devam edelim.";
          }
          
          if (!analysisData.containsKey('olumsuzCevapTahmini')) {
            analysisData['olumsuzCevapTahmini'] = "Şu an müsait değilim, sonra konuşalım.";
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
      _logger.e('Görsel ve açıklama analizi hatası', e);
      return null;
    }
  }
  
  // Analiz talebi içerip içermediğini kontrol etme
  bool _analizTalebiIceriyorMu(String aciklama) {
    final String kucukHarfliAciklama = aciklama.toLowerCase();
    final List<String> analizTalebiIbareleri = [
      'sence kim haklı',
      'beni seviyor mu',
      'ne düşünüyorsun',
      'yorumlar mısın',
      'analiz eder misin',
      'nasıl olduğunu düşünüyorsun',
      'hakkındaki fikrin nedir',
      'eleştirir misin',
      'yorum yapar mısın'
    ];
    
    for (final ibare in analizTalebiIbareleri) {
      if (kucukHarfliAciklama.contains(ibare)) {
        return true;
      }
    }
    
    return false;
  }
  
  // Özel analiz yanıtı oluşturma
  MessageCoachAnalysis _ozelAnalizYanitiOlustur(String aciklama) {
    return MessageCoachAnalysis(
      iliskiTipi: 'Belirlenmedi',
      analiz: 'Bu tarz sorular için analiz ekranını kullanmalısın.',
      gucluYonler: null,
      oneriler: [
        'Bu tarz analiz talepleri için "Analiz" bölümünü kullanmalısın.',
        'Burada yalnızca mesaj önerileri alabilirssin.',
        'İstersen nasıl mesaj yazacağın konusunda yardımcı olabilirim.'
      ],
      etki: {'uygunsuz': 100},
      yenidenYazim: null,
      strateji: null,
      karsiTarafYorumu: null,
      anlikTavsiye: null,
      sohbetGenelHavasi: 'Analiz Talebi',
      genelYorum: 'Bu tarz sorular için analiz ekranını kullanmalısın.',
      sonMesajTonu: 'Uygunsuz',
      sonMesajEtkisi: {'uygunsuz': 100},
      direktYorum: 'Bu mesaj koçu özelliği değerlendirme yapmak için değil, mesajlaşmana yardımcı olmak için tasarlandı. Analizler için lütfen doğru ekranı kullan.',
      cevapOnerileri: [
        'Mesajlaşma konusunda yardıma ihtiyacın varsa, sorunu daha açık ifade edebilir misin?',
        'Nasıl bir mesaj yazmak istediğini anlatırsan sana yardımcı olabilirim.'
      ]
    );
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
}