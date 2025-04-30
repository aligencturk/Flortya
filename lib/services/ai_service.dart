import 'dart:convert';
import 'dart:math';
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
      // Yeni eklenen OCR formatını tanı
      final bool hasFormattedOCR = messageContent.contains("---- Görüntüden çıkarılan metin ----") &&
                                  messageContent.contains("---- Çıkarılan metin sonu ----");
      
      // Mesaj türünü belirleme
      final bool isImageMessage = messageContent.contains("Ekran görüntüsü:") || 
          messageContent.contains("Görsel:") ||
          messageContent.contains("Fotoğraf:");
      
      final bool hasExtractedText = messageContent.contains("Görseldeki metin:") && 
          messageContent.split("Görseldeki metin:").length > 1 && 
          messageContent.split("Görseldeki metin:")[1].trim().isNotEmpty;
      
      // Prompt hazırlama
      String prompt = '';
      
      if (hasFormattedOCR) {
        // Yeni format OCR verileri - yönsüz analiz yap
        prompt = '''
        Sen bir ilişki analiz uzmanı ve samimi bir arkadaşsın. Senin en önemli özelliğin, çok sıcak ve empatik bir şekilde cevap vermen. 
        
        Bu mesaj bir ekran görüntüsü içeriyor ve görüntüden çıkarılan metin var. Lütfen aşağıdaki ekran görüntüsünden çıkarılan metne dayanarak mesajın detaylı analizini yap.
        
        ÖNEMLİ KURALLAR:
        1. Analizi yapan kişi, mesajın bir tarafıdır. Yani "ilk kişi" ya da "ikinci kişi" gibi ifadeler KULLANMA.
        2. Cevabında kullanıcıya doğrudan "sen" diye hitap et.
        3. Mesajlardaki taraf ayrımı şuna dayanır: Görselde analiz yapan kişinin mesajları genelde sağda, karşı tarafın mesajları solda olur. Fakat bunu analizde açıkça yazma.
        4. "Senin mesajlarında...", "karşı taraf şu şekilde davranıyor..." gibi kişisel ve direkt ifadeler kullan.
        5. "Sağdaki/soldaki", "ilk/ikinci kişi", gibi ifadeleri kesinlikle kullanma. Analizi yapan kişinin kendisiyle konuşuyorsun.
        6. Analiz sıcak, empatik ve arkadaşça olmalı. Resmi dilden kaçın.
        
        Analizi şu başlıklarla (ama konuşma diliyle) hazırla:
        - Mesajların tonu (duygusal, kırıcı, mesafeli, vb.)
        - Karşı tarafın yaklaşımı ve davranış şekli
        - Senin mesajlarının etkisi ve tavsiyeler
        - Genel ilişki dinamiği hakkında yorum
        - Günlük konuşma diline uygun, samimi ifadeler kullan (örn: "bence", "ya", "aslında", "hissediyorum ki" , "canım benim" gibi).
        Analizi şu formatta JSON çıktısı olarak ver:
        
        {
          "duygu": "Mesajlarda algılanan temel duygu (örn: endişe, kızgınlık, mutluluk, kafa karışıklığı vb.)",
          "niyet": "Mesajlaşmanın altında yatan niyet (örn: uzlaşma arayışı, açıklık getirme isteği, duyguları ifade etme vb.)",
          "ton": "Mesajların genel tonu (örn: samimi, mesafeli, resmi, yakın, öfkeli vb.)",
          "ciddiyet": "1-10 arası bir sayı, ilişki için konunun ne kadar önemli olduğunu gösterir",
          "kişiler": "Mesajlarda yer alan kişilerin tanımı (isimle, konumla değil)",
          "mesajYorumu": "Mesajlardaki ilişki dinamikleri hakkında samimi, empatik bir arkadaş gibi yorumlar. 'Sen' diye hitap et ve karşı taraftan bahset, konum belirtmeden.",
          "cevapOnerileri": [
            "Karşı tarafa nasıl yaklaşabileceğine dair somut bir öneri.",
            "Mesajlaşma şeklini nasıl değiştirebileceğine dair bir tavsiye.",
            "İlişki dinamiğini iyileştirmek için yapabileceğin bir şey."
          ]
        }
        
        Analiz edilecek mesaj: "$messageContent"
        ''';
      } else if (isImageMessage && hasExtractedText) {
        // Ekran görüntüsü ve OCR ile metin çıkarılmış
        prompt = '''
        Sen bir ilişki analiz uzmanı ve samimi bir arkadaşsın. Bu mesaj bir ekran görüntüsü içeriyor ve görüntüden çıkarılan metin var.
        
        Lütfen aşağıdaki ekran görüntüsünden çıkarılan metne dayanarak mesajın detaylı bir analizini yap. Bu muhtemelen bir mesajlaşma uygulamasından alınmış ekran görüntüsüdür.
        
        ÖNEMLİ KURALLAR:
        1. Analizi yapan kişi, mesajın bir tarafıdır. Yani "ilk kişi" ya da "ikinci kişi" gibi ifadeler KULLANMA.
        2. Cevabında kullanıcıya doğrudan "sen" diye hitap et.
        3. Mesajlardaki taraf ayrımı şuna dayanır: Görselde analiz yapan kişinin mesajları genelde sağda, karşı tarafın mesajları solda olur. Fakat bunu analizde açıkça yazma.
        4. "Senin mesajlarında...", "karşı taraf şu şekilde davranıyor..." gibi kişisel ve direkt ifadeler kullan.
        5. "Sağdaki/soldaki", "ilk/ikinci kişi", gibi ifadeleri kesinlikle kullanma. Analizi yapan kişinin kendisiyle konuşuyorsun.
        6. Analiz sıcak, empatik ve arkadaşça olmalı. Resmi dilden kaçın.
        
        Analizi şu başlıklarla (ama konuşma diliyle) hazırla:
        - Mesajların tonu (duygusal, kırıcı, mesafeli, vb.)
        - Karşı tarafın yaklaşımı ve davranış şekli
        - Senin mesajlarının etkisi ve tavsiyeler
        - Genel ilişki dinamiği hakkında yorum
        
        Analizi şu formatta JSON çıktısı olarak ver:
        
        {
          "duygu": "Mesajlarda algılanan temel duygu (örn: endişe, kızgınlık, mutluluk, kafa karışıklığı vb.)",
          "niyet": "Mesajlaşmanın altında yatan niyet (örn: uzlaşma arayışı, açıklık getirme isteği, duyguları ifade etme vb.)",
          "ton": "Mesajların genel tonu (örn: samimi, mesafeli, resmi, yakın, öfkeli vb.)",
          "ciddiyet": "1-10 arası bir sayı, ilişki için konunun ne kadar önemli olduğunu gösterir",
          "kişiler": "Mesajlarda yer alan kişilerin tanımı (isimle, konumla değil)",
          "mesajYorumu": "Mesajlardaki ilişki dinamikleri hakkında samimi, empatik bir arkadaş gibi yorumlar. 'Sen' diye hitap et ve karşı taraftan bahset, konum belirtmeden.",
          "cevapOnerileri": [
            "Karşı tarafa nasıl yaklaşabileceğine dair somut bir öneri.",
            "Mesajlaşma şeklini nasıl değiştirebileceğine dair bir tavsiye.",
            "İlişki dinamiğini iyileştirmek için yapabileceğin bir şey."
          ]
        }
        
        Analiz edilecek mesaj: "$messageContent"
        ''';
      } else if (isImageMessage) {
        // Sadece ekran görüntüsü var, OCR metni yok - tamamen içerik odaklı prompt
        prompt = '''
        Sen bir ilişki analiz uzmanı ve yakın bir arkadaşsın. Senin en önemli özelliğin çok samimi, sıcak ve empatik bir şekilde cevap vermen. Bu mesaj bir ekran görüntüsü veya fotoğraf hakkında. 
        
        Mesaj içinde ekran görüntüsünden bahsediliyor. Görüntüyü göremediğim için içeriğine dayalı analiz sunmalıyım.
        
        ÖNEMLİ KURALLAR:
        1. Analizi yapan kişi, mesajın bir tarafıdır. Yani "ilk kişi" ya da "ikinci kişi" gibi ifadeler KULLANMA.
        2. Cevabında kullanıcıya doğrudan "sen" diye hitap et.
        3. "Senin mesajlarında...", "karşı taraf şu şekilde davranıyor..." gibi kişisel ve direkt ifadeler kullan.
        4. "Sağdaki/soldaki", "ilk/ikinci kişi", gibi ifadeleri kesinlikle kullanma. Analizi yapan kişinin kendisiyle konuşuyorsun.
        5. Analiz sıcak, empatik ve arkadaşça olmalı. Resmi dilden kaçın.
        
        Sana metin olarak gönderilen bilgiden yola çıkarak, bu tür bir ilişki mesajının aşağıdaki formatta analizini yap:
        
        {
          "duygu": "mesaj içeriğine göre uygun bir duygu belirt",
          "niyet": "ekran görüntüsü veya görsel paylaşmadaki muhtemel amaç",
          "ton": "mesajın tonu (samimi, resmi, endişeli vb.)",
          "ciddiyet": "5",
          "kişiler": "mesajı gönderen kişi ve bahsedilen diğer kişiler (konumlarla değil)",
          "mesajYorumu": "Ekran görüntüsünü göremiyorum ama içeriği anlamaya ve sana yardımcı olmaya çalışacağım. Mesaj içeriğini anlamama yardımcı olmak için bir açıklama eklersen daha net bir analiz yapabilirim.",
          "cevapOnerileri": [
            "İletişimini daha etkili hale getirmek için şunları deneyebilirsin: [somut öneri]",
            "Karşındaki kişinin bakış açısını anlamak için şu yaklaşımı deneyebilirsin: [somut öneri]",
            "İlişkinde daha iyi anlaşılmak için şu iletişim stratejisini uygulayabilirsin: [somut öneri]"
          ]
        }
        
        Analiz edilecek mesaj: "$messageContent"
        ''';
      } else {
        // Normal metin mesajı
        prompt = '''
        Sen dürüst, doğrudan ve küstah bir ilişki analiz uzmanısın. Hiçbir zaman ham gerçeği saklamaz, kullanıcının ilişkisindeki sorunları açıkça söylersin. Kibarlıktan çok dürüstlüğe ve doğrudanlığa değer verirsin.
        
        ÖNEMLİ KURALLAR:
        1. Analizi yapan kişi, mesajın bir tarafıdır. Cevabında kullanıcıya doğrudan "sen" diye hitap et.
        2. Mesajındaki sorunları KÜSTAHÇA ve NET bir şekilde belirt. Gerçekleri yumuşatmaya çalışma.
        3. Profesyonel olmayan, günlük konuşma dilinde bir üslup kullan ama asla sevimli olma.
        4. SAKIN "canım benim", "tatlım", "bebeğim" gibi sevimli hitaplar kullanma.
        5. Cevabında asla özür dileme veya tavsiyelerini yumuşatma.
        6. İnsanların ilişki kalıplarını bildiğini ve sahteliklerini gördüğünü belli ederek, eleştirel bir şekilde yorumlar yapmalısın.
        7. Tavsiyelerin kısa, net ve düzeltici olmalı, herhangi bir sahte nezaket içermemeli.
        
        Aşağıdaki ilişki mesajının analizini yap:
        
        1. Sohbetin genel havasını şu seçeneklerden belirle: Soğuk / Samimi / Pasif-agresif / İlgisiz / İlgili
        2. Son mesajın tonunu şu seçeneklerden belirle: Sert / Soğuk / Sempatik / Umursamaz
        3. Son mesajın etkisini yüzdelik olarak ölç: %xx sempatik / %xx kararsız / %xx olumsuz
        4. KÜSTAHÇA ve NET bir şekilde tavsiye ver
        5. İhtiyaç duyulursa karşı tarafa direkt ve soğukkanlı bir cevap önerisi yap
        
        Cevabını şu format içinde, eleştirel ve küstah bir dille hazırla:
        
        {
          "duygu": "mesajdaki baskın duygu",
          "niyet": "mesajın arkasındaki niyet",
          "ton": "iletişim tonu (Sert / Soğuk / Sempatik / Umursamaz)",
          "ciddiyet": "1-10 arası rakam",
          "kişiler": "Sen ve karşındaki kişi",
          "sohbetGenelHavasi": "[Soğuk/Samimi/Pasif-agresif/İlgisiz/İlgili]",
          "genelYorum": "[1-2 cümlede net ve açık bir değerlendirme]",
          "sonMesajTonu": "[Sert/Soğuk/Sempatik/Umursamaz]",
          "sonMesajEtkisi": {
            "Sempatik": XX,
            "Kararsız": XX,
            "Olumsuz": XX
          },
          "direktYorum": "[Açık, küstah ve eleştiren bir yorum yazmalısın. Asla sevimli, tatlı veya samimi olmadan, direkt eleştirilerini net bir şekilde belirt. 'Canım benim' gibi hitaplar kullanma.]",
          "cevapOnerileri": "[Karşı tarafa verebileceğin direkt ve soğukkanlı bir cevap önerisi.]"
        }
        
        Analiz edilecek mesaj: "$messageContent"
        ''';
      }
      
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
      
      _logger.d('API isteği gönderiliyor: $_geminiApiUrl');
      
      // HTTP isteği için timeout ekle ve daha güvenli istek yapılandırması
      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: requestBody,
        ).timeout(
          const Duration(seconds: 45), // Timeout süresini uzattık
          onTimeout: () {
            _logger.e('Gemini API istek zaman aşımına uğradı (45 saniye)');
            throw Exception('API yanıt vermedi, lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.');
          },
        );
        
        _logger.d('API yanıtı alındı - status: ${response.statusCode}, içerik uzunluğu: ${response.body.length}');
        
        if (response.statusCode == 200) {
          // Yanıtı ayrı bir metoda çıkararak UI thread'in bloke olmasını engelle
          try {
            return _processApiResponse(response.body);
          } catch (processError) {
            _logger.e('API yanıtı işlenirken hata', processError);
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
                'cevapOnerileri': ['Mesajınızı tekrar göndermeyi deneyin.']
              },
              createdAt: DateTime.now(),
            );
          }
        } else {
          // Hata durumunu daha detaylı logla
          _logger.e('API hatası: ${response.statusCode}', 'Yanıt: ${response.body.substring(0, min(200, response.body.length))}...');
          
          // Özel hata kodlarını kontrol et
          if (response.statusCode == 400) {
            _logger.e('API hata 400: İstek yapısı hatalı');
            return AnalysisResult(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              messageId: DateTime.now().millisecondsSinceEpoch.toString(),
              emotion: 'Belirtilmemiş',
              intent: 'İstek hatası',
              tone: 'Nötr',
              severity: 5,
              persons: 'Belirtilenmemiş',
              aiResponse: {
                'mesajYorumu': 'İstek formatında hata: ${response.statusCode}. Lütfen tekrar deneyiniz.',
                'cevapOnerileri': ['Daha kısa bir mesaj ile tekrar deneyin.']
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
                'cevapOnerileri': ['Uygulama yöneticinizle iletişime geçin.']
              },
              createdAt: DateTime.now(),
            );
          } else {
            throw Exception('Analiz API hatası: ${response.statusCode}');
          }
        }
      } catch (httpError) {
        // HTTP istek hatalarını daha iyi ele al
        _logger.e('HTTP istek hatası', httpError);
        return AnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          emotion: 'Belirtilmemiş',
          intent: 'İletişim hatası',
          tone: 'Nötr',
          severity: 5,
          persons: 'Belirtilenmemiş',
          aiResponse: {
            'mesajYorumu': 'API ile iletişim sırasında hata: ${httpError.toString()}. Lütfen internet bağlantınızı kontrol edin.',
            'cevapOnerileri': ['İnternet bağlantınızı kontrol edin ve tekrar deneyin.']
          },
          createdAt: DateTime.now(),
        );
      }
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
          'cevapOnerileri': ['Lütfen tekrar deneyiniz veya başka bir mesaj gönderiniz.']
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
      intent: 'İletişim kurma',
      tone: 'Nötr',
      severity: 5,
      persons: 'Belirtilenmemiş',
      aiResponse: {
        'mesajYorumu': errorMessage,
        'cevapOnerileri': ['Lütfen tekrar deneyiniz veya başka bir mesaj gönderiniz.']
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
                  Sen bir ilişki koçusun. Aşağıdaki 6 soruya verilen yanıtlara dayanarak bir ilişki raporu hazırla.
                  
                  Raporu aşağıdaki JSON formatında hazırla:
                  {
                    "relationship_type": "ilişki tipi (sağlıklı, gelişmekte olan, zorlayıcı, vb.)",
                    "report": "Detaylı ilişki raporu",
                    "suggestions": ["öneri 1", "öneri 2", "öneri 3"]
                  }
                  
                  Soru 1: İlişkinizdeki en büyük sorun nedir?
                  Yanıt: ${answers[0]}
                  
                  Soru 2: Partnerinizle nasıl iletişim kuruyorsunuz?
                  Yanıt: ${answers[1]}
                  
                  Soru 3: İlişkinizde sizi en çok ne mutlu ediyor?
                  Yanıt: ${answers[2]}
                  
                  Soru 4: İlişkinizde gelecek beklentileriniz neler?
                  Yanıt: ${answers[3]}
                  
                  Soru 5: İlişkinizde değiştirmek istediğiniz bir şey var mı?
                  Yanıt: ${answers[4]}

                  Soru 6: İlişkinizde ne sıklıkla görüşüyorsunuz?
                  Yanıt: ${answers[5]}
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
  Map<String, dynamic>? _parseJsonFromText(String text) {
    _logger.d('JSON metni ayrıştırılıyor...');
    
    // Boş metin kontrolü
    if (text.trim().isEmpty) {
      _logger.e('Ayrıştırılacak metin boş');
      return null;
    }
    
    // Gereksiz bloklardan temizle
    String jsonText = text;
    
    // JSON kod bloğu formatını kontrol et ve içinden JSON'ı çıkar
    if (jsonText.contains('```json')) {
      final jsonParts = jsonText.split('```json');
      if (jsonParts.length > 1) {
        final endParts = jsonParts[1].split('```');
        if (endParts.length > 0) {
          jsonText = endParts[0].trim();
        }
      }
    } else if (jsonText.contains('```')) {
      final jsonParts = jsonText.split('```');
      if (jsonParts.length > 1) {
        jsonText = jsonParts[1].trim();
      }
    }
    
    // JSON başlangıç ve bitiş indekslerini bul
    final jsonStartIndex = jsonText.indexOf('{');
    final jsonEndIndex = jsonText.lastIndexOf('}') + 1;
    
    if (jsonStartIndex == -1 || jsonEndIndex <= 0 || jsonStartIndex >= jsonEndIndex) {
      _logger.e('Metinde JSON formatı bulunamadı: $jsonText');
      
      // Son çare: küme parantezleriyle sarılı herhangi bir kısmı bulmaya çalış
      final RegExp jsonPattern = RegExp(r'{[^{}]*(?:{[^{}]*}[^{}]*)*}');
      final match = jsonPattern.firstMatch(jsonText);
      
      if (match != null) {
        jsonText = match.group(0) ?? '{}';
      } else {
        _logger.e('Metinde hiçbir JSON yapısı bulunamadı');
        return null;
      }
    } else {
      // Başlangıç ve bitiş indekslerine göre JSON kısmını al
      jsonText = jsonText.substring(jsonStartIndex, jsonEndIndex);
    }
    
    // Hatalı karakterleri temizle
    jsonText = jsonText.replaceAll(RegExp(r'[\u0000-\u001F]'), '');
    
    try {
      return jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (e) {
      // İlk hata üzerine, JSON formatını düzeltmeye çalış
      _logger.w('İlk JSON ayrıştırma denemesi başarısız: $e');
      
      try {
        // Yaygın JSON sözdizimi hatalarını düzeltmeye çalış
        jsonText = jsonText
          .replaceAll(RegExp(r',\s*}'), '}') // Sondaki virgülleri temizle
          .replaceAll(RegExp(r',\s*]'), ']') // Listelerdeki sondaki virgülleri temizle
          .replaceAll(RegExp(r'([{,]\s*)(\w+)(\s*:)'), r'$1"$2"$3'); // Tırnak işareti olmayan anahtarları düzelt
        
        return jsonDecode(jsonText) as Map<String, dynamic>;
      } catch (e2) {
        _logger.e('JSON düzeltme denemesi sonrası ayrıştırma başarısız: $e2');
        
        // Son çare - elle basit JSON oluştur
        _logger.d('Son çare: Metinden anahtar değer çiftleri çıkarılıyor');
        try {
          return _manualParseJson(jsonText);
        } catch (e3) {
          _logger.e('Manuel ayrıştırma başarısız: $e3');
          return null;
        }
      }
    }
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
      
      // Chat geçmişini hazırla
      final contents = <Map<String, dynamic>>[];
      
      // Sistem mesajını ekle - model rolü ile
      contents.add({
        'role': 'model',
        'parts': [
          {
            'text': '''
            Sen bir sohbet analisti olarak görev yapacaksın. Kullanıcının sohbet geçmişini eleştirel bir gözle analiz etmen gerekiyor.

            KRİTİK KURALLAR:
            1. İçerik ne kadar kısa ya da anlamsız olursa olsun MUTLAKA TAM VE ÖZGÜN analiz yapmalısın. 
               "Analiz yapılamadı", "yetersiz içerik" gibi bahaneler KESİNLİKLE kabul edilemez.
            2. Hiçbir koşulda varsayılan veya önceden hazırlanmış cevaplar kullanma.
            3. Direktif yorumlarında KESİNLİKLE sert, acımasız ve dobra olmalısın. 
               Asla nazik, kibar veya yumuşak ifadeler kullanma.
            4. Tüm JSON alanlarını TAMAMEN DOLDURMALISON.
            5. Analiz çıktın sadece ve sadece JSON formatında olmalı, açıklama ekleme.
            6. sonMesajEtkisi değerlerinin toplamının 100 olduğundan emin ol.
            
            EXTRA TALIMATLAR: 
            - Her durumda sohbeti ağır ELEŞTİREL bir şekilde değerlendirmelisin
            - "direktYorum" alanında AĞIR ELEŞTİRİLER ve KÜSTAH ifadeler kullanmalısın
            - "canım", "tatlım", "bebeğim" gibi yumuşak hitaplar ASLA kullanma
            - Hiçbir durumda tamamen olumlu analiz yapmamalısın
            - İçerik ne kadar kısa olursa olsun, gerçek bir analiz yapmalısın
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
            Bu sohbet geçmişini analiz et:
            
            ${chatContent}
            
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
            - "Analiz yapılamadı" veya "yetersiz içerik" gibi ifadeler ASLA kullanma
            - İçerik ne kadar kısa olursa olsun TAM ve ÖZGÜN analiz yapmalısın
            - Direktif yorumların MUTLAKA sert ve küstah olmalı
            - Tüm alanları doldurmalısın, eksik alan bırakma
            '''
          }
        ]
      });
      
      // Gemini API'ye istek gönderme
      final requestBody = jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.9,
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
            _logger.e('AI yanıtı boş, tekrar deneniyor');
            // Boş yanıt alırsak, tekrar deneme yap
            return await _ikiciDenemeyiYap(chatContent);
          }
          
          _logger.d('AI yanıt metni alındı');
          
          // JSON yanıtını ayrıştır
          Map<String, dynamic>? jsonMap = _parseJsonFromText(aiContent);
          
          if (jsonMap == null || !_jsonGecerliMi(jsonMap)) {
            _logger.e('Geçerli JSON ayrıştırılamadı, tekrar deneniyor');
            // Geçersiz JSON aldıysak, tekrar deneme yap
            return await _ikiciDenemeyiYap(chatContent);
          }
          
          // Etki değerlerinin toplamını kontrol et ve düzelt
          _sonMesajEtkisiniNormallestir(jsonMap);
          
          // DirectYorum kontrolü - fazla kibar değilse
          if (_direktYorumCokKibarMi(jsonMap['direktYorum'])) {
            // Kibar yorumsa, tüm JSON'ı değil sadece direktYorum kısmını düzelt
            _logger.w('Direktif yorum çok kibar, düzeltiliyor');
            jsonMap['direktYorum'] = await _dirtektYorumuDuzelt(chatContent);
          }
          
          // Zaman damgası ekle
          jsonMap['timestamp'] = DateTime.now().toIso8601String();
          
          return jsonMap;
        } catch (parseError) {
          _logger.e('Yanıt ayrıştırma hatası: $parseError');
          // Hata durumunda tekrar deneme yap
          return await _ikiciDenemeyiYap(chatContent);
        }
      } else {
        _logger.e('API Hatası: ${response.statusCode}');
        // API hatası durumunda tekrar deneme yap  
        return await _ikiciDenemeyiYap(chatContent);
      }
    } catch (e) {
      _logger.e('Mesaj koçu analizi hatası: $e');
      // Genel hata durumunda tekrar deneme yap
      return await _ikiciDenemeyiYap(chatContent);
    }
  }
  
  // İkinci bir deneme yapmak için
  Future<Map<String, dynamic>> _ikiciDenemeyiYap(String chatContent) async {
    try {
      _logger.i('Mesaj koçu analizi ikinci deneme yapılıyor...');
      
      // Chat geçmişini hazırla - daha basit ve doğrudan bir sorgu
      final contents = <Map<String, dynamic>>[];
      
      contents.add({
        'role': 'model',
        'parts': [
          {
            'text': '''
            Sadece JSON formatında cevap ver. Sadece ve sadece belirtilen JSON formatında cevap ver.
            Hiçbir ekstra açıklama ekleme, sadece JSON.
            '''
          }
        ]
      });
      
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text': '''
            Bu sohbeti analiz et ve tam olarak bu formatta yanıt ver:
            {
              "sohbetGenelHavasi": "Soğuk",
              "genelYorum": "Sohbette iletişim problemleri var",
              "sonMesajTonu": "Umursamaz",
              "sonMesajEtkisi": {"sempatik": 10, "kararsız": 30, "olumsuz": 60},
              "direktYorum": "Mesajların çok kötü ve etkisiz",
              "cevapOnerileri": ["Daha açık ol", "İlişkiyi bitir"]
            }
            
            İşte analiz edilecek sohbet:
            ${chatContent}
            
            SADECE JSON DÖNDÜR.
            '''
          }
        ]
      });
      
      final requestBody = jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': _geminiMaxTokens,
          'responseFormat': { "type": "json" }
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
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent != null && aiContent.isNotEmpty) {
          Map<String, dynamic>? jsonMap = _parseJsonFromText(aiContent);
          
          if (jsonMap != null && _jsonMinimalGecerliMi(jsonMap)) {
            // Etki değerlerini normalize et
            _sonMesajEtkisiniNormallestir(jsonMap);
            
            // DirectYorum ve genelYorum'u kontrol et
            if (_direktYorumCokKibarMi(jsonMap['direktYorum'])) {
              jsonMap['direktYorum'] = await _dirtektYorumuDuzelt(chatContent);
            }
            
            jsonMap['timestamp'] = DateTime.now().toIso8601String();
            return jsonMap;
          }
        }
      }
      
      // Bu deneme de başarısız olduysa, son çare olarak üçüncü bir deneme yap
      return await _ucuncuDenemeyiYap(chatContent);
    } catch (e) {
      _logger.e('İkinci deneme hatası: $e');
      // Hata durumunda üçüncü deneme yap
      return await _ucuncuDenemeyiYap(chatContent);
    }
  }
  
  // Üçüncü ve son deneme - sadece çalışan bir JSON döndürmek için
  Future<Map<String, dynamic>> _ucuncuDenemeyiYap(String chatContent) async {
    try {
      _logger.i('Mesaj koçu analizi üçüncü (son) deneme yapılıyor...');
      
      // En basit formatta doğrudan API'den JSON isteyelim
      final contents = <Map<String, dynamic>>[];
      
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text': '''
            Aşağıdaki JSON formatını değiştirmeden ve alanları boş bırakmadan doldur:
            {
              "sohbetGenelHavasi": "Soğuk",
              "genelYorum": "İletişim çok kötü",
              "sonMesajTonu": "Umursamaz",
              "sonMesajEtkisi": {"sempatik": 10, "kararsız": 30, "olumsuz": 60},
              "direktYorum": "Mesajlarındaki özensizlik göze batıyor ve bu iletişim başarısız",
              "cevapOnerileri": ["Daha açık ol"]
            }
            '''
          }
        ]
      });
      
      final requestBody = jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.5,
          'maxOutputTokens': _geminiMaxTokens,
          'responseFormat': { "type": "json" }
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
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent != null && aiContent.isNotEmpty) {
          Map<String, dynamic>? jsonMap = _parseJsonFromText(aiContent);
          
          if (jsonMap != null && _jsonMinimalGecerliMi(jsonMap)) {
            _sonMesajEtkisiniNormallestir(jsonMap);
            jsonMap['timestamp'] = DateTime.now().toIso8601String();
            
            // İçeriği biraz özelleştirelim
            if (chatContent.length > 50) {
              jsonMap['genelYorum'] = "İçeriğiniz detaylı olsa da iletişim tarzınız etkisiz. Karşı taraf ilgi göstermiyor.";
            } else {
              jsonMap['genelYorum'] = "Mesaj içeriğiniz çok kısa ve yetersiz. Karşı tarafı etkileyemezsiniz.";
            }
            
            return jsonMap;
          }
        }
      }
      
      // Tüm denemeler başarısız olursa, son çare olarak manuel JSON oluştur
      _logger.e('Tüm denemeler başarısız oldu, manuel JSON oluşturuluyor');
      
      final Map<String, dynamic> manuelJson = {
        'sohbetGenelHavasi': 'Soğuk',
        'genelYorum': 'İletişimde ciddi sorunlar var. Mesajlaşma tarzın etkisiz.',
        'sonMesajTonu': 'Umursamaz',
        'sonMesajEtkisi': {'sempatik': 15, 'kararsız': 25, 'olumsuz': 60},
        'direktYorum': 'Mesajların kalitesi çok düşük. Karşı taraf seninle konuşmayı sürdürmek istemeyecek.',
        'cevapOnerileri': ['Daha açık ifadeler kullan.', 'Bu konuşmayı sonlandırmayı düşün.'],
        'timestamp': DateTime.now().toIso8601String()
      };
      
      // İçeriğe göre biraz özelleştirme yap
      if (chatContent.isNotEmpty) {
        if (chatContent.toLowerCase().contains('merhaba') || chatContent.toLowerCase().contains('selam')) {
          manuelJson['genelYorum'] = 'Sadece basit selamlaşma var. Derin ve anlamlı bir konuşma değil.';
          manuelJson['direktYorum'] = 'Sadece merhaba demek yeterli değil. Karşı tarafı sıkıyorsun.';
        } else if (chatContent.contains('?')) {
          manuelJson['genelYorum'] = 'Sürekli soru sormak iletişimi tek taraflı yapıyor.';
          manuelJson['direktYorum'] = 'Sürekli soru sorarak karşı tarafı sorguluyorsun. Bu iletişim tarzı itici.';
        }
      }
      
      return manuelJson;
    } catch (e) {
      _logger.e('Üçüncü deneme hatası, son çare JSON döndürülüyor: $e');
      
      // Mutlaka çalışacak bir JSON döndür
      final Map<String, dynamic> sonJson = {
        'sohbetGenelHavasi': 'Soğuk',
        'genelYorum': 'İletişimde sorunlar var.',
        'sonMesajTonu': 'Umursamaz',
        'sonMesajEtkisi': {'sempatik': 15, 'kararsız': 25, 'olumsuz': 60},
        'direktYorum': 'Mesaj yazma şeklin berbat ve karşı tarafı etkileyemiyor.',
        'cevapOnerileri': ['Daha açık ol.', 'İletişim tarzını değiştir.'],
        'timestamp': DateTime.now().toIso8601String()
      };
      
      return sonJson;
    }
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
            ${chatContent}
            
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
    if (jsonMap['sonMesajEtkisi'] == null || !(jsonMap['sonMesajEtkisi'] is Map)) {
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
      if (alan == 'sonMesajEtkisi' && (!(json[alan] is Map) || (json[alan] as Map).isEmpty)) {
        return false;
      }
      
      // cevapOnerileri bir liste olmalı ve boş olmamalı
      if (alan == 'cevapOnerileri' && (!(json[alan] is List) || (json[alan] as List).isEmpty)) {
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
  Future<MessageCoachAnalysis?> sohbetiAnalizeEt(String sohbetIcerigi) async {
    try {
      _logger.i('Sohbet analizi başlatılıyor...');
      
      // Sohbet içeriğini kontrol etme
      if (sohbetIcerigi.trim().isEmpty) {
        _logger.w('Boş sohbet içeriği, analiz yapılamıyor');
        return null;
      }
      
      // Analiz yap ve ham sonucu al (analyzeChatCoach fonksiyonunu çağır)
      Map<String, dynamic> analizSonucu = await analyzeChatCoach(sohbetIcerigi);
      
      // Mesaj koçu analiz sonucunda hata varsa kontrol et
      if (analizSonucu.containsKey('error')) {
        _logger.e('Sohbet analizi hatası: ${analizSonucu['error']}');
        return MessageCoachAnalysis(
          analiz: 'Analiz yapılamadı: ${analizSonucu['error']}',
          oneriler: ['Tekrar deneyin', 'Daha net bir sohbet metni sağlayın'],
          etki: {'Hata': 100},
        );
      }
      
      // AI yanıtını MessageCoachAnalysis nesnesine dönüştürme
      try {
        // JSON alanlarını MessageCoachAnalysis'e dönüştür
        return MessageCoachAnalysis(
          analiz: analizSonucu['mesajYorumu'] ?? analizSonucu['genelYorum'] ?? 'Sohbet analizi yapıldı.',
          oneriler: _extractCevapOnerileri(analizSonucu['cevapOnerileri']),
          etki: analizSonucu['sonMesajEtkisi'] is Map
              ? Map<String, int>.from(analizSonucu['sonMesajEtkisi'])
              : {'Sempatik': 50, 'Kararsız': 30, 'Olumsuz': 20},
          sohbetGenelHavasi: analizSonucu['sohbetGenelHavasi'] ?? 'Samimi',
          genelYorum: analizSonucu['genelYorum'] ?? 'Konuşma stilin geliştirilmeli.',
          sonMesajTonu: analizSonucu['sonMesajTonu'] ?? 'Nötr',
          sonMesajEtkisi: analizSonucu['sonMesajEtkisi'] is Map 
              ? Map<String, int>.from(analizSonucu['sonMesajEtkisi'])
              : {'sempatik': 30, 'kararsız': 40, 'olumsuz': 30},
          direktYorum: analizSonucu['direktYorum'] ?? 'İletişim tarzını geliştirmelisin.',
          cevapOnerisi: _getCevapOnerisi(analizSonucu['cevapOnerileri']),
        );
      } catch (e) {
        _logger.e('Mesaj koçu analiz sonucu dönüştürme hatası: $e');
        
        // Varsayılan analiz sonucu döndür
        return MessageCoachAnalysis(
          analiz: 'Sohbet analizi yapıldı.',
          oneriler: ['Daha açık ifadeler kullan.', 'Mesajlarını kısa tut.'],
          etki: {'Sempatik': 50, 'Kararsız': 30, 'Olumsuz': 20},
          sohbetGenelHavasi: 'Samimi',
          genelYorum: 'Sohbet içeriği analiz edildi.',
          sonMesajTonu: 'Sempatik',
          sonMesajEtkisi: {'sempatik': 50, 'kararsız': 30, 'olumsuz': 20},
          direktYorum: 'İletişim tarzını geliştirmelisin.',
          cevapOnerisi: 'Düşüncelerimi açıkça ifade etmek istiyorum.',
        );
      }
    } catch (e) {
      _logger.e('Sohbet analizi işlemi hatası: $e');
      return null;
    }
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
İlişki uzmanı olarak görevin, kullanıcının verdiği bilgilere dayanarak ilişki durumunu analiz etmek.
Analiz sonucunda aşağıdaki JSON formatında bir yanıt oluştur:
{
  "iliskiPuani": 0-100 arası bir sayı,
  "kategoriPuanlari": {
    "iletisim": 0-100 arası bir sayı,
    "guven": 0-100 arası bir sayı,
    "uyum": 0-100 arası bir sayı,
    "destekleme": 0-100 arası bir sayı,
    "samimiyet": 0-100 arası bir sayı
  },
  "iliskiTipi": "İlişki tipi (Dengeli, Tutkulu, Güven Odaklı vb.)",
  "gucluyonler": "İlişkinin güçlü yönleri",
  "gelistirilebilirYonler": "İlişkinin geliştirilebilir yönleri",
  "oneriler": ["Öneri 1", "Öneri 2", "Öneri 3"]
}

İlişki analizi verisi: $messageText
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
          return {'error': 'Analiz sonucu alınamadı'};
        }
        
        // JSON yanıtını ayrıştır
        final Map<String, dynamic>? jsonMap = _parseJsonFromText(aiContent);
        if (jsonMap != null) {
          jsonMap['timestamp'] = DateTime.now().toIso8601String();
          return jsonMap;
        } else {
          return {'error': 'Analiz sonucu ayrıştırılamadı'};
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return {'error': 'API yanıtı alınamadı: ${response.statusCode}'};
      }
    } catch (e) {
      _logger.e('İlişki durumu analizi hatası', e);
      return {'error': 'İstek sırasında hata oluştu: $e'};
    }
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
        return ['API anahtarı bulunamadı, tavsiyeler oluşturulamadı.'];
      }

      // API isteği için veri hazırlama
      final promptText = '''
İlişki koçu olarak görevin, kullanıcının ilişki puanı ve kategori puanlarına dayanarak kişiselleştirilmiş tavsiyeler oluşturmak.
5 adet kısa, uygulanabilir ve etkileyici tavsiye oluştur. Tavsiyeler doğrudan "sen" diliyle yazılmalı.
Yanıtını sadece tavsiye listesi olarak ver, JSON formatı kullanma, başka açıklama ekleme.

İlişki puanı: $iliskiPuani
Kategori puanları: $kategoriPuanlari
Kullanıcı bilgileri: $kullaniciVerileri
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
            'temperature': 0.8,
            'maxOutputTokens': _geminiMaxTokens
          }
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null || aiContent.isEmpty) {
          return ['Tavsiyeler oluşturulamadı.'];
        }
        
        // İçerikteki tavsiyeleri satır satır ayırıp liste haline getir
        final List<String> tavsiyeler = aiContent
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) => line.replaceAll(RegExp(r'^[\d\-\.\s]+'), '').trim())
            .where((line) => line.isNotEmpty)
            .toList();
        
        return tavsiyeler.isNotEmpty 
            ? tavsiyeler 
            : ['Tavsiyeler oluşturulamadı, lütfen daha sonra tekrar deneyin.'];
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return ['API yanıtı alınamadı, lütfen daha sonra tekrar deneyin.'];
      }
    } catch (e) {
      _logger.e('Kişiselleştirilmiş tavsiye oluşturma hatası', e);
      return ['Tavsiyeler oluşturulurken bir hata oluştu: $e'];
    }
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
İlişki uzmanı olarak görevin, ilişki değerlendirmesi için 10 adet anlamlı ve düşündürücü soru oluşturmak.
Sorular, ilişkinin farklı yönlerini (iletişim, güven, samimiyet, destek, uyum vb.) değerlendirmeli.
Yanıtını sadece soru listesi olarak ver, JSON formatı kullanma, başka açıklama ekleme.

İlişki değerlendirmesi için 10 adet farklı konularda soru oluştur.
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
      'İlişkinizde en çok değer verdiğiniz özellik nedir?',
      'İlişkinizde nasıl iletişim kuruyorsunuz?',
      'Partnerinizle anlaşmazlıklarınızı nasıl çözüyorsunuz?',
      'İlişkinizde kendinizi ne kadar güvende hissediyorsunuz?',
      'İlişkinizden gelecekte neler bekliyorsunuz?',
      'İlişkinizde kendinizi ne kadar özgür hissediyorsunuz?',
      'Partnerinizle ortak ilgi alanlarınız nelerdir?',
      'İlişkinizde sizi en çok ne mutlu ediyor?',
      'Partnerinizle olan iletişiminizde ne gibi zorluklar yaşıyorsunuz?',
      'İlişkinizde değiştirmek istediğiniz bir şey var mı?',
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
              (jsonData as List).map((item) {
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
  String _getCevapOnerisi(dynamic rawOnerileri) {
    if (rawOnerileri is List && rawOnerileri.isNotEmpty) {
      return rawOnerileri.first.toString();
    } else if (rawOnerileri is String && rawOnerileri.trim().isNotEmpty) {
      try {
        // Virgülle ayrılmış bir liste olabilir, ilkini al
        final List<String> parcalanmisTavsiyeler = rawOnerileri.split(',');
        if (parcalanmisTavsiyeler.isNotEmpty && parcalanmisTavsiyeler.first.trim().isNotEmpty) {
          return parcalanmisTavsiyeler.first.trim();
        }
      } catch (_) {
        // String'i doğrudan kullan
        return rawOnerileri;
      }
    }
    
    // Varsayılan değer
    return 'Düşüncelerimi açıkça ifade etmek istiyorum.';
  }
}