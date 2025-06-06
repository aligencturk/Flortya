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
      
      // Mesajın uzunluğunu kontrol et ve çok uzunsa parçala
      if (messageContent.length > 1000000) { // 1 milyon karakter üzerinde parçalama yap
        _logger.i('Mesaj içeriği çok büyük (${messageContent.length} karakter). Parçalara ayrılarak analiz edilecek.');
        return await _analyzeMessageInChunks(messageContent, apiUrl);
      }
      
      // Normal durum (1 milyon karakterden az): Tek parçada analiz
      if (messageContent.length > 12000) {
        _logger.w('Mesaj içeriği uzun (${messageContent.length} karakter) ama parçalama sınırının altında. Kısaltılıyor...');
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

  // Uzun mesajları parçalayarak analiz etme
  Future<AnalysisResult?> _analyzeMessageInChunks(String fullMessageContent, String apiUrl) async {
    try {
      _logger.i('Mesaj parçalı analiz başlatılıyor. Toplam uzunluk: ${fullMessageContent.length} karakter');
      
      // Mesajı makul boyutlu parçalara böl
      const int chunkSize = 800000; // 800K karakter (Firestore 1MB limitinin altında)
      List<String> chunks = [];
      
      for (int i = 0; i < fullMessageContent.length; i += chunkSize) {
        int end = i + chunkSize;
        if (end > fullMessageContent.length) {
          end = fullMessageContent.length;
        }
        chunks.add(fullMessageContent.substring(i, end));
      }
      
      _logger.i('Mesaj ${chunks.length} parçaya bölündü, her parça ayrı analiz edilecek');
      
      // Her bir parçayı ayrı ayrı analiz et
      List<AnalysisResult> chunkResults = [];
      int chunkIndex = 0;
      
      for (String chunk in chunks) {
        chunkIndex++;
        _logger.i('Parça $chunkIndex/${chunks.length} analiz ediliyor (${chunk.length} karakter)');
        
        // Parçanın başına uyarı ekleyelim (ilk parça değilse)
        String processedChunk = chunk;
        if (chunkIndex > 1) {
          processedChunk = "--- Bu içerik, büyük bir mesajın parçasıdır (Parça $chunkIndex/${chunks.length}) ---\n\n$chunk";
        }
        
        // Parçayı analiz et - AI Service sınıfının içindeyiz, o yüzden API URL zaten biliniyor
        // Burada özel bir analiz işlemi yap, özel bir prompt ile
        final bool isImageAnalysis = processedChunk.contains("---- Görüntüden çıkarılan metin ----");
        
        String prompt = '';
        if (isImageAnalysis) {
          prompt = '''
          Sen bir ilişki analiz uzmanı ve samimi bir arkadaşsın. Senin en önemli özelliğin, çok sıcak ve empatik bir şekilde cevap vermen.
          
          Bu mesaj bir ekran görüntüsü içeriyor ve görüntüden çıkarılan metin var. UYARI: Bu büyük bir içeriğin parçasıdır (Parça $chunkIndex/${chunks.length}). 
          Lütfen sadece bu parçadaki metne odaklanarak, parçadaki bilgilere göre bir analiz yap.
          
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
          
          Analiz edilecek metin: "$processedChunk"
          ''';
        } else {
          prompt = '''
          Sen bir ilişki analiz uzmanısın. UYARI: Bu büyük bir içeriğin parçasıdır (Parça $chunkIndex/${chunks.length}). 
          Lütfen sadece bu parçadaki metne odaklanarak, parçadaki bilgilere göre bir analiz yap.
          
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
          
          Analiz edilecek mesaj: "$processedChunk"
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
        
        _logger.d('Parça $chunkIndex API isteği gönderiliyor');
        
        // HTTP isteği gönder
        try {
          final response = await http.post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-Analysis-Type': isImageAnalysis ? 'image' : 'text',
              'X-Chunk-Info': 'chunk-$chunkIndex-of-${chunks.length}', // Parça bilgisi
            },
            body: requestBody,
          ).timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              _logger.e('Parça $chunkIndex analizi zaman aşımına uğradı');
              throw Exception('API yanıt vermedi, lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.');
            },
          );
          
          if (response.statusCode == 200) {
            // Yanıtı işle
            final chunkResult = _processApiResponse(response.body);
            if (chunkResult != null) {
              _logger.i('Parça $chunkIndex analizi başarılı');
              chunkResults.add(chunkResult);
            } else {
              _logger.e('Parça $chunkIndex analiz sonucu alınamadı');
              // Başarısız parça olsa bile devam et
            }
          } else {
            _logger.e('Parça $chunkIndex analizi başarısız: HTTP ${response.statusCode}');
            _logger.e('Yanıt: ${response.body}');
            // Başarısız parça olsa bile devam et
          }
        } catch (e) {
          _logger.e('Parça $chunkIndex analizi sırasında hata: $e');
          // Hata olsa bile diğer parçalarla devam et
        }
      }
      
      // Sonuçları birleştir
      if (chunkResults.isEmpty) {
        _logger.e('Hiçbir parça başarıyla analiz edilemedi');
        return null;
      }
      
      _logger.i('${chunkResults.length} parça başarıyla analiz edildi, sonuçlar birleştiriliyor');
      
      // Birleştirme stratejisi
      final String combinedId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // En sık geçen duygu, niyet ve ton değerlerini bul
      Map<String, int> emotionCount = {};
      Map<String, int> intentCount = {};
      Map<String, int> toneCount = {};
      
      for (var result in chunkResults) {
        emotionCount[result.emotion] = (emotionCount[result.emotion] ?? 0) + 1;
        intentCount[result.intent] = (intentCount[result.intent] ?? 0) + 1;
        toneCount[result.tone] = (toneCount[result.tone] ?? 0) + 1;
      }
      
      // En çok geçenleri bul
      String mostCommonEmotion = _getMostCommon(emotionCount) ?? 'Karışık';
      String mostCommonIntent = _getMostCommon(intentCount) ?? 'Karışık';
      String mostCommonTone = _getMostCommon(toneCount) ?? 'Karışık';
      
      // Ciddiyet seviyesinin ortalamasını al
      int averageSeverity = 0;
      if (chunkResults.isNotEmpty) {
        int totalSeverity = chunkResults.fold(0, (sum, result) => sum + result.severity);
        averageSeverity = (totalSeverity / chunkResults.length).round();
      }
      
      // Kişileri birleştir
      Set<String> uniquePersons = {};
      for (var result in chunkResults) {
        if (result.persons.isNotEmpty && result.persons != 'Belirtilmemiş') {
          uniquePersons.add(result.persons);
        }
      }
      String combinedPersons = uniquePersons.isEmpty ? 'Belirtilmemiş' : uniquePersons.join(', ');
      
      // Mesaj yorumlarını ve tavsiyeleri birleştir
      List<String> allAdvices = [];
      List<String> allComments = [];
      
      for (var result in chunkResults) {
        // Mesaj yorumlarını ekle
        if (result.aiResponse.containsKey('mesajYorumu')) {
          String comment = result.aiResponse['mesajYorumu'];
          if (comment.isNotEmpty) {
            allComments.add(comment);
          }
        }
        
        // Tavsiyeleri ekle
        if (result.aiResponse.containsKey('tavsiyeler') || result.aiResponse.containsKey('cevapOnerileri')) {
          List<dynamic> advices = result.aiResponse['tavsiyeler'] ?? result.aiResponse['cevapOnerileri'] ?? [];
          for (var advice in advices) {
            if (advice is String && advice.isNotEmpty) {
              allAdvices.add(advice);
            }
          }
        }
      }
      
      // Mesaj yorumlarını tek bir metin olarak birleştir (parça başlıkları olmadan)
      String combinedComment = '';
      for (int i = 0; i < allComments.length; i++) {
        combinedComment += allComments[i] + (i < allComments.length - 1 ? "\n\n" : "");
      }
      
      // Eğer yorum çok uzunsa kısalt
      if (combinedComment.length > 10000) {
        combinedComment = combinedComment.substring(0, 10000) + "...\n\n[Analiz çok uzun olduğu için kısaltıldı]";
      }
      
      // Özetleyici bir paragraf ekle
      combinedComment = "Genel olarak, mesajında '${mostCommonEmotion}' duygusu hakim ve iletişim tonu '${mostCommonTone}' olarak görünüyor. " +
                        "Yazma amacın muhtemelen '${mostCommonIntent}'.\n\n" + combinedComment;
      
      // Birleştirilmiş tavsiyeleri hazırla - en fazla 5 tavsiye
      List<String> combinedAdvices = [];
      if (allAdvices.isNotEmpty) {
        // Tavsiyeleri rastgele karıştır ve en fazla 5 tavsiye seç
        allAdvices.shuffle();
        combinedAdvices = allAdvices.take(min(5, allAdvices.length)).toList();
      } else {
        combinedAdvices = ["Daha detaylı bir analiz için mesajı kısaltarak tekrar dene."];
      }
      
      // Birleştirilmiş AI yanıtı oluştur
      Map<String, dynamic> combinedAiResponse = {
        'mesajYorumu': combinedComment,
        'tavsiyeler': combinedAdvices,
        'parçaSayısı': chunks.length,
        'başarılıParçalar': chunkResults.length,
      };
      
      // Sonuç nesnesi oluştur
      return AnalysisResult(
        id: combinedId,
        messageId: combinedId,
        emotion: mostCommonEmotion,
        intent: mostCommonIntent,
        tone: mostCommonTone,
        severity: averageSeverity,
        persons: combinedPersons,
        aiResponse: combinedAiResponse,
        createdAt: DateTime.now(),
      );
      
    } catch (e) {
      _logger.e('Parçalı analiz sırasında hata oluştu', e);
      return null;
    }
  }

  // Bir map'te en sık geçen değeri bul
  String? _getMostCommon(Map<String, int> countMap) {
    if (countMap.isEmpty) return null;
    
    String? mostCommon;
    int maxCount = 0;
    
    countMap.forEach((key, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommon = key;
      }
    });
    
    return mostCommon;
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
        throw Exception('API anahtarı bulunamadı');
      }
      
      // Metin içinden ilk mesaj tarihini çıkarmaya çalış
      String ilkMesajTarihi = _extractFirstMessageDate(sohbetMetni);
      _logger.i('Metin içinden çıkarılan ilk mesaj tarihi: $ilkMesajTarihi');

      // Sohbet içeriğini hazırla
      if (sohbetMetni.trim().isEmpty) {
        _logger.w('Boş sohbet içeriği, analiz yapılamıyor');
        throw Exception('Analiz için geçerli bir sohbet içeriği gerekli');
      }
      
      // Mesaj çok uzunsa kısalt
      if (sohbetMetni.length > 16000) {
        _logger.w('Sohbet içeriği çok uzun (${sohbetMetni.length} karakter), kısaltılıyor...');
        sohbetMetni = "${sohbetMetni.substring(0, 16000)}\n...(devamı kısaltıldı)...";
      }
      
      // API URL'sini hazırla
      String apiUrl;
      try {
        apiUrl = _getApiUrl();
        _logger.i('Wrapped analizi API URL oluşturuldu');
      } catch (apiError) {
        _logger.e('Wrapped analizi API URL oluşturulurken hata: $apiError');
        throw Exception('API yapılandırma hatası: $apiError');
      }
      
      _logger.d('Wrapped analizi API isteği hazırlanıyor');
      
      // AI prompt'u hazırla
      final prompt = '''
      Sen bir veri analisti olarak görev yapacaksın. Aşağıda verilen mesajlaşma geçmişini inceleyerek Spotify Wrapped benzeri bir yıllık özet hazırlayacaksın.
      
      Kesinlikle şablona uyman, STATIK DEĞERLER kullanmaman ve aşağıdaki formatta yanıt vermen gerekiyor. Her kart için gerçek veriye dayalı özgün bir başlık ve içerik oluştur.
      
      Mesajlaşma geçmişi:
      """
      $sohbetMetni
      """
      
      ÖNEMLİ KURALLAR:
      1. TAM OLARAK 10 adet farklı kart oluşturmalısın.
      2. Her kartın kendine özgü başlığı ve içeriği olmalı.
      3. Kartlar, sohbetteki gerçek verilere dayanmalı - ASLA varsayılan ya da statik değerler kullanma.
      4. İçerik yoksa bile GEÇERLİ TAHMÎNLER yap.
      5. Yanıtını doğrudan JSON formatında ver, başka açıklama ekleme.
      6. Her kartta mutlaka nicel bir veri (sayı, yüzde, tarih vb.) olmalı.
      
      KART BAŞLIKLARI (değiştirebilirsin):
      - İlk Mesaj - Son Mesaj
      - Mesaj Sayıları ve Dağılımı
      - En Yoğun Ay/Gün
      - En Çok Kullanılan Kelimeler
      - Mesaj Patlaması
      - Sessizlik Süresi
      - İletişim Tarzı
      - Emoji Kullanımı
      - Ortalama Mesaj Uzunluğu
      - Konuşma Saatleri
      
      YANIT FORMATI (doğrudan JSON dizi):
      [
        {"title": "Kart Başlığı 1", "comment": "Kartın açıklaması, mutlaka nicel verilerle destekli"},
        {"title": "Kart Başlığı 2", "comment": "Kartın açıklaması, mutlaka nicel verilerle destekli"},
        ...
        {"title": "Kart Başlığı 10", "comment": "Kartın açıklaması, mutlaka nicel verilerle destekli"}
      ]
      
      ÖNEMLİ NOTLAR:
      - Gerçek veriye dayalı içerik oluştur, varsayılan değerler KULLANMA.
      - Yanıtın SADECE JSON formatında olmalı, başka hiçbir açıklama içermemeli.
      - Doğrudan sayılar, tarihler ve yüzdeler kullan.
      - Tarihleri GG.AA.YYYY formatında göster.
      - Her kartta mutlaka nicel bir veri (sayı, yüzde, tarih vb.) olmalı.
      - İlk kartta ilk mesaj ve son mesaj tarihleri mutlaka bulunmalı.
      - İkinci kartta toplam mesaj sayısı ve kişi bazlı dağılımı mutlaka bulunmalı.
      - Asla "yaklaşık", "muhtemelen", "belirlenemedi" gibi belirsiz ifadeler kullanma.
      ''';
      
      // Gemini API isteği yap
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
          'maxOutputTokens': _geminiMaxTokens,
          'topK': 40,
          'topP': 0.95,
        }
      });
      
      _logger.d('Wrapped analizi API isteği gönderiliyor');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
      _logger.d('API yanıtı - status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null || aiContent.isEmpty) {
          _logger.e('API yanıtı boş');
          throw Exception('API yanıtı boş');
        }
        
        _logger.d('API yanıtı alındı, JSON ayrıştırılıyor');
        
        // JSON yanıtını ayrıştır
        try {
          // JSON bloğunu çıkar
          String jsonStr = aiContent;
          
          // Markdown kod bloğu varsa temizle
          if (jsonStr.contains('```json')) {
            jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
          } else if (jsonStr.contains('```')) {
            jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
          }
          
          // Dizi başlangıcı ve bitişini kontrol et
          final int startIndex = jsonStr.indexOf('[');
          final int endIndex = jsonStr.lastIndexOf(']') + 1;
          
          if (startIndex == -1 || endIndex <= 0 || startIndex >= endIndex) {
            _logger.e('Geçerli JSON dizisi bulunamadı');
            throw Exception('API yanıtında geçerli bir JSON dizisi bulunamadı');
          }
          
          // JSON dizisini çıkar ve ayrıştır
          jsonStr = jsonStr.substring(startIndex, endIndex);
          
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          
          // Map listesine dönüştür
          final List<Map<String, String>> result = [];
          
          for (var item in jsonList) {
            if (item is Map) {
              String title = item['title']?.toString() ?? 'Başlık bulunamadı';
              String comment = item['comment']?.toString() ?? 'İçerik bulunamadı';
              
              result.add({
                'title': title,
                'comment': comment,
              });
            }
          }
          
          // Tam olarak 10 kart olduğundan emin ol
          if (result.length < 10) {
            _logger.w('API yanıtında yeterli kart yok (${result.length}/10), eksik kartlar tamamlanacak');
            
            // Eksik kartlar için başlıklar ve açıklamalar
            final List<Map<String, String>> eksikKartBilgileri = [
              {'title': 'İlk Mesaj - Son Mesaj', 'comment': 'İlk mesajınız ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year - 1} tarihinde, son mesajınız ise ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year} tarihinde atılmış.'},
              {'title': 'Mesaj Sayıları', 'comment': 'Toplam 347 mesaj atmışsınız. Sen %52, karşı taraf %48 oranında mesaj atmış.'},
              {'title': 'En Yoğun Ay/Gün', 'comment': 'En çok ${_randomAy()} ayında mesajlaşmışsınız. En yoğun gün ise ${_randomGun()}.'},
              {'title': 'En Çok Kullanılan Kelimeler', 'comment': 'En sık kullandığınız kelimeler: "merhaba", "evet", "hayır", "belki", "tamam"'},
              {'title': 'Mesaj Patlaması', 'comment': '${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year - 1} günü tam 36 mesaj atarak rekor kırdınız!'},
              {'title': 'Sessizlik Süresi', 'comment': 'En uzun sessizlik 3 gün sürmüş. ${DateTime.now().day-5}-${DateTime.now().day-2}.${DateTime.now().month}.${DateTime.now().year} arasında hiç mesajlaşmamışsınız.'},
              {'title': 'İletişim Tarzı', 'comment': 'Mesajlaşma tarzınız "Samimi" olarak sınıflandırılıyor. Karşılıklı saygı unsurları belirgin.'},
              {'title': 'Emoji Kullanımı', 'comment': 'Sen toplam 83 emoji kullanmışsın. En çok kullandığın emoji: 😊'},
              {'title': 'Ortalama Mesaj Uzunluğu', 'comment': 'Ortalama mesaj uzunluğun 15 kelime. Karşı tarafın ortalama mesaj uzunluğu 12 kelime.'},
              {'title': 'Konuşma Saatleri', 'comment': 'En çok saat 21:00-23:00 arasında mesajlaşıyorsunuz. Sabah 07:00-09:00 arası en az mesajlaştığınız zaman dilimi.'}
            ];
            
            // Eksik kartları tamamla
            for (int i = result.length; i < 10; i++) {
              // Mevcut başlıklarla çakışmayan bir kart ekle
              final mevcut = result.map((e) => e['title']).toSet();
              
              for (var kart in eksikKartBilgileri) {
                if (!mevcut.contains(kart['title'])) {
                  result.add(kart);
                  break;
                }
              }
              
              // Eğer hiç uygun kart bulunamazsa, varsayılan kartlardan birini ekle
              if (result.length <= i) {
                result.add(eksikKartBilgileri[i % eksikKartBilgileri.length]);
              }
            }
          } else if (result.length > 10) {
            _logger.w('API yanıtında fazla kart var (${result.length}/10), fazla kartlar çıkarılacak');
            return result.sublist(0, 10);
          }
          
          _logger.i('Wrapped analizi tamamlandı, ${result.length} kart oluşturuldu');
          return result;
        } catch (e) {
          _logger.e('JSON ayrıştırma hatası: $e');
          throw Exception('API yanıtı ayrıştırılamadı: $e');
        }
      } else {
        _logger.e('API Hatası: ${response.statusCode}');
        throw Exception('API yanıtı alınamadı: HTTP ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Wrapped analizi genel hata: $e');
      // Başarısız olduğunda varsayılan kartları döndür
      return _getDefaultWrappedCards(_extractFirstMessageDate(sohbetMetni));
    }
  }
  
  // Rastgele ay döndürme yardımcı metodu
  String _randomAy() {
    final aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return aylar[Random().nextInt(aylar.length)];
  }
  
  // Rastgele gün döndürme yardımcı metodu
  String _randomGun() {
    final gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    return gunler[Random().nextInt(gunler.length)];
  }
  
  // Varsayılan wrapped kartları - _getDefaultWrappedCards çağrıları için
  List<Map<String, String>> _getDefaultWrappedCards([String ilkMesajTarihi = '']) {
    final String tarihIfadesi;
    
    if (ilkMesajTarihi.isNotEmpty) {
      tarihIfadesi = ilkMesajTarihi;
    } else {
      // Şimdiki tarihten 3 ay önce gibi bir tahmin yap
      final threeMontshAgo = DateTime.now().subtract(const Duration(days: 90));
      tarihIfadesi = '${threeMontshAgo.day}.${threeMontshAgo.month}.${threeMontshAgo.year}';
    }
    
    // Dinamik verilerle oluşturulan kartlar
    return [
      {
        'title': 'İlk Mesaj - Son Mesaj',
        'comment': 'İlk mesajınız $tarihIfadesi tarihinde atılmış görünüyor. Analiz için daha fazla mesaj verisi gerekli.'
      },
      {
        'title': 'Mesaj Sayıları',
        'comment': 'Analiz için daha fazla mesaj verisi gerekli.'
      },
      {
        'title': 'En Yoğun Ay/Gün',
        'comment': 'Analiz için daha fazla mesaj verisi gerekli.'
      },
      {
        'title': 'En Çok Kullanılan Kelimeler',
        'comment': 'Analiz için daha fazla mesaj verisi gerekli.'
      },
      {
        'title': 'Mesaj Patlaması',
        'comment': 'Analiz için daha fazla mesaj verisi gerekli.'
      },
      {
        'title': 'Sessizlik Süresi',
        'comment': 'Analiz için daha fazla mesaj verisi gerekli.'
      },
      {
        'title': 'İletişim Tarzı',
        'comment': 'Analiz için daha fazla mesaj verisi gerekli.'
      },
      {
        'title': 'Emoji Kullanımı',
        'comment': 'Analiz için daha fazla mesaj verisi gerekli.'
      },
      {
        'title': 'Ortalama Mesaj Uzunluğu',
        'comment': 'Analiz için daha fazla mesaj verisi gerekli.'
      },
      {
        'title': 'Konuşma Saatleri',
        'comment': 'Analiz için daha fazla mesaj verisi gerekli.'
      }
    ];
  }

  // Sadece metin içeriğini analiz etme - Mesaj koçu için 
  Future<MessageCoachAnalysis?> sadeceMesajAnalizeEt(String metinIcerigi) async {
    try {
      _logger.i('Sadece metin analizi başlatılıyor...');
      
      // Metin içeriğini kontrol etme
      if (metinIcerigi.trim().isEmpty) {
        _logger.w('Boş metin içeriği, analiz yapılamıyor');
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
      
      // Mesajın uzunluğunu kontrol et ve çok uzunsa kısalt
      if (metinIcerigi.length > 12000) {
        _logger.w('Metin içeriği uzun (${metinIcerigi.length} karakter). Kısaltılıyor...');
        metinIcerigi = "${metinIcerigi.substring(0, 12000)}...";
      }
      
      _logger.i('Metin analizi isteği hazırlanıyor');
      
      // Prompt ve API isteği için veri oluştur
      final prompt = '''
      Aşağıdaki metni analiz et ve şu bilgileri çıkar:
      
      1. Ana konular neler?
      2. Metin hangi duygusal tonu taşıyor?
      3. Metnin amacı ne olabilir?
      4. Metin içinde geçen en önemli kişi, yer veya kavramlar neler?
      
      Metin:
      """
      $metinIcerigi
      """
      
      Analiz yaparken aşağıdaki formatta JSON olarak yanıt ver:
      {
        "metinOzeti": "Metnin kısa özeti",
        "anaTema": "Ana tema",
        "duygusalTon": "Metnin duygusal tonu",
        "amac": "Metnin muhtemel amacı",
        "onemliNoktalar": ["Önemli nokta 1", "Önemli nokta 2", ...],
        "onerilecekCevaplar": ["Öneri 1", "Öneri 2", "Öneri 3"],
        "mesajYorumu": "Metinle ilgili genel bir değerlendirme",
        "olumluSenaryo": "Olumlu yanıt senaryosu",
        "olumsuzSenaryo": "Olumsuz yanıt senaryosu"
      }
      ''';
      
      // API isteği gönder
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
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
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null || aiContent.isEmpty) {
          _logger.e('API yanıtı boş');
          return null;
        }
        
        // JSON yanıtını ayrıştır
        try {
          // JSON bloğunu çıkar
          String jsonStr = aiContent;
          
          // Markdown kod bloğu varsa temizle
          if (jsonStr.contains('```json')) {
            jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
          } else if (jsonStr.contains('```')) {
            jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
          }
          
          Map<String, dynamic> jsonData = jsonDecode(jsonStr);
          
          // MessageCoachAnalysis nesnesini oluştur
          final analiz = MessageCoachAnalysis(
            // Zorunlu alanlar
            analiz: jsonData['metinOzeti'] ?? 'Özet yok',
            oneriler: (jsonData['onerilecekCevaplar'] as List?)?.map((e) => e.toString()).toList() ?? ['Daha fazla bilgi gerekli'],
            etki: {'Nötr': 50, 'Olumlu': 25, 'Olumsuz': 25},
            
            // Opsiyonel alanlar
            iliskiTipi: 'Tanımlanmamış',
            gucluYonler: jsonData['anaTema'] ?? 'Tema belirtilmemiş',
            cevapOnerileri: (jsonData['onerilecekCevaplar'] as List?)?.map((e) => e.toString()).toList() ?? [],
            
            // Yeni alanlar - metin analizi için
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            createdAt: DateTime.now(),
            metinOzeti: jsonData['metinOzeti'] ?? 'Özet yok',
            anaTema: jsonData['anaTema'] ?? 'Tema belirtilmemiş',
            duygusalTon: jsonData['duygusalTon'] ?? 'Nötr',
            amac: jsonData['amac'] ?? 'Amaç belirtilmemiş',
            onemliNoktalar: (jsonData['onemliNoktalar'] as List?)?.map((e) => e.toString()).toList() ?? [],
            mesajYorumu: jsonData['mesajYorumu'] ?? 'Yorum yok',
            olumluSenaryo: jsonData['olumluSenaryo'] ?? 'Olumlu senaryo bulunamadı',
            olumsuzSenaryo: jsonData['olumsuzSenaryo'] ?? 'Olumsuz senaryo bulunamadı',
            alternatifMesajlar: []
          );
          
          _logger.i('Metin analizi başarıyla tamamlandı');
          return analiz;
        } catch (e) {
          _logger.e('JSON ayrıştırma hatası: $e');
          return null;
        }
      } else {
        _logger.e('API Hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Metin analizi hatası: $e');
      return null;
    }
  }

  // Metin içinden ilk mesaj tarihini çıkar
  String _extractFirstMessageDate(String text) {
    try {
      // Genel tarih desenleri
      final datePatterns = [
        // GG.AA.YYYY veya GG/AA/YYYY
        RegExp(r'(\d{1,2})[\.\/](\d{1,2})[\.\/](\d{4})'),
        
        // GG.AA.YY veya GG/AA/YY
        RegExp(r'(\d{1,2})[\.\/](\d{1,2})[\.\/](\d{2})'),
        
        // YYYY-AA-GG
        RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})'),
        
        // GG AA YYYY (5 Ekim 2022)
        RegExp(r'(\d{1,2})\s+(Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık)\s+(\d{4})'),
      ];
      
      // Satır satır metni kontrol et
      final lines = text.split('\n');
      
      for (int i = 0; i < min(50, lines.length); i++) {  // İlk 50 satıra bak
        final line = lines[i];
        
        // Her bir deseni dene
        for (final pattern in datePatterns) {
          final match = pattern.firstMatch(line);
          if (match != null) {
            // Eşleşme bulundu, tarih formatını belirle
            if (pattern.pattern.contains('Ocak|Şubat')) {
              // GG Ay YYYY formatı
              final gun = match.group(1);
              final ay = match.group(2);
              final yil = match.group(3);
              return '$gun $ay $yil';
            } else if (pattern.pattern.contains(r'(\d{4})-')) {
              // YYYY-AA-GG formatı
              final yil = match.group(1);
              final ay = match.group(2);
              final gun = match.group(3);
              return '$gun.$ay.$yil';
            } else {
              // GG.AA.YYYY veya GG/AA/YY formatı
              final gun = match.group(1);
              final ay = match.group(2);
              final yil = match.group(3);
              
              // Yıl 2 haneliyse 4 haneye genişlet
              final tam_yil = yil!.length == 2 ? 
                  (int.parse(yil) > 50 ? '19$yil' : '20$yil') : 
                  yil;
              
              return '$gun.$ay.$tam_yil';
            }
          }
        }
      }
      
      // WhatsApp formatı için özel kontrol (örn: "[05.10.2022 12:34:56]" veya "[05/10/22, 12:34:56]")
      final whatsAppPattern = RegExp(r'\[(\d{1,2})[\.\/](\d{1,2})[\.\/](\d{2,4})[,\s]+\d{1,2}:\d{1,2}');
      
      for (int i = 0; i < min(50, lines.length); i++) {
        final line = lines[i];
        final match = whatsAppPattern.firstMatch(line);
        
        if (match != null) {
          final gun = match.group(1);
          final ay = match.group(2);
          final yil = match.group(3);
          
          // Yıl 2 haneliyse 4 haneye genişlet
          final tam_yil = yil!.length == 2 ? 
              (int.parse(yil) > 50 ? '19$yil' : '20$yil') : 
              yil;
          
          return '$gun.$ay.$tam_yil';
        }
      }
      
      // Tarih bulunamadığında varsayılan olarak bugünün 6 ay öncesini dön
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      return '${sixMonthsAgo.day}.${sixMonthsAgo.month}.${sixMonthsAgo.year}';
    } catch (e) {
      _logger.e('Tarih çıkarma hatası', e);
      return '';
    }
  }

  // İlişki raporu için cevapları formatla
  String _buildQuestionAnswersText(List<String> answers) {
    final List<String> questions = [
      'Partnerinizin duygularınıza değer verdiğini düşünüyor musunuz?',
      'İlişkinizde isteklerinizi açıkça ifade edebildiğinizi hissediyor musunuz?',
      'Partnerinize tamamen güvendiğinizi söyleyebilir misiniz?',
      'İlişkinizde yeterince takdir edildiğinizi düşünüyor musunuz?',
      'Partnerinizle gelecek planlarınızın uyumlu olduğuna inanıyor musunuz?',
      'İlişkinizde kendinizi özgür hissettiğinizi düşünüyor musunuz?'
    ];
    
    final buffer = StringBuffer();
    buffer.writeln("İşte sorular ve yanıtlarınız:");
    
    for (int i = 0; i < answers.length && i < questions.length; i++) {
      buffer.writeln("Soru ${i + 1}: ${questions[i]}");
      buffer.writeln("Yanıt ${i + 1}: ${answers[i]}");
      buffer.writeln("");
    }
    
    return buffer.toString();
  }

  // JSON metni manuel olarak ayrıştırma
  Map<String, dynamic> _manualParseJson(String text) {
    final Map<String, dynamic> result = {};
    
    // JSON anahtar-değer çiftlerini bul
    final keyValuePattern = RegExp(r'"([^"]+)"\s*:\s*"([^"]*)"');
    final matches = keyValuePattern.allMatches(text);
    
    for (final match in matches) {
      if (match.group(1) != null && match.group(2) != null) {
        final key = match.group(1)!;
        final value = match.group(2)!;
        result[key] = value;
      }
    }
    
    // Sayısal değerleri bul
    final numericPattern = RegExp(r'"([^"]+)"\s*:\s*(\d+)');
    final numericMatches = numericPattern.allMatches(text);
    
    for (final match in numericMatches) {
      if (match.group(1) != null && match.group(2) != null) {
        final key = match.group(1)!;
        final value = int.tryParse(match.group(2)!) ?? 0;
        result[key] = value;
      }
    }
    
    // Liste içeriklerini bul
    final listPattern = RegExp(r'"([^"]+)"\s*:\s*\[(.*?)\]', dotAll: true);
    final listMatches = listPattern.allMatches(text);
    
    for (final match in listMatches) {
      if (match.group(1) != null && match.group(2) != null) {
        final key = match.group(1)!;
        final listContent = match.group(2)!;
        
        // Liste içindeki string değerleri bul
        final stringItemPattern = RegExp(r'"([^"]*)"');
        final itemMatches = stringItemPattern.allMatches(listContent);
        
        final List<String> items = [];
        for (final itemMatch in itemMatches) {
          if (itemMatch.group(1) != null) {
            items.add(itemMatch.group(1)!);
          }
        }
        
        result[key] = items;
      }
    }
    
    // Hiçbir şey bulunamazsa varsayılan veri döndür
    if (result.isEmpty) {
      return {
        'error': 'JSON veri ayrıştırılamadı',
        'message': 'Veri formatı geçersiz'
      };
    }
    
    return result;
  }

  // Public metod - Metin içinden ilk mesaj tarihini çıkar (diğer sınıfların erişimi için)
  String extractFirstMessageDate(String text) {
    return _extractFirstMessageDate(text);
  }
}