import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/analysis_result_model.dart';
import '../models/user_model.dart';
import '../models/relationship_quote.dart';
import 'logger_service.dart';

class AiService {
  final LoggerService _logger = LoggerService();
  
  // Gemini API anahtarını ve ayarlarını .env dosyasından alma
  String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get _geminiModel => dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.0-flash';
  int get _geminiMaxTokens => int.tryParse(dotenv.env['GEMINI_MAX_TOKENS'] ?? '1024') ?? 1024;
  String get _geminiApiUrl => 'https://generativelanguage.googleapis.com/v1/models/$_geminiModel:generateContent?key=$_geminiApiKey';

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
      
      // API anahtarını kontrol et
      if (_geminiApiKey.isEmpty) {
        _logger.e('Gemini API anahtarı bulunamadı. .env dosyasını kontrol edin.');
        throw Exception('API anahtarı eksik veya geçersiz. Lütfen .env dosyasını kontrol edin ve GEMINI_API_KEY değerini ayarlayın.');
      }
      
      // Mesajın uzunluğunu kontrol et
      if (messageContent.length > 12000) {
        _logger.w('Mesaj içeriği çok uzun (${messageContent.length} karakter). Kısaltılıyor...');
        messageContent = "${messageContent.substring(0, 12000)}...";
      }
      
      // OCR metni ve Görsel Analizi işleme biçimini modernize edelim
      final bool isImageAnalysis = messageContent.contains("Görsel Analizi:");
      final bool hasOcrText = messageContent.contains("---- OCR Metni ----") && 
                             messageContent.contains("---- OCR Metni Sonu ----");
      
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
      
      final bool hasConversationParts = messageContent.contains("---- Mesaj içeriği ----") &&
                                       messageContent.contains("Konuşmacı:");
      
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
        Sen bir ilişki analiz uzmanı olmasına rağmen, yakın bir arkadaş gibi davranıyorsun. Kullanıcıya asla bir uzman gibi cevap verme, bir arkadaş olarak cevap ver. 
        Resmi dilden ve profesyonel söylemlerden kaçın. Samimi, empatik ve sıcak bir yaklaşım sergile.
        
        ÖNEMLİ KURALLAR:
        1. Analizi yapan kişi, mesajın bir tarafıdır. Yani "ilk kişi" ya da "ikinci kişi" gibi ifadeler KULLANMA.
        2. Cevabında kullanıcıya doğrudan "sen" diye hitap et.
        3. Mesajlardaki taraf ayrımı şuna dayanır: Görselde analiz yapan kişinin mesajları genelde sağda, karşı tarafın mesajları solda olur. Fakat bunu analizde açıkça yazma.
        4. "Senin mesajlarında...", "karşı taraf şu şekilde davranıyor..." gibi kişisel ve direkt ifadeler kullan.
        5. "Sağdaki/soldaki", "ilk/ikinci kişi", gibi ifadeleri kesinlikle kullanma. Analizi yapan kişinin kendisiyle konuşuyorsun.
        6. Analiz sıcak, empatik ve arkadaşça olmalı. Resmi dilden kaçın.
        
        Aşağıdaki ilişki mesajının analizini yap:
        
        1. Mesajdaki baskın duyguyu belirle
        2. Mesajın arkasındaki niyeti anlamaya çalış
        3. İletişimin tonunu belirle (samimi, resmi, agresif, sevecen, vb.)
        4. Mesajın ciddiyetini 1-10 arası derecelendir (10 en ciddi)
        5. Mesajda konuşan kişileri belirlemeye çalış - Sen ve karşındaki olarak düşün
        6. Mesajla ilgili dostça ve empatik bir yorum yap
        7. Mesaja nasıl yaklaşılması gerektiğine dair somut ve uygulanabilir öneriler sun
        
        Cevabını şu format içinde, ama bir arkadaş gibi konuşarak hazırla:
        
        {
          "duygu": "mesajdaki baskın duygu",
          "niyet": "mesajın arkasındaki niyet",
          "ton": "iletişim tonu",
          "ciddiyet": "1-10 arası rakam",
          "kişiler": "Sen ve karşındaki kişi",
          "mesajYorumu": "mesaj hakkında arkadaşça, empatik bir yorum. Kesinlikle 'Sen' diye hitap et, 'siz' değil. Günlük konuşma diline uygun ifadeler kullan.",
          "cevapOnerileri": [
            "Karşındaki kişiye şöyle cevap verebilirsin: '[somut bir cevap örneği]'. Bu yaklaşım iletişimi güçlendirecek.",
            "Son mesajın yerine şöyle bir şey yazabilirsin: '[örnek yanıt]'. Bu yanıt karşındaki kişinin seni anlamasını kolaylaştırır.",
            "Karşı tarafın mesajlarına yanıt verirken şu tekniği kullanabilirsin: '[belirli bir teknik]'. Şöyle diyebilirsin: '[örnek yanıt]'."
          ]
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
      
      // HTTP isteği için timeout ekle
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.e('Gemini API istek zaman aşımına uğradı');
          throw Exception('API yanıt vermedi, lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.');
        },
      );
      
      _logger.d('API yanıtı alındı - status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Yanıtı ayrı bir metoda çıkararak UI thread'in bloke olmasını engelle
        return _processApiResponse(response.body);
      } else {
        _logger.e('API hatası: ${response.statusCode}', response.body);
        throw Exception('Analiz API hatası: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Mesaj analizi hatası', e);
      rethrow;
    }
  }

  // API yanıtını işleme - UI thread'i blokelemeden çalışır
  AnalysisResult? _processApiResponse(String responseBody) {
    try {
      // Uzun JSON işleme
      final Map<String, dynamic> data = jsonDecode(responseBody);
      final String? aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      
      if (aiContent == null || aiContent.isEmpty) {
        _logger.e('AI yanıtı boş veya beklenen formatta değil');
        return null;
      }
      
      // JSON içindeki JSON string'i ayıkla
      final jsonStart = aiContent.indexOf('{');
      final jsonEnd = aiContent.lastIndexOf('}') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0 || jsonStart >= jsonEnd) {
        _logger.e('JSON yanıtında geçerli bir JSON formatı bulunamadı', aiContent);
        
        // Fallback sonuç döndür, iletişim kurma
        return AnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          emotion: 'Belirtilmemiş',
          intent: 'Belirtilmemiş',
          tone: 'Belirtilmemiş',
          severity: 5,
          persons: 'Belirtilmemiş',
          aiResponse: {
            'mesajYorumu': 'Analiz sırasında teknik bir sorun oluştu. Lütfen tekrar deneyiniz.',
            'cevapOnerileri': ['Mesajı tekrar gönderin veya farklı bir mesaj ile analiz yapın.']
          },
          createdAt: DateTime.now(),
        );
      }
      
      // API yanıtından JSON kısmını ayıkla
      String jsonStr = aiContent.substring(jsonStart, jsonEnd);
      
      // JSON yanıtını işle
      Map<String, dynamic> analysisJson = jsonDecode(jsonStr);
      
      // Analiz sonucunu oluştur
      final result = AnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        emotion: analysisJson['duygu'] ?? 'Belirtilmemiş',
        intent: analysisJson['niyet'] ?? 'Belirtilmemiş',
        tone: analysisJson['ton'] ?? 'Belirtilmemiş',
        severity: int.tryParse(analysisJson['ciddiyet']?.toString() ?? '5') ?? 5,
        persons: analysisJson['kişiler']?.toString() ?? 'Belirtilmemiş',
        aiResponse: analysisJson,
        createdAt: DateTime.now(),
      );
      
      _logger.i('Analiz tamamlandı: ${result.emotion}, ${result.intent}, ${result.tone}');
      return result;
    } catch (e) {
      _logger.e('API yanıtı işlenirken hata oluştu', e);
      return null;
    }
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

  // Metinden dizi çıkarma
  List<String>? _extractArrayFromText(String text, String fieldName) {
    try {
      // JSON içinde dizi formatı: "fieldName": [ "item1", "item2" ]
      final RegExp regex = RegExp('"$fieldName"\\s*:\\s*\\[(.*?)\\]', caseSensitive: false, dotAll: true);
      final match = regex.firstMatch(text);
      
      if (match != null && match.group(1) != null) {
        final String arrayContent = match.group(1)!;
        // Dizideki itemları ayrıştır - tırnak işaretleri içindeki metinleri bul
        final RegExp itemRegex = RegExp('"(.*?)"', dotAll: true);
        final matches = itemRegex.allMatches(arrayContent);
        
        if (matches.isNotEmpty) {
          return matches
              .map((m) => m.group(1))
              .where((item) => item != null)
              .map((item) => item!.trim())
              .toList();
        }
      }
      
      // Regex ile bulunamazsa, basit bir yaklaşım dene
      if (text.contains(fieldName)) {
        final parts = text.split(fieldName);
        if (parts.length > 1) {
          // Alanın bulunduğu satırdan sonraki 3 satırı al (muhtemelen öneri içerir)
          final nextLines = parts[1].split('\n').take(5).toList();
          return nextLines
              .where((line) => line.contains('-') || line.contains('*'))
              .map((line) => line.replaceAll(RegExp(r'^[- *]+'), '').trim())
              .where((line) => line.isNotEmpty)
              .toList();
        }
      }
      
      return null;
    } catch (e) {
      _logger.e('Dizi çıkarma hatası: $e');
      return null;
    }
  }
  
  // Metinden alan çıkarma
  String? _extractFieldFromText(String text, String fieldName) {
    final RegExp regex = RegExp('"$fieldName"\\s*:\\s*"([^"]*)"', caseSensitive: false);
    final match = regex.firstMatch(text);
    final value = match?.group(1)?.trim();
    _logger.d('$fieldName alanı çıkarıldı: $value');
    return value;
  }
  
  // Metinden sayısal alan çıkarma
  int? _extractNumericFieldFromText(String text, String fieldName) {
    final RegExp regex = RegExp('"$fieldName"\\s*:\\s*(\\d+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match == null) {
      // Alternatif regex - tırnak içinde sayı olabilir
      final altRegex = RegExp('"$fieldName"\\s*:\\s*"(\\d+)"', caseSensitive: false);
      final altMatch = altRegex.firstMatch(text);
      final altValue = altMatch?.group(1);
      final numericValue = altValue != null ? int.tryParse(altValue) : null;
      return numericValue ?? 5; // Varsayılan değer
    }
    
    final value = match.group(1);
    final numericValue = value != null ? int.tryParse(value) : null;
    return numericValue ?? 5; // Varsayılan değer
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
  
  // Metinden JSON çıkarma
  Map<String, dynamic>? _parseJsonFromText(String text) {
    _logger.d('JSON metni ayrıştırılıyor: $text');
    
    // Gereksiz bloklardan temizle
    String jsonText = text;
    if (jsonText.contains('```json')) {
      jsonText = jsonText.split('```json')[1].split('```')[0].trim();
    } else if (jsonText.contains('```')) {
      jsonText = jsonText.split('```')[1].split('```')[0].trim();
    }
    
    try {
      return jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (e) {
      _logger.e('JSON ayrıştırma hatası', e);
      return null;
    }
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

  // Mesaj Koçu - mesaj analizi
  Future<Map<String, dynamic>> getMesajKocuAnalizi(String messageText) async {
    _logger.d('Mesaj analizi istendi');
    
    if (messageText.isEmpty) {
      return {'error': 'Mesaj boş olamaz'};
    }
    
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return {'error': 'API anahtarı bulunamadı'};
    }
    
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': '''
              Sen profesyonel bir mesaj koçusun. Kullanıcının sana gönderdiği mesajlaşma içeriğini analiz ederek aşağıdaki bilgileri içeren bir JSON oluşturmalısın:
              
              1. Mesaj etki yüzdeleri - Mesajlaşmanın duygusal etkisini yüzdelik dilimlerle analiz et (örn. %56 sempatik, %30 kararsız, %14 endişeli). Yüzdelerin toplamı 100 olmalı.
              2. Anlık tavsiye - Kullanıcıya hemen yapması gereken eylem (yazmalı mı, beklemeli mi, farklı bir yaklaşım mı göstermeli).
              3. Yeniden yazım önerisi - Eğer mesajlar kullanıcıya aitse, daha etkili nasıl yazabileceğini göster.
              4. Karşı taraf yorumu - Karşı tarafın mesajlaşma tarzı (kısa kesiyor mu, ilgisiz mi, flörtöz mü, soğuk mu?).
              5. Strateji önerisi - İlişki dinamiğini iyileştirmek için izlenmesi gereken yol.
              
              Yanıtını aşağıdaki JSON formatında ver:
              {
                "effect": {
                  "sempatik": 56,
                  "kararsız": 30,
                  "endişeli": 14
                },
                "anlikTavsiye": "Şu an yazmalı mısın, beklemeli misin",
                "rewrite": "Şu mesajı şöyle yazarsan daha etkili olur...",
                "karsiTarafYorumu": "Karşı tarafın mesajlaşma tarzı hakkında detaylı yorum...",
                "strategy": "İlişki dinamiğini iyileştirmek için şunları yapabilirsin...",
                "analiz": "Genel bir mesajlaşma analizi",
                "öneriler": [
                  "Somut bir iletişim önerisi 1",
                  "Somut bir iletişim önerisi 2",
                  "Somut bir iletişim önerisi 3"
                ]
              }
              
              İlişki türüne göre (romantik, arkadaşlık, iş, aile vb.) ve mesajlaşma içeriğine göre analizini derinleştir. 
              Karşı tarafın yazdıkları hakkında özellikle detaylı içgörü sun.
              Pratik ve uygulanabilir tavsiyeler ver.
              "Effect" değerleri tam sayı olmalı ve toplamı 100'e eşit olmalı.
              Sadece JSON formatında yanıt ver, başka açıklama yapma.
              '''
            },
            {
              'role': 'user',
              'content': messageText
            }
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? aiContent = data['choices']?[0]?['message']?['content'];
        
        if (aiContent == null || aiContent.isEmpty) {
          _logger.e('API yanıtı boş veya beklenen formatta değil', data);
          return {'error': 'Analiz sonucu alınamadı'};
        }
        
        _logger.d('API yanıt metni: $aiContent');
        
        // JSON yanıtını ayrıştır
        try {
          final Map<String, dynamic>? jsonMap = _parseJsonFromText(aiContent);
          
          if (jsonMap != null) {
            return jsonMap;
          } else {
            // JSON ayrıştılamazsa metin tabanlı veri çıkarma yöntemlerini kullan
            final iliskiTipi = _extractRelationshipType(aiContent);
            final oneriler = _extractSuggestions(aiContent);
            
            return {
              'ilişki_tipi': iliskiTipi ?? 'belirlenemedi',
              'analiz': 'Mesaj analiz edildi',
              'öneriler': oneriler ?? <String>[],
              'effect': {'nötr': 100},
              'anlikTavsiye': 'Teknik bir sorun nedeniyle analiz tamamlanamadı. Lütfen tekrar deneyin.',
              'rewrite': 'Teknik bir sorun nedeniyle öneri oluşturulamadı.',
              'karsiTarafYorumu': 'Teknik bir sorun nedeniyle yorum yapılamadı.',
              'strategy': 'Teknik bir sorun nedeniyle strateji önerilemedi.'
            };
          }
        } catch (e) {
          _logger.e('JSON ayrıştırma hatası', e);
          return {'error': 'Analiz formatı geçersiz: $e'};
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return {'error': 'API yanıtı alınamadı: ${response.statusCode}'};
      }
    } catch (e) {
      _logger.e('Mesaj analizi hatası', e);
      return {'error': 'İstek sırasında hata oluştu: $e'};
    }
  }

  // İlişki durumu analizi yapma
  Future<Map<String, dynamic>> iliskiDurumuAnaliziYap(String userId, Map<String, dynamic> analizVerileri) async {
    _logger.i('İlişki durumu analizi yapılıyor', analizVerileri);
    
    try {
      // API anahtarını kontrol et
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return {'error': 'API anahtarı bulunamadı'};
      }

      // Analiz verileri temel kontrolü
      if (analizVerileri.isEmpty) {
        return {'error': 'Analiz verileri boş olamaz'};
      }

      // API isteği için veri hazırlama
      final messageText = 'İlişki analizi: ${analizVerileri.toString()}';
      
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '''
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
''',
            },
            {
              'role': 'user',
              'content': messageText,
            },
          ],
          'temperature': 0.7,
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? aiContent = data['choices']?[0]?['message']?['content'];
        
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
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return ['API anahtarı bulunamadı, tavsiyeler oluşturulamadı.'];
      }

      // API isteği için veri hazırlama
      final promptText = '''
İlişki puanı: $iliskiPuani
Kategori puanları: $kategoriPuanlari
Kullanıcı bilgileri: $kullaniciVerileri

Bu verilere dayanarak kişiselleştirilmiş tavsiyeler oluştur.
''';
      
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '''
İlişki koçu olarak görevin, kullanıcının ilişki puanı ve kategori puanlarına dayanarak kişiselleştirilmiş tavsiyeler oluşturmak.
5 adet kısa, uygulanabilir ve etkileyici tavsiye oluştur. Tavsiyeler doğrudan "sen" diliyle yazılmalı.
Yanıtını sadece tavsiye listesi olarak ver, JSON formatı kullanma, başka açıklama ekleme.
''',
            },
            {
              'role': 'user',
              'content': promptText,
            },
          ],
          'temperature': 0.8,
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? aiContent = data['choices']?[0]?['message']?['content'];
        
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
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return _getFallbackQuestions();
      }

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '''
İlişki uzmanı olarak görevin, ilişki değerlendirmesi için 10 adet anlamlı ve düşündürücü soru oluşturmak.
Sorular, ilişkinin farklı yönlerini (iletişim, güven, samimiyet, destek, uyum vb.) değerlendirmeli.
Yanıtını sadece soru listesi olarak ver, JSON formatı kullanma, başka açıklama ekleme.
''',
            },
            {
              'role': 'user',
              'content': 'İlişki değerlendirmesi için 10 adet farklı konularda soru oluştur.',
            },
          ],
          'temperature': 0.7,
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? aiContent = data['choices']?[0]?['message']?['content'];
        
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
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return [{'error': 'API anahtarı bulunamadı'}];
      }

      // Metin çok uzunsa kısalt
      final String kisaltilmisSohbet = sohbetMetni.length > 15000 
          ? sohbetMetni.substring(0, 15000) + "... (sohbet kesildi)"
          : sohbetMetni;

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '''
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

Başlıklar kısa ve çarpıcı, yorumlar ise detaylı ve eğlenceli olmalı. İstatistikler ve yorumlar, Spotify Wrapped stilinde esprili ve kişiselleştirilmiş bir dille yazılmalı.
''',
            },
            {
              'role': 'user',
              'content': kisaltilmisSohbet,
            },
          ],
          'temperature': 0.8,
        }),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? aiContent = data['choices']?[0]?['message']?['content'];
        
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
}