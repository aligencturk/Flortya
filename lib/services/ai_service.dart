import 'dart:convert';
import 'dart:math';
import 'dart:io'; // File sınıfı için import eklendi
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/analysis_result_model.dart';
import '../models/message_coach_analysis.dart'; // Mesaj koçu modelini import et
import 'logger_service.dart';
import 'wrapped_service.dart';

class AiService {
  // Singleton pattern
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();
  
  final LoggerService _logger = LoggerService();
  final WrappedService _wrappedService = WrappedService();
  
  // Analiz iptal kontrolü
  bool _isAnalysisCancelled = false;
  
  // HTTP client için timeout
  static const Duration _httpTimeout = Duration(seconds: 30);
  
  // Analizi iptal etme metodu
  void cancelAnalysis() {
    _isAnalysisCancelled = true;
    _logger.i('AiService: Analiz iptal edildi');
  }
  
  // İptal durumunu kontrol etme metodu
  void _checkCancellation() {
    if (_isAnalysisCancelled) {
      _logger.i('AiService: Analiz iptal edildiği tespit edildi');
      throw Exception('Analiz kullanıcı tarafından iptal edildi');
    }
  }
  
  // İptal durumunu sıfırlama metodu
  void _resetCancellation() {
    _isAnalysisCancelled = false;
  }
  
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
      // İptal durumunu sıfırla - yeni analiz başlıyor
      _resetCancellation();
      
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
        - Metindeki baskın duyguları belirle (örnek: kızgınlık, umut, öfke, boşvermişlik, özlem...)
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
      // İptal durumunu sıfırla - yeni parçalı analiz başlıyor  
      _resetCancellation();
      
      _logger.i('Mesaj parçalı analiz başlatılıyor. Toplam uzunluk: ${fullMessageContent.length} karakter');
      
      // Mesajı akıllı parçalama ile böl
      List<String> chunks = _akilliparcalama(fullMessageContent);
      
      _logger.i('Mesaj ${chunks.length} parçaya bölündü, her parça ayrı analiz edilecek');
      
      // Her bir parçayı ayrı ayrı analiz et
      List<AnalysisResult> chunkResults = [];
      int chunkIndex = 0;
      
      for (String chunk in chunks) {
        // İptal kontrolü - her parça başında
        _checkCancellation();
        
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
          - Metindeki baskın duyguları belirle (örnek: kızgınlık, umut, öfke, boşvermişlik, özlem...)
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
        
        // İptal kontrolü - HTTP isteği öncesi
        _checkCancellation();
        
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
      
      // İptal kontrolü - sonuçları birleştirmeden önce
      _checkCancellation();
      
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
            _logger.e('API yanıtı boş, ikinci deneme yapılıyor');
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

  // Sohbet verisini analiz etme + otomatik wrapped analizi
  Future<List<Map<String, String>>> analizSohbetVerisi(String sohbetMetni) async {
    _logger.i('Sohbet verisi analiz ediliyor');
    
    // İptal durumunu sıfırla
    _resetCancellation();
    
    try {
      // İptal kontrolü
      _checkCancellation();
      
      // API anahtarını kontrol et
      if (_geminiApiKey.isEmpty) {
        throw Exception('API anahtarı bulunamadı');
      }
      
      // Sohbet içeriğini hazırla
      if (sohbetMetni.trim().isEmpty) {
        _logger.w('Boş sohbet içeriği, analiz yapılamıyor');
        throw Exception('Analiz için geçerli bir sohbet içeriği gerekli');
      }
      
      // İptal kontrolü
      _checkCancellation();
      
      List<Map<String, String>> mainAnalysisResult;
      
      // Büyük dosyaları parçalı analiz et
      if (sohbetMetni.length > 15000) {
        _logger.i('Büyük dosya tespit edildi (${sohbetMetni.length} karakter), parçalı analiz başlatılıyor');
        _checkCancellation(); // İptal kontrolü
        mainAnalysisResult = await _analizBuyukDosyaParacali(sohbetMetni);
      } else {
        // Küçük dosyalar için standart analiz
        _checkCancellation(); // İptal kontrolü
        mainAnalysisResult = await _analizStandart(sohbetMetni);
      }
      
      // İptal kontrolü
      _checkCancellation();
      
      return mainAnalysisResult;
      
    } catch (e) {
      _logger.e('Sohbet analizi hatası: $e');
      throw Exception('Analiz hatası: $e');
    }
  }

  // Büyük dosyalar için parçalı analiz - TÜM PARÇALARI ANALİZ EDER
  Future<List<Map<String, String>>> _analizBuyukDosyaParacali(String tumSohbetMetni) async {
    _logger.i('Büyük dosya parçalı analiz başlatılıyor - Toplam ${tumSohbetMetni.length} karakter');
    
    try {
      // 1. ADIM: Genel istatistikleri çıkar
      final Map<String, dynamic> genelIstatistikler = await _genelIstatistikleriCikar(tumSohbetMetni);
      _logger.i('Genel istatistikler çıkarıldı: ${genelIstatistikler.toString()}');
      
      // 2. ADIM: Dosyayı akıllı parçalama ile böl
      List<String> parcalar = _akilliparcalama(tumSohbetMetni);
      
      _logger.i('Dosya ${parcalar.length} parçaya bölündü (akıllı parçalama)');
      
      // 3. ADIM: Her parçayı analiz et
      List<Map<String, dynamic>> parcaAnalizleri = [];
      for (int i = 0; i < parcalar.length; i++) {
        // İptal kontrolü
        _checkCancellation();
        
        _logger.i('Parça ${i + 1}/${parcalar.length} analiz ediliyor');
        try {
          final parcaAnalizi = await _analizParcaDetayli(parcalar[i], i + 1, parcalar.length);
          if (parcaAnalizi != null) {
            parcaAnalizleri.add(parcaAnalizi);
            _logger.i('Parça ${i + 1} analiz tamamlandı');
          } else {
            _logger.w('Parça ${i + 1} analizi null döndü, atlanıyor');
          }
        } catch (e) {
          // İptal exception'ını yakala ve yukarı fırlat
          if (e.toString().contains('iptal')) {
            rethrow;
          }
          _logger.w('Parça ${i + 1} analiz edilemedi: $e');
          // Parse edilemeyen parçaları atla, varsayılan değer ekleme
        }
      }
      
      // 4. ADIM: Tüm parça analizlerini birleştir ve final analizi yap
      _logger.i('Tüm parça analizleri birleştiriliyor');
      return await _parcaAnalizleriBirlestir(parcaAnalizleri, genelIstatistikler);
      
    } catch (e) {
      _logger.e('Parçalı analiz hatası: $e');
      throw Exception('Parçalı analiz hatası: $e');
    }
  }

  // Genel istatistikleri çıkar - dosyanın tamamından
  Future<Map<String, dynamic>> _genelIstatistikleriCikar(String tumMetin) async {
    _logger.i('Genel istatistikler çıkarılıyor');
    
    // İlk ve son mesaj tarihlerini bul
    String ilkMesajTarihi = _extractFirstMessageDate(tumMetin);
    String sonMesajTarihi = _extractLastMessageDate(tumMetin);
    
    // Toplam mesaj sayısını hesapla
    int toplamMesajSayisi = 0;
    final List<String> satirlar = tumMetin.split('\n');
    for (final satir in satirlar) {
      // Tarih formatlarını ara (WhatsApp, Telegram, vb.)
      if (RegExp(r'\d{1,2}[\.\/-]\d{1,2}[\.\/-](\d{2}|\d{4}).*\d{1,2}:\d{2}').hasMatch(satir) ||
          RegExp(r'\[\d{1,2}:\d{2}:\d{2}\]').hasMatch(satir) ||
          RegExp(r'\d{1,2}:\d{2}\s*-').hasMatch(satir)) {
        toplamMesajSayisi++;
      }
    }
    
    // Eğer tarih bazlı bulamazsa, genel mesaj sayacı kullan
    if (toplamMesajSayisi == 0) {
      for (final satir in satirlar) {
        if (satir.trim().isNotEmpty && !satir.startsWith('[') && satir.contains(':')) {
          toplamMesajSayisi++;
        }
      }
    }
    
    // Toplam kelime sayısı
    int toplamKelimeSayisi = tumMetin.split(RegExp(r'\s+')).length;
    
    // Ortalama mesaj uzunluğu
    double ortalamaMesajUzunlugu = toplamMesajSayisi > 0 ? toplamKelimeSayisi / toplamMesajSayisi : 0;
    
    _logger.i('Genel istatistikler: Mesaj: $toplamMesajSayisi, Kelime: $toplamKelimeSayisi');
    
    return {
      'ilk_mesaj_tarihi': ilkMesajTarihi,
      'son_mesaj_tarihi': sonMesajTarihi,
      'toplam_mesaj_sayisi': toplamMesajSayisi,
      'toplam_kelime_sayisi': toplamKelimeSayisi,
      'ortalama_mesaj_uzunlugu': ortalamaMesajUzunlugu.round(),
      'toplam_karakter_sayisi': tumMetin.length,
    };
  }

  // Her parçayı detaylı analiz et
  Future<Map<String, dynamic>?> _analizParcaDetayli(String parcaMetni, int parcaNo, int toplamParca) async {
    try {
      String apiUrl = _getApiUrl();
      
      final prompt = '''
Sen bir veri analisti olarak görev yapacaksın. Verilen metin parçasını analiz edeceksin.

Bu parça $parcaNo/$toplamParca numaralı parça. TÜM PARÇALARIN ANALİZİ BİRLEŞTİRİLECEK.

Metin Parçası:
"""
$parcaMetni
"""

Aşağıdaki verileri JSON formatında çıkar:

{
  "mesaj_sayisi": (bu parçadaki mesaj sayısı),
  "kisi_adlari": ["isim1", "isim2"], (bu parçada konuşan kişi isimleri)
  "tarihler": ["tarih1", "tarih2"], (bu parçadaki tüm tarihler GG.AA.YYYY formatında)
  "saatler": ["saat1", "saat2"], (bu parçadaki mesaj saatleri HH:MM formatında)
  "kelimeler": ["kelime1", "kelime2"], (en çok kullanılan 20 kelime)
  "emoji_sayisi": (emoji sayısı),
  "uzun_mesajlar": (50+ karakterli mesaj sayısı),
  "kisa_mesajlar": (10- karakterli mesaj sayısı)
}

SADECE JSON yanıtı ver, başka açıklama ekleme.
''';
      
      // İptal kontrolü HTTP istemi öncesi
      _checkCancellation();
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'role': 'user', 'parts': [{'text': prompt}]}],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 1000,
          }
        }),
      ).timeout(_httpTimeout, onTimeout: () {
        _logger.w('HTTP isteği timeout oldu');
        throw Exception('İstek zaman aşımına uğradı');
      });
      
      // İptal kontrolü HTTP yanıtı sonrası
      _checkCancellation();
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent != null) {
          // JSON çıkar ve temizle
          String jsonStr = aiContent.trim();
          
          // JSON bloğunu ayıkla
          if (jsonStr.contains('```json')) {
            jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
          } else if (jsonStr.contains('```')) {
            jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
          }
          
          // JSON başlangıç ve bitiş kontrolü
          int startIndex = jsonStr.indexOf('{');
          int endIndex = jsonStr.lastIndexOf('}') + 1;
          
          if (startIndex != -1 && endIndex > 0 && startIndex < endIndex) {
            jsonStr = jsonStr.substring(startIndex, endIndex);
            
            try {
              final result = jsonDecode(jsonStr);
              _logger.i('Parça $parcaNo başarıyla parse edildi');
              return result;
            } catch (e) {
              _logger.w('Parça $parcaNo JSON parse hatası: $e');
              _logger.w('Hatalı JSON içeriği: ${jsonStr.length > 200 ? jsonStr.substring(0, 200) + "..." : jsonStr}');
              
              // Alternatif parse denemesi - eksik olan JSON'u tamamlamaya çalış
              try {
                String fixedJson = _tryFixJson(jsonStr);
                final result = jsonDecode(fixedJson);
                _logger.i('Parça $parcaNo düzeltilmiş JSON ile parse edildi');
                return result;
                             } catch (e2) {
                 _logger.w('Parça $parcaNo JSON düzeltme de başarısız: $e2');
                 return null;
               }
             }
           } else {
             _logger.w('Parça $parcaNo\'da geçerli JSON yapısı bulunamadı');
             return null;
           }
        }
      }
      
      _logger.w('Parça $parcaNo API hatası: ${response.statusCode}');
      return null;
      
    } catch (e) {
      _logger.w('Parça $parcaNo analiz hatası: $e');
      return null;
    }
  }

  // Tüm parça analizlerini birleştirip final wrapped analizi yap
  Future<List<Map<String, String>>> _parcaAnalizleriBirlestir(
      List<Map<String, dynamic>> parcaAnalizleri, 
      Map<String, dynamic> genelIstatistikler) async {
    
    _logger.i('Parça analizleri birleştiriliyor - ${parcaAnalizleri.length} parça');
    
    try {
      // Tüm parça verilerini birleştir
      List<String> tumKelimeler = [];
      List<String> tumTarihler = [];
      List<String> tumSaatler = [];
      List<String> tumKisiAdlari = [];
      int toplamEmojiSayisi = 0;
      int toplamUzunMesajlar = 0;
      int toplamKisaMesajlar = 0;
      
      for (final parca in parcaAnalizleri) {
        // Null veya boş parçaları atla
        if (parca.isEmpty) continue;
        
        if (parca['kelimeler'] is List) {
          tumKelimeler.addAll((parca['kelimeler'] as List).cast<String>());
        }
        if (parca['tarihler'] is List) {
          tumTarihler.addAll((parca['tarihler'] as List).cast<String>());
        }
        if (parca['saatler'] is List) {
          tumSaatler.addAll((parca['saatler'] as List).cast<String>());
        }
        if (parca['kisi_adlari'] is List) {
          tumKisiAdlari.addAll((parca['kisi_adlari'] as List).cast<String>());
        }
        
        toplamEmojiSayisi += (parca['emoji_sayisi'] as int? ?? 0);
        toplamUzunMesajlar += (parca['uzun_mesajlar'] as int? ?? 0);
        toplamKisaMesajlar += (parca['kisa_mesajlar'] as int? ?? 0);
      }
      
      // Benzersiz değerleri al
      final benzersizKisiAdlari = tumKisiAdlari.toSet().toList();
      final benzersizTarihler = tumTarihler.toSet().toList();
      
      // En çok kullanılan kelimeleri bul
      Map<String, int> kelimeSayaclari = {};
      for (String kelime in tumKelimeler) {
        kelimeSayaclari[kelime] = (kelimeSayaclari[kelime] ?? 0) + 1;
      }
      
      // En çok kullanılan kelimeleri sırala
      final enCokKelimeler = kelimeSayaclari.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      
      _logger.i('Birleşik veriler: ${genelIstatistikler['toplam_mesaj_sayisi']} mesaj, ${benzersizKisiAdlari.length} kişi');
      _logger.i('Başarılı parça analizi: ${parcaAnalizleri.where((p) => p.isNotEmpty).length} / ${parcaAnalizleri.length}');
      
      // Final wrapped analizi yap
      return await _finalWrappedAnalizi(genelIstatistikler, {
        'benzersiz_kisi_adlari': benzersizKisiAdlari,
        'benzersiz_tarihler': benzersizTarihler,
        'tum_saatler': tumSaatler,
        'en_cok_kelimeler': enCokKelimeler.take(20).toList(),
        'toplam_emoji_sayisi': toplamEmojiSayisi,
        'toplam_uzun_mesajlar': toplamUzunMesajlar,
        'toplam_kisa_mesajlar': toplamKisaMesajlar,
      });
      
    } catch (e) {
      _logger.e('Parça birleştirme hatası: $e');
      throw Exception('Parça birleştirme hatası: $e');
    }
  }

  // Final wrapped analizi - tüm verileri kullanarak 10 kart oluştur
  Future<List<Map<String, String>>> _finalWrappedAnalizi(
      Map<String, dynamic> genelIstatistikler,
      Map<String, dynamic> birlesikVeriler) async {
    
    try {
      String apiUrl = _getApiUrl();
      
      final prompt = '''
Sen bir veri analisti olarak görev yapacaksın. Verilen kapsamlı analiz verilerinden Spotify Wrapped benzeri kartlar oluşturacaksın.

ANALİZ VERİLERİ:
- İlk Mesaj Tarihi: ${genelIstatistikler['ilk_mesaj_tarihi']}
- Son Mesaj Tarihi: ${genelIstatistikler['son_mesaj_tarihi']}
- Toplam Mesaj Sayısı: ${genelIstatistikler['toplam_mesaj_sayisi']}
- Toplam Kelime Sayısı: ${genelIstatistikler['toplam_kelime_sayisi']}
- Ortalama Mesaj Uzunluğu: ${genelIstatistikler['ortalama_mesaj_uzunlugu']} kelime
- Konuşan Kişiler: ${birlesikVeriler['benzersiz_kisi_adlari']}
- Toplam Emoji Sayısı: ${birlesikVeriler['toplam_emoji_sayisi']}
- Uzun Mesajlar (50+ karakter): ${birlesikVeriler['toplam_uzun_mesajlar']}
- Kısa Mesajlar (10- karakter): ${birlesikVeriler['toplam_kisa_mesajlar']}
- En Çok Kullanılan Kelimeler: ${birlesikVeriler['en_cok_kelimeler']}

Bu VERİLERİ KULLANARAK tam olarak 10 adet wrapped kartı oluştur.

ÖNEMLİ KURALLAR:
1. Yukarıdaki VERİLERİ OLDUĞU GİBİ kullan - değiştirme!
2. Her kartta mutlaka nicel veri olmalı (sayı, tarih, yüzde)
3. SADECE JSON formatında yanıt ver
4. Asla "yaklaşık", "muhtemelen" kullanma

YANIT FORMATI:
[
  {"title": "İlk Mesaj - Son Mesaj", "comment": "İlk mesajınız ${genelIstatistikler['ilk_mesaj_tarihi']} tarihinde, son mesajınız ${genelIstatistikler['son_mesaj_tarihi']} tarihinde gönderildi."},
  {"title": "Toplam Mesajlar", "comment": "Bu yıl toplam ${genelIstatistikler['toplam_mesaj_sayisi']} mesaj gönderdiniz. ${birlesikVeriler['benzersiz_kisi_adlari'].length} farklı kişiyle konuştunuz."},
  // ... 8 kart daha
]
''';
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'role': 'user', 'parts': [{'text': prompt}]}],
          'generationConfig': {
            'temperature': 0.5,
            'maxOutputTokens': 2000,
          }
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent != null) {
          // JSON çıkar ve parse et
          String jsonStr = aiContent;
          if (jsonStr.contains('```json')) {
            jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
          } else if (jsonStr.contains('```')) {
            jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
          }
          
          // Dizi başlangıcı ve bitişini kontrol et
          final int startIndex = jsonStr.indexOf('[');
          final int endIndex = jsonStr.lastIndexOf(']') + 1;
          
          if (startIndex != -1 && endIndex > 0 && startIndex < endIndex) {
            jsonStr = jsonStr.substring(startIndex, endIndex);
            
            final List<dynamic> jsonList = jsonDecode(jsonStr);
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
            
            _logger.i('Final wrapped analizi tamamlandı: ${result.length} kart oluşturuldu');
            return result;
          }
        }
      }
      
      throw Exception('Final analiz API hatası');
      
    } catch (e) {
      _logger.e('Final wrapped analizi hatası: $e');
      throw Exception('Final wrapped analizi hatası: $e');
    }
  }

  // Küçük dosyalar için standart analiz
  Future<List<Map<String, String>>> _analizStandart(String sohbetMetni) async {
    _logger.i('Küçük dosya standart analiz başlatılıyor - ${sohbetMetni.length} karakter');
    
    try {
      // Metin içinden ilk mesaj tarihini çıkarmaya çalış
      String ilkMesajTarihi = _extractFirstMessageDate(sohbetMetni);
      _logger.i('Metin içinden çıkarılan ilk mesaj tarihi: $ilkMesajTarihi');

      // Mesaj çok uzunsa kısalt
      String sonMesajTarihi = '';
      int tumMesajSayisi = 0;
      
      // Tüm metin üzerinden bazı genel istatistikleri çıkar
      try {
        // Mesaj sayısını tahmini olarak hesapla
        final List<String> satirlar = sohbetMetni.split('\n');
        int mesajSayaci = 0;
        for (final satir in satirlar) {
          // Tipik mesaj başlangıcı genelde tarih içerir veya : ile biter
          if (RegExp(r'\d{1,2}[\.\/-]\d{1,2}[\.\/-](\d{2}|\d{4})').hasMatch(satir) || 
              RegExp(r'.*:').hasMatch(satir)) {
            mesajSayaci++;
          }
        }
        tumMesajSayisi = mesajSayaci > 0 ? mesajSayaci : 100; // En az 100 mesaj varsay
        _logger.i('Tahmini toplam mesaj sayısı: $tumMesajSayisi');
      } catch (e) {
        _logger.w('Mesaj sayısı hesaplanırken hata: $e');
        tumMesajSayisi = 100; // Varsayılan değer
      }
      
      if (sohbetMetni.length > 16000) {
        _logger.w('Sohbet içeriği çok uzun (${sohbetMetni.length} karakter), kısaltılıyor...');
        // Uzun içerikte son mesaj tarihini bulmaya çalış
        sonMesajTarihi = _extractLastMessageDate(sohbetMetni);
        _logger.i('Uzun içerikten çıkarılan son mesaj tarihi: $sonMesajTarihi');
        
        sohbetMetni = "${sohbetMetni.substring(0, 16000)}\n...(devamı kısaltıldı)...";
      }
      
      // API URL'sini hazırla
      String apiUrl;
      try {
        apiUrl = _getApiUrl();
        _logger.i('Standart analizi API URL oluşturuldu');
      } catch (apiError) {
        _logger.e('Standart analizi API URL oluşturulurken hata: $apiError');
        throw Exception('API yapılandırma hatası: $apiError');
      }
      
      _logger.d('Standart analizi API isteği hazırlanıyor');
      
      // AI prompt'u hazırla
      String promptEk = "";
      if (sonMesajTarihi.isNotEmpty || tumMesajSayisi > 0) {
        promptEk = """
        ⚠️ ÇOK ÖNEMLİ UYARI ⚠️

        Bu sohbet çok uzun olduğu için kısaltıldı. ASLA SADECE VERILEN METNE DAYANMA!
        Aşağıdaki GERÇEK VERİLERİ kartları oluştururken MUTLAKA KULLAN:
        
        1. İLK MESAJ TARİHİ: ${ilkMesajTarihi.isNotEmpty ? ilkMesajTarihi : 'Belirlenemedi'}
        2. SON MESAJ TARİHİ: ${sonMesajTarihi.isNotEmpty ? sonMesajTarihi : 'Belirlenemedi'}
        3. TOPLAM MESAJ SAYISI: $tumMesajSayisi
        
        Kartları oluştururken:
        - "İlk Mesaj - Son Mesaj" kartında yukarıdaki tarihleri OLDUĞU GİBİ kullan
        - "Mesaj Sayıları" kartında toplam mesaj sayısını $tumMesajSayisi olarak kullan
        - Tüm istatistikleri bu GERÇEK VERİLERE dayanarak hesapla
        - İçeriği kısaltılmış olsa bile, tüm analizinde BU TOPLAM SAYILARI kullan
        
        UYARI: Verilen metin tam sohbeti içermiyor! Sadece bir kısmını görüyorsun. O yüzden yukarıdaki GERÇEK VERİLERİ KULLAN!
        """;
      }
      
      final prompt = '''
      Sen bir veri analisti olarak görev yapacaksın. Aşağıda verilen mesajlaşma geçmişini inceleyerek Spotify Wrapped benzeri bir yıllık özet hazırlayacaksın.
      
      Kesinlikle şablona uyman, STATIK DEĞERLER kullanmaman ve aşağıdaki formatta yanıt vermen gerekiyor. Her kart için gerçek veriye dayalı özgün bir başlık ve içerik oluştur.
      
      Mesajlaşma geçmişi:
      """
      $sohbetMetni
      """
      
      ${promptEk.isNotEmpty ? promptEk : ""}
      
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
      
      _logger.d('Standart analizi API isteği gönderiliyor');
      
      // İptal kontrolü HTTP istemi öncesi
      _checkCancellation();
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      ).timeout(_httpTimeout, onTimeout: () {
        _logger.w('Standart analiz HTTP isteği timeout oldu');
        throw Exception('İstek zaman aşımına uğradı');
      });
      
      // İptal kontrolü HTTP yanıtı sonrası
      _checkCancellation();
      
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
          
          _logger.i('Standart analiz tamamlandı: ${result.length} kart oluşturuldu');
          return result;
          
        } catch (jsonError) {
          _logger.e('JSON ayrıştırma hatası: $jsonError');
          throw Exception('Analiz sonucu formatı hatalı: $jsonError');
        }
      } else {
        _logger.e('API hatası - ${response.statusCode}: ${response.body}');
        throw Exception('AI servis hatası: ${response.statusCode}');
      }
      
    } catch (e) {
      _logger.e('Standart analiz hatası: $e');
      throw Exception('Standart analiz hatası: $e');
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
  List<Map<String, String>> _getDefaultWrappedCards([String ilkMesajTarihi = '', String sonMesajTarihi = '']) {
    final String tarihIfadesi;
    final String sonTarihIfadesi;
    
    if (ilkMesajTarihi.isNotEmpty) {
      tarihIfadesi = ilkMesajTarihi;
    } else {
      // Şimdiki tarihten 3 ay önce gibi bir tahmin yap
      final threeMontshAgo = DateTime.now().subtract(const Duration(days: 90));
      tarihIfadesi = '${threeMontshAgo.day}.${threeMontshAgo.month}.${threeMontshAgo.year}';
    }
    
    if (sonMesajTarihi.isNotEmpty) {
      sonTarihIfadesi = sonMesajTarihi;
    } else {
      // Şimdiki tarihi kullan
      final today = DateTime.now();
      sonTarihIfadesi = '${today.day}.${today.month}.${today.year}';
    }
    
    return [
      {
        'title': 'İlk Mesaj - Son Mesaj',
        'comment': 'İlk mesajınız $tarihIfadesi tarihinde, son mesajınız ise $sonTarihIfadesi tarihinde atılmış.'
      },
      {
        'title': 'Mesaj Sayıları',
        'comment': 'Toplam 347 mesaj atmışsınız. Sen %52, karşı taraf %48 oranında mesaj atmış.'
      },
      {
        'title': 'En Yoğun Ay/Gün',
        'comment': 'En çok ${_randomAy()} ayında mesajlaşmışsınız. En yoğun gün ise ${_randomGun()}.'
      },
      {
        'title': 'En Çok Kullanılan Kelimeler',
        'comment': 'En sık kullandığınız kelimeler: "merhaba", "evet", "hayır", "belki", "tamam"'
      },
      {
        'title': 'Mesaj Patlaması',
        'comment': '${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year - 1} günü tam 36 mesaj atarak rekor kırdınız!'
      },
      {
        'title': 'Sessizlik Süresi',
        'comment': 'En uzun sessizlik 3 gün sürmüş. ${DateTime.now().day-5}-${DateTime.now().day-2}.${DateTime.now().month}.${DateTime.now().year} arasında hiç mesajlaşmamışsınız.'
      },
      {
        'title': 'İletişim Tarzı',
        'comment': 'Mesajlaşma tarzınız "Samimi" olarak sınıflandırılıyor. Karşılıklı saygı unsurları belirgin.'
      },
      {
        'title': 'Emoji Kullanımı',
        'comment': 'Sen toplam 83 emoji kullanmışsın. En çok kullandığın emoji: 😊'
      },
      {
        'title': 'Ortalama Mesaj Uzunluğu',
        'comment': 'Ortalama mesaj uzunluğun 15 kelime. Karşı tarafın ortalama mesaj uzunluğu 12 kelime.'
      },
      {
        'title': 'Konuşma Saatleri',
        'comment': 'En çok saat 21:00-23:00 arasında mesajlaşıyorsunuz. Sabah 07:00-09:00 arası en az mesajlaştığınız zaman dilimi.'
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
      Sen bir mesajlaşma analiz uzmanısın. Aşağıdaki metni mesajlaşma koçu olarak analiz et. 
      Mesajın genel havasını ve etkisini değerlendir. Metni bir mesajlaşma/sohbet olarak ele al.
      
      İletişime dair derinlemesine analiz yap:
      1. Sohbetin genel havası nasıl? (samimi, resmi, soğuk, sıcak, vb.)
      2. Son mesajın tonu nasıl? (ilgili, ilgisiz, heyecanlı, kızgın, vb.)
      3. Bu metne verilecek etkili cevaplar neler olabilir?
      
      Metin:
      """
      $metinIcerigi
      """
      
      Analiz sonucunu aşağıdaki JSON formatında ver:
      {
        "sohbetGenelHavasi": "Sohbetin genel havasını belirten bir ifade (örn: samimi, resmi, soğuk, sıcak)",
        "genelYorum": "Sohbete dair genel bir değerlendirme (1-2 cümle)",
        "sonMesajTonu": "Son mesajın tonu (ilgili, ilgisiz, heyecanlı, kızgın, vb.)",
        "sonMesajEtkisi": {
          "sempatik": X,
          "kararsız": Y,
          "olumsuz": Z
        },
        "direktYorum": "Kısa, net ve gerekiyorsa acımasız bir yorum",
        "cevapOnerileri": ["Öneri 1", "Öneri 2", "Öneri 3"],
        "olumluSenaryo": "Olumlu bir yanıt senaryosu",
        "olumsuzSenaryo": "Olumsuz bir yanıt senaryosu",
        "mesajYorumu": "Mesaja dair detaylı bir yorum"
      }
      
      Önemli: Cevabını SADECE JSON formatında ver, başka açıklama yapma.
      Cevabında "Analiz edilemedi", "yetersiz içerik" veya benzeri ifadeler KULLANMA.
      İçerik ne kadar az olursa olsun mutlaka bir yorum yap ve değerleri doldur.
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
          
          // Önce içerikteki saf JSON'u almak için regex kullan
          RegExp jsonRegex = RegExp(r'\{[\s\S]*\}');
          Match? jsonMatch = jsonRegex.firstMatch(jsonStr);
          
          if (jsonMatch != null) {
            jsonStr = jsonMatch.group(0) ?? jsonStr;
          } else {
            // Markdown kod bloğu varsa temizle
            if (jsonStr.contains('```json')) {
              jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
            } else if (jsonStr.contains('```')) {
              jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
            }
          }
          
          // Hata ayıklama
          _logger.d('JSON ayrıştırılmaya çalışılıyor: ${jsonStr.substring(0, min(100, jsonStr.length))}...');
          
          Map<String, dynamic> jsonData;
          try {
            jsonData = jsonDecode(jsonStr);
            _logger.i('JSON başarıyla ayrıştırıldı');
          } catch (jsonError) {
            _logger.e('İlk JSON ayrıştırma hatası: $jsonError, alternatif yöntem deneniyor');
            
            // Alternatif çözüm: Yanıt düzgün JSON olmayabilir, düzeltmeye çalış
            jsonStr = jsonStr.replaceAll("'", '"'); // Tek tırnakları çift tırnağa çevir
            
            // Eksik çift tırnakları düzelt
            RegExp keyPattern = RegExp(r'([a-zA-Z0-9_]+):');
            jsonStr = jsonStr.replaceAllMapped(keyPattern, (Match m) => '"${m.group(1)}":');
            
            // Şimdi tekrar dene
            try {
              jsonData = jsonDecode(jsonStr);
              _logger.i('JSON düzeltme sonrası başarıyla ayrıştırıldı');
            } catch (e) {
              _logger.e('JSON düzeltme sonrası da ayrıştırılamadı: $e');
              
              // Manuel bir yapı oluştur
              jsonData = {
                'metinOzeti': 'Metin analiz edilemedi',
                'anaTema': 'Belirlenemedi',
                'duygusalTon': 'Nötr',
                'amac': 'Belirlenemedi',
                'onemliNoktalar': ['Analiz edilemedi'],
                'onerilecekCevaplar': ['Üzgünüm, mesajınızı analiz edemedim.', 'Lütfen mesajınızı daha açık bir şekilde yazabilir misiniz?', 'Farklı bir yaklaşımla iletişim kurmayı deneyebilirsiniz.'],
                'mesajYorumu': 'Mesaj analiz edilemedi, lütfen başka bir metin ile tekrar deneyin.',
                'olumluSenaryo': 'Analiz edilemedi',
                'olumsuzSenaryo': 'Analiz edilemedi'
              };
            }
          }
          
          // JSON'dan listeyi güvenli şekilde ayıkla
          List<String> getStringList(dynamic jsonValue) {
            if (jsonValue == null) return [];
            
            if (jsonValue is List) {
              return jsonValue.map((e) => e.toString()).toList();
            } else if (jsonValue is String) {
              // Metin içinde liste formatı olabilir [item1, item2] gibi
              if (jsonValue.startsWith('[') && jsonValue.endsWith(']')) {
                final listText = jsonValue.substring(1, jsonValue.length - 1);
                return listText.split(',').map((e) => e.trim()).toList();
              }
              // Tek bir string ise, onu liste yap
              return [jsonValue];
            }
            
            return [];
          }
          
          // MessageCoachAnalysis nesnesini oluştur
          final analiz = MessageCoachAnalysis(
            // Zorunlu alanlar
            analiz: jsonData['genelYorum'] ?? jsonData['mesajYorumu'] ?? 'Analiz yok',
            oneriler: getStringList(jsonData['cevapOnerileri']),
            etki: _parseSonMesajEtkisi(jsonData['sonMesajEtkisi']),
            
            // Opsiyonel alanlar
            iliskiTipi: 'Tanımlanmamış',
            gucluYonler: jsonData['anaTema'] ?? 'Tema belirtilmemiş',
            cevapOnerileri: getStringList(jsonData['cevapOnerileri']),
            
            // Metin koçu alanları
            sohbetGenelHavasi: jsonData['sohbetGenelHavasi'] ?? 'Belirlenemedi',
            genelYorum: jsonData['genelYorum'] ?? 'Belirlenemedi',
            sonMesajTonu: jsonData['sonMesajTonu'] ?? 'Nötr',
            sonMesajEtkisi: _parseSonMesajEtkisi(jsonData['sonMesajEtkisi']),
            direktYorum: jsonData['direktYorum'] ?? 'Belirlenemedi',
            
            // Yanıt senaryoları
            olumluCevapTahmini: jsonData['olumluSenaryo'] ?? 'Olumlu senaryo bulunamadı',
            olumsuzCevapTahmini: jsonData['olumsuzSenaryo'] ?? 'Olumsuz senaryo bulunamadı',
            
            // Yeni alanlar - metin analizi için
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            createdAt: DateTime.now(),
            metinOzeti: jsonData['direktYorum'] ?? 'Özet yok',
            anaTema: jsonData['sohbetGenelHavasi'] ?? 'Tema belirtilmemiş',
            duygusalTon: jsonData['sonMesajTonu'] ?? 'Nötr',
            amac: jsonData['mesajYorumu'] ?? 'Amaç belirtilmemiş',
            onemliNoktalar: getStringList(jsonData['onemliNoktalar'] ?? []),
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
      
      // WhatsApp deseni (başlangıç için)
      final whatsAppPattern = RegExp(r'\[?(\d{1,2})[\.\/](\d{1,2})[\.\/](\d{2,4})[,\s]');
      
      // İlk 50 satırı kontrol et (veya tüm satırları, hangisi daha az ise)
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

  // Metin içinden son mesaj tarihini çıkar
  String _extractLastMessageDate(String text) {
    try {
      _logger.i('Son mesaj tarihi çıkarılıyor...');
      
      // Genel tarih desenleri
      final List<RegExp> datePatterns = [
        // GG.AA.YYYY veya GG/AA/YYYY
        RegExp(r'(\d{1,2})[\.\/](\d{1,2})[\.\/](20\d{2})'),
        
        // GG.AA.YY veya GG/AA/YY
        RegExp(r'(\d{1,2})[\.\/](\d{1,2})[\.\/](\d{2})'),
        
        // YYYY-AA-GG
        RegExp(r'(20\d{2})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])'),
        
        // GG AA YYYY (5 Ekim 2022)
        RegExp(r'(\d{1,2})\s+(Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık)\s+(20\d{2})'),
        
        // WhatsApp deseni [GG.AA.YY, HH:MM:SS]
        RegExp(r'\[(\d{1,2})[\.\/](\d{1,2})[\.\/](\d{2,4})[,\s]'),
        
        // Farklı WhatsApp desenleri
        RegExp(r'(\d{1,2})[\.\/](\d{1,2})[\.\/](20\d{2})\s+\d{1,2}:\d{2}'),
        RegExp(r'(\d{1,2})[\.\/](\d{1,2})[\.\/](\d{2})\s+\d{1,2}:\d{2}'),
      ];
      
      // Metin çok uzunsa son 2000 karaktere bak
      String searchText = text;
      if (text.length > 2000) {
        searchText = text.substring(text.length - 2000);
      }
      
      // Satır satır metni kontrol et
      final lines = searchText.split('\n');
      
      // Son 100 satırı kontrol et (veya tüm satırları, hangisi daha az ise) - sondan başa doğru
      for (int i = lines.length - 1; i >= max(0, lines.length - 100); i--) {
        final line = lines[i];
        
        // Her deseni kontrol et
        for (final pattern in datePatterns) {
          final match = pattern.firstMatch(line);
          
          if (match != null) {
            // RegExp'in grup sayısını kontrol et
            if (match.groupCount >= 3) {
              String gun = '';
              String ay = '';
              String yil = '';
              
              // Tarih formatını belirle ve grupları uygun şekilde al
              if (pattern.pattern.contains('(20\\d{2})-(0[1-9]|1[0-2])-(0[1-9]|[12]\\d|3[01])')) {
                // YYYY-MM-DD formatı
                yil = match.group(1)!;
                ay = match.group(2)!;
                gun = match.group(3)!;
              } else if (pattern.pattern.contains('(\\d{1,2})\\s+(Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık)\\s+(20\\d{2})')) {
                // DD Month YYYY formatı
                gun = match.group(1)!;
                // Ay ismini sayıya çevir
                final ayIsimleri = {
                  'Ocak': '1', 'Şubat': '2', 'Mart': '3', 'Nisan': '4', 'Mayıs': '5', 'Haziran': '6',
                  'Temmuz': '7', 'Ağustos': '8', 'Eylül': '9', 'Ekim': '10', 'Kasım': '11', 'Aralık': '12'
                };
                ay = ayIsimleri[match.group(2)] ?? '1';
                yil = match.group(3)!;
              } else {
                // Standart DD/MM/YYYY veya DD/MM/YY formatı
                gun = match.group(1)!;
                ay = match.group(2)!;
                yil = match.group(3)!;
                
                // Yıl 2 haneliyse 4 haneye genişlet
                if (yil.length == 2) {
                  yil = int.parse(yil) > 50 ? '19$yil' : '20$yil';
                }
              }
              
              _logger.i('Son tarih bulundu: $gun.$ay.$yil');
              return '$gun.$ay.$yil';
            }
          }
        }
      }
      
      // Desenleri tek tek dene
      for (final pattern in datePatterns) {
        final matches = pattern.allMatches(searchText).toList();
        if (matches.isNotEmpty) {
          final lastMatch = matches.last;
          
          // RegExp'in grup sayısını kontrol et
          if (lastMatch.groupCount >= 3) {
            String gun = '';
            String ay = '';
            String yil = '';
            
            // Tarih formatını belirle ve grupları uygun şekilde al
            if (pattern.pattern.contains('(20\\d{2})-(0[1-9]|1[0-2])-(0[1-9]|[12]\\d|3[01])')) {
              // YYYY-MM-DD formatı
              yil = lastMatch.group(1)!;
              ay = lastMatch.group(2)!;
              gun = lastMatch.group(3)!;
            } else if (pattern.pattern.contains('(\\d{1,2})\\s+(Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık)\\s+(20\\d{2})')) {
              // DD Month YYYY formatı
              gun = lastMatch.group(1)!;
              // Ay ismini sayıya çevir
              final ayIsimleri = {
                'Ocak': '1', 'Şubat': '2', 'Mart': '3', 'Nisan': '4', 'Mayıs': '5', 'Haziran': '6',
                'Temmuz': '7', 'Ağustos': '8', 'Eylül': '9', 'Ekim': '10', 'Kasım': '11', 'Aralık': '12'
              };
              ay = ayIsimleri[lastMatch.group(2)] ?? '1';
              yil = lastMatch.group(3)!;
            } else {
              // Standart DD/MM/YYYY veya DD/MM/YY formatı
              gun = lastMatch.group(1)!;
              ay = lastMatch.group(2)!;
              yil = lastMatch.group(3)!;
              
              // Yıl 2 haneliyse 4 haneye genişlet
              if (yil.length == 2) {
                yil = int.parse(yil) > 50 ? '19$yil' : '20$yil';
              }
            }
            
            _logger.i('Son tarih bulundu: $gun.$ay.$yil');
            return '$gun.$ay.$yil';
          }
        }
      }
      
      // Tarih bulunamadığında varsayılan olarak bugünün tarihini dön
      final today = DateTime.now();
      return '${today.day}.${today.month}.${today.year}';
    } catch (e) {
      _logger.e('Son tarih çıkarma hatası', e);
      // Hata durumunda bugünün tarihini dön
      final today = DateTime.now();
      return '${today.day}.${today.month}.${today.year}';
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

  // Public metod - Metin içinden son mesaj tarihini çıkar (diğer sınıfların erişimi için)
  String extractLastMessageDate(String text) {
    return _extractLastMessageDate(text);
  }

  // Mesaj etkisi JSON'ını ayrıştırma
  Map<String, int> _parseSonMesajEtkisi(dynamic etkiJson) {
    // Varsayılan etki değerleri
    Map<String, int> etkiMap = {'sempatik': 33, 'kararsız': 34, 'olumsuz': 33};
    
    // Eğer veri yoksa veya dönüştürülemezse varsayılan değerleri kullan
    if (etkiJson == null) {
      return etkiMap;
    }
    
    try {
      // Map formatında ise dönüştür
      if (etkiJson is Map) {
        Map<String, int> yeniMap = {};
        
        etkiJson.forEach((key, value) {
          int deger = 0;
          
          if (value is int) {
            deger = value;
          } else if (value is double) {
            deger = value.toInt();
          } else if (value is String) {
            // String'i int'e çevirmeye çalış
            deger = int.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
          }
          
          yeniMap[key.toString()] = deger;
        });
        
        // En az bir değer var mı kontrol et
        if (yeniMap.isNotEmpty) {
          // Toplam kontrol et, 100'e yakın değilse ayarla
          int toplam = yeniMap.values.fold(0, (sum, value) => sum + value);
          
          if (toplam < 80 || toplam > 120) {
            // Değerleri oranla
            double oran = 100 / toplam;
            Map<String, int> duzeltilmisMap = {};
            int yeniToplam = 0;
            
            // Değerleri oranla ve yuvarla
            yeniMap.forEach((key, value) {
              int yeniDeger = (value * oran).round();
              duzeltilmisMap[key] = yeniDeger;
              yeniToplam += yeniDeger;
            });
            
            // Hala 100 değilse, farkı en büyük değere ekle/çıkar
            if (yeniToplam != 100 && duzeltilmisMap.isNotEmpty) {
              String enBuyukKey = duzeltilmisMap.entries
                  .reduce((a, b) => a.value > b.value ? a : b)
                  .key;
              duzeltilmisMap[enBuyukKey] = duzeltilmisMap[enBuyukKey]! + (100 - yeniToplam);
            }
            
            return duzeltilmisMap;
          }
          
          return yeniMap;
        }
      }
    } catch (e) {
      _logger.e('Etki değerlerini ayrıştırma hatası: $e');
    }
    
    return etkiMap;
  }

  // Büyük dosyalar için parçalı analiz
  Future<List<Map<String, String>>> _analizBuyukDosya(String sohbetMetni, String ilkMesajTarihi, String sonMesajTarihi, int tumMesajSayisi) async {
    _logger.i('Büyük dosya parçalı analiz başlatılıyor');
    
    try {
      // API URL'sini hazırla
      String apiUrl = _getApiUrl();
      
      // Dosyayı akıllı parçalama ile böl
      List<String> parcalar = _akilliparcalama(sohbetMetni);
      
      _logger.i('Dosya ${parcalar.length} parçaya bölündü');
      
      List<Map<String, String>> tumKartlar = [];
      
      // Her parçayı analiz et
      for (int i = 0; i < parcalar.length; i++) {
        _logger.i('Parça ${i + 1}/${parcalar.length} analiz ediliyor');
        
        final parcaPrompt = '''
Sen bir veri analisti olarak görev yapacaksın. Bu büyük bir sohbetin ${i + 1}. parçası (toplam ${parcalar.length} parça).

TAMAMLAYICI BİLGİLER:
- İlk mesaj tarihi: $ilkMesajTarihi
- Son mesaj tarihi: $sonMesajTarihi  
- Toplam mesaj sayısı: $tumMesajSayisi

Bu parçadan çıkarabileceğin analiz kartları oluştur. Her kart için gerçek veriye dayalı özgün bir başlık ve içerik oluştur.

Mesajlaşma geçmişi (Parça ${i + 1}/${parcalar.length}):
"""
${parcalar[i]}
"""

ÖNEMLİ KURALLAR:
1. Bu parçadan çıkarabileceğin 2-3 kart oluştur.
2. Her kartın kendine özgü başlığı ve içeriği olmalı.
3. Bu parçadaki gerçek verilere dayanmalı.
4. Her kartta mutlaka nicel bir veri (sayı, yüzde, tarih vb.) olmalı.
5. Yanıtını doğrudan JSON formatında ver.

YANIT FORMATI (doğrudan JSON dizi):
[
  {"title": "Parça Analiz Başlığı 1", "comment": "Kartın açıklaması, mutlaka nicel verilerle destekli"},
  {"title": "Parça Analiz Başlığı 2", "comment": "Kartın açıklaması, mutlaka nicel verilerle destekli"}
]
''';

        try {
          var parcaRequestBody = jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {
                    'text': parcaPrompt
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
          
          final parcaResponse = await http.post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: parcaRequestBody,
          );
          
          if (parcaResponse.statusCode == 200) {
            final parcaData = jsonDecode(parcaResponse.body);
            final parcaContent = parcaData['candidates']?[0]?['content']?['parts']?[0]?['text'];
            
            if (parcaContent != null && parcaContent.isNotEmpty) {
              try {
                String parcaJsonStr = parcaContent;
                
                // JSON bloğunu temizle
                if (parcaJsonStr.contains('```json')) {
                  parcaJsonStr = parcaJsonStr.split('```json')[1].split('```')[0].trim();
                } else if (parcaJsonStr.contains('```')) {
                  parcaJsonStr = parcaJsonStr.split('```')[1].split('```')[0].trim();
                }
                
                final int startIndex = parcaJsonStr.indexOf('[');
                final int endIndex = parcaJsonStr.lastIndexOf(']') + 1;
                
                if (startIndex != -1 && endIndex > 0 && startIndex < endIndex) {
                  parcaJsonStr = parcaJsonStr.substring(startIndex, endIndex);
                  
                  final List<dynamic> parcaJsonList = jsonDecode(parcaJsonStr);
                  
                  for (var item in parcaJsonList) {
                    if (item is Map) {
                      String title = item['title']?.toString() ?? 'Parça Analizi';
                      String comment = item['comment']?.toString() ?? 'Parça içeriği analiz edildi';
                      
                      // Aynı başlıktan olmadığından emin ol
                      if (!tumKartlar.any((existing) => existing['title'] == title)) {
                        tumKartlar.add({
                          'title': title,
                          'comment': comment,
                        });
                      }
                    }
                  }
                }
              } catch (e) {
                _logger.e('Parça ${i + 1} ayrıştırma hatası: $e');
              }
            }
          }
          
          // Parçalar arası kısa bekleme
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          _logger.e('Parça ${i + 1} analiz hatası: $e');
        }
      }
      
      _logger.i('Parçalı analiz tamamlandı, ${tumKartlar.length} kart oluşturuldu');
      
      // Eğer hala yeterli kart yoksa fallback kartları ekle
      if (tumKartlar.length < 10) {
        final fallbackKartlar = await _generateFallbackCards(sohbetMetni, ilkMesajTarihi, sonMesajTarihi, tumMesajSayisi, tumKartlar);
        tumKartlar.addAll(fallbackKartlar);
      }
      
      // Tam olarak 10 kart döndür
      return tumKartlar.take(10).toList();
      
    } catch (e) {
      _logger.e('Büyük dosya analiz hatası: $e');
      return await _generateFallbackCards(sohbetMetni, ilkMesajTarihi, sonMesajTarihi, tumMesajSayisi, []);
    }
  }
  
  // Gerçek veriye dayalı fallback kartları oluştur
  Future<List<Map<String, String>>> _generateFallbackCards(String sohbetMetni, String ilkMesajTarihi, String sonMesajTarihi, int tumMesajSayisi, List<Map<String, String>> mevcutKartlar) async {
    _logger.i('Gerçek veriye dayalı fallback kartları oluşturuluyor');
    
    List<Map<String, String>> fallbackKartlar = [];
    final mevcutBasliklar = mevcutKartlar.map((e) => e['title']).toSet();
    
    // Gerçek veriyi analiz et
    final satirlar = sohbetMetni.split('\n');
    int mesajSayisi = 0;
    int senMesajSayisi = 0;
    int karsiTarafMesajSayisi = 0;
    List<String> tumKelimeler = [];
    Map<String, int> saatlikDagilim = {};
    
    // Temel analiz
    for (final satir in satirlar) {
      if (satir.trim().isEmpty) continue;
      
      // Mesaj sayısını say
      if (RegExp(r'\d{1,2}[\.\/-]\d{1,2}[\.\/-](\d{2}|\d{4})').hasMatch(satir) || 
          RegExp(r'.*:').hasMatch(satir)) {
        mesajSayisi++;
        
        // Saat bilgisini çıkar
        final saatMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(satir);
        if (saatMatch != null) {
          final saat = saatMatch.group(1);
          if (saat != null) {
            final saatAraligi = '${saat}:00-${int.parse(saat) + 1}:00';
            saatlikDagilim[saatAraligi] = (saatlikDagilim[saatAraligi] ?? 0) + 1;
          }
        }
        
        // Sen mi karşı taraf mı gönderdi?
        if (satir.toLowerCase().contains('sen:') || satir.toLowerCase().contains('you:')) {
          senMesajSayisi++;
        } else {
          karsiTarafMesajSayisi++;
        }
      }
      
      // Kelimeleri topla
      final kelimeler = satir.toLowerCase().split(RegExp(r'[\s,\.\!\?\;]+'));
      for (final kelime in kelimeler) {
        if (kelime.length > 2) {
          tumKelimeler.add(kelime);
        }
      }
    }
    
    // En yoğun saat
    String enYogunSaat = 'Belirlenemedi';
    if (saatlikDagilim.isNotEmpty) {
      enYogunSaat = saatlikDagilim.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }
    
    // En çok kullanılan kelimeler
    Map<String, int> kelimeSikligi = {};
    for (final kelime in tumKelimeler) {
      kelimeSikligi[kelime] = (kelimeSikligi[kelime] ?? 0) + 1;
    }
    
    final enCokKelimeler = kelimeSikligi.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topKelimeler = enCokKelimeler.take(5).map((e) => '"${e.key}"').join(', ');
    
    // Fallback kartlarını oluştur
    final potansiyelKartlar = [
      {
        'title': 'İlk Mesaj - Son Mesaj',
        'comment': 'İlk mesajınız ${ilkMesajTarihi.isNotEmpty ? ilkMesajTarihi : "uzun zaman önce"} tarihinde, son mesajınız ise ${sonMesajTarihi.isNotEmpty ? sonMesajTarihi : "yakın zamanda"} atılmış.'
      },
      {
        'title': 'Mesaj Sayıları ve Dağılımı',
        'comment': 'Toplam ${tumMesajSayisi > 0 ? tumMesajSayisi : mesajSayisi} mesaj atmışsınız. ${senMesajSayisi > 0 && karsiTarafMesajSayisi > 0 ? "Sen %${((senMesajSayisi / (senMesajSayisi + karsiTarafMesajSayisi)) * 100).round()}, karşı taraf %${((karsiTarafMesajSayisi / (senMesajSayisi + karsiTarafMesajSayisi)) * 100).round()} oranında mesaj atmış." : "Mesaj dağılımı analiz edildi."}'
      },
      {
        'title': 'En Aktif Zaman Dilimi',
        'comment': 'En çok $enYogunSaat saatleri arasında mesajlaşıyorsunuz.'
      },
      {
        'title': 'En Çok Kullanılan Kelimeler',
        'comment': 'En sık kullandığınız kelimeler: ${topKelimeler.isNotEmpty ? topKelimeler : "analiz ediliyor"}'
      },
      {
        'title': 'Kelime Çeşitliliği',
        'comment': 'Toplam ${kelimeSikligi.length} farklı kelime kullanmışsınız. Ortalama kelime tekrarı ${kelimeSikligi.isNotEmpty ? (tumKelimeler.length / kelimeSikligi.length).toStringAsFixed(1) : "0"} kez.'
      },
      {
        'title': 'Mesaj Yoğunluğu',
        'comment': 'Günde ortalama ${(mesajSayisi / 30).toStringAsFixed(1)} mesaj atmışsınız.'
      },
      {
        'title': 'İletişim Analizi',
        'comment': 'Mesajlaşma tarzınız düzenli ve sürekli. ${mesajSayisi} mesajın analiz sonucu.'
      },
      {
        'title': 'Sohbet Sürekliliği',
        'comment': '${ilkMesajTarihi.isNotEmpty && sonMesajTarihi.isNotEmpty ? "İlk mesajdan bu yana düzenli olarak iletişim kuruyorsunuz." : "Uzun süredir devam eden bir sohbet."}'
      },
      {
        'title': 'Metin Uzunluğu Analizi',
        'comment': 'Ortalama mesaj uzunluğunuz ${(tumKelimeler.length / max(mesajSayisi, 1)).toStringAsFixed(1)} kelime.'
      },
      {
        'title': 'Sohbet Karakteristiği',
        'comment': 'Toplam ${satirlar.length} satır veri analiz edildi. Düzenli ve aktif bir iletişim tarzı.'
      }
    ];
    
    // Mevcut kartlarla çakışmayan kartları ekle
    for (final kart in potansiyelKartlar) {
      if (!mevcutBasliklar.contains(kart['title']) && fallbackKartlar.length < 10) {
        fallbackKartlar.add(kart);
        mevcutBasliklar.add(kart['title']!);
      }
    }
    
    _logger.i('${fallbackKartlar.length} fallback kart oluşturuldu');
    return fallbackKartlar;
  }

  /// Akıllı parçalama sistemi
  /// Maksimum 5 parça ile sınırlı, büyük parçalar oluşturur
  List<String> _akilliparcalama(String metin) {
    // Maksimum parça sayısı limiti
    const int maxChunks = 5;
    
    // Gemini model limitleri
    const int maxTokensPerRequest = 120000; // Daha yüksek limit kullan
    const int tokensPerChar = 3; // Daha optimistik oran
    const int safetyMargin = 5000; // Daha büyük güvenlik marjı
    const int usableTokens = maxTokensPerRequest - safetyMargin;
    
    // Token bazlı optimal parça boyutu
    final int tokenBasedChunkSize = (usableTokens / tokensPerChar).floor();
    
    // Dosya boyutuna göre minimum parça boyutu (maksimum 5 parça için)
    final int minChunkSizeForMaxChunks = (metin.length / maxChunks).ceil();
    
    // İki değerden büyük olanını seç
    final int finalChunkSize = tokenBasedChunkSize > minChunkSizeForMaxChunks 
        ? tokenBasedChunkSize 
        : minChunkSizeForMaxChunks;
    
    _logger.i('Akıllı parçalama parametreleri:');
    _logger.i('- Maksimum parça sayısı: $maxChunks');
    _logger.i('- Token bazlı parça boyutu: $tokenBasedChunkSize karakter');
    _logger.i('- Dosya bazlı min parça boyutu: $minChunkSizeForMaxChunks karakter');
    _logger.i('- Seçilen parça boyutu: $finalChunkSize karakter');
    _logger.i('- Toplam metin uzunluğu: ${metin.length} karakter');
    
    // Tahmini parça sayısını hesapla
    final int estimatedChunks = (metin.length / finalChunkSize).ceil();
    _logger.i('- Tahmini parça sayısı: $estimatedChunks');
    
    // Eğer dosya çok küçükse parçalama
    if (metin.length <= finalChunkSize || estimatedChunks <= 1) {
      _logger.i('Dosya küçük, parçalama yapılmayacak');
      return [metin];
    }
    
    List<String> parcalar = [];
    int baslangic = 0;
    int parcaSayaci = 0;
    
        while (baslangic < metin.length && parcaSayaci < maxChunks) {
      parcaSayaci++;
      int bitis = baslangic + finalChunkSize;
      
      // Son parça kontrolü veya maksimum parça sayısına ulaştık
      if (bitis >= metin.length || parcaSayaci == maxChunks) {
        bitis = metin.length; // Son parçada kalan tüm metni al
        String sonParca = metin.substring(baslangic, bitis);
        parcalar.add(sonParca);
        _logger.i('Son parça $parcaSayaci oluşturuldu: ${sonParca.length} karakter');
        break;
      }
      
      // Doğal bir kırılma noktası bul (satır sonu veya nokta)
      int dogalKirilma = _dogalKirilmaNoktasiBul(metin, baslangic, bitis);
      
      if (dogalKirilma > baslangic) {
        bitis = dogalKirilma;
      }
      
      String parca = metin.substring(baslangic, bitis);
      parcalar.add(parca);
      
      _logger.i('Parça $parcaSayaci oluşturuldu: ${parca.length} karakter');
      
      baslangic = bitis;
    }
    
    _logger.i('Akıllı parçalama tamamlandı: ${parcalar.length} parça oluşturuldu');
    
    // Parça boyutlarını logla
    for (int i = 0; i < parcalar.length; i++) {
      _logger.d('Parça ${i + 1}: ${parcalar[i].length} karakter');
    }
    
    // Özet bilgi
    _logger.i('PARÇALAMA ÖZETİ:');
    _logger.i('- Toplam dosya boyutu: ${metin.length} karakter');
    _logger.i('- Oluşturulan parça sayısı: ${parcalar.length}');
    _logger.i('- Maksimum izin verilen parça: $maxChunks');
    _logger.i('- Ortalama parça boyutu: ${(metin.length / parcalar.length).round()} karakter');
    
    return parcalar;
  }

  /// Doğal kırılma noktası bulur (satır sonu, nokta, vb.)
  int _dogalKirilmaNoktasiBul(String metin, int baslangic, int maksimumBitis) {
    // Geriye doğru 1000 karaktere kadar ara
    const int aramaGenisligi = 1000;
    int aramaBaslangici = maksimumBitis - aramaGenisligi;
    if (aramaBaslangici < baslangic) {
      aramaBaslangici = baslangic;
    }
    
    String aramaBolgesi = metin.substring(aramaBaslangici, maksimumBitis);
    
         // Oncelik sirasi: cift satir sonu, tek satir sonu, nokta+bosluk, virgul+bosluk
         List<String> kirilmaDesenleri = [
      '\n\n',  // Paragraf sonu
      '\n',    // Satır sonu
      '. ',    // Cümle sonu
      ', ',    // Virgül sonrası
    ];
    
           for (String desen in kirilmaDesenleri) {
      int sonIndex = aramaBolgesi.lastIndexOf(desen);
      if (sonIndex != -1) {
        int globalIndex = aramaBaslangici + sonIndex + desen.length;
        if (globalIndex > baslangic && globalIndex < maksimumBitis) {
          return globalIndex;
        }
      }
    }
    
         // Doğal kırılma bulunamazsa orijinal biti döndür
     return maksimumBitis;
   }

   /// JSON'u düzeltmeye çalışır
   String _tryFixJson(String brokenJson) {
     String fixed = brokenJson.trim();
     
     // Eksik kapatma parantezleri ekle
     int openBraces = 0;
     for (int i = 0; i < fixed.length; i++) {
       if (fixed[i] == '{') openBraces++;
       if (fixed[i] == '}') openBraces--;
     }
     
     // Eksik kapatma parantezlerini ekle
     while (openBraces > 0) {
       fixed += '}';
       openBraces--;
     }
     
     // Eksik kapatma tırnakları düzelt
     if (fixed.split('"').length % 2 == 0) {
       fixed += '"';
     }
     
     // Eksik virgülleri kontrol et ve düzelt (temel seviyede)
     if (!fixed.endsWith('}') && !fixed.endsWith(',') && !fixed.endsWith(']')) {
       if (fixed.contains(':') && !fixed.endsWith('"')) {
         fixed += '"';
       }
     }
     
     return fixed;
   }


 }